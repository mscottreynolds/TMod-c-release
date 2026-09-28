module semantic()

(**
 * semantic.mc - Semantic analysis pass (phase 1: declaration collection).
 *
 * Walks the AST, builds scoped symbol tables, detects duplicate names.
 * Expression type-checking and const-expressions enforcement come later.
 *)


import Arena, arena_alloc, arena_append_ptr, ppvoid 
	from arena
import TSymbol, symbol_create, pTSymbol 
	from symbol
import 
	pTSymbolTable, TSymbolTable, symtab_lookup, symtab_lookup_current, symtab_define,
	symtab_refine_symbol, symtab_create, symtab_define_let 
	from symtab
import MhModule, MhExport, MhFormal, MhField, mh_path_is_mh, mh_strip_string_literal,
	mh_resolve_import_path, mh_reader_load, mh_module_find, mh_module_free, 
	mh_export_to_symkind, 
	from mh_reader
import SYM_KIND_LET, SYM_KIND_IMPORT, SYM_KIND_PARAM, SYM_KIND_PROC, SYM_KIND_FUNC,
	SYM_KIND_VAR, SYM_KIND_CONST, SYM_KIND_TYPE, SYM_KIND_UNKNOWN, SymbolKind,
	from symkind
import 
	pTType, type_create_named, type_is_builtin_name, type_is_portable_rebindable,
	type_copy_shell, TType,
	from ttype

import size_t from "stddef.h"
import memcmp, memcpy, strlen from "string.h"
import strtol, exit from "stdlib.h"
import strncasecmp from "strings.h"
import fprintf, snprintf, stderr from "stdio.h"

import TOK_NUMBER, TOK_ADD, TOK_SUB, TOK_MUL, TOK_DIV, 
	TOK_MOD, TOK_KEYWORD_MOD, TOK_REAL, TOK_CHAR, TOK_STRING,
	TOK_AT, TOK_CARET, TOK_BITWISE_AND, TOK_BITWISE_OR, TOK_BITWISE_NOT,
	TOK_BITWISE_LSHIFT, TOK_BITWISE_RSHIFT, TOK_POWER,
	TOK_KEYWORD_AND, TOK_KEYWORD_OR, TOK_KEYWORD_XOR, TOK_KEYWORD_NOT,
	TOK_KEYWORD_DIV, TOK_EQ_EQ, TOK_NOT_EQ, TOK_LESS, TOK_LESS_EQ,
	TOK_GREATER, TOK_GREATER_EQ, TokenKind, TOK_KEYWORD_MODULE, TToken,
	from Lexer
import 
	Node, NODE_IMPORT_ITEM, NODE_IMPORT, NODE_PARAM, NODE_IDENT, NODE_CALL,
	NODE_BINARY, NODE_UNARY, NODE_PAREN, NODE_CAST, NODE_TERNARY, NODE_ARRAY_INDEX,
	NODE_FIELD_ACCESS, NODE_SIZEOF, NODE_LITERAL, NODE_ARRAY_LITERAL, NODE_INC,
	NODE_DEC, NODE_VAR_DECL, NODE_CONST_DECL, NODE_LET_DECL, NODE_EXPR_STMT,
	NODE_ASSIGN, NODE_IF, NODE_FOR, NODE_WHILE, NODE_REPEAT_UNTIL, NODE_LOOP,
	NODE_RETURN, NODE_ASSERT, NODE_DEFER, NODE_DEBUG, NODE_SWITCH, NODE_BREAK,
	NODE_CONTINUE, NODE_DOC_COMMENT, NODE_PREPROCESSOR, NODE_BLOCK, NODE_PROC_DECL,
	NODE_FUNC_DECL, NODE_PARAM_LIST, NODE_PROGRAM, NODE_TYPE_DECL, NODE_VAR_ITEM,
	NODE_CONST_ITEM, NODE_LET_ITEM, NODE_STRUCT_DECL, NODE_FIELD_DECL,
	NODE_METHOD_TYPE, NODE_ARRAY_TYPE, NODE_ELSIF, NODE_ELSE, SwitchCase,
	NODE_ENUM_TYPE, NODE_ENUM_ITEM, node_create, node_print, NodeKind, NODE_DEFINE,
	NODE_LEN, from "node.h"


const SEMANTIC_MH_PATH_MAX: cardinal = 4096u


export type pNode = ^Node


(** Analysis context *)
export type TSemanticContext = struct
	arena:			^Arena
	scope: 			pTSymbolTable	// current lexical scope
	source_path:	const ^char		// compiling .mc path (for .mh resolve)
	for_var_name:	const ^char		// nil when not analyzing a FOR body
	for_var_len:	size_t
	// NODE_FUNC_DECL / NODE_PROC_DECL / NODE_PROGRAM while analyzing its body (return type).
	enclosing_func: pNode		
end


export type pTSemanticContext = ^TSemanticContext


(* Interim: struct return until VAR output parameters work in codegen *)
type TProcSymName = struct
	name:	const ^char
	length:	size_t
end

type TMethodChainHit = struct
	sym: 		pTSymbol
	owner: 		const ^char
	owner_len: 	size_t
	depth: 		size_t
	is_static: 	bool
end

type pcchar = const ^char

(* forward declare semantic_resolve_expr *)
recursive function semantic_type_of_designator(ctx: pTSemanticContext, n: pNode): pTType forward
recursive function semantic_type_of_expr(ctx: pTSemanticContext, n: pNode): pTType forward
function semantic_eval_const_expr(ctx: pTSemanticContext, n: pNode): integer forward
function semantic_try_eval_const_expr(ctx: pTSemanticContext, n: pNode, out_val: ^integer, msg: ^pcchar): bool forward
procedure semantic_resolve_expr(ctx: pTSemanticContext, n: pNode) forward
procedure semantic_analyze_block_body(ctx: pTSemanticContext, block: pNode) forward
function semantic_mangle_method(arena: ^Arena, owner: const ^char, owner_len: size_t,
	method: const ^char, method_len: size_t): ^char forward
function semantic_proc_sym_name(ctx: pTSemanticContext, decl: pNode): TProcSymName forward
function semantic_method_is_instance(ctx: pTSemanticContext, decl: pNode): bool forward
procedure semantic_verify_method_self(ctx: pTSemanticContext, decl: pNode) forward
function semantic_method_type_node(ctx: pTSemanticContext, ty: pTType): pNode forward
function semantic_field_type_on(ctx: pTSemanticContext, recv_ty: pTType,
		fname: const ^char, flen: size_t): pTType forward
function semantic_sym_is_method_value(ctx: pTSemanticContext, sym: pTSymbol): bool forward


(**
* Fatal semantic error with source location from the node's token.
*)
export procedure semantic_error_at(n: pNode, msg: const ^char)
begin
	if n <> nil then
		node_print(n, 0)
		fprintf(stderr, "ERROR: line %d col %d: %s\n", n^.token.line, n^.token.column, msg)
	else
		fprintf(stderr, "ERROR: %s\n", msg)
	end
	exit(1)
end


(**
 * Merge use-site qualifiers (^ / CONST) onto an already-resolved base type.
 *)
function type_apply_use_qualifiers(ctx: pTSemanticContext, use_ty: pTType, resolved_base: pTType): pTType
begin
	var result: pTType = nil

	if resolved_base == nil then
		return nil
	end

	result := type_copy_shell(ctx^.arena, resolved_base)

	if use_ty <> nil and use_ty^.is_const then
		result^.is_const := true
	end

	if use_ty <> nil and use_ty^.is_pointer then
		result^.is_pointer := true
	end

	return result
end type_apply_use_qualifiers


(**
 * Resolve type TType tree to its concrete form; return a new TType copy.
 * at = AST node for error location (may be nil).
 *)
recursive function semantic_resolve_type_inner(ctx: pTSemanticContext, ty: pTType, depth: size_t, at: pNode): pTType
begin
	var elem: pTType = nil
	var result: pTType = nil
	var sym: pTSymbol = nil
	var base: pTType = nil
	var resolved_base: pTType = nil

	if ty == nil then
		return nil
	end

	if depth > 64 then
		semantic_error_at(at, "semantic_resolve_type_inner: cicular type alias")
	end

	// // ARRAY[N] OF T or T[]
	// if ty^.is_array and ty^.element_type <> nil then
	// 	elem := semantic_resolve_type_inner(ctx, ty^.element_type, depth, at)
	// 	result := type_copy_shell(ctx^.arena, ty)
	// 	result^.element_type := elem
	// 	return result
	// end

	// ARRAY[N] of T or T[] (N may still be size_expr until folded)
	if ty^.is_array and ty^.element_type <> nil then
		elem := semantic_resolve_type_inner(ctx, ty^.element_type, depth, at)

		if ty^.size_expr <> nil then
			var sz: integer = 0
			sz := semantic_eval_const_expr(ctx, ty^.size_expr as pNode)
			if sz < 0 then
				semantic_error_at(at, "semantic_resolve_type_inner: array size must be non-negative")
			end
			ty^.array_size 	:= sz as size_t
			ty^.size_expr 	:= nil
		end

		result := type_copy_shell(ctx^.arena, ty)
		result^.element_type := elem
		return result
	end

	// // User TYPE name (not a grammar builtin)
	// if ty^.name <> nil and ty^.name_len > 0 and not type_is_builtin_name(ty^.name, ty^.name_len) then
	// 	sym := symtab_lookup(ctx^.scope, ty^.name, ty^.name_len)
	// 	if sym == nil then
	// 		// Opaque C type (FILE, size_t, ...) -- not insymtab until EXTERN/IMPORT TYPE
	// 		return type_copy_shell(ctx^.arena, ty)
	// 		// semantic_error_at(at, "semantic_resolve_type_inner: unknown type")
	// 	elsif sym^.kind <> SYM_KIND_TYPE then
	if ty^.name <> nil and ty^.name_len > 0 and not type_is_builtin_name(ty^.name, ty^.name_len) then
		sym := symtab_lookup(ctx^.scope, ty^.name, ty^.name_len)
		if sym == nil then
			// Multi-word C spellings (long long, unsigned int) -- prelude extras.
			// Single-word names must be IMPORT / EXTERN TYPE/ a TYPE decl.
			var i: size_t = 0
			var is_compound: bool = false
			while i < ty^.name_len do
				if ty^.name[i] == ' ' then
					is_compound := true
					break
				end
				i := i + 1
			end
			if not is_compound then
				semantic_error_at(at, "semantic_resolve_type_inner: unknown type")
			end
			return type_copy_shell(ctx^.arena, ty)
		elsif sym^.kind <> SYM_KIND_TYPE then
			if sym^.kind == SYM_KIND_IMPORT then
				return type_copy_shell(ctx^.arena, ty)
			end
			semantic_error_at(at, "semantic_resolve_type_inner: identifier is not a type")
		end

		// STRUCT / method TYPE: leaf record name -- never chase symbol_type
		if sym^.decl <> nil and sym^.decl^.kind == NODE_TYPE_DECL then
			if sym^.decl^.type_decl.is_forward or
					sym^.decl^.type_decl.struct_body <> nil or
					sym^.decl^.type_decl.method_type <> nil or
					sym^.decl^.type_decl.enum_type <> nil then
				resolved_base := type_create_named(ctx^.arena, sym^.name, sym^.name_len)
				return type_apply_use_qualifiers(ctx, ty, resolved_base)
			end
		end

		// Opaque type from .mh import: name only, no layout - do not chase symbol_type
		if sym^.decl <> nil and sym^.decl^.kind == NODE_IMPORT_ITEM then
			if sym^.symbol_type <> nil then
				resolved_base := type_copy_shell(ctx^.arena, sym^.symbol_type)
				return type_apply_use_qualifiers(ctx, ty, resolved_base)
			end
			resolved_base := type_create_named(ctx^.arena, sym^.name, sym^.name_len)
			return type_apply_use_qualifiers(ctx, ty, resolved_base)
		end

		base := sym^.symbol_type
		if base == nil then
			if sym^.decl <> nil and sym^.decl^.kind == NODE_TYPE_DECL and		\
					sym^.decl^.type_decl.is_extern then
				resolved_base := type_create_named(ctx^.arena, sym^.name, sym^.name_len)
				return type_apply_use_qualifiers(ctx, ty, resolved_base)
			end
			// if sym^.decl <> nil and sym^.decl^.kind == NODE_IMPORT_ITEM then
			// 	resolved_base := type_create_named(ctx^.arena, sym^.name, sym^.name_len)
			// 	return type_apply_use_qualifiers(ctx, ty, resolved_base)
			// end
			semantic_error_at(at, "semantic_resolve_type_inner: TYPE has no defined_type")
		end

		resolved_base := semantic_resolve_type_inner(ctx, base, depth + 1, at)
		return type_apply_use_qualifiers(ctx, ty, resolved_base)
	end

	// // Builtin (integer, char, ...) or opaque C name (FILE, long long, ...)
	// return type_copy_shell(ctx^.arena, ty)
	// Builtin (integer, char, ...) or multi-word C spelling (long long, ...)
	return type_copy_shell(ctx^.arena, ty)
end semantic_resolve_type_inner


(**
 * Resolve ty in place; sets ty^.resolved_type (idempotent).
 *)
procedure semantic_resolve_type(ctx: pTSemanticContext, ty: pTType, at: pNode)
begin
	if ty == nil then
		return
	end

	if ty^.resolved_type <> nil then
		return
	end

	ty^.resolved_type := semantic_resolve_type_inner(ctx, ty, 0, at)
end semantic_resolve_type


(**
 * Name equality (reuse enum style)
 *)
function semantic_names_equal(a: const ^char, a_len: size_t, b: const ^char, b_len: size_t): bool
begin
	if a == nil or b == nil or a_len <> b_len then
		return false
	end
	return memcmp(a, b, a_len) == 0
end semantic_names_equal


(**
 * Struct body for a type name
 *)
function semantic_struct_body_named(ctx: pTSemanticContext, name: const ^char, name_len: size_t): pNode
begin
	var sym: pTSymbol = nil

	if ctx == nil or name == nil or name_len == 0 then
		return nil
	end
	sym := symtab_lookup(ctx^.scope, name, name_len)
	if sym == nil or sym^.kind <> SYM_KIND_TYPE or sym^.decl == nil then
		return nil
	end
	if sym^.decl^.kind <> NODE_TYPE_DECL then
		return nil
	end
	return sym^.decl^.type_decl.struct_body
end semantic_struct_body_named


(**
 * Strip pointer layers (for ^Child formals later; harmless now)
 *)
// Saving for later use.

// function semantic_type_strip_pointers(ty: pTType): pTType
// begin
// 	while ty <> nil and ty^.is_pointer do
// 		// named pointer: ^T => look up T by name; element_type if present
// 		if ty^.element_type <> nil then
// 			ty := ty^.element_type
// 		elsif ty^.name <> nil and ty^.name_len > 0 then
// 			// leave as named; caller resolves via name
// 			return ty
// 		else
// 			return ty
// 		end
// 	end
// 	return ty
// end semantic_type_strip_pointers


(**
 * Struct body of type 
 *)
function semantic_struct_body_of_type(ctx: pTSemanticContext, body_type: pTType): pNode
begin
	var ty: pTType = body_type

	if ty == nil then
		return nil
	end

	// chase aliases
	if ty^.resolved_type <> nil then
		ty := ty^.resolved_type
	end
	if ty^.name == nil or ty^.name_len == 0 then
		return nil
	end
	return semantic_struct_body_named(ctx, ty^.name, ty^.name_len)
end semantic_struct_body_of_type


(**
 * By-value EXTENDS upcast distance.
 * Returns N >= 1 if *actual* may be used where *expected is required by
 * walking N synthetic ".base" members (option A layout).
 * Returns 0 if same type, not both named structs, pointer/array, or not an ancestor.
 *)
function semantic_extends_upcast_depth(ctx: pTSemanticContext, actual_type: pTType, expected_type: pTType): size_t
begin
	var st: pNode = nil
	var depth: size_t = 0
	var parent_ty: pTType = nil
	var actual: pTType = actual_type
	var expected: pTType = expected_type

	if ctx == nil or actual == nil or expected == nil then
		return 0
	end
	if actual^.resolved_type <> nil then
		actual := actual^.resolved_type
	end
	if expected^.resolved_type <> nil then
		expected := expected^.resolved_type
	end

	// v1: by-value only (pointer / REF upcast later)
	// both pointers: walk pointee names (still on TType.name). mixed: no
	if actual^.is_pointer <> expected^.is_pointer then
		return 0
	end
	if actual^.is_array or expected^.is_array then
		return 0
	end
	if actual^.name == nil or actual^.name_len == 0 then
		return 0
	end
	if expected^.name == nil or expected^.name_len == 0 then
		return 0
	end
	if semantic_names_equal(actual^.name, actual^.name_len, 
				expected^.name, expected^.name_len) then
		return 0
	end
	st := semantic_struct_body_of_type(ctx, actual)
	if st == nil then
		return 0
	end
	depth := 0
	while st <> nil and st^.struct_decl.extends_type <> nil do
		parent_ty := st^.struct_decl.extends_type
		depth := depth + 1
		if parent_ty^.name <> nil and semantic_names_equal(parent_ty^.name, parent_ty^.name_len,
				expected^.name, expected^.name_len) then
			return depth
		end
		st := semantic_struct_body_of_type(ctx, parent_ty)
	end
	return 0
end semantic_extends_upcast_depth


(**
 * If expr's type exrends expected, record upcast_depth on *expr* for codegen.
 * Does not error on mismatch (assignability still soft elsewhere).
 *)
procedure semantic_maybe_upcast(ctx: pTSemanticContext, expr: pNode, expected: pTType)
begin
	var actual: pTType = nil
	var d: size_t = 0

	if ctx == nil or expr == nil or expected == nil then
		return
	end
	actual := semantic_type_of_expr(ctx, expr)
	if actual == nil then
		return
	end
	d := semantic_extends_upcast_depth(ctx, actual, expected)
	if d > 0 then
		expr^.upcast_depth := d
		expr^.upcast_ptr := actual^.is_pointer
	end
end semantic_maybe_upcast


(**
 * Pointer at the use type or its resolved_type. Do not chase first
 * (^Child would become Child).
 *)
function semantic_type_is_pointer(ty: pTType): bool
begin
	if ty == nil then
		return false
	end
	if ty^.is_pointer then
		return true
	end
	if ty^.resolved_type <> nil and ty^.resolved_type^.is_pointer then
		return true
	end
	return false
end semantic_type_is_pointer


(**
 * Pointer-to-array (Oberon p[i] peel). Not array-of-pointer (^char[] argv).
 *)
function semantic_type_is_pointer_to_array(ty: pTType): bool
begin
	var t: pTType = ty

	if t == nil then
		return false
	end
	if not t^.is_pointer then
		if t^.resolved_type == nil or not t^.resolved_type^.is_pointer then
			return false
		end
		t := t^.resolved_type
	end
	if t^.is_array then
		return true
	end
	if t^.resolved_type <> nil and t^.resolved_type^.is_array then
		return true
	end
	return false
end semantic_type_is_pointer_to_array


(**
 * Designator type
 *)
recursive function semantic_type_of_designator(ctx: pTSemanticContext, n: pNode): pTType
begin
	var sym: pTSymbol = nil
	var st: pNode = nil
	var i: size_t = 0
	var f: pNode = nil
	var ety: pTType = nil

	if n == nil then
		return nil
	end

	switch n^.kind of
		case NODE_PAREN:
			return semantic_type_of_designator(ctx, n^.paren.expr)

		case NODE_IDENT:
			sym := n^.resolved_sym
			if sym == nil then
				return nil
			end
			return sym^.symbol_type

		case NODE_FIELD_ACCESS:
			// Prefer type of the selected field after resolve has run.
			// We set field result type only via lookup below when resolving;
			// recompute: type of record => find field.
			ety := semantic_type_of_designator(ctx, n^.field_access.record_)
			st := semantic_struct_body_of_type(ctx, ety)
			if st == nil then
				return nil
			end
			// synthetic base?
			if semantic_names_equal(n^.field_access.field_name, n^.field_access.field_len, "base", 4) then
				if st^.struct_decl.extends_type <> nil then
					return st^.struct_decl.extends_type
				end
			end
			// walk chain for field type (same order as find)
			while st <> nil do
				for i := 1 to st^.struct_decl.field_count do
					f := st^.struct_decl.fields[i-1]
					if f <> nil and semantic_names_equal(f^.field_decl.name, f^.field_decl.name_len,
								n^.field_access.field_name, n^.field_access.field_len) then
						return f^.field_decl.field_type
					end
				end
				if st^.struct_decl.extends_type == nil then
					return nil
				end
				st := semantic_struct_body_of_type(ctx, st^.struct_decl.extends_type)
			end
			return nil

		case NODE_ARRAY_INDEX:
			ety := semantic_type_of_designator(ctx, n^.array_index.array_)
			if ety == nil then
				return nil
			end
			if ety^.resolved_type <> nil then
				ety := ety^.resolved_type
			end
			if ety^.is_array and ety^.element_type <> nil then
				return ety^.element_type
			end
			// C-style [i] on ^T (kilo E.row[at]). Pointer-to-array
			// is handled above (is_array after resolve). Same strip as p^.
			if ety^.is_pointer then
				ety := type_copy_shell(ctx^.arena, ety)
				ety^.is_pointer := false
				return ety
			end
			return nil

		case NODE_UNARY:
			// p^ : type_of_expr already strips one pointer
			if n^.unary.op == TOK_CARET then
				return semantic_type_of_expr(ctx, n)
			end
			return nil

		case NODE_CAST:
			return semantic_type_of_expr(ctx, n)

		else:
			return nil
	end
end semantic_type_of_designator


(**
 * True if ty is a named type with the given spelling.
 *)
function semantic_type_name_is(ty: pTType, name: const ^char, name_len: size_t): bool
begin
	if ty == nil or name == nil or ty^.name == nil then
		return false
	end
	if ty^.is_pointer or ty^.is_array then
		return false
	end
	if ty^.name_len <> name_len then
		return false
	end
	return memcmp(ty^.name, name, name_len) == 0
end semantic_type_name_is


(**
 * Everyday integer-ish names for thin binary/unary typing (not full promotion).
 *)
function semantic_type_is_integerish(param_type: pTType): bool
begin
	var ty: pTType = param_type

	if ty == nil then
		return false
	end
	if ty^.resolved_type <> nil then
		ty := ty^.resolved_type
	end
	return semantic_type_name_is(ty, "integer", 7) or
		semantic_type_name_is(ty, "int", 3) or
		semantic_type_name_is(ty, "cardinal", 8)
end semantic_type_is_integerish


function semantic_type_is_realish(param_type: pTType): bool
begin
	var ty: pTType = param_type

	if ty == nil then
		return false
	end
	if ty^.resolved_type <> nil then
		ty := ty^.resolved_type
	end
	return semantic_type_name_is(ty, "real", 4) or
		semantic_type_name_is(ty, "float", 5) or
		semantic_type_name_is(ty, "double", 6)
end semantic_type_is_realish



(**
 * Thin expression typing (item 21a). Not full type-checking.
 * Returns a type descriptor or nil when unknown.
 * Prerequisite: semantic_resolve_expr has been run on n when idents/calls matter.
 *)
recursive function semantic_type_of_expr(ctx: pTSemanticContext, n: pNode): pTType
begin
	var sym: pTSymbol = nil
	// var ety: pTType = nil

	if n == nil then
		return nil
	end

	switch n^.kind of
		case NODE_PAREN:
			return semantic_type_of_expr(ctx, n^.paren.expr)

		case NODE_IDENT, NODE_FIELD_ACCESS, NODE_ARRAY_INDEX:
			return semantic_type_of_designator(ctx, n)

		case NODE_LITERAL:
			if n^.token.kind == TOK_NUMBER then
				return type_create_named(ctx^.arena, "integer", 7)
			elsif n^.token.kind == TOK_REAL then
				return type_create_named(ctx^.arena, "real", 4)
			elsif n^.token.kind == TOK_CHAR then
				return type_create_named(ctx^.arena, "char", 4)
			elsif n^.token.kind == TOK_STRING then
				return type_create_named(ctx^.arena, "string", 6)
			else
				return nil
			end

		case NODE_CAST:
			return n^.cast_expr.target_type

		case NODE_SIZEOF, NODE_LEN:
			return type_create_named(ctx^.arena, "integer", 7)

		case NODE_CALL:
			// Call-through field / designator: reutrn type from method type.
			if n^.call.callee_expr <> nil then
				var cty: pTType = nil
				var mtn: pNode = nil

				cty := semantic_type_of_expr(ctx, n^.call.callee_expr)
				mtn := semantic_method_type_node(ctx, cty)
				if mtn <> nil and mtn^.method_type.return_type <> nil then
					return mtn^.method_type.return_type
				end
				return nil 			// PROCEDURE type: no result
			end
			// FUNC symbols store return type in symbol_type (see register_decl)
			sym := n^.resolved_sym
			if sym == nil then
				return nil
			end
			if sym^.kind == SYM_KIND_FUNC then
				return sym^.symbol_type
			end
			// Local / param / let of method type: fp(...) return type
			if semantic_sym_is_method_value(ctx, sym) then
				begin
					var mtn2: pNode = nil

					mtn2 := semantic_method_type_node(ctx, sym^.symbol_type)
					if mtn2 <> nil and mtn2^.method_type.return_type <> nil then
						return mtn2^.method_type.return_type
					end
					return nil
				end
			end
			// Module entry / imported function: use symbol_type if present.
			if sym^.kind == SYM_KIND_IMPORT and sym^.symbol_type <> nil then
				return sym^.symbol_type
			end
			if sym^.decl <> nil and sym^.decl^.kind == NODE_FUNC_DECL then
				return sym^.decl^.proc_decl.return_type
			end
			return nil

		case NODE_UNARY:
			// Unary minus keeps operanted type when known (e.g. -1 => integer).
			// if n^.unary.op == TOK_SUB then
			// Unary minus / not: keep operand type when known.
			if n^.unary.op == TOK_SUB or n^.unary.op == TOK_KEYWORD_NOT or
					n^.unary.op == TOK_BITWISE_NOT then
				return semantic_type_of_expr(ctx, n^.unary.operand)
			elsif n^.unary.op == TOK_AT then
				// Address-of: ^T from T
				begin
					var base: pTType = nil
					var ptr: pTType = nil
					base := semantic_type_of_expr(ctx, n^.unary.operand)
					if base == nil then
						return nil
					end
					ptr := type_copy_shell(ctx^.arena, base)
					ptr^.is_pointer := true
					return ptr
				end
			elsif n^.unary.op == TOK_CARET then
				// Deref: strip one pointer layer
				begin
					var ptr: pTType = nil
					var base: pTType = nil
					ptr := semantic_type_of_expr(ctx, n^.unary.operand)
					if ptr == nil then
						return nil
					end
					if ptr^.resolved_type <> nil then
						ptr := ptr^.resolved_type
					end
					if not ptr^.is_pointer then
						return nil
					end
					base := type_copy_shell(ctx^.arena, ptr)
					base^.is_pointer := false
					return base
				end
			end
			return nil

		case NODE_BINARY:
			begin
				var lt: pTType = nil
				var rt: pTType = nil
				var op: TokenKind

				lt := semantic_type_of_expr(ctx, n^.binary.left)
				rt := semantic_type_of_expr(ctx, n^.binary.right)
				op := n^.binary.op

				// Comparisons => bool
				if op == TOK_EQ_EQ or op == TOK_NOT_EQ or op == TOK_LESS or
						op == TOK_LESS_EQ or op == TOK_GREATER or op == TOK_GREATER_EQ then
					if lt <> nil and rt <> nil then
						return type_create_named(ctx^.arena, "bool", 4)
					end
					return nil
				end

				// Arithmetic / bitwise / logical on integers => integer
				if semantic_type_is_integerish(lt) and semantic_type_is_integerish(rt) then
					if op == TOK_ADD or op == TOK_SUB or op == TOK_MUL or op == TOK_DIV or
							op == TOK_MOD or op == TOK_KEYWORD_MOD or op == TOK_KEYWORD_DIV or
							op == TOK_POWER or op == TOK_BITWISE_AND or op == TOK_BITWISE_OR or
							op == TOK_KEYWORD_XOR or op == TOK_KEYWORD_AND or op == TOK_KEYWORD_OR or
							op == TOK_BITWISE_LSHIFT or op == TOK_BITWISE_RSHIFT then
						return type_create_named(ctx^.arena, "integer", 7)
					end
				end

				// Real arithmetic
				if semantic_type_is_realish(lt) and semantic_type_is_realish(rt) then
					if op == TOK_ADD or op == TOK_SUB or op == TOK_MUL or op == TOK_DIV then
						return type_create_named(ctx^.arena, "real", 4)
					end
				end

				return nil
			end

		// Still deferred
		case NODE_TERNARY, NODE_ARRAY_LITERAL:
			return nil

		else:
			return nil
	end
end semantic_type_of_expr


(**
 * Find field => set base_depth
 * Returns true if found; out_depth = # of .base prefixes before field_name
 *)
function semantic_find_field_depth(ctx: pTSemanticContext, sem_type: pNode,
	name: const ^char, name_len: size_t, out_depth: ^size_t): bool
begin
	var depth: size_t = 0
	var i: size_t = 0
	var f: pNode = nil
	var parent: pNode = nil
	var st: pNode = sem_type

	if st == nil or name == nil or name_len == 0 or out_depth == nil then
		return false
	end

	while st <> nil do
		// synthetic base only at this level
		if depth == 0 and st^.struct_decl.extends_type <> nil and
				semantic_names_equal(name, name_len, "base", 4) then
			out_depth^ := 0
			return true
		end

		for i := 1 to st^.struct_decl.field_count do
			f := st^.struct_decl.fields[i-1]
			if f <> nil and semantic_names_equal(f^.field_decl.name, f^.field_decl.name_len, name, name_len) then
				out_depth^ := depth
				return true
			end
		end

		if st^.struct_decl.extends_type == nil then
			return false
		end
		parent := semantic_struct_body_of_type(ctx, st^.struct_decl.extends_type)
		if parent == nil then
			return false
		end
		st := parent
		depth := depth + 1
	end 
	return false
end semantic_find_field_depth


(**
 * Check extends clashes
 *)
procedure semantic_check_extends_clashes(ctx: pTSemanticContext, st: pNode, at: pNode)
begin
	var i: size_t = 0
	var j: size_t = 0
	var f: pNode = nil
	var g: pNode = nil
	var anc: pNode = nil
	var depth: size_t = 0

	if st == nil then
		return
	end

	// duplicate names within this struct (always; plain STRUCT may use field name "base")
	for i := 1 to st^.struct_decl.field_count do
		f := st^.struct_decl.fields[i-1]
		if f == nil then
			continue
		end
		// if semantic_names_equal(f^.field_decl.name, f^.field_decl.name_len, "base", 4) then
		// 	semantic_error_at(at, "semantic_check_extends_clashes: field name 'base' is reserved for EXTENDS")
		// end
		for j := i + 1 to st^.struct_decl.field_count do
			g := st^.struct_decl.fields[j-1]
			if g <> nil and semantic_names_equal(f^.field_decl.name, f^.field_decl.name_len,
						g^.field_decl.name, g^.field_decl.name_len) then
				semantic_error_at(at, "semantic_check_extends_clashes: duplicate field name in STRUCT")
			end
		end
	end

	if st^.struct_decl.extends_type == nil then
		return
	end

	// base must be a non-union STRUCT
	anc := semantic_struct_body_of_type(ctx, st^.struct_decl.extends_type)
	if anc == nil then
		semantic_error_at(at, "semantic_check_extends_clashes: EXTENDS base must be a STRUCT type")
	end
	if anc^.struct_decl.is_union then
		semantic_error_at(at, "semantic_check_extends_clashes: EXTENDS base cannot be a UNION")
	end

	// EXTENDS only: reserve synthetic "base"; no clash with ancestor fields (Oberon)
	for i := 1 to st^.struct_decl.field_count do
		f := st^.struct_decl.fields[i-1]
		if f == nil then
			continue
		end
		if semantic_names_equal(f^.field_decl.name, f^.field_decl.name_len, "base", 4) then
			semantic_error_at(at, "semantic_check_extends_clashes: field name 'base' is reserved for EXTENDS")
		end
		if semantic_find_field_depth(ctx, anc, f^.field_decl.name, f^.field_decl.name_len, @depth) then
			semantic_error_at(at, "semantic_check_extends_clashes: field name clashes with EXTENDS base")
		end
	end
end semantic_check_extends_clashes


(**
 * Resolve field types inside a STRUCT ... END type body. 
 *)
procedure semantic_resolve_struct_type(ctx: pTSemanticContext, st: pNode, at: pNode)
begin
	var i: size_t = 0
	var f: pNode = nil

	if st == nil or st^.kind <> NODE_STRUCT_DECL then
		return
	end

	if st^.struct_decl.extends_type <> nil then
		if st^.struct_decl.is_union then
			semantic_error_at(at, "semantic_resolve_struct_type: UNION cannot have EXTENDS")
		else
			semantic_resolve_type(ctx, st^.struct_decl.extends_type, at)
		end
	end

	for i := 1 to st^.struct_decl.field_count do
		f := st^.struct_decl.fields[i-1]
		if f <> nil and f^.field_decl.field_type <> nil then
			semantic_resolve_type(ctx, f^.field_decl.field_type, at)
		end
	end
	semantic_check_extends_clashes(ctx, st, at)

end semantic_resolve_struct_type


(**
 * Parse integer literal token (deciman / 0x hex); strip '_' separators.
 *)
function semantic_parse_integer_literal(n: pNode): integer
begin
	var buf: array[128] of char
	var i: size_t = 0
	var j: size_t = 0
	var endptr: ^char = nil
	var v: long = 0

	if n == nil or n^.kind <> NODE_LITERAL or n^.token.kind <> TOK_NUMBER then
		semantic_error_at(n, "semantic_parse_integer_literal: expected integer literal")
	end

	if n^.token.length >= sizeof(buf) then
		semantic_error_at(n, "semantic_parse_integer_literal: integer literal too long")
	end

	while i < n^.token.length do
		if n^.token.start[i] <> '_' then
			buf[j] := n^.token.start[i]
			inc(j)
		end
		inc(i)
	end
	buf[j] := '\0'

	v := strtol(@buf[0], @endptr, 0)
	if endptr == @buf[0] then
		semantic_error_at(n, "semantic_parse_integer_literal: invalid integer literal")
	end

	return v as integer
end semantic_parse_integer_literal


(**
 * Evaluate a compile-time integer expression.
 * Implementation lives in semantic_try_eval_const_expr
 *)
function semantic_eval_const_expr(ctx: pTSemanticContext, n: pNode): integer
begin
	var val: integer = 0
	var msg: pcchar = nil

	if not semantic_try_eval_const_expr(ctx, n, @val, @msg) then
		if msg == nil then
			msg := "semantic_eval_const_expr: not an integer constant expression"
		end
		semantic_error_at(n, msg)
	end
	return val
end semantic_eval_const_expr


(**
 * Try integer const-fold. true + out_val^ on success.
 * Non-integer CONST (strings, pointers, ...) return false -- not an error.
 *)
recursive function semantic_try_eval_const_expr(ctx: pTSemanticContext, n: pNode, out_val: ^integer, msg: ^pcchar): bool
begin
	var sym: pTSymbol = nil
	var left: integer = 0
	var right: integer = 0

	if n == nil or out_val == nil then
		if msg <> nil then
			msg^ := "semantic_eval_const_expr: missing expression"
		end
		return false
	end

	switch n^.kind of
		case NODE_LITERAL:
			if n^.token.kind <> TOK_NUMBER then
				if msg <> nil then
					msg^ := "semantic_eval_const_expr: not an integer constant expression"
				end
				return false
			end
			out_val^ := semantic_parse_integer_literal(n)
			return true

		case NODE_IDENT:
			sym := symtab_lookup(ctx^.scope, n^.token.start, n^.token.length)
			if sym == nil or sym^.kind <> SYM_KIND_CONST or not sym^.has_const_value then
				if msg <> nil then
					msg^ := "semantic_eval_const_expr: expected constant value"
				end
				return false
			end
			out_val^ := sym^.const_value
			return true

		case NODE_PAREN:
			return semantic_try_eval_const_expr(ctx, n^.paren.expr, out_val, msg)

		case NODE_UNARY:
			if n^.unary.op <> TOK_SUB then
				if msg <> nil then
					msg^ := "semantic_eval_const_expr: unsupported unary operator"
				end
				return false
			end
			if not semantic_try_eval_const_expr(ctx, n^.unary.operand, out_val, msg) then
				return false
			end
			out_val^ := -(out_val^)
			return true

		case NODE_BINARY:
			if not semantic_try_eval_const_expr(ctx, n^.binary.left, @left, msg) then
				return false
			end
			if not semantic_try_eval_const_expr(ctx, n^.binary.right, @right, msg) then
				return false
			end
			if n^.binary.op == TOK_ADD then
				out_val^ := left + right
			elsif n^.binary.op == TOK_SUB then
				out_val^ := left - right
			elsif n^.binary.op == TOK_MUL then
				out_val^ := left * right
			elsif n^.binary.op == TOK_DIV then
				if right == 0 then
					if msg <> nil then
						msg^ := "semantic_eval_const_expr: division by zero"
					end
					return false
				end
				out_val^ := left / right
			elsif n^.binary.op == TOK_MOD or n^.binary.op == TOK_KEYWORD_MOD then
				if right == 0 then
					if msg <> nil then
						msg^ := "semantic_eval_const_expr: division by zero"
					end
					return false
				end
				out_val^ := left mod right
			else
				if msg <> nil then
					msg^ := "semantic_eval_const_expr: unsupported binary operator"
				end
				return false
			end
			return true

		else:
			if msg <> nil then
				msg^ := "semantic_eval_const_expr: not a constant expression"
			end
			return false
	end
	return false
end semantic_try_eval_const_expr




(**
 * Register enum members as CONST symbols; set TYPE symbol_type.
 * Called from semantic_resolve_type_decls (Pass  1 1/2).
 *)
procedure semantic_register_enum_type(ctx: pTSemanticContext, en: pNode, type_decl: pNode)
begin
	var i: size_t = 0
	var j: size_t = 0
	var item: pNode = nil
	var other: pNode = nil
	var val: integer = 0
	var next_val: integer = 0
	var sym: pTSymbol = nil
	var int_ty: pTType = nil
	var type_sym: pTSymbol = nil

	if en == nil or en^.kind <> NODE_ENUM_TYPE then
		return
	end
	if type_decl == nil or type_decl^.kind <> NODE_TYPE_DECL then
		return
	end

	int_ty := type_create_named(ctx^.arena, "integer", 7)
	next_val := 0

	for i := 1 to en^.enum_type.count do
		item := en^.enum_type.elements[i - 1]
		if item == nil or item^.kind <> NODE_ENUM_ITEM then
			semantic_error_at(en, "semantic_register_enum_type: invalid enum number")
		end
		if item^.enum_item.name == nil or item^.enum_item.name_len == 0 then
			semantic_error_at(item, "semantic_register_enum_type: enum member has no name")
		end

		for j := 1 to i - 1 do
			other := en^.enum_type.elements[j - 1]
			if other <> nil and other^.enum_item.name_len == item^.enum_item.name_len and
					memcmp(other^.enum_item.name, item^.enum_item.name, item^.enum_item.name_len) == 0 then
				semantic_error_at(item, "semantic_register_enum_type: duplicate enum member")
			end
		end

		if item^.enum_item.value <> nil then
			val := semantic_eval_const_expr(ctx, item^.enum_item.value)
		else
			val := next_val
		end

		item^.enum_item.value_known := true
		item^.enum_item.int_value 	:= val
		next_val := val + 1

		if symtab_lookup_current(ctx^.scope, item^.enum_item.name, item^.enum_item.name_len) <> nil then
			semantic_error_at(item, "semantic_register_enum_type: enum member conflics with existing symbol")
		end

		sym := symbol_create(ctx^.arena, SYM_KIND_CONST, item^.enum_item.name, item^.enum_item.name_len, item)
		sym^.symbol_type 	:= int_ty
		sym^.has_const_value 	:= true
		sym^.const_value 	:= val
		sym^.is_exported 	:= type_decl^.type_decl.is_exported
		symtab_define(ctx^.arena, ctx^.scope, sym)
	end

	type_sym := symtab_lookup(ctx^.scope, type_decl^.type_decl.name, type_decl^.type_decl.name_len)
	if type_sym <> nil then
		type_sym^.symbol_type := type_create_named(ctx^.arena, type_decl^.type_decl.name, type_decl^.type_decl.name_len)
	end
end semantic_register_enum_type


(** 
 * Resolve param / return types inside PROCEDURE/FUNCTION method types.
 *)
procedure semantic_resolve_method_type(ctx: pTSemanticContext, mt: pNode, at: pNode)
begin
	var params: ^pNode = nil
	var count: size_t = 0
	var i: size_t = 0
	var p: pNode = nil

	if mt == nil or mt^.kind <> NODE_METHOD_TYPE then
		return
	end

	if mt^.method_type.return_type <> nil then
		semantic_resolve_type(ctx, mt^.method_type.return_type, at)
	end

	if mt^.method_type.params <> nil and mt^.method_type.params^.kind == NODE_PARAM_LIST then
		params 	:= mt^.method_type.params^.param_list.params
		count 	:= mt^.method_type.params^.param_list.count
		for i := 1 to count do
			p := params[i-1]
			if p <> nil and p^.param.param_type <> nil then
				semantic_resolve_type(ctx, p^.param.param_type, p)
			end
		end
	end
end semantic_resolve_method_type


(**
 * Pass 1 1/2: resolve all top-level TYPE bodies; refresh sym^.symbol_type.
 *)
procedure semantic_resolve_type_decls(ctx: pTSemanticContext, root: pNode)
begin
	var i: size_t = 0
	var decl: pNode = nil
	var sym: pTSymbol = nil

	if root == nil or root^.kind <> NODE_PROGRAM then
		return
	end

	for i := 1 to root^.program_decl.count do
		decl := root^.program_decl.decls[i-1]
		if decl == nil or decl^.kind <> NODE_TYPE_DECL then
			continue
		end

		if decl^.type_decl.is_forward then
			continue
		end

		if decl^.type_decl.defined_type <> nil then
			semantic_resolve_type(ctx, decl^.type_decl.defined_type, decl)

		elsif decl^.type_decl.struct_body <> nil then
			semantic_resolve_struct_type(ctx, decl^.type_decl.struct_body, decl)

		elsif decl^.type_decl.enum_type <> nil then
			semantic_register_enum_type(ctx, decl^.type_decl.enum_type, decl)

		elsif decl^.type_decl.method_type <> nil then
			semantic_resolve_method_type(ctx, decl^.type_decl.method_type, decl)
		end

		sym := symtab_lookup(ctx^.scope, decl^.type_decl.name, decl^.type_decl.name_len)
		if sym <> nil and decl^.type_decl.defined_type <> nil and 			\
				decl^.type_decl.defined_type^.resolved_type <> nil then
			sym^.symbol_type := decl^.type_decl.defined_type^.resolved_type
		end
	end
end semantic_resolve_type_decls


(**
 * FOR control matches
 *)
function semantic_for_control_matches(ctx: pTSemanticContext, name: const ^char, name_len: size_t): bool
begin
	if ctx == nil or ctx^.for_var_name == nil or ctx^.for_var_len == 0 then
		return false
	elsif name == nil or name_len == 0 then
		return false
	else
		return name_len == ctx^.for_var_len and memcmp(name, ctx^.for_var_name, name_len) == 0
	end
end semantic_for_control_matches


(**
 * If designator is rooted at a forma, return that NODE_PARAM; else nil.
 * Walks IDENT, FIELD_ACCESS, ARRAY_INDEX, and postfix ^ (unary CARET).
 *)
recursive function semantic_designator_param_root(d: pNode): pNode
begin
	if d == nil then
		return nil
	end
	if d^.kind == NODE_IDENT then
		if d^.resolved_sym <> nil and d^.resolved_sym^.kind == SYM_KIND_PARAM and
				d^.resolved_sym^.decl <> nil and d^.resolved_sym^.decl^.kind == NODE_PARAM then
			return d^.resolved_sym^.decl
		end
		return nil
	end
	if d^.kind == NODE_FIELD_ACCESS then
		return semantic_designator_param_root(d^.field_access.record_)
	end
	if d^.kind == NODE_ARRAY_INDEX then
		return semantic_designator_param_root(d^.array_index.array_)
	end
	if d^.kind == NODE_UNARY and d^.unary.op == TOK_CARET then
		return semantic_designator_param_root(d^.unary.operand)
	end
	if d^.kind == NODE_PAREN then
		return semantic_designator_param_root(d^.paren.expr)
	end
	return nil
end semantic_designator_param_root


(**
 * Forbid writes that violate parameter modes.
 * - CONST formal: no rebind and no mutation through the parameter.
 * - Non-VAR formal: no rebind of the binding (are name on LHS of :=).
 *)
procedure semantic_forbid_param_mode_write(lhs: pNode)
begin
	var param: pNode = nil

	if lhs == nil then
		return
	end

	// Resolve LHS first so resolved_sym is set on idents.
	// Caller should resolve_expr(left) before or we resolve here.
	param := semantic_designator_param_root(lhs)
	if param == nil then
		return
	end

	if param^.param.is_const then
		semantic_error_at(lhs, 
			"semantic_forbid_param_mode_write: cannot write through CONST parameter")
	end

	// Rebind: assignment target is the bare parameter name (not field/index).
	if lhs^.kind == NODE_IDENT and not param^.param.is_var then
		semantic_error_at(lhs,
			"semantic_forbid_param_mode_write: cannot assign to non-VAR parameter; use VAR")
	end
end semantic_forbid_param_mode_write


(**
 * Forbid FOR control write
 *)
procedure semantic_forbid_for_control_write(ctx: pTSemanticContext, d: pNode)
begin
	if d == nil then
		return
	elsif d^.kind == NODE_IDENT then
		if semantic_for_control_matches(ctx, d^.token.start, d^.token.length) then
			semantic_error_at(d, "semantic_forbid_for_control_write: FOR control variable is read-only in loop body")
		end
	end
	// phase 1: plan ident only - not array[i] / field
end


(**
 * If designator is rooted at a LET, return that symbol; else nil.
 * Same walk as semantic_designator_param_root.
 *)
recursive function semantic_designator_let_root(d: pNode): pTSymbol
begin
	if d == nil then
		return nil
	end
	if d^.kind == NODE_IDENT then
		if d^.resolved_sym <> nil and 
				(d^.resolved_sym^.kind == SYM_KIND_LET or
					d^.resolved_sym^.kind == SYM_KIND_CONST) then
			return d^.resolved_sym
		end
		return nil
	end
	if d^.kind == NODE_FIELD_ACCESS then
		return semantic_designator_let_root(d^.field_access.record_)
	end
	if d^.kind == NODE_ARRAY_INDEX then
		return semantic_designator_let_root(d^.array_index.array_)
	end
	if d^.kind == NODE_UNARY and d^.unary.op == TOK_CARET then
		return semantic_designator_let_root(d^.unary.operand)
	end
	if d^.kind == NODE_PAREN then
		return semantic_designator_let_root(d^.paren.expr)
	end
	return nil
end semantic_designator_let_root


(**
 * Forbid writes that violate LET immutability.
 * 	- Bare name: no rebind (n :=, INC(n), DEC(n)).
 * 	- Through-selector on a non-pointer LET: no mutation of the bound value.
 * 	- Through-selector on a pointer LET: allowed (object may be VAR).
 *)
procedure semantic_forbid_let_write(lhs: pNode)
begin
	var sym: pTSymbol = nil

	if lhs == nil then
		return
	end

	sym := semantic_designator_let_root(lhs)
	if sym == nil then
		return
	end

	if lhs^.kind == NODE_IDENT then
		semantic_error_at(lhs, 
			"semantic_forbid_let_write: cannot assign to LET binding")

	// vvv --- TODO: do we really want this? --- vvv //
	// elsif not semantic_type_is_pointer(sym^.symbol_type) then
	// 	semantic_error_at(lhs,
	// 		"semantic_forbid_let_write: cannot mutate a LET binding")
	end
end semantic_forbid_let_write


(**
 * @ of a LET or declaration CONST would yield a mutable C pointer to
 * storage that TMod-c must not alias. Read-only `const ^T = @n` can wait.
 *)
procedure semantic_forbid_at_immutable(operand: pNode)
begin
	var sym: pTSymbol = nil

	if operand == nil then
		return
	end

	sym := semantic_designator_let_root(operand)
	if sym == nil then
		return
	end

	semantic_error_at(operand,
		"semantic_forbid_at_immutable: cannot take address of LET or CONST")
end semantic_forbid_at_immutable


(** 
* Define one symbol in the current scope.
*)
procedure semantic_define(ctx: pTSemanticContext, kind: SymbolKind,
							name: const ^char, name_len: size_t,
							symbol_type: ^TType, decl: pNode, is_exported: bool)
begin
	var sym: pTSymbol = nil

	if ctx == nil or ctx^.scope == nil then
		semantic_error_at(decl, "semantic_define: internal error: no active scope")
	end

	if type_is_builtin_name(name, name_len) then
		//semantic_error_at(decl, "semantic_define: cannot shadow builtin types")
		fprintf(stderr, "WARNING: semantic_define: cannot shadow builtin types\n")
	end

	sym := symbol_create(ctx^.arena, kind, name, name_len, decl)
	sym^.symbol_type 	:= symbol_type
	sym^.is_exported 	:= is_exported

	if kind == SYM_KIND_LET then
		symtab_define_let(ctx^.arena, ctx^.scope, sym)
	else
		symtab_define(ctx^.arena, ctx^.scope,sym)
	end
	// symtab_define(ctx^.arena, ctx^.scope, sym)
end


(**
 * Define a symbol, or refine an existing IMPORT in the current scope.
 *)
procedure semantic_define_or_refine(ctx: pTSemanticContext, kind: SymbolKind,
									name: const ^char, name_len: size_t,
									symbol_type: ^TType, decl: pNode, is_exported: bool)
begin
	var existing: pTSymbol = nil
	var sym: pTSymbol = nil

	if ctx == nil or ctx^.scope == nil then
		semantic_error_at(decl, "semantic_define_or_refine: internal error: no active scope")
	end

	if type_is_builtin_name(name, name_len) then
		semantic_error_at(decl, "semantic_define_or_refine: cannot shadow builtin types")
	end

	existing := symtab_lookup_current(ctx^.scope, name, name_len)
	sym := symbol_create(ctx^.arena, kind, name, name_len, decl)
	sym^.symbol_type := symbol_type
	sym^.is_exported := is_exported

	if existing == nil then
		symtab_define(ctx^.arena, ctx^.scope, sym)
	elsif existing^.kind == SYM_KIND_IMPORT then
		symtab_refine_symbol(ctx^.arena, ctx^.scope, existing, sym)
	else
		semantic_error_at(decl, "semantic_define_or_refine: duplicate symbol")
	end
end semantic_define_or_refine


(*
 * Import of integer|cardinal|real|string is the one unit bind
 * (Language Report 5.5). Prelude TYPE has decl == nil.
 *)
procedure semantic_bind_portable_import(ctx: pTSemanticContext, loc: pNode,
		name: const ^char, name_len: size_t)
begin
	var existing: pTSymbol =nil
	var sym: pTSymbol = nil

	if ctx == nil or ctx^.scope == nil then
		semantic_error_at(loc, "semantic_bind_portable_import: internal error: no active scope")
	end

	existing := symtab_lookup_current(ctx^.scope, name, name_len)
	sym := symbol_create(ctx^.arena, SYM_KIND_TYPE, name, name_len, loc)
	sym^.symbol_type := nil
	sym^.is_exported := false

	if existing == nil then
		symtab_define(ctx^.arena, ctx^.scope, sym)
	elsif existing^.kind == SYM_KIND_TYPE and existing^.decl == nil then
		symtab_refine_symbol(ctx^.arena, ctx^.scope, existing, sym)
	elsif existing^.kind == SYM_KIND_TYPE and existing^.decl <> nil then
		semantic_error_at(loc,
			"semantic_bind_portable_import: portable type already bound in this unit")
	else
		semantic_error_at(loc,
			"semantic_bind_portable_import: cannot bind portable type over existing symbol")
	end
end semantic_bind_portable_import


(*
 * Define a symbol, complete a prior FORWARD, or refine IMPORT.
 *)
procedure semantic_define_or_complete_forward(ctx: pTSemanticContext, kind: SymbolKind,
										name: const ^char, name_len: size_t,
										symbol_type: ^TType, decl: pNode, is_exported: bool)
begin
	var existing: pTSymbol = nil
	var sym: pTSymbol = nil

	if ctx == nil or ctx^.scope == nil then
		semantic_error_at(decl, "semantic_define_or_complete_forward: internal error: no active scope")
	end

	// Fixed builtins (bool/byte/char and C-ish prelude names) cannot be redefined.
	// Portable four may be bound once as TYPE (prelude entry has decl == nil).
	if type_is_builtin_name(name, name_len) then
		if not (kind == SYM_KIND_TYPE and type_is_portable_rebindable(name, name_len)) then
			semantic_error_at(decl,
				"semantic_define_or_complete_forward: cannot rebind or shadow this builtin type")
		end
	end

	existing := symtab_lookup_current(ctx^.scope, name, name_len)
	sym := symbol_create(ctx^.arena, kind, name, name_len, decl)
	sym^.symbol_type := symbol_type
	sym^.is_exported := is_exported

	if existing == nil then
		symtab_define(ctx^.arena, ctx^.scope, sym)
	elsif existing^.kind == SYM_KIND_IMPORT then
		symtab_refine_symbol(ctx^.arena, ctx^.scope, existing, sym)
	elsif (existing^.kind == SYM_KIND_PROC or existing^.kind == SYM_KIND_FUNC) and
			existing^.decl <> nil and existing^.decl^.proc_decl.is_forward and
			decl^.proc_decl.is_forward == false then
		symtab_refine_symbol(ctx^.arena, ctx^.scope, existing, sym)
	elsif existing^.kind == SYM_KIND_TYPE and
			existing^.decl <> nil and existing^.decl^.kind == NODE_TYPE_DECL and
			existing^.decl^.type_decl.is_forward and
			decl <> nil and decl^.kind == NODE_TYPE_DECL and
			decl^.type_decl.is_forward == false then
		symtab_refine_symbol(ctx^.arena, ctx^.scope, existing, sym)
	elsif kind == SYM_KIND_TYPE and type_is_portable_rebindable(name, name_len) and
			existing^.kind == SYM_KIND_TYPE then
		// First unit binding or integer|cardinal|real|string (prelude: decl == nil).
		if existing^.decl == nil and decl <> nil and decl^.kind == NODE_TYPE_DECL and
				decl^.type_decl.is_forward == false then
			symtab_refine_symbol(ctx^.arena, ctx^.scope, existing, sym)
		elsif existing^.decl <> nil then
			semantic_error_at(decl,
				"semantic_define_or_complete_forward: portable type already bound in this unit")
		else
			semantic_error_at(decl, 
				"semantic_define_or_complete_forward: invalid portable type binding")
		end
	else
		semantic_error_at(decl, "semantic_define_or_complete_forward: duplicate symbol")
	end
end semantic_define_or_complete_forward


(**
 * Register one IMPORT item in the current scope (foreign / minimal symbol).
 *)
procedure semantic_register_import_item(ctx: pTSemanticContext, item: pNode)
begin
	var name: const ^char = nil
	var name_len: size_t = 0

	if item == nil or item^.kind <> NODE_IMPORT_ITEM then
		semantic_error_at(item, "semantic_register_import_item: expected import item")
	end

	if item^.import_item.import_alias <> nil and item^.import_item.import_alias_len > 0 then
		name 		:= item^.import_item.import_alias
		name_len 	:= item^.import_item.import_alias_len
	else
		name 		:= item^.import_item.qualident
		name_len 	:= item^.import_item.qualident_len
	end

	if name == nil or name_len == 0 then
		semantic_error_at(item, "semantic_register_import_item: import item has no name")
	end

	semantic_define(ctx, SYM_KIND_IMPORT, name, name_len, nil, item, false)
end semantic_register_import_item


(*
 * Arena copy of n bytes + NUL (for .mh strings that die at mh_module_free).
 *)
function semantic_arena_strndup(arena: ^Arena, s: const ^char, n: size_t): ^char
begin
	var p: ^char = nil

	if arena == nil or s == nil or n == 0 then
		return nil
	end
	p := arena_alloc(arena, n + 1) as ^char
	memcpy(p, s, n)
	p[n] := '\0'
	return p
end semantic_arena_strndup


(*
 * Build TType from .mh type-spec fields (name may be multi-word, e.g. "long long").
 *)
function semantic_mh_make_type(ctx: pTSemanticContext,
		is_const: bool, is_pointer: bool,
		name: const ^char, name_len: size_t, width: int): pTType
begin
	var ty: pTType = nil
	var nm: ^char = nil

	if ctx == nil or name == nil or name_len == 0 then
		return nil
	end
	nm := semantic_arena_strndup(ctx^.arena, name, name_len)
	ty := type_create_named(ctx^.arena, nm, name_len)
	ty^.is_const := is_const
	ty^.is_pointer := is_pointer
	ty^.width := width
	return ty
end semantic_mh_make_type


(*
 * Synthetic NODE_PROC_DECL / NODE_FUNC_DECL from MhExport signature.
 * loc: import item (token for diagnostics). name/name_len: symtab bind name
 * (often mangled).
 *)
function semantic_mh_make_proc_decl(ctx: pTSemanticContext, exp: const ^MhExport,
		loc: pNode, name: const ^char, name_len: size_t,
		kind: SymbolKind): pNode
begin
	var decl: pNode = nil
	var pl: pNode = nil
	var param: pNode = nil
	var ty: pTType = nil
	var i: size_t = 0
	var f: const ^MhFormal = nil
	var pname: ^char = nil
	var pbuf: array[32] of char
	var nkind: NodeKind = NODE_PROC_DECL
	var tok: TToken

	if ctx == nil or exp == nil or not exp^.has_signature then
		return nil
	end
	if kind <> SYM_KIND_PROC and kind <> SYM_KIND_FUNC then
		return nil
	end

	if loc <> nil then
		tok := loc^.token
	else
		// arena-zeroed node_create path: zero token
		tok.kind := 0
		tok.start := nil
		tok.length := 0
		tok.line := 0
		tok.column := 0
		tok.error_msg := nil
	end

	if kind == SYM_KIND_FUNC then
		nkind := NODE_FUNC_DECL
	end

	decl := node_create(ctx^.arena, nkind, tok)
	decl^.proc_decl.name := name
	decl^.proc_decl.name_len := name_len
	decl^.proc_decl.method_owner := nil
	decl^.proc_decl.method_owner_len := 0
	decl^.proc_decl.params := nil
	decl^.proc_decl.return_type := nil
	decl^.proc_decl.body := nil
	decl^.proc_decl.is_exported := false
	decl^.proc_decl.is_recursive := false
	decl^.proc_decl.is_extern := exp^.is_extern
	decl^.proc_decl.is_forward := false
	decl^.proc_decl.is_function := (kind == SYM_KIND_FUNC)
	decl^.proc_decl.receiver := nil

	if exp^.is_method and exp^.method_owner <> nil and exp^.method_owner_len > 0 then
		decl^.proc_decl.method_owner := semantic_arena_strndup(ctx^.arena,
			exp^.method_owner, exp^.method_owner_len)
		decl^.proc_decl.method_owner_len := exp^.method_owner_len
	end

	// Parameter list (may be empty "()")
	pl := node_create(ctx^.arena, NODE_PARAM_LIST, tok)
	pl^.param_list.params := nil
	pl^.param_list.count := 0
	pl^.param_list.capacity := 0
	pl^.param_list.has_ellipsis := false

	for i := 1 to exp^.formal_count do
		f := @exp^.formals[i - 1]
		if f <> nil and f^.is_ellipsis then
			if i == 1 then
				semantic_error_at(loc, "semantic_mh_make_proc_decl: '...' requires at least one named formal")
			end
			if i <> exp^.formal_count then
				semantic_error_at(loc, "semantic_mh_make_proc_decl: '...' must be the last formal")
			end
			pl^.param_list.has_ellipsis := true
			continue
		end
		if f == nil or f^.type_name == nil or f^.type_name_len == 0 then
			semantic_error_at(loc, "semantic_mh_make_proc_decl: formal missing type name")
		end

		ty := semantic_mh_make_type(ctx, f^.type_is_const, f^.type_is_pointer,
			f^.type_name, f^.type_name_len, f^.type_width)
		if ty == nil then
			semantic_error_at(loc, "semantic_mh_make_proc_decl: cannot build formal type")
		end

		// Dummy name "_0", "_1", ... (codegen formals do not need real names)
		snprintf(@pbuf[0], 32, "_%zu", i - 1)
		pname := semantic_arena_strndup(ctx^.arena, @pbuf[0], strlen(@pbuf[0]))

		param := node_create(ctx^.arena, NODE_PARAM, tok)
		param^.param.name := pname
		param^.param.name_len := strlen(pname)
		param^.param.param_type := ty
		param^.param.is_var := f^.is_var
		param^.param.is_ref := f^.is_ref
		param^.param.is_const := f^.is_const

		arena_append_ptr(ctx^.arena,
			(@pl^.param_list.params) as ppvoid,
			@pl^.param_list.count,
			@pl^.param_list.capacity,
			param)
	end

	decl^.proc_decl.params := pl

	if exp^.has_result and exp^.result_name <> nil and exp^.result_name_len > 0 then
		decl^.proc_decl.return_type := semantic_mh_make_type(ctx,
			exp^.result_is_const, exp^.result_is_pointer,
			exp^.result_name, exp^.result_name_len, exp^.result_width)
	end

	return decl
end semantic_mh_make_proc_decl


(*
 * Synthetic NODE_TYPE_DECL + STRUCT/UNION body from .mh field list.
 * loc: import item (token). bind_name already arena-owned.
 *)
function semantic_mh_make_type_decl(ctx: pTSemanticContext, exp: const ^MhExport,
		loc: pNode, bind_name: const ^char, bind_len: size_t): pNode
begin
	var decl: pNode = nil
	var st: pNode = nil
	var field: pNode = nil
	var i: size_t = 0
	var f: const ^MhField = nil
	var tok: TToken

	if ctx == nil or exp == nil then
		return nil
	end
	if not exp^.is_struct and not exp^.is_union then
		return nil
	end

	if loc <> nil then
		tok := loc^.token
	else
		tok.kind := 0
		tok.start := nil
		tok.length := 0
		tok.line := 0
		tok.column := 0
		tok.error_msg := nil
	end

	st := node_create(ctx^.arena, NODE_STRUCT_DECL, tok)
	st^.struct_decl.name := bind_name
	st^.struct_decl.name_len := bind_len
	st^.struct_decl.extends_type := nil
	st^.struct_decl.fields := nil
	st^.struct_decl.field_count := 0
	st^.struct_decl.field_capacity := 0
	st^.struct_decl.is_exported := false
	st^.struct_decl.is_packed := false
	st^.struct_decl.is_union := exp^.is_union

	if exp^.extends_name <> nil and exp^.extends_name_len > 0 then
		st^.struct_decl.extends_type := semantic_mh_make_type(ctx, false, false, 
			exp^.extends_name, exp^.extends_name_len, 0)
	end

	for i := 1 to exp^.field_count do
		f := @exp^.fields[i - 1]
		if f == nil or f^.name == nil or f^.name_len == 0 then
			semantic_error_at(loc, "semantic_mh_make_type_decl: field missing name")
		end

		field := node_create(ctx^.arena, NODE_FIELD_DECL, tok)
		field^.field_decl.name := semantic_arena_strndup(ctx^.arena, f^.name, f^.name_len)
		field^.field_decl.name_len := f^.name_len
		field^.field_decl.field_type := semantic_mh_make_type(ctx,
			f^.type_is_const, f^.type_is_pointer, f^.type_name, f^.type_name_len, f^.type_width)
		field^.field_decl.initializer := nil

		arena_append_ptr(ctx^.arena,
			(@st^.struct_decl.fields) as ppvoid,
			@st^.struct_decl.field_count,
			@st^.struct_decl.field_capacity,
			field)
	end

	decl := node_create(ctx^.arena, NODE_TYPE_DECL, tok)
	decl^.type_decl.name := bind_name
	decl^.type_decl.name_len := bind_len
	decl^.type_decl.defined_type := nil
	decl^.type_decl.struct_body := st
	decl^.type_decl.method_type := nil
	decl^.type_decl.enum_type := nil
	decl^.type_decl.initializer := nil
	decl^.type_decl.is_exported := false
	decl^.type_decl.is_extern := exp^.is_extern
	decl^.type_decl.is_forward := false

	return decl
end semantic_mh_make_type_decl


function semantic_mh_make_method_type_decl(ctx: pTSemanticContext, exp: const ^MhExport,
		loc: pNode, bind_name: const ^char, bind_len: size_t): pNode
begin
	var decl: pNode = nil
	var mt: pNode = nil
	var pl: pNode = nil
	var param: pNode = nil
	var ty: pTType = nil
	var i: size_t = 0
	var f: const ^MhFormal = nil
	var pname: ^char = nil
	var pbuf: array[32] of char
	var tok: TToken

	if ctx == nil or exp == nil or not exp^.has_signature then
		return nil
	end
	if exp^.is_struct or exp^.is_union then
		return nil
	end

	if loc <> nil then
		tok := loc^.token
	else
		tok.kind := 0
		tok.start := nil
		tok.length := 0
		tok.line := 0
		tok.column := 0
		tok.error_msg := nil
	end

	pl := node_create(ctx^.arena, NODE_PARAM_LIST, tok)
	pl^.param_list.params := nil
	pl^.param_list.count := 0
	pl^.param_list.capacity := 0

	for i := 1 to exp^.formal_count do
		f := @exp^.formals[i - 1]
		if f == nil or f^.type_name == nil or f^.type_name_len == 0 then
			semantic_error_at(loc, "semantic_mh_make_method_type_decl: formal missing type name")
		end
		ty := semantic_mh_make_type(ctx, f^.type_is_const, f^.type_is_pointer,
			f^.type_name, f^.type_name_len, f^.type_width)
		snprintf(@pbuf[0], 32, "_%zu", i - 1)
		pname := semantic_arena_strndup(ctx^.arena, @pbuf[0], strlen(@pbuf[0]))
		param := node_create(ctx^.arena, NODE_PARAM, tok)
		param^.param.name := pname
		param^.param.name_len := strlen(pname)
		param^.param.param_type := ty
		param^.param.is_var := f^.is_var
		param^.param.is_ref := f^.is_ref
		param^.param.is_const := f^.is_const
		arena_append_ptr(ctx^.arena,
			(@pl^.param_list.params) as ppvoid,
			@pl^.param_list.count,
			@pl^.param_list.capacity,
			param)
	end

	mt := node_create(ctx^.arena, NODE_METHOD_TYPE, tok)
	mt^.method_type.params := pl
	mt^.method_type.is_function := exp^.is_func_type
	mt^.method_type.return_type := nil
	if exp^.has_result and exp^.result_name <> nil and exp^.result_name_len > 0 then
		mt^.method_type.return_type := semantic_mh_make_type(ctx,
			exp^.result_is_const, exp^.result_is_pointer,
			exp^.result_name, exp^.result_name_len, exp^.result_width)
	end

	decl := node_create(ctx^.arena, NODE_TYPE_DECL, tok)
	decl^.type_decl.name := bind_name
	decl^.type_decl.name_len := bind_len
	decl^.type_decl.defined_type := nil
	decl^.type_decl.struct_body := nil
	decl^.type_decl.method_type := mt
	decl^.type_decl.enum_type := nil
	decl^.type_decl.initializer := nil
	decl^.type_decl.is_exported := false
	decl^.type_decl.is_extern := exp^.is_extern
	decl^.type_decl.is_forward := false

	return decl
end semantic_mh_make_method_type_decl


(**
 * bind one .mh export into the current scope (listed import or 7a unit entry).
 *)
procedure semantic_bind_mh_export(ctx: pTSemanticContext, loc: pNode,
		exp: const ^MhExport, bind_name: const ^char, bind_len: size_t)
begin
	var kind: SymbolKind = SYM_KIND_IMPORT
	var sym: pTSymbol = nil
	var synth: pNode = nil
	var owned: ^char = nil

	if ctx == nil or exp == nil or bind_name == nil or bind_len == 0 then
		return
	end

	kind := mh_export_to_symkind(exp^.kind)
	if kind == SYM_KIND_UNKNOWN then
		semantic_error_at(loc, "semantic_bind_mh_export: unknown export kind in .mh")
	end

	owned := semantic_arena_strndup(ctx^.arena, bind_name, bind_len)
	// semantic_define(ctx, kind, owned, bind_len, nil, loc, false)

	// sym := symtab_lookup_current(ctx^.scope, owned, bind_len)
	// if sym == nil then
	// 	semantic_error_at(loc, "semantic_bind_mh_export: internal: symbol not defined")
	// end
	if kind == SYM_KIND_TYPE and type_is_portable_rebindable(owned, bind_len) then
		semantic_bind_portable_import(ctx, loc, owned, bind_len)
	else
		semantic_define(ctx, kind, owned, bind_len, nil, loc, false)
	end

	sym := symtab_lookup_current(ctx^.scope, owned, bind_len)
	if sym == nil then
		semantic_error_at(loc, "semantic_bind_mh_export: internal: symbol not defined")
	end

	if exp^.has_signature and (kind == SYM_KIND_PROC or kind == SYM_KIND_FUNC) then
		synth := semantic_mh_make_proc_decl(ctx, exp, loc, owned, bind_len, kind)
		if synth <> nil then
			sym^.decl := synth
		end
	end
	if kind == SYM_KIND_TYPE and (exp^.is_struct or exp^.is_union) then
		synth := semantic_mh_make_type_decl(ctx, exp, loc, owned, bind_len)
		if synth <> nil then
			sym^.decl := synth
		end
	end
	if kind == SYM_KIND_TYPE and exp^.has_signature and
			not exp^.is_struct and not exp^.is_union then
		synth := semantic_mh_make_method_type_decl(ctx, exp, loc, owned, bind_len)
		if synth <> nil then
			sym^.decl := synth
		end
	end
	if kind == SYM_KIND_TYPE and exp^.has_alias and exp^.alias_name <> nil then
		var alias_ty: pTType = nil
		alias_ty := semantic_mh_make_type(ctx, exp^.alias_is_const, exp^.alias_is_pointer,
			exp^.alias_name, exp^.alias_name_len, exp^.alias_width)
		if alias_ty <> nil then
			sym^.symbol_type := alias_ty
		end
	end

	if exp^.is_method and exp^.is_instance then
		sym^.is_method_instance := true
	end
end semantic_bind_mh_export


(**
 * Register all names from an IMPORT ... FROM statement.
 * .mh paths: parse export table and register real symbol kinds.
 * .h paths: minimal SYM_KIND_IMPORT placeholders (unchanged).
 *)
procedure semantic_register_import(ctx: pTSemanticContext, decl: pNode)
begin
	var i: size_t = 0
	var resolved: ARRAY[4096] of char		// SEMANTIC_MH_PATH_MAX
	var m: MhModule
	var mname_len: size_t = 0
	var unit_exp: const ^MhExport = nil

	if decl == nil or decl^.kind <> NODE_IMPORT then
		return
	end

	if decl^.import_stmt.from_path == nil or decl^.import_stmt.path_len == 0 then
		semantic_error_at(decl, "semantic_register_import: IMPORT requires FROM import-source")
	end

	if mh_path_is_mh(decl^.import_stmt.from_path, decl^.import_stmt.path_len) then
		if ctx^.source_path == nil then
			semantic_error_at(decl, "semantic_register_import: internal error: missing source_path for .mh")
		end
		if not mh_resolve_import_path(ctx^.source_path,
			decl^.import_stmt.from_path, decl^.import_stmt.path_len,
			@resolved[0], SEMANTIC_MH_PATH_MAX) then
			semantic_error_at(decl, "semantic_register_import: cannot resolve .mh path")
		end
		if not mh_reader_load(@resolved[0], @m) then
			semantic_error_at(decl, "semantic_register_import: failed to read .mh file")
		end

		for i := 1 to decl^.import_stmt.count do
			var item: pNode = decl^.import_stmt.items[i - 1]
			var lookup_name: const ^char = nil
			var lookup_len: size_t = 0
			var bind_name: const ^char = nil
			var bind_len: size_t = 0
			var mangled: ^char = nil
			var exp: const ^MhExport = nil
			// var kind: SymbolKind = SYM_KIND_IMPORT
			// var sym: pTSymbol = nil

			// if item^.import_item.import_alias <> nil and item^.import_item.import_alias_len > 0 then
			// 	name 		:= item^.import_item.import_alias
			// 	name_len 	:= item^.import_item.import_alias_len
			// else
			// 	name		:= item^.import_item.qualident
			// 	name_len	:= item^.import_item.qualident_len
			if item == nil or item^.kind <> NODE_IMPORT_ITEM then
				semantic_error_at(decl, "semantic_register_import: expected import item")
			end

			// Lookup key in .mh: Type::name => Type__name; else written name (may already be mangled).
			if item^.import_item.method_owner <> nil and
					item^.import_item.method_owner_len > 0 then
				mangled := semantic_mangle_method(ctx^.arena,
					item^.import_item.method_owner,
					item^.import_item.method_owner_len,
					item^.import_item.qualident,
					item^.import_item.qualident_len)
				lookup_name := mangled
				lookup_len := item^.import_item.method_owner_len + 2 +
					item^.import_item.qualident_len
			else
				lookup_name := item^.import_item.qualident
				lookup_len := item^.import_item.qualident_len
			end

			if lookup_name == nil or lookup_len == 0 then
				semantic_error_at(item, "semantic_register_import: import item has no name")
			end

			exp := mh_module_find(@m, lookup_name, lookup_len)
			if exp == nil then
				var buf: array[256] of char
				snprintf(@buf[0], 256,
					"semantic_register_import: name not exported in .mh: %.*s",
					lookup_len as int, lookup_name)
				semantic_error_at(item, @buf[0])
			end

			// kind := mh_export_to_symkind(exp^.kind)
			// if kind == SYM_KIND_UNKNOWN then
			// 	semantic_error_at(item, "semantic_register_import: unknown export kind in .mh")
			// end

			// Symtab name: AS alias if present, else mangled / lookup name.
			if item^.import_item.import_alias <> nil and
					item^.import_item.import_alias_len > 0 then
				bind_name := item^.import_item.import_alias
				bind_len := item^.import_item.import_alias_len
			else
				bind_name := lookup_name
				bind_len := lookup_len
			end

			// semantic_define(ctx, kind, bind_name, bind_len, nil, item, false)

			// // A2 metadata => symbol flag for A4 instance sugar
			// if exp^.is_method and exp^.is_instance then
			// 	sym := symtab_lookup_current(ctx^.scope, bind_name, bind_len)
			// 	if sym <> nil then
			// 		sym^.is_method_instance := true
			// 	end
			// end
			// sym := symtab_lookup_current(ctx^.scope, bind_name, bind_len)
			// if sym == nil then
			// 	semantic_error_at(item, "semantic_register_import: internal: symbol not defined")
			// end

			// S4: synthetic proc/func with formals for auto-& / upcast
			// if exp^.has_signature and
			// 		(kind == SYM_KIND_PROC or kind == SYM_KIND_FUNC) then
			// 	var synth: pNode = nil
			// 	synth := semantic_mh_make_proc_decl(ctx, exp, item, 
			// 		bind_name, bind_len, kind)
			// 	if synth <> nil then
			// 		sym^.decl := synth
			// 	end
			// end

			// Phase A: instance method import
			// if exp^.is_method and exp^.is_instance then
			// 	sym^.is_method_instance := true
			// end
			semantic_bind_mh_export(ctx, item, exp, bind_name, bind_len)
		end

		// 7a: any named import from this .mh also binds the unit-entry export.
		if decl^.import_stmt.count > 0 and m.module_name <> nil then
			mname_len := m.module_name_len
			unit_exp := mh_module_find(@m, m.module_name, mname_len)
			if unit_exp <> nil then
				if symtab_lookup_current(ctx^.scope, m.module_name, mname_len) == nil then
					semantic_bind_mh_export(ctx, decl, unit_exp, m.module_name, mname_len)
				end
			end
		end

		mh_module_free(@m)
	else
		for i := 1 to decl^.import_stmt.count do
			semantic_register_import_item(ctx, decl^.import_stmt.items[i - 1])
		end
	end
end semantic_register_import


(**
 * Register a parameter list (NODE_PARAM_LIST or program_decl.params array).
 *)
procedure semantic_register_param_list(ctx: pTSemanticContext, params: ^pNode, count: size_t)
begin
	var i: size_t = 0

	for i := 1 to count do
		let param: pNode = params[i-1]
		if param == nil or param^.kind <> NODE_PARAM then
			semantic_error_at(param, "semantic_register_param_list: internal error: expected parameter")
		end

		if param^.param.name == nil or param^.param.name_len == 0 then
			semantic_error_at(param, "semantic_register_param_list: parameter has no name")
		end

		if param^.param.param_type <> nil then
			semantic_resolve_type(ctx, param^.param.param_type, param)
		end

		semantic_define(ctx, SYM_KIND_PARAM, param^.param.name, param^.param.name_len, 		\
			param^.param.param_type, param, false)
	end
end


(**
 * Register one builtin type in the semantic prelude (global scop).
 *)
procedure semantic_register_prelude_builtin(ctx: pTSemanticContext, name: const ^char, name_len: size_t)
begin
	var sym: pTSymbol = nil
 	var ty: ^TType = nil

 	if ctx == nil or ctx^.scope == nil then
 		semantic_error_at(nil, "semantic_register_prelude_builtin: internal error: no active scope")
 	end

 	ty := type_create_named(ctx^.arena, name, name_len)
 	sym := symbol_create(ctx^.arena, SYM_KIND_TYPE, name, name_len, nil)
 	sym^.symbol_type := ty
 	symtab_define(ctx^.arena, ctx^.scope, sym)
 end


(**
 * Install builtin types into the program/module global scope.
 * See docs/grammar.md - bool, byte, char, integer, cardinal, real, string.
 *)
procedure semantic_register_prelude(ctx: pTSemanticContext)
begin
	semantic_register_prelude_builtin(ctx, "bool", 4)
	semantic_register_prelude_builtin(ctx, "bit", 3)
	semantic_register_prelude_builtin(ctx, "int", 3)
	semantic_register_prelude_builtin(ctx, "byte", 4)
	semantic_register_prelude_builtin(ctx, "char", 4)
	semantic_register_prelude_builtin(ctx, "real", 4)
	semantic_register_prelude_builtin(ctx, "long", 4)
	semantic_register_prelude_builtin(ctx, "float", 5)
	semantic_register_prelude_builtin(ctx, "short", 5)
	semantic_register_prelude_builtin(ctx, "double", 6)
	semantic_register_prelude_builtin(ctx, "string", 6)
	semantic_register_prelude_builtin(ctx, "integer", 7)
	semantic_register_prelude_builtin(ctx, "cardinal", 8)
end


(**
 * True for literal spellings the parser still emits as NODE_IDENT.
 * Case-insensitive (Mod-c keyword rules). Remove when lexer owns NIL/TRUE/FALSE.
 *)
function semantic_is_literal_ident(name: const ^char, name_len: size_t): bool
begin
	if name == nil or name_len == 0 then
		return false
	elsif name_len == 3 then
		return strncasecmp(name, "nil", 3) == 0 or 		\
			memcmp(name, "NaN", 3) == 0
	elsif name_len == 4 then
		return strncasecmp(name, "true", 4) == 0
	elsif name_len == 5 then
		return strncasecmp(name, "false", 5) == 0
	else
		return false
	end
end


(**
 * Resolve one identifier use.
 *)
procedure semantic_resolve_ident(ctx: pTSemanticContext, n: pNode)
begin
	var sym: pTSymbol = nil
	var name: const ^char = nil
	var name_len: size_t = 0

	if n == nil or n^.kind <> NODE_IDENT then
		return
	end

	name 		:= n^.token.start
	name_len 	:= n^.token.length

	if name == nil or name_len == 0 then
		semantic_error_at(n, "semantic_resolve_ident: internal error: identifier has no token text")
	end

	if semantic_is_literal_ident(name, name_len) then
		return
	end

	sym := symtab_lookup(ctx^.scope, name, name_len)
	if sym == nil then
		semantic_error_at(n, "semantic_resolve_ident: undefined identifier")
	end
	n^.resolved_sym := sym
end semantic_resolve_ident


(**
 * Build linker name Type__method in arena storage.
 *)
function semantic_mangle_method(arena: ^Arena, owner: const ^char, owner_len: size_t, 	\
	method: const ^char, method_len: size_t): ^char
begin
	var total: size_t = owner_len + 2 + method_len
	var buf: ^char = arena_alloc(arena, total + 1) as ^char

	memcpy(buf, owner, owner_len)
	buf[owner_len] 		:= '_'
	buf[owner_len + 1]	:= '_'
	memcpy(buf + owner_len + 2, method, method_len)
	buf[total] 	:= '\0'
	return buf
end semantic_mangle_method


(**
 * Symtab registration name: Type__method for qualified decls, plan name otherwise.
 *)
function semantic_proc_sym_name(ctx: pTSemanticContext, decl: pNode): TProcSymName
begin
	var result: TProcSymName

	if decl^.proc_decl.method_owner <> nil and decl^.proc_decl.method_owner_len > 0 then
		result.name := semantic_mangle_method(ctx^.arena,						\
			decl^.proc_decl.method_owner, decl^.proc_decl.method_owner_len,		\
			decl^.proc_decl.name, decl^.proc_decl.name_len)
		result.length := decl^.proc_decl.method_owner_len + 2 + decl^.proc_decl.name_len
	else
		result.name 	:= decl^.proc_decl.name
		result.length	:= decl^.proc_decl.name_len
	end

	return result
end semantic_proc_sym_name


(**
 * True if decl is a Type:: method whose first formal type is the owner type
 * (instance method). Formal name is free (Oberon-style; need not be "self").
 * False => static / factory: no formals, or first formal type <> owner, or
 * not a type-qualified method. Poitner first formals are not instance in v1.
 *)
 function semantic_method_is_instance(ctx: pTSemanticContext, decl: pNode): bool
 begin
	var params_list: pNode = nil
	var self_param: pNode = nil
	var pt: pTType = nil
	var owner: const ^char = nil
	var owner_len: size_t = 0

	if decl == nil then
		return false
	end

	if decl^.kind <> NODE_PROC_DECL and decl^.kind <> NODE_FUNC_DECL then
		return false
	end

	owner		:= decl^.proc_decl.method_owner
	owner_len 	:= decl^.proc_decl.method_owner_len
	if owner == nil or owner_len == 0 then
		return false
	end

	params_list := decl^.proc_decl.params
	if params_list == nil or params_list^.kind <> NODE_PARAM_LIST or
			params_list^.param_list.count == 0 then
		return false 		// static: no parameters
	end

	self_param := params_list^.param_list.params[0]
	if self_param == nil or self_param^.kind <> NODE_PARAM then
		return false
	end

	pt := self_param^.param.param_type
	if pt == nil then
		return false
	end

	semantic_resolve_type(ctx, pt, self_param)
	if pt^.resolved_type <> nil then
		pt := pt^.resolved_type
	end

	// v1 instance receivers are by-value named owner type, not ^Owner
	if pt^.is_pointer or pt^.is_array then
		return false
	end
	if pt^.name == nil or pt^.name_len == 0 then
		return false
	end
	return semantic_names_equal(pt^.name, pt^.name_len, owner, owner_len)
end semantic_method_is_instance


(**
 * Type:: methods: instance vs static is determined by first formal type
 * (see semantic_method_is_instance). Both forms are legal at declaration;
 * resolve first formal type early so bad type names still fail here.
 *)
procedure semantic_verify_method_self(ctx: pTSemanticContext, decl: pNode)
begin
	// Side effect: resolve first formal when present (instance or static).
	// No error if first formal type <> owner -- that is a static method.
	(semantic_method_is_instance(ctx, decl))

	// yea, nothing useful happens right now. TODO: cleanup/refactor/remove
	
end semantic_verify_method_self


(**
 * If ty names TYPE ... = PROCEDURE/FUNCTION ... return NODE_METHOD_TYPE (else nil).
 *)
function semantic_method_type_node(ctx: pTSemanticContext, ty: pTType): pNode
begin
	var t: pTType = ty
	var sym: pTSymbol = nil

	if ctx == nil or t == nil then
		return nil
	end
	if t^.resolved_type <> nil then
		t := t^.resolved_type
	end
	if t^.name == nil or t^.name_len == 0 then
		return nil
	end
	sym := symtab_lookup(ctx^.scope, t^.name, t^.name_len)
	if sym == nil or sym^.kind <> SYM_KIND_TYPE or sym^.decl == nil then
		return nil
	end
	if sym^.decl^.kind <> NODE_TYPE_DECL then
		return nil
	end
	return sym^.decl^.type_decl.method_type
end semantic_method_type_node


(**
 * semantic_field_type_on
 *)
function semantic_field_type_on(ctx: pTSemanticContext, recv_ty: pTType,
		fname: const ^char, flen: size_t): pTType
begin
	var st: pNode = nil
	var i: size_t = 0
	var f: pNode = nil

	if ctx == nil or recv_ty == nil or fname == nil then
		return nil
	end
	st := semantic_struct_body_of_type(ctx, recv_ty)
	while st <> nil do
		for i := 1 to st^.struct_decl.field_count do
			f := st^.struct_decl.fields[i-1]
			if f <> nil and semantic_names_equal(f^.field_decl.name, f^.field_decl.name_len,
					fname, flen) then
				return f^.field_decl.field_type
			end
		end
		if st^.struct_decl.extends_type == nil then
			return nil
		end
		st := semantic_struct_body_of_type(ctx, st^.struct_decl.extends_type)
	end
	return nil
end semantic_field_type_on


(**
 * semantic_sym_is_method_value
 *)
function semantic_sym_is_method_value(ctx: pTSemanticContext, sym: pTSymbol): bool
begin
	if sym == nil then
		return false
	end
	if sym^.kind <> SYM_KIND_VAR and sym^.kind <> SYM_KIND_PARAM and
			sym^.kind <> SYM_KIND_LET and sym^.kind <> SYM_KIND_CONST then
		return false
	end
	return semantic_method_type_node(ctx, sym^.symbol_type) <> nil
end semantic_sym_is_method_value


(**
 * Distance along EXTENDS from ty's named struct to name.
 * 0 = same name. Ignores is_pointer (named ^Child still walks Child).
 *)
function semantic_chain_depth_to_name(ctx: pTSemanticContext, ty: pTType,
	name: const ^char, name_len: size_t, out_depth: ^size_t): bool
begin
	var t: pTType = ty
	var st: pNode = nil
	var depth: size_t = 0
	var parent_ty: pTType = nil

	if out_depth <> nil then
		out_depth^ := 0
	end
	if ctx == nil or t == nil or name == nil or name_len == 0 then
		return false
	end
	if t^.resolved_type <> nil then
		t := t^.resolved_type
	end
	if t^.name <> nil and semantic_names_equal(t^.name, t^.name_len, name, name_len) then
		return true
	end
	st := semantic_struct_body_of_type(ctx, t)
	while st <> nil and st^.struct_decl.extends_type <> nil do
		parent_ty := st^.struct_decl.extends_type
		depth := depth + 1
		if parent_ty^.name <> nil and semantic_names_equal(parent_ty^.name,
				parent_ty^.name_len, name, name_len) then
			if out_depth <> nil then
				out_depth^ := depth
			end
			return true
		end
		st := semantic_struct_body_of_type(ctx, parent_ty)
	end
	return false
end semantic_chain_depth_to_name


(**
 * Instance Type__name on recv_ty, then each EXTENDS parent.
 * is_static: a Type_name exists at that level but is not instance (stop).
 *)
function semantic_find_instance_on_chain(ctx: pTSemanticContext, recv_ty: pTType,
	method: const ^char, method_len: size_t): TMethodChainHit
begin
	var result: TMethodChainHit
	var ty: pTType = recv_ty
	var st: pNode = nil
	var mangled: ^char = nil
	var owner: const ^char = nil
	var owner_len: size_t = 0
	var depth: size_t = 0
	var sym: pTSymbol = nil

	result.sym := nil
	result.owner := nil
	result.owner_len := 0
	result.depth := 0
	result.is_static := false

	if ctx == nil or ty == nil or method == nil or method_len == 0 then
		return result
	end
	if ty^.resolved_type <> nil then
		ty := ty^.resolved_type
	end

	while ty <> nil do
		owner := ty^.name
		owner_len := ty^.name_len
		if owner == nil or owner_len == 0 then
			return result
		end
		mangled := semantic_mangle_method(ctx^.arena, owner, owner_len,
			method, method_len)
		sym := symtab_lookup(ctx^.scope, mangled, owner_len + 2 + method_len)
		if sym <> nil then
			result.sym := sym
			result.owner := owner
			result.owner_len := owner_len
			result.depth := depth
			if sym^.is_method_instance or 
					(sym^.decl <> nil and semantic_method_is_instance(ctx, sym^.decl)) then
				return result
			end
			result.is_static := true
			return result
		end
		st := semantic_struct_body_of_type(ctx, ty)
		if st == nil or st^.struct_decl.extends_type == nil then
			return result
		end
		ty := st^.struct_decl.extends_type
		depth := depth + 1
	end
	return result
end semantic_find_instance_on_chain



(**
 * Resolve a call target (procedure/function) and its arguments.
 * Type::name uses method_owner from the parser.
 * obj.method (item 21): instance Type__method; receiver prepended in codegen.
 * obj.field: method-typed field call-through (Oberon: no auto-self); callee_expr
 * Ambiguity if both instance method and method-typed field share the name
 * Free name: PROC/FUNC/IMPORT, or VAR/PARAM/LET/CONST of method type.
 * Unresolved free names and Type::name are errors (0.26).
 *)
recursive procedure semantic_resolve_call(ctx: pTSemanticContext, n: pNode)
begin
	var sym: pTSymbol = nil
	var lookup_name: const ^char = nil
	var lookup_len: size_t = 0
	var mangled: ^char = nil
	var i: size_t = 0
	var recv_ty: pTType = nil
	var owner: const ^char = nil
	var owner_len: size_t = 0
	var pl: pNode = nil
	var formals: ^pNode = nil
	var fcount: size_t = 0
	var fi: size_t = 0
	var formal: pNode = nil
	var formal_index: size_t = 0
	var has_receiver: bool = false
	var field_ty: pTType = nil
	var mt: pNode = nil
	var is_instance: bool = false
	var field_callable: bool = false
	var hit: TMethodChainHit

	if n == nil or n^.kind <> NODE_CALL then
		return
	end
	n^.call.base_depth := 0

	// -- Dot-call: obj.name(...) may be instance method or field call-through ---
	if n^.call.receiver_expr <> nil then
		has_receiver := true
		semantic_resolve_expr(ctx, n^.call.receiver_expr)

		recv_ty := semantic_type_of_expr(ctx, n^.call.receiver_expr)
		if recv_ty == nil then
			semantic_error_at(n, "semantic_resolve_call: cannot determine type of method receiver")
		end
		n^.call.auto_deref := semantic_type_is_pointer(recv_ty)
		if recv_ty^.resolved_type <> nil then
			recv_ty := recv_ty^.resolved_type
		end
		if recv_ty^.name == nil or recv_ty^.name_len == 0 then
			semantic_error_at(n, "semantic_resolve_call: method receiver has no named type")
		end

		owner 		:= recv_ty^.name
		owner_len 	:= recv_ty^.name_len

		hit := semantic_find_instance_on_chain(ctx, recv_ty,
			n^.call.name, n^.call.name_len)
		if hit.is_static then
			semantic_error_at(n,
				"semantic_resolve_call: static method cannot be caled with instance syntax: use Type::name(...)")
		end
		sym := hit.sym
		is_instance := (sym <> nil)
		owner := hit.owner
		owner_len := hit.owner_len

		// Candidate method-typed field on the receiver type
		field_ty := semantic_field_type_on(ctx, recv_ty, n^.call.name, n^.call.name_len)
		mt := semantic_method_type_node(ctx, field_ty)
		field_callable := (mt <> nil)

		if is_instance and field_callable then
			semantic_error_at(n, 
				"semantic_resolve_call: ambiguous obj.name(...): instance method and callable field; use Type::name(obj, ...)")
		end

		if is_instance then
			n^.call.method_owner 		:= owner
			n^.call.method_owner_len 	:= owner_len
			n^.call.callee_expr 		:= nil
			n^.resolved_sym 			:= sym
			n^.call.base_depth 			:= hit.depth
		elsif field_callable then
			// Oberon: call through field value; no auto-self / no receiver prepend
			if n^.call.callee_expr == nil then
				semantic_error_at(n, "semantic_resolve_call: integernal: missing field callee_expr")
			end
			semantic_resolve_expr(ctx, n^.call.callee_expr)
			n^.call.receiver_expr 		:= nil
			n^.call.method_owner 		:= nil
			n^.call.method_owner_len 	:= 0
			n^.call.auto_deref 			:= false
			n^.resolved_sym 			:= nil
			sym 						:= nil
			has_receiver 				:= false
		// elsif sym <> nil then
		// 	// 
		// 	// Found Type__name but not instance (static / factory)
		// 	semantic_error_at(n,
		// 		"semantic_resolve_call: static method cannot be called with instance syntax: use Type::name(...)")
		else
			semantic_error_at(n,
				"semantic_resolve_call: undefined type-bound method or non-callable field")
		end
	else
		// --- Free call / Type::name (method_owner already set by parser) ---
		if n^.call.method_owner <> nil and n^.call.method_owner_len > 0 then
			mangled := semantic_mangle_method(ctx^.arena,
				n^.call.method_owner, n^.call.method_owner_len,
				n^.call.name, n^.call.name_len)
			lookup_name 	:= mangled
			lookup_len 		:= n^.call.method_owner_len + 2 + n^.call.name_len
		else
			lookup_name 	:= n^.call.name
			lookup_len 		:= n^.call.name_len
		end

		// sym := symtab_lookup(ctx^.scope, lookup_name, lookup_len)
		// if sym <> nil then
		// 	if sym^.kind <> SYM_KIND_PROC and sym^.kind <> SYM_KIND_FUNC and
		// 			sym^.kind <> SYM_KIND_IMPORT and
		// 			not semantic_sym_is_method_value(ctx, sym) then
		// 		semantic_error_at(n, "semantic_resolve_call: identifier is not callable")
		// 	end
		// end
		// n^.resolved_sym := sym
		// // unresolved free names still allowed (C foreign soft-miss)
		sym := symtab_lookup(ctx^.scope, lookup_name, lookup_len)
		if sym <> nil then
			if sym^.kind <> SYM_KIND_PROC and sym^.kind <> SYM_KIND_FUNC and
					sym^.kind <> SYM_KIND_IMPORT and
					not semantic_sym_is_method_value(ctx, sym) then
				semantic_error_at(n, "semantic_resolve_call: identifier isnot callable")
			end
		else
			if n^.call.method_owner <> nil and n^.call.method_owner_len > 0 then
				semantic_error_at(n, "semantic_resolve_call: undefined type-bound method")
			else
				semantic_error_at(n, "semantic_resolve_call: undefined procedure or function")
			end
		end
		n^.resolved_sym := sym

	end

	// if sym == nil or (sym^.kind <> SYM_KIND_PROC and sym^.kind <> SYM_KIND_FUNC) then
	// 	semantic_error_at(n, "undefined procedure or function")
	// end

	for i := 1 to n^.call.argc do
		semantic_resolve_expr(ctx, n^.call.args[i-1])
	end

	// Type::m(p) only. Do not touch pp.getX() (receiver_expr already set the flag).
	if n^.call.receiver_expr == nil and n^.call.method_owner <> nil and
			n^.call.argc > 0 and n^.resolved_sym <> nil and
			(n^.resolved_sym^.is_method_instance or
				(n^.resolved_sym^.decl <> nil and
					semantic_method_is_instance(ctx, n^.resolved_sym^.decl))) then
		n^.call.auto_deref := false
		begin
			var arg_ty: pTType = nil
			var arg0: pNode = n^.call.args[0]
			var chain_d: size_t = 0

			if arg0^.kind == NODE_UNARY and arg0^.unary.op == TOK_AT then
				; // already &x for a REF formal; do not wrap (*&)
			else
				arg_ty := semantic_type_of_expr(ctx, n^.call.args[0])
				if semantic_type_is_pointer(arg_ty) then
					if semantic_chain_depth_to_name(ctx, arg_ty, n^.call.method_owner,
							n^.call.method_owner_len, @chain_d) then
						n^.call.auto_deref := true
						n^.call.base_depth := chain_d
					end
				end
			end
		end
	end

	// Prefer resolved_sym after reclassification (field path clears local sym above).
	sym := n^.resolved_sym

	// Direct self-call: same PROC/FUNC node as enclosing_func. Field
	// call-through has resolved_sym = nil. NODE_PROGRAM unit body is skipped.
	if ctx^.enclosing_func <> nil and
			(ctx^.enclosing_func^.kind == NODE_PROC_DECL or
			 ctx^.enclosing_func^.kind == NODE_FUNC_DECL) and
			sym <> nil and sym^.decl == ctx^.enclosing_func and
			not ctx^.enclosing_func^.proc_decl.is_recursive then
		semantic_error_at(n,
			"semantic_resolve_call: direct recursion requires RECURSIVE")
	end

	// EXTENDS auto-upcast: by-value formals of same-unit PROC/FUNC decls
	if sym <> nil and sym^.decl <> nil and
			(sym^.decl^.kind == NODE_PROC_DECL or sym^.decl^.kind == NODE_FUNC_DECL) then

		pl := sym^.decl^.proc_decl.params
		formals := nil
		fcount := 0
		if pl <> nil and pl^.kind == NODE_PARAM_LIST then
			formals := pl^.param_list.params
			fcount := pl^.param_list.count
		end

		// Formal 0 is the receiver when using obj.method(...).
		if has_receiver and fcount > 0 and formals <> nil then
			formal_index := 1
		else
			formal_index := 0
		end

		for fi := 1 to n^.call.argc do
			if formal_index >= fcount then
				break
			end
			formal := formals[formal_index]
			if formal <> nil and formal^.kind == NODE_PARAM and
					formal^.param.param_type <> nil then
				semantic_maybe_upcast(ctx, n^.call.args[fi - 1],
					formal^.param.param_type)
			end
			formal_index := formal_index + 1
		end
	end
end semantic_resolve_call


(**
 * Resolve SIZEOF operand: validate type names; designators must not be types.
 * LEN uses the same designator path (no type operand).
 *)
procedure semantic_resolve_sizeof(ctx: pTSemanticContext, n: pNode)
begin
	var sym: pTSymbol = nil
	var ty: pTType = nil
	var name: const ^char = nil
	var name_len: size_t = 0
	var d: pNode = nil

	if n == nil or (n^.kind <> NODE_SIZEOF and n^.kind <> NODE_LEN) then
		return
	end
	if n^.kind == NODE_LEN and n^.sizeof_expr.is_type then
		semantic_error_at(n, "semantic_resolve_sizeof: LEN takes a designator, not a type")
	end

	if n^.sizeof_expr.is_type then
		ty := n^.sizeof_expr.target.sizeof_type
		if ty == nil or ty^.name == nil or ty^.name_len == 0 then
			semantic_error_at(n, "semantic_resolve_sizeof: SIZEOF type operand has no name")
		end
		name := ty^.name
		name_len := ty^.name_len
		if not type_is_builtin_name(name, name_len) then
			sym := symtab_lookup(ctx^.scope, name, name_len)
			if sym == nil or sym^.kind <> SYM_KIND_TYPE then
				semantic_error_at(n, "semantic_resolve_sizeof: unknown type in SIZEOF")
			end
		end
		semantic_resolve_type(ctx, ty, n)
	else
		d := n^.sizeof_expr.target.designator
		if d == nil then
			if n^.kind == NODE_LEN then
				semantic_error_at(n, "semantic_resolve_sizeof: LEN designator missing")
			else
				semantic_error_at(n, "semantic_resolve_sizeof: SIZEOF designator missing")
			end
		end
		if d^.kind == NODE_IDENT then
			name := d^.token.start
			name_len := d^.token.length
			if name <> nil and name_len > 0 then
				if type_is_builtin_name(name, name_len) then
					semantic_error_at(n, "semantic_resolve_sizeof: LEN/SIZEOF: type name is not a designator")
				end
				sym := symtab_lookup(ctx^.scope, name, name_len)
				if sym <> nil and sym^.kind == SYM_KIND_TYPE then
					semantic_error_at(n, "semantic_resolve_sizeof: LEN/SIZEOF: type name is not a designator")
				end
			end
		end
		semantic_resolve_expr(ctx, d)
	end
end semantic_resolve_sizeof


(**
 * Walk an expression tree and resole identifier/call uses.
 *)
recursive procedure semantic_resolve_expr(ctx: pTSemanticContext, n: pNode)
begin
	// var i: size_t = 0

	if n == nil then
		return
	end

	switch n^.kind of
		case NODE_IDENT:
			semantic_resolve_ident(ctx, n)

		case NODE_CALL:
			semantic_resolve_call(ctx, n)

		case NODE_BINARY:
			semantic_resolve_expr(ctx, n^.binary.left)
			semantic_resolve_expr(ctx, n^.binary.right)

		case NODE_UNARY:
			semantic_resolve_expr(ctx, n^.unary.operand)
			if n^.unary.op == TOK_AT then
				semantic_forbid_at_immutable(n^.unary.operand)
			end

		case NODE_PAREN:
			semantic_resolve_expr(ctx, n^.paren.expr)

		case NODE_CAST:
			if n^.cast_expr.target_type <> nil then
				semantic_resolve_type(ctx, n^.cast_expr.target_type, n)
			end
			semantic_resolve_expr(ctx, n^.cast_expr.expr)
			if n^.cast_expr.target_type <> nil then
				var inner_ty: pTType = nil
				var d: size_t = 0

				inner_ty := semantic_type_of_expr(ctx, n^.cast_expr.expr)
				d := semantic_extends_upcast_depth(ctx, inner_ty,
					n^.cast_expr.target_type)
				if d > 0 then
					n^.upcast_depth := d
					n^.upcast_ptr := inner_ty^.is_pointer
				end
			end

		case NODE_TERNARY:
			semantic_resolve_expr(ctx, n^.ternary.cond)
			semantic_resolve_expr(ctx, n^.ternary.then_expr)
			semantic_resolve_expr(ctx, n^.ternary.else_expr)

		case NODE_ARRAY_INDEX:
			semantic_resolve_expr(ctx, n^.array_index.array_)
			semantic_resolve_expr(ctx, n^.array_index.index)
			n^.array_index.auto_deref := false
			begin
				var arr_ty: pTType = nil

				arr_ty := semantic_type_of_designator(ctx, n^.array_index.array_)
				if semantic_type_is_pointer_to_array(arr_ty) then
					n^.array_index.auto_deref := true
				end
			end

		case NODE_FIELD_ACCESS:
			semantic_resolve_expr(ctx, n^.field_access.record_)
			begin
				var rec_ty: pTType = nil
				var st: pNode = nil
				var depth: size_t = 0

				n^.field_access.base_depth := 0
				n^.field_access.auto_deref := false
				rec_ty := semantic_type_of_designator(ctx, n^.field_access.record_)
				// if rec_ty <> nil then
				// 	if rec_ty^.is_pointer then
				// 		n^.field_access.auto_deref := true
				// 	elsif rec_ty^.resolved_type <> nil and rec_ty^.resolved_type^.is_pointer then
				// 		n^.field_access.auto_deref := true
				// 	end
				// end
				if semantic_type_is_pointer(rec_ty) then
					n^.field_access.auto_deref := true
				end
				st := semantic_struct_body_of_type(ctx, rec_ty)
				if st <> nil then
					if semantic_find_field_depth(ctx, st, n^.field_access.field_name,
								n^.field_access.field_len, @depth) then
						n^.field_access.base_depth := depth
					else
						semantic_error_at(n, "semantic_resolve_expr, unknown field for STRUCT type")
					end
				end
				// else: foreign / untyped left side - leave depth 0
			end

		case NODE_SIZEOF, NODE_LEN:
			semantic_resolve_sizeof(ctx, n)

		case NODE_LITERAL, NODE_ARRAY_LITERAL:
			// no identifiers

		case NODE_INC, NODE_DEC:
			semantic_resolve_expr(ctx, n^.binary.left)
			semantic_forbid_for_control_write(ctx, n^.binary.left)
			semantic_forbid_param_mode_write(n^.binary.left)
			semantic_forbid_let_write(n^.binary.left)
			if n^.binary.right <> nil then
				semantic_resolve_expr(ctx, n^.binary.right)
			end

		else:
			// other expression kinds: phase 2 later
	end
end semantic_resolve_expr


(**
 * Register VAR / CONST / LET items from a declaration node.
 *)
procedure semantic_register_var_decl(ctx: pTSemanticContext, decl: pNode, kind: SymbolKind)
begin
	var i: size_t = 0
	var count: size_t = 0
	var items: ^pNode = nil
	var is_exported: bool = false

	if decl == nil then
		return
	end

	if kind == SYM_KIND_VAR and decl^.kind == NODE_VAR_DECL then
		count  		:= decl^.var_decl.count
		items 		:= decl^.var_decl.items
		is_exported := decl^.var_decl.is_exported
	elsif kind == SYM_KIND_CONST and decl^.kind == NODE_CONST_DECL then
		count 		:= decl^.const_decl.count
		items 		:= decl^.const_decl.items
		is_exported := decl^.const_decl.is_exported
	elsif kind == SYM_KIND_LET and decl^.kind == NODE_LET_DECL then
		count 		:= decl^.let_decl.count
		items 		:= decl^.let_decl.items
		is_exported := decl^.let_decl.is_exported
	else
		semantic_error_at(decl, "semantic_register_var_decl: internal error: unexpected var/const/let decl")
	end

	for i := 1 to count do
		let item: pNode = items[i-1]
		if item == nil or item^.var_item.name == nil or item^.var_item.name_len == 0 then
			semantic_error_at(decl, "semantic_register_var_decl: declaration item has no name")
		end
		if item^.var_item.initializer <> nil then
			semantic_resolve_expr(ctx, item^.var_item.initializer)
		end

		// if item^.var_item.item_type <> nil then
		// 	semantic_resolve_type(ctx, item^.var_item.item_type, item)
		if item^.var_item.item_type == nil and item^.var_item.initializer <> nil then
			// Item 21a: infer type from initializer when ":" was omitted.
			item^.var_item.item_type := semantic_type_of_expr(ctx, item^.var_item.initializer)
			if item^.var_item.item_type == nil then
				semantic_error_at(item, "semantic_register_var_decl: cannot infer type from initializer")
			end
		end

		if item^.var_item.item_type <> nil then
			semantic_resolve_type(ctx, item^.var_item.item_type, item)
		end

		// EXENDS: var p: Parent = child => upcast on initializer
		if item^.var_item.initializer <> nil and item^.var_item.item_type <> nil then
			semantic_maybe_upcast(ctx, item^.var_item.initializer, item^.var_item.item_type)
		end

		if decl^.kind == NODE_VAR_DECL and decl^.var_decl.is_extern then
			semantic_define_or_refine(ctx, kind, item^.var_item.name, item^.var_item.name_len,	\
				item^.var_item.item_type, item, is_exported)
		else
			semantic_define(ctx, kind, item^.var_item.name, item^.var_item.name_len, 		\
				item^.var_item.item_type, item, is_exported)
		end

		// Fold compile-time CONST values (needed for array[LIMIT], case, etc.)
		if kind == SYM_KIND_CONST and item^.var_item.initializer <> nil then
			var csym: pTSymbol = nil
			var cval: integer = 0
			csym := symtab_lookup_current(ctx^.scope, item^.var_item.name, item^.var_item.name_len)
			if csym == nil then
				semantic_error_at(item, "semantic_register_var_decl: CONST not in scope after define")
			end			
			if semantic_try_eval_const_expr(ctx, item^.var_item.initializer, @cval, nil) then
				csym^.has_const_value := true
				csym^.const_value := cval
			end
		end
	end
end


(**
 * Resolve uses in one statement (no declaration registration).
 *)
procedure semantic_resolve_stmt(ctx: pTSemanticContext, n: pNode)
begin
	var i: size_t = 0
	var j: size_t = 0
	var sc: ^SwitchCase = nil

	if n == nil then
		return
	end

	switch n^.kind of
		case NODE_EXPR_STMT:
			// semantic_resolve_expr(ctx, n^.expr_stmt.expr)
			begin
				var e: pNode = n^.expr_stmt.expr
				var ty: pTType = nil

				semantic_resolve_expr(ctx, e)
				// 13b Policy A: bar call with a *known* result must use (f()).
				// Unknown result (procedure, untyped C import) may stay bare.
				if e <> nil and e^.kind == NODE_CALL then
					ty := semantic_type_of_expr(ctx, e)
					if ty <> nil then
						semantic_error_at(e, 
							"semantic_resolve_stmt: bare call discards a known result; use (f()) to discard")
					end
				end
			end

		case NODE_ASSIGN:
			semantic_forbid_for_control_write(ctx, n^.binary.left)
			semantic_resolve_expr(ctx, n^.binary.left)
			semantic_forbid_param_mode_write(n^.binary.left)
			semantic_forbid_let_write(n^.binary.left)
			semantic_resolve_expr(ctx, n^.binary.right)
			begin
				var lhs_ty: pTType = nil
				lhs_ty := semantic_type_of_expr(ctx, n^.binary.left)
				semantic_maybe_upcast(ctx, n^.binary.right, lhs_ty)
			end

		case NODE_IF:
			semantic_resolve_expr(ctx, n^.if_stmt.cond)
			semantic_analyze_stmt_or_block(ctx, n^.if_stmt.then_)
			semantic_resolve_elsif_chain(ctx, n^.if_stmt.elsif_)
			semantic_analyze_stmt_or_block(ctx, n^.if_stmt.else_)

		case NODE_FOR:
			var saved_name: const ^char = nil
			var saved_len: size_t = 0

			semantic_resolve_expr(ctx, n^.for_stmt.start_)
			semantic_resolve_expr(ctx, n^.for_stmt.end_)
			for i := 1 to n^.for_stmt.invariant_count do
				semantic_resolve_expr(ctx, n^.for_stmt.invariants[i-1])
			end

			saved_name 			:= ctx^.for_var_name
			saved_len			:= ctx^.for_var_len
			ctx^.for_var_name	:= n^.for_stmt.var_name
			ctx^.for_var_len	:= n^.for_stmt.var_len
			semantic_analyze_stmt_or_block(ctx, n^.for_stmt.body)
			ctx^.for_var_name	:= saved_name
			ctx^.for_var_len 	:= saved_len

		case NODE_WHILE:
			semantic_resolve_expr(ctx, n^.while_stmt.cond)
			for i := 1 to n^.while_stmt.invariant_count do
				semantic_resolve_expr(ctx, n^.while_stmt.invariants[i-1])
			end
			semantic_analyze_stmt_or_block(ctx, n^.while_stmt.body)

		case NODE_REPEAT_UNTIL:
			semantic_analyze_stmt_or_block(ctx, n^.repeat_until.body)
			semantic_resolve_expr(ctx, n^.repeat_until.cond)
			for i := 1 to n^.repeat_until.invariant_count do
				semantic_resolve_expr(ctx, n^.repeat_until.invariants[i-1])
			end

		case NODE_LOOP:
			for i := 1 to n^.loop_stmt.invariant_count do
				semantic_resolve_expr(ctx, n^.loop_stmt.invariants[i-1])
			end
			semantic_analyze_stmt_or_block(ctx, n^.loop_stmt.body)

		case NODE_RETURN:
			if n^.ret.expr <> nil then
				semantic_resolve_expr(ctx, n^.ret.expr)
				begin
					var ret_ty: pTType = nil
					var enc: pNode = ctx^.enclosing_func
					if enc <> nil then
						if enc^.kind == NODE_FUNC_DECL or enc^.kind == NODE_PROC_DECL then
							ret_ty := enc^.proc_decl.return_type
						elsif enc^.kind == NODE_PROGRAM then
							ret_ty := enc^.program_decl.return_type
						end
					end
					semantic_maybe_upcast(ctx, n^.ret.expr, ret_ty)
				end
			end

		case NODE_ASSERT:
			semantic_resolve_expr(ctx, n^.assert_stmt.condition)
			if n^.assert_stmt.const_expr <> nil then
				semantic_resolve_expr(ctx, n^.assert_stmt.const_expr)
			end

		case NODE_INC, NODE_DEC:
			semantic_forbid_for_control_write(ctx, n^.binary.left)
			semantic_resolve_expr(ctx, n^.binary.left)
			semantic_forbid_param_mode_write(n^.binary.left)
			semantic_forbid_let_write(n^.binary.left)
			if n^.binary.right <> nil then
				semantic_resolve_expr(ctx, n^.binary.right)
			end

		case NODE_DEFER, NODE_DEBUG:
			semantic_analyze_stmt_or_block(ctx, n^.defer_stmt.action)

		case NODE_SWITCH:
			semantic_resolve_expr(ctx, n^.switch_stmt.expr)
			for i := 1 to n^.switch_stmt.case_count do
				sc := n^.switch_stmt.cases[i-1]
				if sc <> nil then
					for j := 1 to sc^.label_count do
						semantic_resolve_expr(ctx, sc^.labels[j-1])
					end
					semantic_analyze_stmt_or_block(ctx, sc^.body)
				end
			end
			semantic_analyze_stmt_or_block(ctx, n^.switch_stmt.else_body)

		case NODE_BREAK, NODE_CONTINUE, NODE_DOC_COMMENT, NODE_PREPROCESSOR, NODE_DEFINE:
			// nothing to resolve

		else:
			// declarations handled in semantic_analyze_block_body
	end
end semantic_resolve_stmt


(**
 * Walk block statements: register local VAR/CONST/LET; recurese into nested BEGIN blocks.
 *)
recursive procedure semantic_analyze_block_body(ctx: pTSemanticContext, block: pNode)
begin
	var i: size_t = 0
	var saved: pTSymbolTable = nil
	var inner: pTSymbolTable = nil

	if block == nil or block^.kind <> NODE_BLOCK then
		return
	end

	// REQUIRE is parsed right before BEGIN, before this block's definitions
	for i := 1 to block^.block.require_count do
		semantic_resolve_expr(ctx, block^.block.requires[i-1])
	end
	
	for i := 1 to block^.block.count do
		let stmt: pNode = block^.block.stmts[i-1]
		if stmt == nil then
			continue
		end

		switch stmt^.kind of
			case NODE_VAR_DECL:
				semantic_register_var_decl(ctx, stmt, SYM_KIND_VAR)

			case NODE_CONST_DECL:
				semantic_register_var_decl(ctx, stmt, SYM_KIND_CONST)

			case NODE_LET_DECL:
				semantic_register_var_decl(ctx, stmt, SYM_KIND_LET)

			case NODE_BLOCK:
				inner 		:= symtab_create(ctx^.arena, ctx^.scope)
				saved 		:= ctx^.scope
				ctx^.scope 	:= inner
				semantic_analyze_block_body(ctx, stmt)		// recursive
				ctx^.scope 	:= saved

			// case NODE_DOC_COMMENT, NODE_PREPROCESSOR, NODE_PROC_DECL, NODE_FUNC_DECL, NODE_TYPE_DECL, 		\
			// 	NODE_IMPORT:
			// 	// ignore

			// case NODE_PROGRAM, NODE_VAR_ITEM, NODE_CONST_ITEM, NODE_LET_ITEM, NODE_PARAM, NODE_PARAM_LIST, 	\
			// 	NODE_IMPORT_ITEM, NODE_STRUCT_DECL, NODE_FIELD_DECL, NODE_METHOD_TYPE, NODE_ARRAY_TYPE, 	\
			// 	NODE_ARRAY_LITERAL, NODE_ARRAY_INDEX, NODE_FIELD_ACCESS, NODE_IF, NODE_ELSIF,				\
			// 	NODE_ELSE, NODE_FOR, NODE_WHILE, NODE_REPEAT_UNTIL, NODE_LOOP, NODE_BREAK, NODE_CONTINUE, 	\
			// 	NODE_RETURN, NODE_EXPR_STMT, NODE_ASSIGN, NODE_ASSERT, NODE_SIZEOF, NODE_INC, NODE_DEC, 	\
			// 	NODE_DEFER, NODE_DEBUG, NODE_SWITCH, NODE_PAREN, NODE_BINARY, NODE_UNARY, NODE_CAST, 		\
			// 	NODE_LITERAL, NODE_IDENT, NODE_CALL, NODE_TERNARY:

			else:
				semantic_resolve_stmt(ctx, stmt)
				// statements / control flow: phase 2
		end
	end

	// ENSURE is parsed after the statement-sequence; locals of this block are in scope.
	for i := 1 to block^.block.ensure_count do
		semantic_resolve_expr(ctx, block^.block.ensures[i-1])
	end
end


(**
 * Analyze a statement body that may be a BLOCK or a single statement
 *)
export procedure semantic_analyze_stmt_or_block(ctx: pTSemanticContext, n: pNode)
begin
	var saved: pTSymbolTable = nil
	var inner: pTSymbolTable = nil

	if n == nil then
		return
	elsif n^.kind == NODE_BLOCK then
		inner 		:= symtab_create(ctx^.arena, ctx^.scope)
		saved 		:= ctx^.scope
		ctx^.scope 	:= inner
		semantic_analyze_block_body(ctx, n)
		ctx^.scope	:= saved
	else
		semantic_resolve_stmt(ctx, n)
	end
end semantic_analyze_stmt_or_block


(**
 * Walk ELSIF chain o an IF node.
 *)
export procedure semantic_resolve_elsif_chain(ctx: pTSemanticContext, elsif_node: pNode)
begin
	var last: pNode = nil
	var elsif_: pNode = elsif_node

	while elsif_ <> nil do
		semantic_resolve_expr(ctx, elsif_^.if_stmt.cond)
		semantic_analyze_stmt_or_block(ctx, elsif_^.if_stmt.then_)
		last := elsif_
		elsif_ := elsif_^.if_stmt.elsif_
	end

	// ELSE is parsed onto the last ElSIF (or root IF when no ELSIF)
	if last <> nil and last^.if_stmt.else_ <> nil then
		semantic_analyze_stmt_or_block(ctx, last^.if_stmt.else_)
	end
end semantic_resolve_elsif_chain


(**
 * Analyze a procedure or function body (params + locals in one scope).
 *)
procedure semantic_analyze_proc(ctx: pTSemanticContext, decl: pNode, global: pTSymbolTable)
begin
	var body_scope: pTSymbolTable = nil
	var saved: pTSymbolTable = nil
	var params: ^pNode = nil
	var param_count: size_t = 0

	if decl == nil then
		return
	elsif decl^.kind <> NODE_PROC_DECL and decl^.kind <> NODE_FUNC_DECL then
		semantic_error_at(decl, "semantic_analyze_proc: internal error: expected procedure or function")
	end

	if decl^.proc_decl.body == nil then
		return		// prototype / EXTERN / FORWARD - no body to analyze
	end

	body_scope := symtab_create(ctx^.arena, global)
	saved := ctx^.scope
	ctx^.scope := body_scope
	ctx^.enclosing_func := decl

	semantic_verify_method_self(ctx, decl)

	if decl^.proc_decl.params <> nil and decl^.proc_decl.params^.kind == NODE_PARAM_LIST then
		params			:= decl^.proc_decl.params^.param_list.params
		param_count 	:= decl^.proc_decl.params^.param_list.count
		semantic_register_param_list(ctx, params, param_count)
	end

	semantic_analyze_block_body(ctx, decl^.proc_decl.body)
	ctx^.enclosing_func := nil
	ctx^.scope := saved
end


(**
 * Synthetic PROC/FUNC decl for this MODULE's entry (same formals as program_decl).
 * Codegen auto-& only looks at NODE_PROC_DECL / NODE_FUNC_DECL.
 *)
function semantic_make_unit_entry_decl(ctx: pTSemanticContext, root: pNode): pNode
begin
	var decl: pNode = nil
	var pl: pNode = nil
	var nkind: NodeKind = NODE_PROC_DECL

	if ctx == nil or root == nil or root^.kind <> NODE_PROGRAM then
		return nil
	end
	if root^.program_decl.unit_kind <> TOK_KEYWORD_MODULE then
		return nil
	end
	if root^.program_decl.name == nil or root^.program_decl.name_len == 0 then
		return nil
	end

	if root^.program_decl.return_type <> nil then
		nkind := NODE_FUNC_DECL
	end

	decl := node_create(ctx^.arena, nkind, root^.token)
	decl^.proc_decl.name := root^.program_decl.name
	decl^.proc_decl.name_len := root^.program_decl.name_len
	decl^.proc_decl.method_owner := nil
	decl^.proc_decl.method_owner_len := 0
	decl^.proc_decl.body := nil
	decl^.proc_decl.is_exported := true
	decl^.proc_decl.is_recursive := false
	decl^.proc_decl.is_extern := false
	decl^.proc_decl.is_forward := false
	decl^.proc_decl.is_function := (nkind == NODE_FUNC_DECL)
	decl^.proc_decl.receiver := nil
	decl^.proc_decl.return_type := root^.program_decl.return_type

	pl := node_create(ctx^.arena, NODE_PARAM_LIST, root^.token)
	pl^.param_list.params := root^.program_decl.params
	pl^.param_list.count := root^.program_decl.param_count
	pl^.param_list.capacity := root^.program_decl.param_capacity
	decl^.proc_decl.params := pl

	return decl
end semantic_make_unit_entry_decl


(**
 * Analyze PROGRAM / MODULE unit
 *)
procedure semantic_analyze_program(ctx: pTSemanticContext, root: pNode)
begin
	var i: size_t = 0
	var global: pTSymbolTable = nil
	var body_scope: pTSymbolTable = nil
	var saved: pTSymbolTable = nil
	var unit_entry: pNode = nil
	var unit_kind: SymbolKind = SYM_KIND_PROC

	if root == nil or root^.kind <> NODE_PROGRAM then
		semantic_error_at(root, "semantic_analye_program: expected PROGRAM or MODULE root node")
	end

	global := symtab_create(ctx^.arena, nil)
	ctx^.scope := global

	semantic_register_prelude(ctx)

	// Pass 0: register IMPORT ... FROM symbols before other declarations
	for i := 1 to root^.program_decl.count do
		let decl: pNode = root^.program_decl.decls[i-1]
		if decl <> nil and decl^.kind == NODE_IMPORT then
			semantic_register_import(ctx, decl)
		end
	end

	// Pass 1: register all top-level declarations (except imports)
	for i := 1 to root^.program_decl.count do
		let decl: pNode = root^.program_decl.decls[i-1]
		if decl <> nil and decl^.kind <> NODE_IMPORT then
			semantic_register_decl(ctx, decl)
		end
	end

	// 7a: MODULE name is a real PROC/FUNC in this unit (same-unit auto-&)
	if root^.program_decl.unit_kind == TOK_KEYWORD_MODULE then
		unit_entry := semantic_make_unit_entry_decl(ctx, root)
		if unit_entry <> nil then
			if root^.program_decl.return_type <> nil then
				unit_kind := SYM_KIND_FUNC
			end
			semantic_define(ctx, unit_kind,
				root^.program_decl.name, root^.program_decl.name_len,
				root^.program_decl.return_type, unit_entry, true)
		end
	end

	// Pass 1 1/2: resolve TYPE alias bodies (all TYPE names now in symtab)
	semantic_resolve_type_decls(ctx, root)

	// Pass 2: procedure / function bodies
	for i := 1 to root^.program_decl.count do
		let decl: pNode = root^.program_decl.decls[i-1]
		if decl <> nil then
			if decl^.kind == NODE_PROC_DECL or decl^.kind == NODE_FUNC_DECL then
				semantic_analyze_proc(ctx, decl, global)
			end
		end
	end

	// Pass 3: program/module body (parameters + locals)
	if root^.program_decl.block <> nil then
		body_scope := symtab_create(ctx^.arena, global)
		saved := ctx^.scope
		ctx^.scope := body_scope
		ctx^.enclosing_func := root

		if root^.program_decl.param_count > 0 then
			if root^.program_decl.return_type <> nil then
				semantic_resolve_type(ctx, root^.program_decl.return_type, root)
			end
			semantic_register_param_list(ctx, root^.program_decl.params, root^.program_decl.param_count)
		end

		semantic_analyze_block_body(ctx, root^.program_decl.block)
		ctx^.enclosing_func := nil
		ctx^.scope := saved
	end
end


(**
 * Register one top-level (or scope-level) declaration.
 *)
export procedure semantic_register_decl(ctx: pTSemanticContext, decl: pNode)
begin
	if decl == nil then
		return
	end

	switch decl^.kind of
		case NODE_TYPE_DECL:
			if decl^.type_decl.name == nil or decl^.type_decl.name_len == 0 then
				semantic_error_at(decl, "semantic_register_decl: TYPE declaration has no name")
			end
			if decl^.type_decl.is_extern then
				if decl^.type_decl.defined_type <> nil then
					semantic_resolve_type(ctx, decl^.type_decl.defined_type, decl)
				end
				semantic_define_or_refine(ctx, SYM_KIND_TYPE, decl^.type_decl.name,			\
					decl^.type_decl.name_len, decl^.type_decl.defined_type, decl,			\
					decl^.type_decl.is_exported)
			elsif decl^.type_decl.is_forward then
				// Incomplete: name only until a later type Name = ... completes it.
				semantic_define_or_complete_forward(ctx, SYM_KIND_TYPE,
					decl^.type_decl.name, decl^.type_decl.name_len,
					nil, decl, decl^.type_decl.is_exported)
			else
				// Complete TYPE -- may refine a prior type Name FORWARD in this unit.
				semantic_define_or_complete_forward(ctx, SYM_KIND_TYPE,
					decl^.type_decl.name, decl^.type_decl.name_len,
					decl^.type_decl.defined_type, decl, decl^.type_decl.is_exported)
			end

		case NODE_VAR_DECL:
			semantic_register_var_decl(ctx, decl, SYM_KIND_VAR)

		case NODE_CONST_DECL:
			semantic_register_var_decl(ctx, decl, SYM_KIND_CONST)

		case NODE_LET_DECL:
			semantic_register_var_decl(ctx, decl, SYM_KIND_LET)

		case NODE_DEFINE:
			if decl^.define_stmt.name == nil or decl^.define_stmt.name_len == 0 then
				semantic_error_at(decl, "semantic_register_decl: DEFINE has no name")
			end
			semantic_define(ctx, SYM_KIND_IMPORT, decl^.define_stmt.name,
				decl^.define_stmt.name_len, nil, decl, decl^.define_stmt.is_exported)

		case NODE_PROC_DECL:
			begin
				var sym: TProcSymName

				if decl^.proc_decl.name == nil or decl^.proc_decl.name_len == 0 then
					semantic_error_at(decl, "semantic_register_decl: PROCEDURE has no name")
				end
				if decl^.proc_decl.return_type <> nil then
					semantic_resolve_type(ctx, decl^.proc_decl.return_type, decl)
				end
				sym := semantic_proc_sym_name(ctx, decl)
				if decl^.proc_decl.is_extern then
					semantic_define_or_refine(ctx, SYM_KIND_PROC, sym.name, sym.length,			\
						decl^.proc_decl.return_type, decl, decl^.proc_decl.is_exported)
				elsif decl^.proc_decl.is_forward or decl^.proc_decl.body == nil then
					semantic_define_or_complete_forward(ctx, SYM_KIND_PROC, sym.name, sym.length, 	\
						decl^.proc_decl.return_type, decl, decl^.proc_decl.is_exported)
				else
					semantic_define_or_complete_forward(ctx, SYM_KIND_PROC, sym.name, sym.length,	\
						decl^.proc_decl.return_type, decl, decl^.proc_decl.is_exported)
				end
			end

		case NODE_FUNC_DECL:
			begin
				var sym: TProcSymName

				if decl^.proc_decl.name == nil or decl^.proc_decl.name_len == 0 then
					semantic_error_at(decl, "semantic_register_decl: FUNCTION has no name")
				end
				if decl^.proc_decl.return_type <> nil then
					semantic_resolve_type(ctx, decl^.proc_decl.return_type, decl)
				end
				sym := semantic_proc_sym_name(ctx, decl)

				if decl^.proc_decl.is_extern then
					semantic_define_or_refine(ctx, SYM_KIND_FUNC, sym.name, sym.length,				\
						decl^.proc_decl.return_type, decl, decl^.proc_decl.is_exported)
				elsif decl^.proc_decl.is_forward or decl^.proc_decl.body == nil then
					semantic_define_or_complete_forward(ctx, SYM_KIND_FUNC, sym.name, sym.length,	\
						decl^.proc_decl.return_type, decl, decl^.proc_decl.is_exported)
				else
					semantic_define_or_complete_forward(ctx, SYM_KIND_FUNC, sym.name, sym.length,	\
						decl^.proc_decl.return_type, decl, decl^.proc_decl.is_exported)
				end
			end

		case NODE_DOC_COMMENT, NODE_PREPROCESSOR, NODE_IMPORT:
			// skip

		case NODE_PROGRAM, NODE_VAR_ITEM, NODE_CONST_ITEM, NODE_LET_ITEM, NODE_PARAM, NODE_PARAM_LIST,
			NODE_IMPORT_ITEM, NODE_STRUCT_DECL, NODE_FIELD_DECL, NODE_METHOD_TYPE, NODE_ARRAY_TYPE,
			NODE_ARRAY_LITERAL, NODE_ARRAY_INDEX, NODE_FIELD_ACCESS, NODE_BLOCK, NODE_IF, NODE_ELSIF,
			NODE_ELSE, NODE_FOR, NODE_WHILE, NODE_REPEAT_UNTIL, NODE_LOOP, NODE_BREAK, NODE_CONTINUE,
			NODE_RETURN, NODE_EXPR_STMT, NODE_ASSIGN, NODE_ASSERT, NODE_SIZEOF, NODE_LEN, NODE_INC, 
			NODE_DEC, NODE_DEFER, NODE_DEBUG, NODE_SWITCH, NODE_PAREN, NODE_BINARY, NODE_UNARY, NODE_CAST,
			NODE_LITERAL, NODE_IDENT, NODE_CALL, NODE_TERNARY:

		else:
			// ignore other top-level nodes for now
	end
end


(**
 * Entry point: analyze AST after parsing, before codegen.
 * Exits on error; returns normally on success.
 *)
export procedure semantic_analyze(arena: ^Arena, root: pNode, source_path: const ^char)
begin
	var ctx: TSemanticContext

	// debug fprintf(stderr, "DEBUG: HELLO FROM semantic_analyze\n")

	if arena == nil then
		semantic_error_at(nil, "semantic_analyze: NULL arena")
	elsif root == nil then
		semantic_error_at(nil, "semantic_analyze: NULL AST root")
	end

	ctx.arena 			:= arena
	ctx.source_path 	:= source_path
	ctx.scope 			:= nil
	ctx.enclosing_func 	:= nil

	semantic_analyze_program(@ctx, root)
end


begin
end semantic
