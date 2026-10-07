module codegen_common()

(**
 * CodegenCommon.mc
 * 5 June 2026
 * 
 * Shared code generation helpers used by both the full C emitter (codegen_c.c)
 * and the header emitter (codegen_header.mc).
 * This file should contain only low-level emission primatives and context
 * management that are independent of "full program" vs "header only" logic.
 *
 * 28 August 2026 - Conversion form .c to .mc started
 *)


import from "tmodc.h"

import ppvoid, pchar 
    from arena
import DynBuf, pDynBuf, dynbuf_append, dynbuf_appendn, dynbuf_append_char,
    from dynbuf
IMPORT TOK_AT, TokenKind, TOK_COLON_EQ, TOK_ADD_EQ, TOK_SUB_EQ, TOK_MUL_EQ, TOK_DIV_EQ, 
    TOK_MOD_EQ, TOK_AND_EQ, TOK_OR_EQ, TOK_BITWISE_NOT_EQ, TOK_LSHIFT_EQ, TOK_RSHIFT_EQ, 
    TOK_KEYWORD_DIV, TOK_POWER, TOK_KEYWORD_AND, TOK_KEYWORD_OR, TOK_KEYWORD_MOD, 
    TOK_KEYWORD_XOR, TokenKind::string, TOK_CARET, TOK_KEYWORD_NOT, TOK_NUMBER,
    from Lexer
import mh_path_is_mh, mh_format_h_include,
    from mh_reader    
import Node, pNode, NODE_PROC_DECL, NODE_FUNC_DECL, NODE_FOR, NODE_WHILE, NODE_REPEAT_UNTIL,
    NODE_LOOP, NODE_DOC_COMMENT, NODE_PROGRAM, NODE_TYPE_DECL, NODE_IMPORT, NODE_IMPORT_ITEM,
    NODE_PARAM, NODE_PARAM_LIST, NODE_UNARY, NODE_STRUCT_DECL, NODE_ENUM_TYPE, NODE_ENUM_ITEM,
    NODE_METHOD_TYPE, NODE_IDENT, NODE_LITERAL, NODE_ARRAY_INDEX, NODE_FIELD_ACCESS, NODE_CALL,
    NODE_ASSIGN, NODE_BINARY, NODE_TERNARY, NODE_CAST, NODE_PAREN, NODE_ARRAY_LITERAL, NODE_SIZEOF,
    NODE_COUNTOF, NODE_INC, NODE_DEC, NODE_PREPROCESSOR, NODE_SWITCH, NODE_DEBUG, NODE_VAR_DECL,
    NODE_CONST_DECL, NODE_LET_DECL, NODE_VAR_ITEM, NODE_CONST_ITEM, NODE_LET_ITEM, NODE_FIELD_DECL,
    NODE_ARRAY_TYPE, NODE_BLOCK, NODE_IF, NODE_ELSIF, NODE_ELSE, NODE_BREAK, NODE_CONTINUE, 
    NODE_RETURN, NODE_EXPR_STMT, NODE_ASSERT, NODE_DEFER, NODE_DEFINE, 
    from "node.h"
import size_t 
    from "stddef.h"
import snprintf,
    from "stdio.h"
import strncmp, memcmp,
    from "string.h"
import TSymbol 
    from symbol
import SYM_KIND_LET, SYM_KIND_PARAM, 
    from symkind
import TType, pTType, type_c_spelling, 
    from ttype
import long_long, utils_parse_integer_literal,
    from utils


// import from "stdlib.h"
// import from "version.h"


(** ===================================
 *  Codegen Context
 *  ===================================
 *)


(**
 * Target backend selection
 *)
export type CodegenTarget = enum
  TARGET_C,         // Current c backend (default)
  TARGET_HEADER,    // Header .h backend conaining exports.
  TARGET_MH,        // modc-mh/1 export table backend.
  TARGET_VM,        // Future bytecode VM
  TARGET_WASM,      // Future WebAssembly (optional)
  TARGET_JSON,      // JSON representation of the AST.
end


(**
 * Context passed through all recursive codegen functions.
 * Contains the output buffer, current indentation, and parent/scope intormation.
 * This eliminates long parameter lists and makes future extensions (symbol table,
 * defer lists, etc.) trivial. This is setup by the main codegen_generate function.
 *)
export type CodegenContext = struct
    out: pDynBuf                        // REQUIRED: Output buffer - never NULL after init
    ast: const ^Node                          // REQUIRED: Top of the AST.
    indent: integer                     // REQUIRED: Current indentation level
    debug_enabled: bool                 // REQUIRED: Indicate if debug mode is on or not.
    assert_off: bool                    // REQUIRED: Turn off assert statemetns if true
    dbc_off: bool                       // REQUIRED: Turn off DbC statements if true
    target: CodegenTarget               // REQUIRED: Code generation target.
    parent_ctx: const ^CodegenContext   // NULL: parent ctx. May be NULL.
    parent_node: const ^Node            // NULL: immediate parent node (may be NULL)
    enclosing_func: const ^Node         // NULL: nearest function/procedure for RETURN/DEFER
    enclosing_loop: const ^Node         // NULL: nearest loop (for BREAK/CONTINUE)
    stmt_index: size_t                  // When parent ode is a BLOCK: index in
                                        // block.stmts of the statement being
                                        // emitted (or block.count at fall-through
                                        // END). Cutoff for DEFER: only stmts[i]
                                        // with i < stmt_index have been executed.
end
export type pCodegenContext = ^CodegenContext


(* ===============================================
 * Conext Helpers
 * =============================================== *)

(**
 * Creae a child context for a nested node.
 *)
export function ctx_push(ctx: const ^CodegenContext, new_parent: const ^Node): CodegenContext forward


(* ===============================================
 * Low-level Emission Helpers
 * =============================================== *)

export procedure emit_indent(out: pDynBuf, indent: int) forward

export function codegen_unit_binds_portable(prog: const ^Node, name: const ^char, name_len: size_t): bool forward

export procedure codegen_emit_c_prelude(out: pDynBuf, prog: const ^Node) forward

export procedure emit_return_type(out: pDynBuf, t: const ^TType) forward

export procedure emit_array_type(out: pDynBuf, t: const ^TType, name: const ^char, name_len: size_t) forward

export procedure emit_type_specifier(out: pDynBuf, t: const ^TType, name: const ^char, length: size_t,
        is_param: bool, is_var: bool, is_ref: bool, is_const: bool) forward

type pNode = ^Node
// TODO: if '^Node[]' then tmodc outputs '?' in the .mh file.
export procedure emit_param_list(out: pDynBuf, params: ^pNode, count: size_t, is_parameter: bool, has_ellipsis: bool) forward

export procedure emit_var_decl(out: pDynBuf, name: const ^char, name_len: size_t, t: const ^TType) forward

export procedure emit_doc_comment_as_c(out: pDynBuf, n: const ^Node) forward


(**
 * Emit a LET binding name: name_l{line}_c{col}
 * binding_decl is the NODE_LET_ITEM (sym-decl or let item node).
 *)
export procedure emit_let_binding_name(out: pDynBuf, name: const ^char, name_len: size_t,
                        binding_decl: const ^Node) forward

(**
 * Emit an identifier expression (mangles LET uses via resolved_sym).
 *)
export procedure emit_let_ident(out: pDynBuf, n: const ^Node) forward


(* ============================================
 * Reusable Declaration Emitters
 * ============================================ *)

export procedure codegen_common_type_decl(n: const ^Node, ctx: CodegenContext) forward

export procedure codegen_common_proc_or_func(n: const ^Node, ctx: CodegenContext) forward

export procedure codegen_common_struct_decl(n: const ^Node, ctx: CodegenContext) forward

export procedure codegen_common_union_decl(n: const ^Node, ctx: CodegenContext) forward

export procedure codegen_common_enum_type(n: const ^Node, type_name: const ^char, type_name_len: size_t,
        ctx: CodegenContext) forward

export procedure codegen_common_method_type(method: const ^Node, type_decl: const ^Node, 
        ctx: CodegenContext) forward

export procedure codegen_common_expr(n: const ^Node, ctx: CodegenContext) forward

export procedure codegen_common_emit_literal(n: const ^Node, ctx: CodegenContext) forward

export procedure codegen_common_array_literal(n: const ^Node, ctx: CodegenContext) forward

export procedure codegen_common_preprocessor(n: const ^Node, ctx: CodegenContext) forward

export procedure codegen_common_field_access(n: const ^Node, ctx: CodegenContext) forward

export procedure codegen_common_sizeof_expr(n: const ^Node, ctx: CodegenContext) forward

export procedure codegen_common_countof_expr(n: const ^Node, ctx: CodegenContext) forward

export procedure codegen_common_inc_dec(n: const ^Node, ctx: CodegenContext, as_statement: bool) forward

export procedure codegen_common_module_prototype(n: const ^Node, ctx: CodegenContext) forward

export procedure codegen_common_import(n: const ^Node, ctx: CodegenContext) forward


(* ============================================
 * Implementation
 * ============================================ *)


procedure emit_type_leaf_name(out: pDynBuf, t: const ^TType)
begin
    var s: const ^char = nil
    var n: size_t = 0

    if t == nil then
        dynbuf_append(out, "int")
        return
    end

    if type_c_spelling(t, @s, @n) and s <> nil and n > 0 then
        dynbuf_appendn(out, s, n)
        return
    end

    if t.name <> nil and t.name_len > 0 then
        dynbuf_appendn(out, t.name, t.name_len)
        return
    end

    // ^opaque / POINTER TO opaque has no name. Callers add '*' when is_pointer.
    if t.is_opaque then
        dynbuf_append(out, "void")
        return
    end

    dynbuf_append(out, "int")
end emit_type_leaf_name


(**
 * Create a child context for a nested node.
 * Struct copy is cheap and safe.
 * Exits on fatal error (should never happen in normal use.).
 *)
export function ctx_push(ctx: const ^CodegenContext, new_parent: const ^Node): CodegenContext
begin
    require ctx <> nil and ctx.out <> nil

    var child: CodegenContext = ctx^        // struct copy
    child.parent_node := new_parent
    child.parent_ctx := ctx

    // Update enclosing scopes when appropriate
    if new_parent <> nil then
        if new_parent.kind == NODE_PROC_DECL or
                new_parent.kind == NODE_FUNC_DECL then
            child.enclosing_func := new_parent
        end

        if new_parent.kind == NODE_FOR or
                new_parent.kind == NODE_WHILE or
                new_parent.kind == NODE_REPEAT_UNTIL or
                new_parent.kind == NODE_LOOP then
            child.enclosing_loop := new_parent
        end
    end
    return child
end ctx_push


(* ================================================================
 * Emit routines
 * ================================================================ *)


(**
 * Emit indentation (4 spaces per level)
 * Safe, clear, and silences -Wstrict-overflow without complexity.
 *)
export procedure emit_indent(out: pDynBuf, indent: int)
begin
    var i: int = 0

    while i < indent do
        dynbuf_append(out, "    ")
        inc(i)
    end
end


(**
 * Emit Doc Comment, both Pascal and C style as C style comments.
 *)
export procedure emit_doc_comment_as_c(out: pDynBuf, n: const ^Node)
begin
    if n == nil or n.kind <> NODE_DOC_COMMENT then
        return
    end

    let text_len: size_t = n.doc_comment.text_len
    let text: const ^char = n.doc_comment.text
    
    // Doc comments should at least be 6 chars long: "(** *)"
    if text_len > 5 then
        // if C style comments, full text can be output.
        if strncmp(text, "/**", 3) == 0 and text[text_len-1] == '/' then
            // output as is.
            dynbuf_appendn(out, text, text_len)

        // Pascal style comments need to be converted.
        elsif strncmp(text, "(**", 3) == 0 and text[text_len-1] == ')' then
            // Pascal style. Switch to C style.
            dynbuf_append_char(out, '/')
            dynbuf_appendn(out, text+1, text_len-2)
            dynbuf_append_char(out, '/')
        end
        dynbuf_append_char(out, '\n')
    end
end emit_doc_comment_as_c


(**
 * True if this unit has type Name = ... for a portable rebindable name.
 *)
export function codegen_unit_binds_portable(prog: const ^Node, name: const ^char, name_len: size_t): bool
begin
    var i: size_t
    var d: const ^Node
    var j: size_t
    var item: const ^Node
    var bind: const ^char
    var bind_len: size_t = 0

    if prog == nil or prog.kind <> NODE_PROGRAM or name == nil or name_len == 0 then
        return false
    end
    for i := 0 to prog.program_decl.count-1 do
        d := prog.program_decl.decls[i]
        if d == nil then
            continue
        end
        if d.kind == NODE_TYPE_DECL then
            if d.type_decl.is_forward or d.type_decl.is_extern then
                continue
            end
            if d.type_decl.name == nil or d.type_decl.name_len <> name_len then
                continue
            end
            if memcmp(d.type_decl.name, name, name_len) == 0 then
                return true
            end
            continue
        end
        if d.kind <> NODE_IMPORT then
            continue
        end
        if d.import_stmt.from_path == nil or
                not mh_path_is_mh(d.import_stmt.from_path, d.import_stmt.path_len) then
            continue
        end
        for j := 0 to d.import_stmt.count-1 do
            item := d.import_stmt.items[j]
            if item == nil or item.kind <> NODE_IMPORT_ITEM then
                continue
            end
            bind := item.import_item.qualident
            bind_len := item.import_item.qualident_len
            if item.import_item.import_alias <> nil and
                    item.import_item.import_alias_len > 0 then
                bind := item.import_item.import_alias
                bind_len := item.import_item.import_alias_len
            end
            if bind <> nil and bind_len == name_len and
                    memcmp(bind, name, name_len) == 0 then
                return true
            end
        end
    end
    return false
end codegen_unit_binds_portable


(**
 * C ABI prelude for a generated .h (includes, nil, byte, portable four).
 * Unit TYPE binds replace the default typedef for that name.
 *)
export procedure codegen_emit_c_prelude(out: pDynBuf, prog: const ^Node)
begin
    if out == nil then
        return
    end

    dynbuf_append(out, "#include <stdint.h>\n")
    dynbuf_append(out, "#include <stdbool.h>\n")
    dynbuf_append(out, "#include <assert.h>\n")
    dynbuf_append_char(out, '\n')

    dynbuf_append(out, "#define nil ((void *)0)\n")
    dynbuf_append(out, "#define NIL nil\n")
    dynbuf_append(out, "typedef uint8_t byte;\n")

    // Portable four: unit TYPE rebind replaces the default
    if not codegen_unit_binds_portable(prog, "string", 6) then
        dynbuf_append(out, "typedef const char* string;\n")
    end
    if not codegen_unit_binds_portable(prog, "integer", 7) then
        dynbuf_append(out, "typedef int integer;\n")
    end
    if not codegen_unit_binds_portable(prog, "cardinal", 8) then
        dynbuf_append(out, "typedef unsigned int cardinal;\n")
    end
    if not codegen_unit_binds_portable(prog, "real", 4) then
        dynbuf_append(out, "typedef float real;\n")
    end
    dynbuf_append_char(out, '\n')
end codegen_emit_c_prelude


(**
 * Emit return type. Same as type-specifier except [] not allowed.
 * TODO: fill out code for handling array type returns, i.e. they must collapse into just *
 *)
export procedure emit_return_type(out: pDynBuf, t: const ^TType)
begin
    if t == nil then
        dynbuf_append(out, "int")       // default to int return type
        return
    end

    if t.is_const then
        dynbuf_append(out, "const ")
    end

    if t.is_pointer then
        emit_type_leaf_name(out, t)
        dynbuf_append_char(out, '*')
    elsif t.is_array and t.element_type <> nil then
        emit_type_leaf_name(out, t.element_type)
        if t.element_type.is_pointer then
            dynbuf_append_char(out, '*')
        end
        dynbuf_append_char(out, '*')
    else
        emit_type_leaf_name(out, t)
    end
end emit_return_type


(**
 * Emit C array type syntax for typedefs and declarations.
 * Recursively handles nested arrays and the ARRAY[N] of syntax.
 * Produces correct C syntax, for example: int Matrix[4][4] or int Vector3[3]
 *
 * Called with name = nil when emitting only the base type (inner recursion).
 *)
export recursive procedure emit_array_type(out: pDynBuf, t: const ^TType, name: const ^char, name_len: size_t)
begin
    if t == nil then
        dynbuf_append(out, "int")
        if name <> nil and name_len > 0 then
            dynbuf_append_char(out, ' ')
            dynbuf_appendn(out, name, name_len)
        end
        return
    end

    if t.is_array and t.element_type <> nil then
        // Recurse to emit base type + name (name only at outermost level)
        emit_array_type(out, t.element_type, name, name_len)

        // Emit this level's dimension (outermost first)
        dynbuf_append_char(out, '[')
        if t.array_size > 0 then
            var buf: array[32] of char

            // Simple portable number -> string (no new utils needed)
            snprintf(buf, sizeof(buf), "%zu", t.array_size)
            dynbuf_append(out, buf)
        else
            // open array [] (rare in typedefs but supported)
            // dynbuf_append_char(out, ']')     // just []
            // return; // no extra chars needed
            // int n[] = {3, 1, 4, }; // is supported.
            ;
        end
        dynbuf_append_char(out, ']')
        return
    end

    // Leaf / base type (int, ^char, String, etc.)
    if t.is_const then
        dynbuf_append(out, "const ")
    end
    if t.is_pointer then
        if t.name <> nil and t.name_len > 0 then
            emit_type_leaf_name(out, t)
        else
            dynbuf_append(out, "void")
        end
        dynbuf_append_char(out, '*')
    else
        emit_type_leaf_name(out, t)
    end

    if name <> nil and name_len > 0 then
        dynbuf_append_char(out, ' ')
        dynbuf_appendn(out, name, name_len)
    end
end emit_array_type


(**
 * Emit type specifier (for typedef, function returns, parameters, etc.)
 * Supports: normal types, open arrays T[], fixed arrays T[N]. If type is an array
 * it needs the name of an identifier associated with the type as array information
 * will be declared after the identifer name. If name = nil or len = 0, then array
 * information will collaps into just a '*' after the type name.
 * New Parameter Passing Model:
 *  - VAR   -> T*
 *  - REF   -> T*
 *  - CONST -> const T* (or const T for small types)
 *  - default -> T (or const T* for aggregates)
 *
 * @param out = output buffer
 * @param t = TType to generate code for
 * @param name = name of the identifier associated with type. Needed for arrays
 * @param len = length of the name.
 *)
export recursive procedure emit_type_specifier(out: pDynBuf, t: const ^TType, 
            name: const ^char, length: size_t,
            is_param: bool, is_var: bool, is_ref: bool, is_const: bool)
begin
    if t == nil then
        dynbuf_append(out, "int ")
        if name <> nil and length > 0 then
            dynbuf_appendn(out, name, length)
        end
        return
    end

    // Parameter qualifiers take precedence
    if (is_const or t.is_const) then
        if not (is_param and (is_var or is_ref)) then
            dynbuf_append(out, "const ")
        end
    end

    // Base type. Full support for nested arrays (ARRAY[N] OF ... and [N])
    // Pointer-to-array (^array[N] of T): both flags on one TType.
    // Must not take array decay (params) or emit_array_type (T name[N]).
    // C: T (*name)[N]. Open N => T (*name)[]. Named ^Vector3 is not this
    // arm (is_pointer only on the use type -> Vector3 *p below).
    // v1: element is a leaf (integer, struct name), not a nested array.
    if t.is_array and t.element_type <> nil and t.is_pointer then
        var buf: array[32] of char

        emit_type_leaf_name(out, t.element_type)
        dynbuf_append(out, " (*")
        if name <> nil and length > 0 then
            dynbuf_appendn(out, name, length)
        end
        dynbuf_append(out, ")")
        dynbuf_append_char(out, '[')
        if t.array_size > 0 then
            snprintf(buf, sizeof(buf), "%zu", t.array_size)
            dynbuf_append(out, buf)
        end
        dynbuf_append_char(out, ']')
        return
    end

    if t.is_array and t.element_type <> nil then
        if is_param then
            // Parameters: array decay to pointer (C standard)
            emit_type_specifier(out, t.element_type, nil, 0, true, false, false, is_const)
            dynbuf_append_char(out, '*')        // ensure pointer

            if name <> nil and length > 0 then
                dynbuf_append_char(out, ' ')
                dynbuf_appendn(out, name, length)
            end
        else
            // Typedefs / variable declarations: emit full C array syntax
            emit_array_type(out, t, name, length)
            return      // recursion already emitted everything.
        end
        return
    end

    // Normal non-array type (pointer, named type, etc.)
    if t.is_pointer then
        if t.name <> nil and t.name_len > 0 then
            emit_type_leaf_name(out, t)
        else
            dynbuf_append(out, "void")
        end
        dynbuf_append_char(out, '*')
    else
        emit_type_leaf_name(out, t)
    end

    // VAR/REF on a non-pointer T => T* (alias / reference to value).
    // REF on ^T => leave as T* (pointer by value; no rebind of caller's pointer).
    // VAR on ^T => T** so p := nil can rebind the caller's pointer variable.
    if is_param and (is_var or is_ref) and not t.is_pointer then
        dynbuf_append_char(out, '*')
    elsif is_param and is_var and t.is_pointer then
        dynbuf_append_char(out, '*')        // T** for VAR p: ^T
    end

    if name <> nil and length > 0 then
        dynbuf_append_char(out, ' ')
        dynbuf_appendn(out, name, length)
    end
end emit_type_specifier


(**
 * Emit parameter list
 *)
export procedure emit_param_list(out: pDynBuf, params: ^pNode, count: size_t, is_parameter: bool,
        has_ellipsis: bool)
begin
    var i: size_t = 0

    // Parameter list
    dynbuf_append(out, "(")

    if params <> nil and count > 0 then
        for i := 0 to count-1 do
            var param: const ^Node = params[i]
            if i > 0 then
                dynbuf_append(out, ", ")
            end

            emit_type_specifier(out, 
                param.param.param_type,
                param.param.name,
                param.param.name_len,
                is_parameter,
                param.param.is_var,
                param.param.is_ref,
                param.param.is_const)
        end
        if has_ellipsis then
            dynbuf_append(out, ", ...")
        end
    else
        dynbuf_append(out, "void")      // no parameters
    end

    dynbuf_append(out, ")")
end emit_param_list


(** 
 * Emit a full variable declaration (name + array brackets in correct position)
 * Example bool is_prime[101] = {0}
 *)
export procedure emit_var_decl(out: pDynBuf, name: const ^char, name_len: size_t, t: const ^TType)
begin
    if t == nil then
        dynbuf_append(out, "int ")
        dynbuf_appendn(out, name, name_len)
        return
    end

    emit_type_specifier(out, t, name, name_len, false, false, false, false)
end emit_var_decl


(**
 * Emit a LET binding name: name_l{line}_c{col}
 * binding_decl is the NODE_LET_ITEM (sym-decl or let item node).
 *)
export procedure emit_let_binding_name(out: pDynBuf, name: const ^char, name_len: size_t, 
        binding_decl: const ^Node)
begin
    var buf: array[32] of char

    if out == nil or name == nil or name_len == 0 or binding_decl == nil then
        return
    end

    dynbuf_appendn(out, name, name_len)
    dynbuf_append(out, "_l")
    snprintf(buf, sizeof(buf), "%d", binding_decl.token.line)
    dynbuf_append(out, buf)
    dynbuf_append(out, "_c")
    snprintf(buf, sizeof(buf), "%d", binding_decl.token.column)
    dynbuf_append(out, buf)
end emit_let_binding_name


(**
 * Codegen_param_is_by_ref
 *)
function codegen_param_is_by_ref(param_decl: const ^Node): bool
begin
    if param_decl == nil or param_decl.kind <> NODE_PARAM then
        return false
    end
    return param_decl.param.is_var or param_decl.param.is_ref
end codegen_param_is_by_ref


(**
 * True when C formal is T* alias of value T (not when formal type is already ^U).
 *)
function codegen_param_needs_pointee_load(param_decl: const ^Node): bool
begin
    var ty: const ^TType

    if not codegen_param_is_by_ref(param_decl) then
        return false
    end
    ty := param_decl.param.param_type
    if ty == nil then
        return false
    end

    // Open array already decays to pointer; use name as pointer
    if ty.is_array then
        return false
    end

    // REF/VAR on non-pointer T => (*p). REF on ^T => p. VAR on ^T => (*p) is T*.
    if ty.is_pointer then
        return param_decl.param.is_var          // only VAR ^T uses (*p) as T*
    end
    return true         // VAR/REF T
end codegen_param_needs_pointee_load


(**
 * Formal for call arg index (0-based). Instance sugar: receiver is formal 0,
 * so args[i] maps to formals[i + 1].
 *)
function codegen_call_formal_for_arg(call: const ^Node, arg_index: size_t): const ^Node
begin
    var decl: const ^Node
    var pl: const ^Node
    var fi: size_t

    if call == nil or call.resolved_sym == nil or call.resolved_sym^.decl == nil then
        return nil
    end
    decl := call.resolved_sym^.decl
    if decl.kind <> NODE_PROC_DECL and decl.kind <> NODE_FUNC_DECL then
        return nil
    end
    pl := decl.proc_decl.params
    if pl == nil or pl.kind <> NODE_PARAM_LIST or pl.param_list.params == nil then
        return nil
    end
    fi := arg_index
    if call.call.receiver_expr <> nil then
        fi := arg_index + 1
    end
    if fi >= pl.param_list.count then
        return nil
    end
    return pl.param_list.params[fi]
end codegen_call_formal_for_arg


(**
 * codgen_call_formal_receiver
 *)
function codegen_call_formal_receiver(call: const ^Node): const ^Node
begin
    var decl: const ^Node
    var pl: const ^Node

    if call == nil or call.call.receiver_expr == nil then
        return nil
    end
    if call.resolved_sym == nil or call.resolved_sym^.decl == nil then
        return nil
    end
    decl := call.resolved_sym^.decl
    if decl.kind <> NODE_PROC_DECL and decl.kind <> NODE_FUNC_DECL then
        return nil
    end
    pl := decl.proc_decl.params
    if pl == nil or pl.kind <>  NODE_PARAM_LIST or pl.param_list.count == 0 then
        return nil
    end
    return pl.param_list.params[0]
end codegen_call_formal_receiver


(**
 * True when this actual should be emitted with a leading '&' for a VAR/REF formal
 *)
function codegen_args_needs_address(formal: const ^Node, arg: const ^Node): bool
begin
    var ty: const ^TType

    if formal == nil or arg == nil or formal.kind <> NODE_PARAM then
        return false
    end

    // Already address-of (@x => &x).
    if arg.kind == NODE_UNARY and arg.unary.op == TOK_AT then
        return false
    end
    if not codegen_param_is_by_ref(formal) then
        return false
    end
    ty := formal.param.param_type
    if ty == nil then
        return false
    end
    if ty.is_array then
        return false
    end
    if ty.is_pointer then
        // VAR p: ^T => T**; need &ptr_var. REF p: ^T => T*; pass pointer as-is.
        return formal.param.is_var
    end

    // VAR/REF p: T => T*; need &value
    return true
end codegen_args_needs_address


(**
 * codegen_emit_call_arg_deref
 *)
procedure codegen_emit_call_arg_deref(formal: const ^Node, arg: const ^Node,
        auto_deref: bool, base_depth: size_t, ctx: CodegenContext)
begin
    var need_addr: bool
    var wrap: bool
    var i: size_t

    need_addr := codegen_args_needs_address(formal, arg)
    wrap := need_addr and (auto_deref or base_depth > 0)

    if need_addr then
        dynbuf_append_char(ctx.out, '&')
    end
    if wrap then
        dynbuf_append_char(ctx.out, '(')
    end
    if auto_deref then
        dynbuf_append(ctx.out, "(*")
    end
    codegen_common_expr(arg, ctx)
    if auto_deref then
        dynbuf_append_char(ctx.out, ')')
    end
    for i := 0 to base_depth-1 do
        dynbuf_append(ctx.out, ".base")
    end
    if wrap then
        dynbuf_append_char(ctx.out, ')')
    end
end codegen_emit_call_arg_deref


(**
 * Emit an identifier expression (mangles LET uses via resolved_sym).
 *)
export procedure emit_let_ident(out: pDynBuf, n: const ^Node)
begin
    if n == nil or out == nil then
        return
    end

    if n.resolved_sym <> nil and n.resolved_sym^.kind == SYM_KIND_LET and
            n.resolved_sym^.decl <> nil then
        emit_let_binding_name(out, n.resolved_sym^.name,
            n.resolved_sym^.name_len,
            n.resolved_sym^.decl)
    elsif n.resolved_sym <> nil and n.resolved_sym^.kind == SYM_KIND_PARAM and
            codegen_param_needs_pointee_load(n.resolved_sym^.decl) then
        // VAR/REF formal is T* in C; surface name is the pointee.
        dynbuf_append(out, "(*")
        dynbuf_appendn(out, n.token.start, n.token.length)
        dynbuf_append_char(out, ')')
    elsif n.token.length > 0 and n.token.start <> nil then
        dynbuf_appendn(out, n.token.start, n.token.length)
    end
end emit_let_ident


(**
 * Emit a TYPE declaration.
 * Simple types for now.
 *)
export procedure codegen_common_type_decl(n: const ^Node, ctx: CodegenContext)
begin
    if n == nil then
        return
    end

    emit_indent(ctx.out, ctx.indent)

    // type Name FORWARD -- incomplete tag+typedef so the name exists for ^Name
    // and for a later complete struct. Method types that take Name by value
    // must still be emitted after the complete definition (see codegen_c).
    if n.type_decl.is_forward then
        if n.type_decl.name == nil or n.type_decl.name_len == 0 then
            dynbuf_append(ctx.out, "/* type FORWARD (unnamed) */\n")
            return
        end
        dynbuf_append(ctx.out, "typedef struct ")
        dynbuf_appendn(ctx.out, n.type_decl.name, n.type_decl.name_len)
        dynbuf_append_char(ctx.out, ' ')
        dynbuf_appendn(ctx.out, n.type_decl.name, n.type_decl.name_len)
        dynbuf_append(ctx.out, ";\n")
        return
    end

    // extern type Name = struct [tag] -- alias for the C tag; layout from #include
    if n.type_decl.is_extern and n.type_decl.is_extern_struct then
        var tag: const ^char
        var tag_len: size_t

        if n.type_decl.name == nil or n.type_decl.name_len == 0 then
            dynbuf_append(ctx.out, "/* extern type struct (unnamed) */\n")
            return
        end
        if n.type_decl.c_tag_name <> nil and n.type_decl.c_tag_name_len > 0 then
            tag := n.type_decl.c_tag_name
            tag_len := n.type_decl.c_tag_name_len
        else
            tag := n.type_decl.name
            tag_len := n.type_decl.name_len
        end
        dynbuf_append(ctx.out, "typedef struct ")
        dynbuf_appendn(ctx.out, tag, tag_len)
        dynbuf_append_char(ctx.out, ' ')
        dynbuf_appendn(ctx.out, n.type_decl.name, n.type_decl.name_len)
        dynbuf_append(ctx.out, ";\n")
        return
    end

    // Opaque EXTERN TYPE: C definition comes from #include, not typedef here.
    if n.type_decl.is_extern and n.type_decl.defined_type == nil then
        dynbuf_append(ctx.out, "/* extern type ")
        dynbuf_appendn(ctx.out, n.type_decl.name, n.type_decl.name_len)
        dynbuf_append(ctx.out, " (foreign) */\n")
        return
    end

    if n.type_decl.name == nil or n.type_decl.name_len == 0 then
        dynbuf_append(ctx.out, "/* TODO: codegen_common_type_decl: Invalid TYPE node */\n")
        return
    end

    dynbuf_append(ctx.out, "typedef ")

    // Check if this TYPE is defining a STRUCT or UNION
    if n.type_decl.struct_body <> nil then
        // Emit the struct inline
        if n.type_decl.struct_body^.struct_decl.is_union then
            codegen_common_union_decl(n.type_decl.struct_body, ctx)
        else
            codegen_common_struct_decl(n.type_decl.struct_body, ctx)
        end

    // ENUM types
    elsif n.type_decl.enum_type <> nil then
        codegen_common_enum_type(n.type_decl.enum_type,
            n.type_decl.name, n.type_decl.name_len, ctx)

    // Method types
    elsif n.type_decl.method_type <> nil then
        codegen_common_method_type(n.type_decl.method_type, n, ctx)

    // Regular type (alias, pointer, array, etc.)
    elsif n.type_decl.defined_type <> nil then
        var dt: const ^TType = n.type_decl.defined_type

        if dt.is_opaque then
            // v1: both opaque and ^opaque => void * alias
            dynbuf_append(ctx.out, "void *")
            dynbuf_appendn(ctx.out, n.type_decl.name, n.type_decl.name_len)
        elsif n.type_decl.defined_type^.is_array and n.type_decl.defined_type^.element_type <> nil then
            emit_type_specifier(ctx.out, 
                n.type_decl.defined_type,
                n.type_decl.name,
                n.type_decl.name_len,
                false, false, false, false)
        else
            // Normal type or pointer
            emit_type_specifier(ctx.out, n.type_decl.defined_type, n.type_decl.name, n.type_decl.name_len,
                false, false, false, false)
        end
    else
        emit_type_specifier(ctx.out, n.type_decl.defined_type, n.type_decl.name, n.type_decl.name_len,
            false, false, false, false)
    end

    dynbuf_append(ctx.out, ";\n")

    return
end codegen_common_type_decl


(**
 * Emit Declaration portion of PROCEDURE or FUNCTION.
 * To be called by codegen_c or codegen_header.
 *)
export procedure codegen_common_proc_or_func(n: const ^Node, ctx: CodegenContext)
begin
    if n == nil then
        return
    end

    if n.kind <> NODE_PROC_DECL and n.kind <> NODE_FUNC_DECL then
        dynbuf_append(ctx.out, "/* TODO: codegen_common_proc_or_func: unexpected node */\n")
        return
    end

    emit_indent(ctx.out, ctx.indent)

    if n.proc_decl.is_extern then
        dynbuf_append(ctx.out, "extern ")
    elsif not n.proc_decl.is_exported then
        dynbuf_append(ctx.out, "static ")
    end

    // Return type
    if n.kind == NODE_FUNC_DECL and n.proc_decl.return_type <> nil then
        emit_return_type(ctx.out, n.proc_decl.return_type)
        dynbuf_append_char(ctx.out, ' ')
    else
        dynbuf_append(ctx.out, "void ")
    end

    // Function name
    if n.proc_decl.method_owner <> nil and n.proc_decl.method_owner_len > 0 then
        dynbuf_appendn(ctx.out, n.proc_decl.method_owner, n.proc_decl.method_owner_len)
        dynbuf_append(ctx.out, "__")
        dynbuf_appendn(ctx.out, n.proc_decl.name, n.proc_decl.name_len)
    else
        dynbuf_appendn(ctx.out, n.proc_decl.name, n.proc_decl.name_len)
    end

    // Parameter list
    if n.proc_decl.params <> nil then
        emit_param_list(ctx.out, n.proc_decl.params^.param_list.params, 
            n.proc_decl.params^.param_list.count, 
            true,
            n.proc_decl.params^.param_list.has_ellipsis)
    else
        emit_param_list(ctx.out, nil, 0, false, false)
    end
end codegen_common_proc_or_func


(**
 * Emit STRUCT declaration.
 * Maps to a C typedef struct with named fields.
 *)
export procedure codegen_common_struct_decl(n: const ^Node, ctx: CodegenContext)
begin
    var i: size_t = 0

    if n == nil or n.kind <> NODE_STRUCT_DECL or n.struct_decl.is_union then
        dynbuf_append(ctx.out, "/* TODO: codegen_common_struct_decl: invalid STRUCT node */\n")
        return
    end

    // First forward declare the struct so self-referential pointers will work.
    dynbuf_append(ctx.out, "struct ")
    if n.struct_decl.is_packed then
        dynbuf_append(ctx.out, "__attribute__((packed)) ")
    end

    dynbuf_appendn(ctx.out, n.struct_decl.name, n.struct_decl.name_len)
    dynbuf_append_char(ctx.out, ' ')
    dynbuf_appendn(ctx.out, n.struct_decl.name, n.struct_decl.name_len)
    dynbuf_append(ctx.out, ";\n")

    // Now emit the regular definition.
    emit_indent(ctx.out, ctx.indent)
    dynbuf_append(ctx.out, "typedef struct ")
    if n.struct_decl.is_packed then
        dynbuf_append(ctx.out, "__attribute__((packed)) ")
    end
    dynbuf_appendn(ctx.out, n.struct_decl.name, n.struct_decl.name_len)
    dynbuf_append(ctx.out, " {\n")

    // EXTENDS support for STRUCT: embed base struct as first member (C composition)
    if n.struct_decl.extends_type <> nil then
        emit_indent(ctx.out, ctx.indent + 1)
        dynbuf_append(ctx.out, "struct ")
        if n.struct_decl.extends_type^.name <> nil and
                n.struct_decl.extends_type^.name_len > 0 then
            dynbuf_appendn(ctx.out, n.struct_decl.extends_type^.name,
                n.struct_decl.extends_type^.name_len)
        else
            dynbuf_append(ctx.out, "Base")          // fallback
        end
        dynbuf_append(ctx.out, " base;\n")
    end

    // Emit fields
    for i := 0 to n.struct_decl.field_count-1 do
        var f: ^Node = n.struct_decl.fields[i]
        if f == nil then
            continue
        end

        emit_indent(ctx.out, ctx.indent + 1)

        // Field type
        if f.field_decl.field_type <> nil then
            emit_type_specifier(ctx.out, f.field_decl.field_type, 
                f.field_decl.name, f.field_decl.name_len,
                false, false, false, false)
        else
            dynbuf_append(ctx.out, "int ")      // safe fallback
        end

        // Optional initialzer (rare in struct fields)
        if f.field_decl.initializer <> nil then
            dynbuf_append(ctx.out, " = ")
            codegen_common_expr(f.field_decl.initializer, ctx)
        end

        dynbuf_append(ctx.out, ";\n")
    end

    emit_indent(ctx.out, ctx.indent)
    dynbuf_append(ctx.out, "} ")
    dynbuf_appendn(ctx.out, n.struct_decl.name, n.struct_decl.name_len)
end codegen_common_struct_decl


(**
 * Emit UNION declaration. (Uses NODE_STRUCT_DECL)
 * Maps to a C typedef union with named field.s
 *)
export procedure codegen_common_union_decl(n: const ^Node, ctx: CodegenContext)
begin
    var i: size_t = 0

    if n == nil or n.kind <> NODE_STRUCT_DECL or not n.struct_decl.is_union then
        dynbuf_append(ctx.out, "/* TODO: codegen_common_union_decl: invalid UNION node */\n")
        return
    end

    // First forward declare the union so self-referential pointers will work.
    dynbuf_append(ctx.out, "union ")
    dynbuf_appendn(ctx.out, n.struct_decl.name, n.struct_decl.name_len)
    dynbuf_append_char(ctx.out, ' ')
    dynbuf_appendn(ctx.out, n.struct_decl.name, n.struct_decl.name_len)
    dynbuf_append(ctx.out, ";\n")

    // Now emit the regular definition.
    emit_indent(ctx.out, ctx.indent)
    dynbuf_append(ctx.out, "typedef union ")
    dynbuf_appendn(ctx.out, n.struct_decl.name, n.struct_decl.name_len)
    dynbuf_append(ctx.out, " {\n")

    // Emit fields
    for i := 0 to n.struct_decl.field_count -1 do
        var f: const ^Node = n.struct_decl.fields[i]
        if f == nil then
            continue
        end

        emit_indent(ctx.out, ctx.indent + 1)

        // Field type
        if f.field_decl.field_type <> nil then
            emit_type_specifier(ctx.out, f.field_decl.field_type, 
                f.field_decl.name, f.field_decl.name_len,
                false, false, false, false)
        else
            dynbuf_append(ctx.out, "int ")          // safe fallback
        end

        // Optional initializer (rare in struct fields)
        if f.field_decl.initializer <> nil then
            dynbuf_append(ctx.out, " = ")
            codegen_common_expr(f.field_decl.initializer, ctx)
        end

        dynbuf_append(ctx.out, ";\n")
    end

    emit_indent(ctx.out, ctx.indent)
    dynbuf_append(ctx.out, "} ")
    dynbuf_appendn(ctx.out, n.struct_decl.name, n.struct_decl.name_len)
end codegen_common_union_decl


(**
 * Emit ENUM type body for TYPE T = ENUM ... END.
 * Emits: enum { M = n, ... } TypeName
 * (Caller adds 'typedf' and trailing ';')
 *)
export procedure codegen_common_enum_type(en: const ^Node, type_name: const ^char,
        type_name_len: size_t, ctx: CodegenContext)
begin
    var i: size_t

    if en == nil or en.kind <> NODE_ENUM_TYPE or type_name == nil or type_name_len == 0 then
        dynbuf_append(ctx.out, "/* TODO: codegen_common_enum_type: invalid ENUM node */\n")
    end

    emit_indent(ctx.out, ctx.indent)
    dynbuf_append(ctx.out, "enum {\n")

    for i := 0 to en.enum_type.count-1 do
        var item: const ^Node = en.enum_type.elements[i]

        if item == nil or item.kind <> NODE_ENUM_ITEM then
            continue
        end

        emit_indent(ctx.out, ctx.indent + 1)
        dynbuf_appendn(ctx.out, item.enum_item.name, item.enum_item.name_len)
        if item.enum_item.value_known then
            dynbuf_append(ctx.out, " = ")
            // small int - snprintf avoids int-string helper
            begin
                var num: array[32] of char

                snprintf(num, sizeof(num), "%d", item.enum_item.int_value)
                dynbuf_append(ctx.out, num)
            end
        end
        if i + 1 < en.enum_type.count then
            dynbuf_append(ctx.out, ",")
        end
        dynbuf_append_char(ctx.out, '\n')
    end

    emit_indent(ctx.out,ctx.indent)
    dynbuf_append(ctx.out, "} ")
    dynbuf_appendn(ctx.out, type_name, type_name_len)
end codegen_common_enum_type


(**
 * Generate method type.
 *)
export procedure codegen_common_method_type(method: const ^Node, type_decl: const ^Node, ctx: CodegenContext)
begin
    if method == nil or method.kind <> NODE_METHOD_TYPE then
        dynbuf_append(ctx.out, "/* TODO: codegen_common_method_type: invalid METHOD_TYPE node */")
        return
    end

    // Emit return type
    if method.method_type.return_type <> nil then
        emit_return_type(ctx.out, method.method_type.return_type)
    else
        dynbuf_append(ctx.out, "void ")
    end

    // Emit " (*Name)"
    dynbuf_append(ctx.out, " (*")
    dynbuf_appendn(ctx.out, type_decl.type_decl.name, type_decl.type_decl.name_len)
    dynbuf_append(ctx.out, ")")

    // Emit parameter list using the existing helper (include names)
    if method.method_type.params <> nil and
            method.method_type.params^.kind == NODE_PARAM_LIST then
        var plist: ^Node = method.method_type.params
        emit_param_list(ctx.out,
            plist.param_list.params,
            plist.param_list.count,
            true,
            plist.param_list.has_ellipsis)
    else
        dynbuf_append(ctx.out, "(void)")
    end
end codegen_common_method_type


(**
 * Emit expression
 *)
export recursive procedure codegen_common_expr(n: const ^Node, ctx: CodegenContext)
begin
    var up, ui, i: size_t

    if n == nil then
        dynbuf_append(ctx.out, "NULL")
        return
    end

    up := n.upcast_depth
    if up > 0 then
        if n.upcast_ptr then
            dynbuf_append(ctx.out, "&((*(")
        else
            dynbuf_append(ctx.out, "((")
        end
    end

    switch n.kind of
        case NODE_IDENT:
            emit_let_ident(ctx.out, n)

        case NODE_LITERAL:
            codegen_common_emit_literal(n, ctx)

        case NODE_ARRAY_INDEX:
            if n.array_index.auto_deref then
                dynbuf_append(ctx.out, "(*")
            end
            codegen_common_expr(n.array_index.array_, ctx)
            if n.array_index.auto_deref then
                dynbuf_append_char(ctx.out, ')')
            end
            dynbuf_append_char(ctx.out, '[')
            codegen_common_expr(n.array_index.index, ctx)
            dynbuf_append_char(ctx.out, ']')

        case NODE_FIELD_ACCESS:
            codegen_common_field_access(n, ctx)

        case NODE_CALL:
            // Field / value call-through: emit designator, then (args). No receiver prepend
            if n.call.callee_expr <> nil then
                dynbuf_append_char(ctx.out, '(')
                codegen_common_expr(n.call.callee_expr, ctx)
                dynbuf_append_char(ctx.out, ')')
            elsif n.resolved_sym <> nil then
                dynbuf_appendn(ctx.out, n.resolved_sym^.name, n.resolved_sym^.name_len)
            elsif n.call.method_owner <> nil and n.call.method_owner_len > 0 then
                dynbuf_appendn(ctx.out, n.call.method_owner, n.call.method_owner_len)
                dynbuf_append(ctx.out, "__")
                dynbuf_appendn(ctx.out, n.call.name, n.call.name_len)
            else
                dynbuf_appendn(ctx.out, n.call.name, n.call.name_len)
            end
            dynbuf_append(ctx.out, "(")

            // Instance sugar only when not a field call-through
            if n.call.callee_expr == nil and n.call.receiver_expr <> nil then
                codegen_emit_call_arg_deref(codegen_call_formal_receiver(n),
                    n.call.receiver_expr, n.call.auto_deref,
                    n.call.base_depth, ctx)
            end
            for i := 0 to n.call.argc-1 do
                if i > 0 or (n.call.callee_expr == nil and n.call.receiver_expr <> nil) then
                    dynbuf_append(ctx.out, ", ")
                end
                codegen_emit_call_arg_deref(codegen_call_formal_for_arg(n, i),
                    n.call.args[i],
                    (i == 0 and n.call.receiver_expr == nil and
                        n.call.callee_expr == nil and n.call.auto_deref),
                    (i == 0 and n.call.receiver_expr == nil and
                        n.call.callee_expr == nil) ? n.call.base_depth : 0,
                    ctx)
            end

            dynbuf_append(ctx.out, ")")

        case NODE_ASSIGN:
            var op_str: const ^char
            var op: TokenKind

            codegen_common_expr(n.binary.left, ctx)
            dynbuf_append_char(ctx.out, ' ')

            // Support compound assignment
            op := n.binary.op
            if op == TOK_COLON_EQ then
                op_str := "="
            elsif op == TOK_ADD_EQ then
                op_str := "+="
            elsif op == TOK_SUB_EQ then
                op_str := "-="
            elsif op == TOK_MUL_EQ then
                op_str := "*="
            elsif op == TOK_DIV_EQ then
                op_str := "/="
            elsif op == TOK_MOD_EQ then
                op_str := "%="
            elsif op == TOK_AND_EQ then
                op_str := "&="
            elsif op == TOK_OR_EQ then
                op_str := "|="
            elsif op == TOK_BITWISE_NOT_EQ then
                op_str := "^="          // ~ becomes ^ in C for bitwise not.
            elsif op == TOK_LSHIFT_EQ then
                op_str := "<<=" 
            elsif op == TOK_RSHIFT_EQ then
                op_str := ">>="
            end
            dynbuf_append(ctx.out, op_str)
            dynbuf_append_char(ctx.out, ' ')
            codegen_common_expr(n.binary.right, ctx)

        case NODE_BINARY:
            if n.binary.op == TOK_KEYWORD_DIV then
                // Special handling for DIV: cast both sides to long (integer division)
                dynbuf_append(ctx.out, "(long)(")
                codegen_common_expr(n.binary.left, ctx)
                dynbuf_append(ctx.out, ") / (long)(")
                codegen_common_expr(n.binary.right, ctx)
                dynbuf_append(ctx.out, ")")
            elsif n.binary.op == TOK_POWER then
                dynbuf_append(ctx.out, "pow((")
                codegen_common_expr(n.binary.left, ctx)
                dynbuf_append(ctx.out, "),(")
                codegen_common_expr(n.binary.right, ctx)
                dynbuf_append(ctx.out, "))")
            else
                codegen_common_expr(n.binary.left, ctx)
                dynbuf_append_char(ctx.out, ' ')
                if n.binary.op == TOK_KEYWORD_AND then
                    dynbuf_append(ctx.out, "&&")
                elsif n.binary.op == TOK_KEYWORD_OR then
                    dynbuf_append(ctx.out, "||")
                elsif n.binary.op == TOK_KEYWORD_MOD then
                    dynbuf_append(ctx.out, "%")
                elsif n.binary.op == TOK_KEYWORD_XOR then
                    dynbuf_append(ctx.out, "^")
                else
                    dynbuf_append(ctx.out, TokenKind::string(n.binary.op))
                end
                dynbuf_append_char(ctx.out, ' ')
                codegen_common_expr(n.binary.right, ctx)
            end

        case NODE_TERNARY:
            dynbuf_append_char(ctx.out, '(')
            codegen_common_expr(n.ternary.cond, ctx)
            dynbuf_append(ctx.out, " ? ")
            codegen_common_expr(n.ternary.then_expr, ctx)
            dynbuf_append(ctx.out, " : ")
            codegen_common_expr(n.ternary.else_expr, ctx)
            dynbuf_append_char(ctx.out, ')')

        case NODE_CAST:
            if n.upcast_depth > 0 then
                // EXTENDS: g as Parent => (g).base, not (Parent)g
                codegen_common_expr(n.cast_expr.expr, ctx)
            else
                dynbuf_append_char(ctx.out, '(')
                emit_type_specifier(ctx.out, n.cast_expr.target_type, nil, 0, false, false, false, false)
                dynbuf_append(ctx.out, ")")
                codegen_common_expr(n.cast_expr.expr, ctx)
            end

        case NODE_UNARY:
            if n.unary.op == TOK_AT then
                dynbuf_append_char(ctx.out, '&')
            elsif n.unary.op == TOK_CARET then
                // Parenthesize so p^[i] is (*p)[i], not *p[i] ([] binds tighter).
                dynbuf_append(ctx.out, "(*")
                codegen_common_expr(n.unary.operand, ctx)
                dynbuf_append_char(ctx.out, ')')
                break
            elsif n.unary.op == TOK_KEYWORD_NOT then
                dynbuf_append(ctx.out, "!")
            else
                dynbuf_append(ctx.out, TokenKind::string(n.unary.op))
            end
            codegen_common_expr(n.unary.operand, ctx)

        case NODE_PAREN:
            dynbuf_append_char(ctx.out, '(')
            codegen_common_expr(n.paren.expr, ctx)
            dynbuf_append_char(ctx.out, ')')

        case NODE_ARRAY_LITERAL:
            codegen_common_array_literal(n, ctx)

        case NODE_SIZEOF:
            codegen_common_sizeof_expr(n, ctx)

        case NODE_COUNTOF:
            codegen_common_countof_expr(n, ctx)

        case NODE_INC, NODE_DEC:
            codegen_common_inc_dec(n, ctx, false)       // expression context

        case NODE_PREPROCESSOR:
            codegen_common_preprocessor(n, ctx)

        case NODE_DOC_COMMENT:
            // i DON'T THINK THEY SHOULD BE APPEARING IN THE MIDDLE OF EXPRESSIONS?
            ;

        // Supress unhandled case warnings.
        case NODE_SWITCH, NODE_DEBUG, NODE_PROGRAM, NODE_PROC_DECL, NODE_FUNC_DECL, NODE_VAR_DECL,
                NODE_CONST_DECL, NODE_LET_DECL, NODE_VAR_ITEM, NODE_CONST_ITEM, NODE_LET_ITEM, NODE_TYPE_DECL,
                NODE_PARAM, NODE_PARAM_LIST, NODE_IMPORT, NODE_IMPORT_ITEM, NODE_STRUCT_DECL, NODE_FIELD_DECL,
                NODE_METHOD_TYPE, NODE_ARRAY_TYPE, NODE_BLOCK, NODE_IF, NODE_ELSIF, NODE_ELSE, NODE_FOR,
                NODE_WHILE, NODE_REPEAT_UNTIL, NODE_LOOP, NODE_BREAK, NODE_CONTINUE, NODE_RETURN, NODE_EXPR_STMT,
                NODE_ASSERT, NODE_DEFER, NODE_DEFINE:
            // TODO: expand as we add more expression kinds
            dynbuf_append(ctx.out, "/* TODO: codegen_common_expr: expr kind ")
            dynbuf_append(ctx.out, TokenKind::string(n.token.kind as TokenKind))
            dynbuf_append(ctx.out, " */")

        else:
            // TODO: expand as we add more expression kinds
            dynbuf_append(ctx.out, "/* TODO: codegen_common_expr: expr kind ")
            dynbuf_append(ctx.out, TokenKind::string(n.token.kind as TokenKind))
            dynbuf_append(ctx.out, " */")
    end

    if up > 0 then
        if n.upcast_ptr then
            dynbuf_append(ctx.out, "))")
        else
            dynbuf_append_char(ctx.out, ')')
        end
        for ui := 0 to up-1 do
            dynbuf_append(ctx.out, ".base")
        end
        dynbuf_append_char(ctx.out, ')')
    end
end codegen_common_expr


(**
 * Emit a literal value as C11-compatible source text.
 *  -   Decimal, hex (0x), octal (converted from 0o to 0), binary
 *      converted from 0b to octal or decimal.
 *  -   Strips all '_' separators.
 *  -   Preserves original token text for strings and chars.
 *)
export procedure codegen_common_emit_literal(n: const ^Node, ctx: CodegenContext)
begin
    if n == nil then
        dynbuf_append(ctx.out, "0")
        return
    end

    if n.token.kind <> TOK_NUMBER then
        // String char, etc. - emit as-is
        dynbuf_appendn(ctx.out, n.token.start, n.token.length)
        return
    end

    // === Handle integer literal with possible base prefix and _ separators ===
    begin
        var s: const ^char = n.token.start
        var len: size_t = n.token.length
        var i: size_t

        if len >= 2 and s[0] == '0' then
            var prefix: char = s[1]

            if prefix == 'x' or prefix == 'X' then
                // Hex is already C11 compatible
                for i := 0 to len-1 do
                    if s[i] <> '_' then
                        dynbuf_append_char(ctx.out, s[i])
                    end
                end
                return
            elsif prefix == 'o' or prefix == 'O' then
                // Convert 0o77 -> 077 (C11 octal)
                dynbuf_append_char(ctx.out, '0')
                for i := 2 to len-1 do
                    if s[i] <> '_' then
                        dynbuf_append_char(ctx.out, s[i])
                    end
                end
                return
            elsif prefix == 'b' or prefix == 'B' then
                // Convert 0b1010 --> decimal (safest for C11)
                var value: long_long = utils_parse_integer_literal(s, len)
                var buf: array[32] of char
                snprintf(buf, sizeof(buf), "%lld", value)
                dynbuf_append(ctx.out, buf)
                return
            end
        end

        // Default: decimal with possible _ separators
        for i := 0 to len - 1 do
            if s[i] <> '_' then
                dynbuf_append_char(ctx.out, s[i])
            end
        end
    end
end codegen_common_emit_literal


(** 
 * Emit array literal: { expr, expr, ... }
 * Special fast path for the extremly common {0} zero-initializer.
 *)
export procedure codegen_common_array_literal(n: const ^Node, ctx: CodegenContext)
begin
    var i: size_t

    if n == nil or n.kind <> NODE_ARRAY_LITERAL then
        dynbuf_append(ctx.out, "{0}")
        return
    end

    if n.array_literal.count == 1 then
        var elem: const ^Node = n.array_literal.elements[0]

        if elem <> nil and elem.kind == NODE_LITERAL and
                elem.token.length == 1 and elem.token.start[0] == '0' then
            dynbuf_append(ctx.out, "{0}")
            return
        end
    end

    dynbuf_append(ctx.out, "{")
    for i := 0 to n.array_literal.count -1 do
        if i > 0 then
            dynbuf_append(ctx.out, ", ")
        end
        codegen_common_expr(n.array_literal.elements[i], ctx)
    end
    dynbuf_append(ctx.out, "}")
end codegen_common_array_literal


(**
 * Preprocessor directives.
 *)
export procedure codegen_common_preprocessor(n: const ^Node, ctx: CodegenContext)
begin
    if n == nil or n.kind <> NODE_PREPROCESSOR then
        return
    end

    dynbuf_appendn(ctx.out, n.preprocessor.text, n.preprocessor.length)
    dynbuf_append_char(ctx.out, '\n')
end codegen_common_preprocessor


(**
 * Emit define
 *)
export procedure codegen_common_define(n: const ^Node, ctx: CodegenContext)
begin
    if n == nil or n.kind <> NODE_DEFINE then
        return
    end

    dynbuf_append(ctx.out, "#define ")
    dynbuf_appendn(ctx.out, n.define_stmt.text, n.define_stmt.length)
    dynbuf_append_char(ctx.out, '\n')
end codegen_common_define


(**
 * Emit field access: record.field
 *)
export procedure codegen_common_field_access(n: const ^Node, ctx: CodegenContext)
begin
    if n == nil then
        return
    end
    if n.field_access.auto_deref then
        dynbuf_append(ctx.out, "(*")
    end
    dynbuf_append_char(ctx.out, '(')
    codegen_common_expr(n.field_access.record_, ctx)
    dynbuf_append_char(ctx.out, ')')
    if n.field_access.auto_deref then
        dynbuf_append_char(ctx.out, ')')
    end
    begin
        var d: size_t = n.field_access.base_depth
        var i: size_t

        for i := 0 to d-1 do
            dynbuf_append(ctx.out, ".base")
        end

        // If record_ lowered as (*p), we need (*p).field not (*p)->field.
        // emit_let_ident already wraps (*p), so '.'' is correct.
        // Only use '->' if we emit base p without (*). Prefer (*p).x always.
        dynbuf_append_char(ctx.out, '.')
        dynbuf_appendn(ctx.out, n.field_access.field_name, n.field_access.field_len)
    end
end codegen_common_field_access


(**
 * Emit COUNTOF. Semantic stores the outermost bound in count.
 * ((integer)N)
 *)
export procedure codegen_common_countof_expr(n: const ^Node, ctx: CodegenContext)
begin
    var buf: array[64] of char

    if n == nil or n.kind <> NODE_COUNTOF then
        dynbuf_append(ctx.out, "((intger)0)")
        return
    end
    if n.sizeof_expr.folded then
        snprintf(buf, sizeof(buf), "((integer)%d)", n.sizeof_expr.count)
        dynbuf_append(ctx.out, buf)
        return
    end
    if n.sizeof_expr.is_type or n.sizeof_expr.target.designator == nil then
        dynbuf_append(ctx.out, "((integer)0)")
        return
    end

    // Unfolded designator: C11 has no _Countof.
    begin
        var d: const ^Node

        d := n.sizeof_expr.target.designator
        dynbuf_append(ctx.out, "((integer)(sizeof(")
        codegen_common_expr(d, ctx)
        dynbuf_append(ctx.out, ") / sizeof((")
        codegen_common_expr(d, ctx)
        dynbuf_append(ctx.out, ")[0])))")
    end
end codegen_common_countof_expr


(**
 * Emit SIZEOF (type or designator)
 *)
export procedure codegen_common_sizeof_expr(n: const ^Node, ctx: CodegenContext)
begin
    if n == nil or n.kind <> NODE_SIZEOF then
        dynbuf_append(ctx.out, "((integer)sizeof(0))")      // safe fallback
        return
    end

    dynbuf_append(ctx.out, "((integer)sizeof(")

    if n.sizeof_expr.is_type and n.sizeof_expr.target.sizeof_type <> nil then
        emit_type_specifier(ctx.out, n.sizeof_expr.target.sizeof_type, nil, 0, false, false, false, false)
    elsif not n.sizeof_expr.is_type and n.sizeof_expr.target.designator <> nil then
        codegen_common_expr(n.sizeof_expr.target.designator, ctx)
    else
        dynbuf_append(ctx.out, "0")         // fallback
    end

    dynbuf_append(ctx.out, "))")
end codegen_common_sizeof_expr


(**
 * Emit INC / DEC statement (works for both statements and expressions)
 *
 * Statement context:   INC(x)      => x++
 *                      INC(x, 5)   => x += 5
 *
 * Expression context:  INC(x)      => x++
 *                      INC(x, 5)   => (x += 5)     <<-- parentheses added here
 *)
export procedure codegen_common_inc_dec(n: const ^Node, ctx: CodegenContext, as_statement: bool)
begin
    if n == nil then
        return
    end

    let is_compound: bool = (n.binary.right <> nil)

    if is_compound and not as_statement then
        dynbuf_append_char(ctx.out, '(')        // protect precedence
    end

    codegen_common_expr(n.binary.left, ctx)     // designator

    if is_compound then
        // compound for with step
        if n.kind == NODE_INC then
            dynbuf_append(ctx.out, " += ")
        else
            dynbuf_append(ctx.out, " -= ")
        end
        codegen_common_expr(n.binary.right, ctx)
    else
        // simple form
        if n.kind == NODE_INC then
            dynbuf_append(ctx.out, "++")
        else
            dynbuf_append(ctx.out, "--")
        end
    end

    if is_compound and not as_statement then
        dynbuf_append_char(ctx.out, ')')        // close protected parentheses
    end

    if as_statement then
        dynbuf_append(ctx.out, ";\n")
    end
end codegen_common_inc_dec


(**
 * Write out module prototype.
 *)
export procedure codegen_common_module_prototype(n: const ^Node, ctx: CodegenContext)
begin
    // Return type
    if n.program_decl.return_type <> nil then
        emit_return_type(ctx.out, n.program_decl.return_type)
        dynbuf_append_char(ctx.out, ' ')
    else
        dynbuf_append(ctx.out, "void ")
    end

    // module name
    dynbuf_appendn(ctx.out, n.program_decl.name, n.program_decl.name_len)

    // parameter list
    emit_param_list(ctx.out, n.program_decl.params, n.program_decl.param_count, true, false)
    dynbuf_append(ctx.out, ";\n\n")
end codegen_common_module_prototype


// const MAX_INCLUDE_PATH_LEN = 4096

(**
 * Emit a C #include from IMPORT ... FROM "path"
 * The string-literal token includes quotes.
 * .mh paths: emit the associated .h (same step/path); tmodc reads .mh at compile time only.
 *)
export procedure codegen_common_import(n: const ^Node, ctx: CodegenContext)
begin
    var from_path: const ^char
    var path_len: size_t
    var include_path: array[4096] of char

    if n == nil or n.kind <> NODE_IMPORT then
        return
    end

    from_path := n.import_stmt.from_path
    path_len := n.import_stmt.path_len
    if from_path == nil or path_len == 0 then
        return
    end

    dynbuf_append(ctx.out, "#include ")
    if mh_path_is_mh(from_path, path_len) then
        if not mh_format_h_include(from_path, path_len, include_path, sizeof(include_path)) then
            return
        end
        dynbuf_append_char(ctx.out, '"')
        dynbuf_append(ctx.out, include_path)
        dynbuf_append_char(ctx.out, '"')
    else
        dynbuf_appendn(ctx.out, from_path, path_len)
    end
    dynbuf_append_char(ctx.out, '\n')
end codegen_common_import


begin
end CodegenCommon
