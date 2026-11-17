module tmodc.node()

(**
 * Mod-c
 * By M. Scott Reynolds
 * Date 28 March 2026
 *
 * AST node creation helper.
 *
 * 3 November 2026
 * Conversion to TMod-c from C started
 * 9 November 2026
 * Conversion to TMod-c finished.
 *)


// import Node, NodeKind, NODE_PROGRAM, NODE_DOC_COMMENT, NODE_PREPROCESSOR, NODE_DEFINE,
// 	NODE_VAR_DECL, NODE_CONST_DECL, NODE_LET_DECL, NODE_VAR_ITEM, NODE_CONST_ITEM,
// 	NODE_LET_ITEM, NODE_TYPE_DECL, NODE_ENUM_TYPE, NODE_ENUM_ITEM, NODE_STRUCT_DECL,
// 	NODE_ARRAY_TYPE, NODE_ARRAY_LITERAL, NODE_ARRAY_INDEX, NODE_FIELD_DECL, 
// 	NODE_FIELD_ACCESS, NODE_PROC_DECL, NODE_FUNC_DECL, NODE_BLOCK, NODE_IF, NODE_ELSIF,
// 	NODE_ELSE, NODE_WHILE, NODE_FOR, NODE_REPEAT_UNTIL, NODE_LOOP, NODE_RETURN,
// 	NODE_CONTINUE, NODE_BREAK, NODE_ASSIGN, NODE_BINARY, NODE_CALL, NODE_LITERAL,
// 	NODE_IDENT, NODE_ASSERT, NODE_SIZEOF, NODE_COUNTOF, NODE_IMPORT, NODE_IMPORT_ITEM,
// 	NODE_PARAM, NODE_EXPR_STMT, NODE_CAST, NODE_UNARY, NODE_TERNARY, NODE_PARAM_LIST,
// 	NODE_INC, NODE_DEC, NODE_DEFER, NODE_DEBUG, NODE_SWITCH, NODE_PAREN,
// 	NODE_METHOD_TYPE, SwitchCase,
// 	from "node.h"
import size_t,
	from "stddef.h"
import printf, 
	from "stdio.h"

import Arena, arena_alloc, 
    from tmodc.arena
import TToken, TokenKind, TokenKind::string, 
	from tmodc.lexer.Lexer
import type_print, TType,
	from tmodc.ttype


(**
 * Kinds of AST nodes.
 * Grouped roughly by syntactic category.
 * Updated 28 March 2026 for grammar version 0.6.2.
 *)
export type NodeKind = enum
	NODE_PROGRAM,

	// Declarations
	NODE_DOC_COMMENT,
	NODE_PREPROCESSOR, 		// #include, #define, #if, etc...
	NODE_DEFINE,			// [EXPORT] DEFINE identifer RestOfLine
	NODE_PROC_DECL,
	NODE_FUNC_DECL,
	NODE_VAR_DECL,
	NODE_CONST_DECL,
	NODE_LET_DECL,
	NODE_VAR_ITEM,			// VAR
	NODE_CONST_ITEM,
	NODE_LET_ITEM,
	NODE_TYPE_DECL,
	NODE_PARAM,				// single parameter (used in param lists)
	NODE_PARAM_LIST,		// (param { , param } )
	NODE_IMPORT,			// IMPORT ... FROM ...
	NODE_IMPORT_ITEM,		// one qualident [AS ident] in the list
	NODE_STRUCT_DECL,		// STRUCT identifier [EXTENDS type] { ... }
	NODE_FIELD_DECL,
	NODE_METHOD_TYPE,		// PROCEDURE / FUNCTION ty pe (for use in TYPE declarations, params, etc.)
	NODE_ARRAY_TYPE,		// array type: array[Size] of ElementType or array_of_T[N]
	NODE_ARRAY_LITERAL,		// { expr, expr, ... }
	NODE_ARRAY_INDEX,		// designator [ index-expr ]
	NODE_FIELD_ACCESS,		// designator . identifier
	NODE_ENUM_TYPE,
	NODE_ENUM_ITEM,			// One member in NODE_ENUM_TYPE.elements[]

	// Statements
	NODE_BLOCK,
	NODE_IF,
	NODE_ELSIF,
	NODE_ELSE,
	NODE_FOR,
	NODE_WHILE,				// WHILE expression DO ... END
	NODE_REPEAT_UNTIL, 
	NODE_LOOP,
	NODE_BREAK,
	NODE_CONTINUE,
	NODE_RETURN,
	NODE_EXPR_STMT,
	NODE_ASSIGN,			// :=
	NODE_ASSERT,			// ASSERT (expression [, const-expression])
	NODE_SIZEOF,			// SIZEOF (type-identifier | designator )
	NODE_COUNTOF,			// COUNTOF (type | designator) - element count
	NODE_INC,				// INC(designator [, step])
	NODE_DEC,				// DEC(designator [, step])
	NODE_DEFER,
	NODE_DEBUG,
	NODE_SWITCH,

	// Expressions
	NODE_PAREN,
	NODE_BINARY,
	NODE_UNARY,
	NODE_CAST, 				// postfix "AS" cast
	NODE_LITERAL,
	NODE_IDENT,
	NODE_CALL,
	NODE_TERNARY,			// cond ? then : else

	// Future expansion placeholders (add here as needed)
end


(**
 * Forward declaration of AST node.
 * All nodes are allocated in an Arena and owned by it.
 *)
export type pNode = pointer to TNode
export type array_of_node = ^pNode 		// alternate for ^pNode

(** Switch statement case *)
export type TSwitchCase = struct
	labels: 			^pNode 		// array of const-expression nodes
	label_count: 		size_t
	label_capacity: 	size_t
	body: 				^TNode		// statement-seqeunce for this arm
end
export type pSwitchCase = ^TSwitchCase
export type array_of_SwitchCase = ^pSwitchCase


(** Program decl *)
export type TProgramDecl = struct
	unit_kind: 			TokenKind	// TOK_KEYWORD_PROGRAM, TOK_KEYWORD_MODULE, or TOK_KEYWORD_HEADER
	name: 				const ^char	// id of the program/module
	name_len: 			size_t		// length of the id, no null assumption.

	// Qualident prefix only ("tmodc.lib"). No trailing dot.
	// NULL and 0 when the unit name is a single identifier.
	package_path: 		const ^char
	package_path_len: 	size_t

	// Optional parameters.
	params: 			^pNode		// array of param nodes (or simple ident+type)
	param_count: 		size_t
	param_capacity: 	size_t

	return_type: 		^TType		// optional return type.

	decls: 				^pNode 		// array of declaration nodes
	count: 				size_t
	capacity: 			size_t		// for dynamic growth

	block: 				^TNode		// BEGIN ... BODY (optional for module)
end

(** Top-level documentation comment (passthrough + future -D support *)
export type TDocComment = struct
	text: 		const ^char		// null-terminated, original delimiters stripped or kept?
	text_len: 	size_t
	// We keep the original token for line/column in AST and future doc generator.
end

(** Preprocessor directives. *)
export type TPreprocessor = struct
	text: 		const ^char
	length: 	size_t
end

(**
 * [EXPORT] DEFINE name ["(" params ")"] "=" replacement.
 * text is the #define tail: name, optional params, replacement. '=' omitted.
 *)
export type TDefineStmt = struct
	name: 			const ^char		// identifier only
	name_len: 		size_t
	text: 			const ^char		// name, optional params, and C replacement
	length: 		size_t
	is_exported: 	bool
end

(* Import statement (top-level) *)
export type TImportStmt = struct
	items: 			^pNode 			// Array of NODE_IMPORT ITEM
	count: 			size_t
	capacity: 		size_t
	from_path: 		const ^char 	// string-literal or qualident after FROM (pointer to source)
	path_len: 		size_t
end

(** Single import item: name | Type::name [ AS ident ] *)
export type TImportItem = struct
	qualident: 			const ^char 		// method short name, or plain/dotted import name
	qualident_len: 		size_t
	method_owner: 		const ^char 		// Type in Type::name; NULL if plain
	method_owner_len: 	size_t
	import_alias: 		const ^char 		// optional AS identifier
	import_alias_len: 	size_t
end

(** Struct declaration *)
export type TStructDecl = struct
	name: const ^char
	name_len: 			size_t
	extends_type: 		^TType 		// optional EXTENDS qualident
	fields: 			^pNode 		// array of field nodes (field-decl)
	field_count: 		size_t 
	field_capacity: 	size_t
	is_exported: 		bool
	is_packed: 			bool
	is_union: 			bool 		// True = C union, false = C struct
end

(** Struct field *)
export type TFieldDecl = struct
	name: const ^char
	name_len: 		size_t
	field_type: 	^TType 		// may be nil if ommited
	initializer: 	^TNode 		// optional = const-expression
	nested: 		^TNode 		// anonymouse UNION body; name is nil
end

(** Method / Procedure type (e.g. TYPE Compare = PROCEDURE(a: T): integer) *)
export type TMethodType = struct
	params: 		^TNode 		// NODE_PARAM_LIST or nil
	return_type: 	^TType 		// nil for PROCEDURE, present for FUNCTION
	is_function: 	bool 		// true = FUNCTION, false = PROCEDURE
end

(** Procedure / function declaration *)
export type TProcDecl = struct
	name: 				const ^char
	name_len: 			size_t
	method_owner: 		const ^char 	// type-identifier for Type::name (nil if free proc)
	method_owner_len: 	size_t
	params: 			^TNode 			// NODE_PARAM_LIST or nil
	return_type: 		^TType 			// optional
	body: 				^TNode 			// Block node
	is_exported: 		bool
	is_recursive: 		bool
	is_extern: 			bool
	is_forward: 		bool 			// postfix FORWARD - body later in unit
	is_function: 		bool 			// True for FUNCTION, false for PROCEDURE
	receiver: 			^TNode 			// Legacy Oberon receiver (unused: remove later)
end
export type TFuncDecl = TProcDecl

(** Var declaration *)
export type TVarDecl = struct
	items: 			^pNode 					// Array of variable items (arena allocated)
	count: 			size_t 					// size of the arrays/VAR entries
	capacity: 		size_t
	is_exported: 	bool
	is_extern: 		bool
	is_static: 		bool
end
export type TConstDecl = TVarDecl
export type TLetDecl = TVarDecl

(** Variable item (VAR/CONST/LET) *)
export type TVarItem = struct
	name: 			const ^char
	name_len: 		size_t
	item_type: 		^TType
	initializer: 	^TNode
end
export type TConstItem = TVarItem
export type TLetItem = TVarItem

(** TType declaration *)
export type TTypeDecl = struct
	name: 				const ^char
	name_len: 			size_t
	defined_type: 		^TType
	struct_body: 		^TNode 		// When non-nil points to struct TYPE indent == STRUCT ...
	method_type: 		^TNode 		// When non-nil points to NODE_METHOD_TYPE
	enum_type: 			^TNode 		// When non-nil points to a NODE_ENUM_TYPE
	initializer: 		^TNode
	is_exported: 		bool
	is_extern: 			bool 		// EXTERN TYPE (opaque foreign / alias )
	is_forward: 		bool 		// type Name FORWARD - completed later in unit
	is_extern_struct: 	bool 		// extern type Name = struct [tag]
	c_tag_name: 		const ^char // nil => tag is Name
	c_tag_name_len: 	size_t
end

(** Enum Type *)
export type TEnumType = struct
	name: 		const ^char
	name_len: 	size_t
	elements: 	^pNode
	count: 		size_t
	capacity: 	size_t
end

(** Enum Item *)
export type TEnumItem = struct
	name: 			const ^char
	name_len: 		size_t
	value: 			^TNode
	value_known:	bool 		// Optional const-expression; nil = auto-increment
	int_value: 		int 		// Set by semantic
end

(** Array type *)
export type TArrayType = struct
	element_type: 	^TNode 		// type node or identifier
	size_expr: 		^TNode 		// size (const expression or nil for open array)
	is_open: 		bool 		// true for dynamic/open arryas later
end

(** Array literal { expr, expr, ... } *)
export type TArrayLiteral = struct
	elements: 		^pNode 		// array of expression nodes
	count: 			size_t
	capacity: 		size_t
end

(** Parameter declaration *)
export type TParam = struct
	name: 		const ^char
	name_len: 	size_t
	is_var: 	bool
	is_ref: 	bool
	is_const: 	bool
	param_type:	^TType
end

(** Parameter list *)
export type TParamList = struct
	params: 		^pNode 		// array of nodes
	count: 			size_t
	capacity: 		size_t
	has_ellipsis: 	bool 		// last formal was ... (C varargs)
end

(** Block (BEGIN ... END) *)
export type TBlock = struct
	stmts: 				^pNode 		// array of statement nodes.
	count: 				size_t
	capacity: 			size_t

	defers: 			^pNode 		// DEFER support - collected during parsing.
	defer_count: 		size_t 		// Emitted LIFO at block exit.
	defer_capacity: 	size_t

	// DbC contract clauses (expressions). Stored directly as the inner expr nodes.
	requires: 			^pNode 		// REQUIRE (expr) clauses at start of block
	require_count: 		size_t
	require_capacity: 	size_t

	ensures: 			^pNode 		// ENSURE (expr) clauses at end of block (before RETURN/END)
	ensure_count: 		size_t
	ensure_capacity: 	size_t
end

(** If / Elsif / Else chain *)
export type TIfStmt = struct
	cond: 		^TNode
	then_: 		^TNode
	elsif_: 	^TNode 		// Next ELSIF (or nil)
	else_:		^TNode 		// ELSE branch (or nil)
end

(** While loop *)
export type TWhileStmt = struct
	cond: 		^TNode 		// Condition expression
	body: 		^TNode 		// Statement sequence (usually a BLOCK)

	invariants: 		^pNode 		// INVARIANT (expr) clauses (after DO, before body)
	invariant_count: 	size_t
	invariant_capacity:	size_t

	bound_expr: 	^TNode 		// nil when BOUND is omitted
	has_bound: 		bool
	bound_value: 	int 		// folded; 0 on LOOP is idel
end

export type TForStmt = struct
	var_name: 		const ^char 	// loop variable name
	var_len: 		size_t
	start_: 		^TNode
	end_:			^TNode
	step: 			int 			// Default 1 (positive or negative)
	body: 			^TNode

	invariants: 		^pNode 		// INVARIANT (expr) clauses
	invariant_count: 	size_t
	invariant_capacity: size_t

	declares: 		bool 			// FOR i = / FOR i: T = instroduces i
	index_type: 	^TType 			// nil until semantic fills it; integer if untyped.
end

export type TRepeatUntil = struct
	body: 			^TNode
	cond: 			^TNode 			// evaluated after body

	invariants: 			^pNode 	// INVARIANT (expr) clauses
	invariant_count: 		size_t
	invariant_capacity: 	size_t

	bound_expr: 	^TNode 			// nil when BOUND is omitted
	has_bound: 		bool
	bound_value: 	int 			// folded; 0 on LOOP is idele
end

(** Infinite LOOP *)
export type TLoopStmt = struct
	body: 			^TNode

	invariants: 			^pNode 		// INVARIANT (expr) clauses
	invariant_count: 		size_t
	invariant_capacity: 	size_t

	bound_expr: 	^TNode 		// nil whne BOUND is omitted
	has_bound: 		bool
	bound_value: 	int 		// folded; 0 on LOOP is idle
end

(** Switch statement *)
export type TSwitchStmt = struct
	expr: 			^TNode 				// the controlling expression
	cases: 			^pSwitchCase		// array of switch cases
	case_count: 	size_t
	case_capacity: 	size_t

	else_labels: 			^pNode 	// array - consts before defaul; empty for else: and else default:
	else_label_count: 		size_t
	else_label_capacity: 	size_t
	else_body: 				^TNode 	// The required ELSE statement-sequence
end

(** Return statement *)
export type TReturnStmt = struct
	expr: 	^TNode 		// optional return value
end

(** Binary / Unary *)
export type TBinary = struct
	left: 	^TNode
	right: 	^TNode
	op: 	TokenKind
end

(** Ternary conditional (a ? b : c) *)
export type TTernary = struct
	cond: 		^TNode
	then_expr: 	^TNode
	else_expr: 	^TNode
end

(** Unary operator expression *)
export type TUnary = struct
	operand: 	^TNode
	op: 		TokenKind
end

(** Unary operator expression paren *)
export type TParen = struct
	expr: 	^TNode
end

(** Cast expression (postfix "AS") *)
export type TCastExpr = struct
	expr: 			^TNode 	// expresison being cast
	target_type: 	^TType 	// Target type after "AS"
end

(** Literal (number, string, char) or Identifier *)
export type TLiteral = struct
	value: 		const ^char 	// Text as in source (not nil-terminated if len used)
	length: 	size_t 			// byte length from original token (preferred over strlen)
end
export type TIdent = TLiteral

(** Function / procedure call *)
export type TCall = struct
	name: 				const ^char
	name_len: 			size_t
	method_owner: 		const ^char 	// for Type::name calls (nil or obj:name sugar)
	method_owner_len: 	size_t
	receiver_expr: 		^TNode 			// instance sugar; prepend as first arg in codegen
	callee_expr: 		^TNode 			// call-through value (field / later designator); no prepend
	args: 				^pNode 			// array of argument expression nodes
	argc: 				size_t
	arg_capacity: 		size_t 			// for dynamic growth
	auto_deref: 		bool 			// Oberon p.method: receiver is ^T: emit (*(p))
	base_depth:			size_t 			// EXTENDS: ".base" hops after peel (0 = owner type)
	slice_arg: 			^int 			// parallel to args; nil if no slice formal.
										// 0 - none, -2 = pass actual's _length > 0 = folded count
	receiver_slice: 	int 			// same encoding for the instance receiver
end

(** Array indexing *)
export type TArrayIndex = struct
	array_: 		^TNode 		// left side (ident, fields, etc.)
	index: 			^TNode 		// Index expression
	auto_deref: 	bool 		// Oberon p[i]: left is ^array; emit (*(p))[i]
end

(** Field access *)
export type TFieldAccess = struct
	record_: 		^TNode 		// left side (struct or object)
	field_name: 	const ^char
	field_len: 		size_t
	base_depth: 	size_t 		// EXTENDS: number of ".base" before field (0 = own/synthetic)
	auto_deref: 	bool 		// Oberron p.x: left is ^T; emit (*(p)).field
end

(** Expression statement *)
export type TExprStmt = struct
	expr: 		^TNode 			// Expression
end

(** Assert statement *)
export type TAssertStmt = struct
	condition: 		^TNode 		// required expression for ASSERT
	const_expr: 	^TNode 		// optinal second argument (const-expression)
end

(** Defer statement/Debug same action. *)
export type TDeferStmt = struct
	action: 	^TNode 			// The defered statement/expression
end
export type TDebugStmt = TDeferStmt


(** Sizeof target *)
export type TSizeofTarget = union
	sizeof_type: 	^TType 		// When is_type == true
	designator: 	^TNode 		// When is_type == false
end

(** Sizeof expression *)
export type TSizeofExpr = struct
	is_type: 		bool 		// true if operand is a type, false if designator
	folded: 		bool 		// COUNTOF: count is the element count
	count: 			int 		// COUNTOF element count when folded
	target: 		TSizeofTarget
end

(**
 * Basic Node structure. Contains UNION of all node types.
 *)
export type TNode = struct
	kind: NodeKind
	token: TToken 			// Originating token (location + text snippet)
	resolved_sym: ^TSymbol 	// Semantic pass: bound symbol for IDENT/CALL (NULL if foreign/unresolved)
	upcast_depth: size_t
	upcast_ptr: bool 		// True => &((*(expr)).base x N); value => ((expr).base x N)

	union
		program_decl: 		TProgramDecl
		doc_comment: 		TDocComment
		preprocessor: 		TPreprocessor
		define_stmt: 		TDefineStmt
		import_stmt: 		TImportStmt
		import_item: 		TImportItem
		struct_decl: 		TStructDecl
		field_decl: 		TFieldDecl
		method_type: 		TMethodType
		proc_decl: 			TProcDecl
		func_decl: 			TFuncDecl
		var_decl: 			TVarDecl
		const_decl: 		TConstDecl
		let_decl: 			TLetDecl
		var_item: 			TVarItem
		const_item: 		TConstItem
		let_item: 			TLetItem
		type_decl: 			TTypeDecl
		enum_type: 			TEnumType
		enum_item: 			TEnumItem
		array_type: 		TArrayType
		array_literal: 		TArrayLiteral
		param: 				TParam
		param_list: 		TParamList
		block: 				TBlock
		if_stmt: 			TIfStmt
		while_stmt: 		TWhileStmt
		for_stmt: 			TForStmt
		repeat_until: 		TRepeatUntil
		loop_stmt: 			TLoopStmt
		switch_stmt: 		TSwitchStmt
		ret: 				TReturnStmt
		binary: 			TBinary
		ternary: 			TTernary
		unary:				TUnary
		paren: 				TParen
		cast_expr: 			TCastExpr
		literal: 			TLiteral
		ident: 				TIdent
		call: 				TCall
		array_index: 		TArrayIndex
		field_access: 		TFieldAccess
		expr_stmt:			TExprStmt
		assert_stmt:		TAssertStmt
		defer_stmt: 		TDeferStmt
		debug_stmt:			TDebugStmt
		sizeof_expr:		TSizeofExpr
	end
end


(** Symbol Kind definition *)
export type SymbolKind = enum
	SYM_KIND_UNKNOWN = 0,
	SYM_KIND_TYPE,
	SYM_KIND_CONST,
	SYM_KIND_LET,
	SYM_KIND_VAR,
	SYM_KIND_PARAM,
	SYM_KIND_RECEIVER,
	SYM_KIND_PROC,
	SYM_KIND_FUNC,
	SYM_KIND_STRUCT,
	SYM_KIND_FIELD,
	SYM_KIND_IMPORT,
end


(** TSymbol structure *)
export type TSymbol = struct
	kind: 				SymbolKind
	name: 				const ^char
	name_len:			size_t
	symbol_type:		^TType			// nil until resolved
	decl:				pNode			// defining AST node
	is_exported: 		bool
	has_const_value:	bool 			// true for enum members / folded CONST (Phase B)
	const_value:		integer			// valid when has_const_value
	// .mh type-bound method import (A2/A3): true => obj.method instance sugar (A4)
	is_method_instance: bool
	c_name: 			const ^char 	// IMPORT AS: C spelling. nil => name
	c_name_len:			size_t
end

export type pTSymbol		= ^TSymbol
export type ppTSymbol		= ^pTSymbol


(**
 * Function symbol_create()
 * @param arena
 * @param kind
 * @param name
 * @param name_len
 * @param decl
 * @return ^TSymbol
 *)
export function symbol_create(arena: ^Arena, kind: SymbolKind, name: const ^char, name_len: size_t, decl: pNode): ^TSymbol
begin
	var s: ^TSymbol = arena_alloc(arena, sizeof(TSymbol))
	s^.kind 				:= kind
	s^.name 				:= name
	s^.name_len 			:= name_len
	s^.symbol_type 			:= nil
	s^.decl 				:= decl
	s^.is_exported 			:= false
	s^.has_const_value		:= false
	s^.const_value 			:= 0
	s^.is_method_instance 	:= false
	s^.c_name 				:= nil
	s^.c_name_len 			:= 0

	return s
end


(**
 * Function symbol_kind_name()
 * @param kind
 * @return const ^char
 *)
export function symbol_kind_name(kind: SymbolKind): const ^char
begin
	switch kind of
		case SYM_KIND_CONST:	return "CONST"
		case SYM_KIND_FIELD:	return "FIELD"
		case SYM_KIND_FUNC:		return "FUNC"
		case SYM_KIND_IMPORT:	return "IMPORT"
		case SYM_KIND_LET:		return "LET"
		case SYM_KIND_PARAM:	return "PARAM"
		case SYM_KIND_PROC:		return "PROC"
		case SYM_KIND_RECEIVER:	return "RECEIVER"
		case SYM_KIND_STRUCT:	return "STRUCT"
		case SYM_KIND_TYPE:		return "TYPE"
		case SYM_KIND_UNKNOWN:	return "UNKNOWN"
		case SYM_KIND_VAR: 		return "VAR"
		else: return "UNKNOWN"
	end
end


(**
 * Emit indentation dots safely.
 * Avoides -Wstrict-overflow on signed loop counters.
 *)
procedure node_indent_dots(indent: int)
begin
	var i: int = 0
	while i < indent do
		printf(". ")
		inc(i)
	end
end node_indent_dots


(**
 * Emit indentation spaces.
 * Avoids -Wstrict-overflow on signed loop counters.
 *)
// procedure node_indent(indent: size_t)
// begin
// 	var i: size_t = 0
// 	while i < indent do
// 		printf("  ")
// 		inc(i)
// 	end
// end node_indent


(**
 * Create a new AST node in the given arena.
 * Zero-initializes all fields, sets kind and token, then returns pointer.
 * Never returns nil - arena_alloc exits on allocation failure.
 *
 * @param arena 	Arena to allocate from (must be initialized)
 * @param kind 		NodeKind to assign
 * @param tok 		TToken to associate (copied by value)
 * @return 			Newly allocated and initialized ^TNode
 *)
export function node_create(arena: ^Arena, kind: NodeKind, tok: TToken): ^TNode
begin
	require arena <> nil

	var n: ^TNode = arena_alloc(arena, sizeof(TNode))

	// Zero all fields (union safety, prevents garbage in pointers/counters/etc.
	// memset(n, 0, sizeof(Node)) - arena_alloc already zero's fields

	n.kind := kind
	n.token := tok 		// struct copy - safe and efficient

	return n
end node_create


procedure print_kind_line_column(n: const ^TNode, kind_name: const ^char)
begin
	// printf("%s %d:%d ", kind_name, n.token.line, n.token.column)
	if n <> nil then
		printf("%s ", kind_name)
	end
end print_kind_line_column


procedure print_line_column(n: const ^TNode)
begin
	printf("%04d:%04d ", n.token.line, n.token.column)
end print_line_column


(**
 * Print the AST node tree recursively with indentation.
 * Shows node kind, source location, token snippet, and recurses into children.
 *)
export recursive procedure node_print(n: const ^TNode, indent: int)
begin
	var kind_name: const ^char = "UNKNOWN"

	if n == nil then
		if indent >= 0 then
			node_indent_dots(indent)
		end
		printf("(null)\n")
		return
	end

	if indent >= 0 then
		print_line_column(n)
		node_indent_dots(indent)
	end

	switch n.kind of
		case NODE_PROGRAM:
			kind_name := TokenKind::string(n.program_decl.unit_kind)
			print_kind_line_column(n, kind_name)
			if n.program_decl.package_path and n.program_decl.package_path_len > 0 then
				printf("'%.*s'.", n.program_decl.package_path_len as int,
					n.program_decl.package_path)
			end
			if n.program_decl.name and n.program_decl.name_len > 0 then
				printf("'%.*s'", n.program_decl.name_len as int, n.program_decl.name)
			else
				printf("(unnamed)")
			end

			if n.program_decl.return_type then
				printf(" : ")
				type_print(n.program_decl.return_type)
			end
			printf("\n")

			// Params
			for i: size_t = 1 to n.program_decl.param_count do
				node_print(n.program_decl.params[i - 1], indent + 1)
			end

			// Decls
			for i: size_t = 1 to n.program_decl.count do
				node_print(n.program_decl.decls[i - 1], indent + 1)
			end

			// Block
			if n.program_decl.block then
				node_print(n.program_decl.block, indent + 1)
			end

		case NODE_DOC_COMMENT:
			kind_name := "DOC_COMMENT"
			print_kind_line_column(n, kind_name)
			printf("'%.*s'\n", n.doc_comment.text_len as int, n.doc_comment.text)

		case NODE_PREPROCESSOR:
			kind_name := "PREPROCESSOR"
			print_kind_line_column(n, kind_name)
			printf("'%.*s'", n.preprocessor.length as int, n.preprocessor.text)
			printf("\n")

		case NODE_DEFINE:
			kind_name := "DEFINE"
			print_kind_line_column(n, kind_name)
			if n.define_stmt.is_exported then
				printf("EXPORT ")
			end
			printf("'%.*s'\n", n.define_stmt.length as int, n.define_stmt.text)

		case NODE_VAR_DECL, NODE_CONST_DECL, NODE_LET_DECL:
			if n.kind == NODE_VAR_DECL then
				kind_name := "VAR_DECL"
			elsif n.kind == NODE_CONST_DECL then
				kind_name := "CONST_DECL"
			else
				kind_name := "LET_DECL"
			end
			print_kind_line_column(n, kind_name)
			if n.var_decl.is_exported then
				printf(" EXPORT")
			end
			if n.var_decl.is_extern then
				printf(" EXTERN")
			end
			if n.var_decl.is_static then
				printf(" STATIC")
			end
			printf("\n")

			// print each VariableItem
			for i: size_t = 1 to n.var_decl.count do
				var item: const ^TNode = n.var_decl.items[i - 1]
				node_print(item, indent + 1)
			end

		case NODE_VAR_ITEM, NODE_CONST_ITEM, NODE_LET_ITEM:
			if n.kind == NODE_VAR_ITEM then
				kind_name := "VAR_ITEM"
			elsif n.kind == NODE_CONST_ITEM then
				kind_name := "CONST_ITEM"
			elsif n.kind == NODE_LET_ITEM then
				kind_name := "LET_ITEM"
			else
				kind_name := "(unknown) ITEM"
			end
			print_kind_line_column(n, kind_name)

			// const type?
			if n.var_item.item_type and n.var_item.item_type.is_const then
				printf("const ")
			end

			printf("'%.*s : ", n.var_item.name_len as int, n.var_item.name)
			type_print(n.var_item.item_type)

			if n.var_item.initializer then
				printf(" =\n")
				node_print(n.var_item.initializer, indent + 1)
			else
				printf(" (zero-initialized)\n")
			end

		case NODE_TYPE_DECL:
			kind_name := "TYPE_DECL"
			print_kind_line_column(n, kind_name)
			if n.type_decl.is_exported then
				printf("(EXPORT)")
			end
			if n.type_decl.is_extern then
				printf("(EXTERN) ")
			end
			if n.type_decl.is_forward then
				printf("(FORWARD) ")
			end

			if n.type_decl.defined_type <> nil and n.type_decl.defined_type.is_const then
				printf(" const ")
			end

			// Show the type name being defined
			if n.type_decl.name <> nil and n.type_decl.name_len > 0 then
				printf("'%.*s' ", n.type_decl.name_len as int, n.type_decl.name)
			else
				printf("(unnamed)")
			end

			// Show the defined type
			printf("= ")

			if n.type_decl.struct_body <> nil then
				var struct_body: ^TNode = n.type_decl.struct_body
				if struct_body.struct_decl.is_packed then
					printf("PACKED ")
				end
				if struct_body.struct_decl.is_union then
					printf("UNION ")
				else
					printf("STRUCT ")
				end
				if struct_body.struct_decl.extends_type then
					printf("EXTENDS '%.*s'",
						struct_body.struct_decl.extends_type.name_len as int,
						struct_body.struct_decl.extends_type.name)
				end
				printf("\n")
				for i: size_t = 1 to struct_body.struct_decl.field_count do
					node_print(struct_body.struct_decl.fields[i - 1], indent + 1)
				end
			elsif n.type_decl.method_type <> nil then
				var m: ^TNode = n.type_decl.method_type
				if m.method_type.is_function then
					printf("FUNCTION ")
					if m.method_type.return_type then
						printf(": ")
						type_print(m.method_type.return_type)
						printf("\n")
					else
						printf(": (none)\n")
					end
				else
					printf("PROCEDURE \n")
				end

				if m.method_type.params then
					node_print(m.method_type.params, indent + 1)
				else
					printf("(no params)\n")
				end
			elsif n.type_decl.enum_type <> nil then
				var en: ^TNode = n.type_decl.enum_type
				printf("ENUM\n")
				for i: size_t = 1 to en.enum_type.count do
					node_print(en.enum_type.elements[i - 1], indent + 1)
				end
			elsif n.type_decl.defined_type <> nil then
				type_print(n.type_decl.defined_type)
				printf("\n")
			elsif n.type_decl.is_extern_struct then
				printf("STRUCT")
				if n.type_decl.c_tag_name <> nil and n.type_decl.c_tag_name_len > 0 then
					printf(" '%.*s'", n.type_decl.c_tag_name_len as int,
						n.type_decl.c_tag_name)
				end
				printf("\n")
			elsif n.type_decl.is_forward then
				printf("FORWARD\n")
			else
				printf("(opaque)\n")
			end

		case NODE_ENUM_TYPE:
			kind_name := "ENUM_TYPE"
			print_kind_line_column(n, kind_name)
			printf("\n")
			for i: size_t = 1 to n.enum_type.count do
				node_print(n.enum_type.elements[i - 1], indent + 1)
			end

		case NODE_ENUM_ITEM:
			kind_name := "ENUM_ITEM"
			print_kind_line_column(n, kind_name)
			printf("'%.*s'", n.enum_item.name_len as int, n.enum_item.name)
			if n.enum_item.value <> nil then
				printf(" =\n")
				node_print(n.enum_item.value, indent + 1)
			else
				printf("\n")
			end

		case NODE_STRUCT_DECL:
			if n.struct_decl.is_union then
				kind_name := "UNION_DECL"
			else
				kind_name := "STRUCT_DECL "
			end
			print_kind_line_column(n, kind_name)
			printf("'%.*s'", n.struct_decl.name_len as int, n.struct_decl.name)
			if n.struct_decl.is_packed then
				printf("PACKED ")
			end
			if n.struct_decl.extends_type then
				printf("EXTENDS '%.*s'",
					n.struct_decl.extends_type.name_len as int,
					n.struct_decl.extends_type.name)
			end
			if n.struct_decl.is_union then
				printf("UNION ")
			end
			printf("\n")
			for i: size_t = 1 to n.struct_decl.field_count do
				node_print(n.struct_decl.fields[i - 1], indent + 1)
			end

		case NODE_ARRAY_TYPE:
			kind_name := "ARRAY_TYPE"
			print_kind_line_column(n, kind_name)
			if n.array_type.element_type then
				node_print(n.array_type.element_type, indent + 1)
			end
			printf("[")
			if n.array_type.size_expr then
				node_print(n.array_type.size_expr, 0)
			else
				printf("?")
			end
			printf("]\n")

		case NODE_ARRAY_LITERAL:
			kind_name := "ARRAY_LITERAL"
			print_kind_line_column(n, kind_name)
			printf("[%zu]\n", n.array_literal.count)
			for i: size_t = 1 to n.array_literal.count do
				node_print(n.array_literal.elements[i - 1], indent + 1)
			end

		case NODE_ARRAY_INDEX:
			kind_name := "ARRAY_INDEX"
			print_kind_line_column(n, kind_name)
			printf("\n")
			node_print(n.array_index.array_, indent + 1)
			node_print(n.array_index.index, indent + 1)

		case NODE_FIELD_DECL:
			kind_name := "FIELD_DECL"
			print_kind_line_column(n, kind_name)
			if n.field_decl.nested then
				printf(" anon union\n")
				node_print(n.field_decl.nested, indent + 1)
			else
				printf("'%.*s'", n.field_decl.name_len as int, n.field_decl.name)
				if n.field_decl.field_type then
					printf(" : ")
					type_print(n.field_decl.field_type)
				end
				if n.field_decl.initializer then
					printf(" = ")
					node_print(n.field_decl.initializer, indent + 1)
				else
					printf("\n")
				end
			end

		case NODE_FIELD_ACCESS:
			kind_name := "FIELD_ACCESS"
			print_kind_line_column(n, kind_name)
			printf("\n")
			node_print(n.field_access.record_, indent + 1)
			kind_name := "FIELD"
			print_line_column(n)
			node_indent_dots(indent + 1)
			print_kind_line_column(n, kind_name)
			printf("'%.*s'\n", n.field_access.field_len as int,
				n.field_access.field_name)

		case NODE_PROC_DECL, NODE_FUNC_DECL:
			kind_name := (n.kind == NODE_PROC_DECL) ? "PROC_DECL" : "FUNC_DECL"
			print_kind_line_column(n, kind_name)

			if n.proc_decl.is_extern then
				printf("EXTERN ")
			end

			if n.proc_decl.is_forward then
				printf("FORWARD ")
			end

			if n.proc_decl.is_exported then
				printf("EXPORT ")
			end

			if n.proc_decl.is_recursive then
				printf("RECURSIVE ")
			end

			if n.proc_decl.is_function then
				printf("FUNCTION ")
				if n.proc_decl.method_owner and n.proc_decl.method_owner_len > 0 then
					printf("'%.*s::%.*s': ",
						n.proc_decl.method_owner_len as int, n.proc_decl.method_owner,
						n.proc_decl.name_len as int, n.proc_decl.name)
				elsif n.proc_decl.name and n.proc_decl.name_len > 0 then
					printf("'%.*s': ", n.proc_decl.name_len as int, n.proc_decl.name)
				end

				if n.proc_decl.return_type then
					type_print(n.proc_decl.return_type)
				end
			else
				printf("PROCEDURE ")
				if n.proc_decl.method_owner and n.proc_decl.method_owner_len > 0 then
					printf("'%.*s::%.*s'",
						n.proc_decl.method_owner_len as int, n.proc_decl.method_owner,
						n.proc_decl.name_len as int, n.proc_decl.name)
				elsif n.proc_decl.name and n.proc_decl.name_len > 0 then
					printf("'%.*s'", n.proc_decl.name_len as int, n.proc_decl.name)
				end
			end

			printf("\n")

			if n.proc_decl.receiver then
				print_line_column(n)
				node_indent_dots(indent + 1)
				printf("RECEIVER\n")
				node_print(n.proc_decl.receiver, indent + 2)
			end

			// Parameters
			if n.proc_decl.params then
				node_print(n.proc_decl.params, indent + 1)
			end

			// Body
			if n.proc_decl.body then
				node_print(n.proc_decl.body, indent + 1)
			end

		case NODE_BLOCK:
			kind_name := "BLOCK"
			print_kind_line_column(n, kind_name)
			if n.block.count == 0 then
				printf(" (empty)")
			else
				; // printf(" (%zu statements)", n.block.count)
			end
			printf("\n")

			// DbC requires
			for i: size_t = 1 to n.block.require_count do
				print_line_column(n)
				node_indent_dots(indent + 1)
				printf("REQUIRE\n")
				node_print(n.block.requires[i - 1], indent + 2)
			end

			for i: size_t = 1 to n.block.count do
				node_print(n.block.stmts[i - 1], indent + 1)
			end

			// DbC ensures
			for i: size_t = 1 to n.block.ensure_count do
				print_line_column(n)
				node_indent_dots(indent + 1)
				printf("ENSURE\n")
				node_print(n.block.ensures[i - 1], indent + 2)
			end

		case NODE_IF:
			kind_name := "IF"
			print_kind_line_column(n, kind_name)
			printf("\n")
			node_print(n.if_stmt.cond, indent + 1)
			node_print(n.if_stmt.then_, indent + 1)
			if n.if_stmt.elsif_ <> nil then
				node_print(n.if_stmt.elsif_, indent + 1)
			end
			if n.if_stmt.else_ <> nil then
				node_print(n.if_stmt.else_, indent + 1)
			end

		case NODE_ELSIF:
			kind_name := "ELSIF"
			print_kind_line_column(n, kind_name)
			printf("\n")
			node_print(n.if_stmt.cond, indent + 1)
			node_print(n.if_stmt.then_, indent + 1)
			if n.if_stmt.elsif_ <> nil then
				node_print(n.if_stmt.elsif_, indent + 1)
			end
			if n.if_stmt.else_ <> nil then
				node_print(n.if_stmt.else_, indent + 1)
			end

		case NODE_ELSE:
			kind_name := "ELSE"
			print_kind_line_column(n, kind_name)
			printf("\n")
			if n.if_stmt.else_ <> nil then
				node_print(n.if_stmt.else_, indent + 1)
			end

		case NODE_WHILE:
			kind_name := "WHILE"
			print_kind_line_column(n, kind_name)
			printf("\n")

			node_print(n.while_stmt.cond, indent + 1)

			if n.while_stmt.bound_expr <> nil then
				print_line_column(n)
				node_indent_dots(indent + 1)
				printf("BOUND\n")
				node_print(n.while_stmt.bound_expr, indent + 2)
			end

			// DbC INVARIANTS
			for i: size_t = 1 to n.while_stmt.invariant_count do
				print_line_column(n)
				node_indent_dots(indent + 1)
				printf("INVARIANT\n")
				node_print(n.while_stmt.invariants[i - 1], indent + 2)
			end

			if n.while_stmt.body <> nil then
				node_print(n.while_stmt.body, indent + 1)
			end

		case NODE_FOR:
			kind_name := "FOR"
			print_kind_line_column(n, kind_name)
			printf("%.*s %s ... %s ... BY %d DO\n", n.for_stmt.var_len as int,
				n.for_stmt.var_name, n.for_stmt.declares ? "=" : ":=",
				n.for_stmt.step >= 0 ? "TO" : "DOWNTO",
				n.for_stmt.step)
			node_print(n.for_stmt.start_, indent + 1)
			node_print(n.for_stmt.end_, indent + 1)

			// TODO: Handle "BY" keyword. Step is currently a placeholder.

			// DbC INVARIANTS
			for i: size_t = 1 to n.for_stmt.invariant_count do
				print_line_column(n)
				node_indent_dots(indent + 1)
				printf("INVARIANT\n")
				node_print(n.for_stmt.invariants[i - 1], indent + 2)
			end

			if n.for_stmt.body <> nil then
				node_print(n.for_stmt.body, indent + 1)
			end

		case NODE_REPEAT_UNTIL:
			kind_name := "REPEAT_UNTIL"
			print_kind_line_column(n, kind_name)
			printf("\n")

			if n.repeat_until.bound_expr <> nil then
				print_line_column(n)
				node_indent_dots(indent + 1)
				printf("BOUND\n")
				node_print(n.repeat_until.bound_expr, indent + 2)
			end

			// DbC INVARIANTS
			for i: size_t = 1 to n.repeat_until.invariant_count do
				print_line_column(n)
				node_indent_dots(indent + 1)
				printf("INVARIANT\n")
				node_print(n.repeat_until.invariants[i - 1], indent + 2)
			end

			if n.repeat_until.body <> nil then
				node_print(n.repeat_until.body, indent + 1)
			end
			if n.repeat_until.cond <> nil then
				node_print(n.repeat_until.cond, indent + 1)
			end

		case NODE_LOOP:
			kind_name := "LOOP"
			print_kind_line_column(n, kind_name)
			printf("\n")

			if n.loop_stmt.bound_expr <> nil then
				print_line_column(n)
				node_indent_dots(indent + 1)
				printf("BOUND\n")
				node_print(n.loop_stmt.bound_expr, indent + 2)
			end
			// DbC INVARIANTS
			for i: size_t = 1 to n.loop_stmt.invariant_count do
				print_line_column(n)
				node_indent_dots(indent + 1)
				printf("INVARIANT\n")
				node_print(n.loop_stmt.invariants[i - 1], indent + 2)
			end

			if n.loop_stmt.body <> nil then
				node_print(n.loop_stmt.body, indent + 1)
			end

		case NODE_RETURN:
			kind_name := "RETURN"
			print_kind_line_column(n, kind_name)
			printf("\n")
			if n.ret.expr <> nil then
				node_print(n.ret.expr, indent + 1)		// print on next line, easier to read
			end

		case NODE_CONTINUE:
			kind_name := "CONTINUE"
			print_kind_line_column(n, kind_name)
			printf("\n")

		case NODE_BREAK:
			kind_name := "BREAK"
			print_kind_line_column(n, kind_name)
			printf("\n")

		case NODE_ASSIGN:
			kind_name := "ASSIGN"
			print_kind_line_column(n, kind_name)
			printf(" %s \n", TokenKind::string(n.binary.op))
			node_print(n.binary.left, indent + 1)
			node_print(n.binary.right, indent + 1)

		case NODE_BINARY:
			kind_name := "BINARY"
			print_kind_line_column(n, kind_name)

			printf("%s\n", TokenKind::string(n.binary.op))
			node_print(n.binary.left, indent + 1)
			node_print(n.binary.right, indent + 1)

		case NODE_CALL:
			kind_name := "CALL"
			print_kind_line_column(n, kind_name)
			if n.call.receiver_expr <> nil then
				printf("<recv>:")
			end
			if n.call.method_owner and n.call.method_owner_len > 0 then
				printf("'%.*s::%.*s', ( ",
					n.call.method_owner_len as int, n.call.method_owner, 
					n.call.name_len as int, n.call.name)
			elsif n.call.name and n.call.name_len > 0 then
				printf("'%.*s' ( ", n.call.name_len as int, n.call.name)
			else
				printf("?? ( ")
			end

			// Print arguments
			for i: size_t = 1 to n.call.argc do
				if i > 1 then
					printf(", ")
				end

				// For simple literals/idents, show a short preview
				let arg: ^TNode = n.call.args[i - 1]

				if arg.kind == NODE_LITERAL then
					let len: size_t = arg.token.length > 30 ? 30 as size_t : arg.token.length
					printf("'%.*s'", len as int, arg.token.start)
				elsif arg.kind == NODE_IDENT then
					printf("%.*s", arg.token.length as int,
						arg.token.start)
				else
					printf("<expr>")
				end
			end
			printf(" )")
			if n.resolved_sym <> nil then
				printf(" -> %s", symbol_kind_name(n.resolved_sym.kind))
			end
			printf("\n")

		case NODE_ASSERT:
			kind_name := "ASSERT"
			print_kind_line_column(n, kind_name)
			printf("\n")
			node_print(n.assert_stmt.condition, indent + 1)
			if n.assert_stmt.const_expr <> nil then
				node_print(n.assert_stmt.const_expr, indent + 1)
			end

		case NODE_SIZEOF:
			kind_name := "SIZEOF"
			print_kind_line_column(n, kind_name)
			if n.sizeof_expr.is_type then
				printf("(type) ")
				if n.sizeof_expr.target.sizeof_type <> nil then
					printf("'%.*s'", n.sizeof_expr.target.sizeof_type.name_len as int,
						n.sizeof_expr.target.sizeof_type.name)
				end
			else
				printf("(designator)\n")
				node_print(n.sizeof_expr.target.designator, indent + 1)
			end
			printf("\n")

		case NODE_COUNTOF:
			kind_name := "COUNTOF"
			print_kind_line_column(n, kind_name)
			if n.sizeof_expr.folded then
				printf(" count=%d", n.sizeof_expr.count)
			end
			if n.sizeof_expr.is_type then
				printf(" (type)\n")
			else
				printf(" (designator)\n")
				node_print(n.sizeof_expr.target.designator, indent + 1)
			end

		case NODE_IMPORT:
			kind_name := "IMPORT"
			print_kind_line_column(n, kind_name)
			if n.import_stmt.from_path and n.import_stmt.path_len > 0 then
				printf(" FROM '%.*s'", n.import_stmt.path_len as int, n.import_stmt.from_path)
			end
			printf("\n")
			for i: size_t = 1 to n.import_stmt.count do
				node_print(n.import_stmt.items[i - 1], indent + 1)
			end			

		case NODE_IMPORT_ITEM:
			kind_name := "IMPORT_ITEM"
			print_kind_line_column(n, kind_name)
			if n.import_item.method_owner <> nil and n.import_item.method_owner_len > 0 then
				printf("'%.*s::%.*s'",
					n.import_item.method_owner_len as int, n.import_item.method_owner,
					n.import_item.qualident_len as int, n.import_item.qualident)
			else
				printf("'%.*s'", n.import_item.qualident_len as int, n.import_item.qualident)
			end
			if n.import_item.import_alias and n.import_item.import_alias_len > 0 then
				printf(" AS '%.*s'", n.import_item.import_alias_len as int, n.import_item.import_alias)
			end
			printf("\n")

		case NODE_PARAM:
			kind_name := "PARAM"
			print_kind_line_column(n, kind_name)
			if n.param.is_const then
				printf("const ")
			end

			// It is a grammar error to have both VAR and REF. But show them both in AST
			// just in case...
			if n.param.is_var then
				printf("VAR ")
			end
			if n.param.is_ref then
				printf("REF ")
			end
			printf("'%.*s' : ", n.param.name_len as int, n.param.name)
			type_print(n.param.param_type)
			printf("\n")

		case NODE_EXPR_STMT:
			kind_name := "EXPR_STMT"
			print_kind_line_column(n, kind_name)
			printf("\n")
			node_print(n.expr_stmt.expr, indent + 1)

		case NODE_CAST:
			kind_name := "CAST"
			print_kind_line_column(n, kind_name)
			printf("AS ")
			type_print(n.cast_expr.target_type)
			printf("\n")
			node_print(n.cast_expr.expr, indent + 1)

		case NODE_UNARY:
			kind_name := "UNARY"
			print_kind_line_column(n, kind_name)
			printf("%s\n", TokenKind::string(n.unary.op))
			node_print(n.unary.operand, indent + 1)

		case NODE_TERNARY:
			kind_name := "TERNARY"
			print_kind_line_column(n, kind_name)
			printf("\n")
			node_print(n.ternary.cond, indent + 1)
			node_print(n.ternary.then_expr, indent + 1)
			node_print(n.ternary.else_expr, indent + 1)

		case NODE_IDENT:
			kind_name := "IDENT"
			print_kind_line_column(n, kind_name)
			if n.token.length > 0 then
				printf("'%.*s'", n.token.length as int, n.token.start)
			end
			if n.resolved_sym <> nil then
				printf(" -> %s", symbol_kind_name(n.resolved_sym.kind))
			end
			printf("\n")

		case NODE_LITERAL:
			kind_name := "LITERAL"
			print_kind_line_column(n, kind_name)
			if n.token.length > 0 and n.token.start <> nil then
				let len: size_t = n.token.length > 60 ? 60 as size_t : n.token.length
				printf("'%.*s'", len as int, n.token.start)
			end
			printf("\n")

		case NODE_PARAM_LIST:
			kind_name := "PARAM_LIST"
			print_kind_line_column(n, kind_name)
			if n.param_list.has_ellipsis then
				printf(" ...")
			end
			printf("\n")
			for i: size_t = 1 to n.param_list.count do
				node_print(n.param_list.params[i - 1], indent + 1)
			end

		case NODE_INC, NODE_DEC:
			kind_name := (n.kind == NODE_INC) ? "INC" : "DEC"
			print_kind_line_column(n, kind_name)
			printf("\n")
			node_print(n.binary.left, indent + 1)
			if n.binary.right <> nil then
				node_print(n.binary.right, indent + 1)
			end

		case NODE_DEFER:
			kind_name := "DEFER"
			print_kind_line_column(n, kind_name)
			printf("\n")
			node_print(n.defer_stmt.action, indent + 1)

		case NODE_DEBUG:
			kind_name := "DEBUG"
			print_kind_line_column(n, kind_name)
			printf("\n")
			node_print(n.defer_stmt.action, indent + 1)

		case NODE_SWITCH:
			kind_name := "SWITCH"
			print_kind_line_column(n, kind_name)
			printf("\n")

			// The controlling expression
			node_print(n.switch_stmt.expr, indent + 1)

			// Each CASE arm
			for i: size_t = 1 to n.switch_stmt.case_count do
				var c: ^TSwitchCase = n.switch_stmt.cases[i - 1]

				print_line_column(n)
				node_indent_dots(indent + 1)
				printf("CASE\n")

				// Print labels for this arm
				for j: size_t = 1 to c.label_count do
					node_print(c.labels[j - 1], indent + 2)
				end

				// Body of the arm
				node_print(c.body, indent + 2)
			end

			// The required ELSE
			print_line_column(n)
			node_indent_dots(indent + 1)
			printf("ELSE\n")
			for k: size_t = 1 to n.switch_stmt.else_label_count do
				node_print(n.switch_stmt.else_labels[k - 1], indent + 2)
			end
			node_print(n.switch_stmt.else_body, indent + 1)

		case NODE_PAREN:
			kind_name := "PAREN"
			print_kind_line_column(n, kind_name)
			printf("\n")
			node_print(n.paren.expr, indent + 1)

		else NODE_METHOD_TYPE, default:
			// Get token name instead.
			kind_name := "UNKNOWN_NODE"
			print_kind_line_column(n, kind_name)
			printf("(%s)", TokenKind::string(n.token.kind))
			if n.token.length > 0 and n.token.start <> nil then
				let len: size_t = n.token.length > 32 ? 32 as size_t: n.token.length

				printf("'%.*s'\n", len as int, n.token.start)
			end
			printf("\n")
	end
end node_print


begin
end node

(* msr/gk/msr *)
