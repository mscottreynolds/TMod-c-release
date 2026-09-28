module declaration()
(**
 * TMod-c
 * By M. Scott Reynolds
 * Date 30 July 2026
 *
 * Declaration parsing routines.
 *)


import arena_append_ptr, ppvoid 
    from arena
import NODE_CONST_ITEM, NODE_CONST_DECL, NODE_LET_ITEM, NODE_VAR_DECL, NODE_VAR_ITEM, 
    NODE_LET_DECL, NODE_TYPE_DECL, NODE_PARAM, NODE_PARAM_LIST, NODE_FUNC_DECL, NODE_PROC_DECL,
    NODE_STRUCT_DECL, NODE_FIELD_DECL, NODE_METHOD_TYPE, NODE_ENUM_TYPE, NODE_ENUM_ITEM,
    node_create, Node, NodeKind,
    from "node.h"
import TParser, advance, match, error_at, check, consume, isEOF, matchEOS, pParser, skip_empty_statements, 
    skip_layout_breaks,
    from parser_common

import TParser::parse_block, TParser::parse_const_expression, TParser::parse_expr, 
    TParser::parse_return_type, TParser::register_type_name, TParser::parse_type_expression,
    from parser_main
// import parse_block, parse_const_expression,
//     parse_expr, parse_return_type, parse_type_expression,
//     parser_register_type_name, skip_empty_statements, skip_layout_breaks, 
//     from "parser.h"
import size_t 
    from "stddef.h"
import snprintf 
    from "stdio.h"
import from "stdlib.h"
import from "string.h"
import TToken, TOK_IDENT, TOK_COLON, TOK_EQ, TOK_COMMA, TOK_KEYWORD_PACKED, TOK_KEYWORD_STRUCT,
    TOK_KEYWORD_UNION, TOK_KEYWORD_PROCEDURE, TOK_KEYWORD_FUNCTION, TOK_KEYWORD_ENUM, 
    TOK_KEYWORD_CONST, TOK_KEYWORD_VAR, TOK_KEYWORD_REF, TOK_LPAREN, TOK_RPAREN, TOK_EOF,
    TOK_COLON_COLON, TOK_KEYWORD_FORWARD, TOK_KEYWORD_BEGIN, TOK_KEYWORD_EXTENDS, TOK_KEYWORD_END,
    TOK_KEYWORD_TYPE, TOK_DOT_DOT_DOT,
    from Lexer
import type_create_named, pTType 
    from ttype

export type pNode = ^Node
// export type pParser = ^Parser

export function parse_item(p: pParser, node_kind: NodeKind): pNode
begin
    require p <> nil

    var item_token: TToken = p^.current
    var item_type: pTType = nil
    var initializer: pNode = nil
    var item: pNode = nil

    if item_token.kind <> TOK_IDENT then
        error_at(p, "parse_item: expected identifier", true)
    end

    let name_start: string = item_token.start
    let name_len: size_t = item_token.length

    advance(p)

    if match(p, TOK_COLON) then
        item_type := TParser::parse_return_type(p^)
    end

    if match(p, TOK_EQ) then
        initializer := TParser::parse_expr(p^)
        if initializer == nil then
            error_at(p, "parse_item: expected initializer or expression after '='", true)
            return nil
        end
    elsif node_kind == NODE_CONST_ITEM then
        error_at(p, "parse_item: expected '=' initializer for CONST items", true)
        return nil
    elsif node_kind == NODE_LET_ITEM THEN
        error_at(p, "parse_item: expected '=' initializer for LET Items", true)
        return nil
    end

    item := node_create(p^.arena, node_kind, item_token)
    item^.var_item.name         := name_start
    item^.var_item.name_len     := name_len
    item^.var_item.item_type    := item_type
    item^.var_item.initializer  := initializer

    return item

    ensure item <> nil
end parse_item


(**
 * Apply grouped trailing type propagation for a comma list of items
 * under a single VAR / CONST / LET.
 *
 * This is a semantic rule (not a grammar rule) described in docs:
 *  - The rightmost explicit type propagates leftward to proceeding bare names.
 *  - An item with "=" but no ":" type is left with TYPE==NULL (for inference)
 *  - and does not block or reset propagation for names to its left.
 *  - A bare name (no ":" and no "=") with no pending type to its right is an error.
 *
 * Works for NODE_VAR_ITEM, NODE_CONST_ITEM, and NODE_LET_ITEM because they
 * alias the same struct layout in hte Node union, and parse_item always
 * writes the fields via the var_item member.
 *)
procedure apply_grouped_trailing_types(p: pParser, items: ^pNode, count: size_t, decl_kind: string)
begin
    var pending: pTType = nil
    var i: size_t

    for i := count downto 1 do
        var it: pNode = items[i-1]

        if it^.var_item.item_type <> nil then
            pending := it^.var_item.item_type
        elsif it^.var_item.initializer <> nil then
            // Has initializer but no explicit type => leave nil for inference
            // Do not update pending (a type to the right still applies to the 
            // earlier bare names).
        else
            // Bare name (no type,no initializer)
            if pending <> nil then
                it^.var_item.item_type := pending
            else
                var msg: char[128]
                snprintf(msg, sizeof(msg),
                    "parse_%s_decl: bare names without type or initializer in declaration list",
                    decl_kind ? decl_kind : "decl")
                error_at(p, msg, true)
            end
        end
    end
end apply_grouped_trailing_types


(**
 * Parse VAR declaration (multi-item grouped trailing type)
 *
 * Uses apply_grouped_trailing_types() for the right-to-left type propagation rule.
 * See docs/langauge_report for the full semantic description.
 *
 * @param p         Parser state
 * @param exported  Whether EXPORT was seen before VAR
 * @param is_extern If the VAR has external definition (cannot also be static)
 * @param is_static If the VAR has static definition (cannot also be external)
 * @return          Parsed VAR_DECL node (exists on fatal error)
 *)
export function parse_var_decl(p: pParser, exported: bool, is_extern: bool, is_static: bool): pNode
begin
    require p <> nil

    var var_token: TToken = p^.current
    var decl: pNode = nil

    advance(p)

    // Check extern vs. static
    if is_extern and is_static then
        error_at(p, "parse_var_decl: VARs cannot be both 'EXTERN' and 'STATIC'", true)
    elsif exported and is_static then
        error_at(p, "parse_var_decl: VARs cannot be both 'EXPORT' and 'STATIC'", true)
    end

    decl := node_create(p^.arena, NODE_VAR_DECL, var_token)
    decl^.var_decl.is_exported  := exported
    decl^.var_decl.is_extern    := is_extern
    decl^.var_decl.is_static    := is_static
    decl^.var_decl.items        := nil
    decl^.var_decl.count        := 0
    decl^.var_decl.capacity     := 0

    // Parse list of items
    repeat
        var item: pNode = nil

        skip_layout_breaks(p)
        item := parse_item(p, NODE_VAR_ITEM)

        if item == nil then
            error_at(p, "parse_var_decl: Expected variable name after VAR", true)
        end
        arena_append_ptr(p^.arena,
                        (@decl^.var_decl.items) as ppvoid,
                        @decl^.var_decl.count,
                        @decl^.var_decl.capacity,
                        item)
    until not match(p, TOK_COMMA)

    // Apply grouped trailing type propagation
    apply_grouped_trailing_types(p, decl^.var_decl.items, decl^.var_decl.count, "var")

    if not matchEOS(p) then
        error_at(p, "parse_var_decl: Expected end-of-statement after VAR declaration", true)
    end

    return decl

    ensure decl <> nil
end parse_var_decl


(**
 * Parse CONST declaration (multi-item grouped trailing type)
 *
 * Uses apply_grouped_trailing_types() for the right-to-left type propagation rule.
 * See docs/langauge_report.md for the full semantic description.
 *
 * @param p         Parser state
 * @param exported  Whether EXPORT was seen before CONST
 * @return          Parsed CONST_DECL node (exists on fatal error)
 *)
export function parse_const_decl(p: pParser, exported: bool): pNode 
begin
    require p <> nil

    var const_token: TToken = p^.current
    var decl: pNode = nil

    advance(p)

    decl := node_create(p^.arena, NODE_CONST_DECL, const_token)
    decl^.const_decl.is_exported    := exported
    decl^.const_decl.items          := nil
    decl^.const_decl.count          := 0
    decl^.const_decl.capacity       := 0

    // parse list of items
    repeat
        var item: pNode = nil

        skip_layout_breaks(p)
        item := parse_item(p, NODE_CONST_ITEM)
        if item == nil then
            error_at(p, "parse_const_decl: Expected variable name after CONST", true)
        end
        arena_append_ptr(p^.arena,
                        (@decl^.const_decl.items) as ppvoid,
                        @decl^.const_decl.count,
                        @decl^.const_decl.capacity,
                        item)
    until not match(p, TOK_COMMA)

    // Apply grouped trailing type propagation
    apply_grouped_trailing_types(p, decl^.const_decl.items, decl^.const_decl.count, "const")

    if not matchEOS(p) then
        error_at(p, "parse_const_decl: Expected end-of-statement after CONST declaration", true)
    end

    return decl

    ensure decl <> nil
end parse_const_decl


export function parse_let_decl(p: pParser, exported: bool): pNode
begin
    require p <> nil

    var let_token: TToken = p^.current
    var decl: pNode = nil

    advance(p)

    decl := node_create(p^.arena, NODE_LET_DECL, let_token)
    decl^.let_decl.is_exported  := exported
    decl^.let_decl.items        := nil
    decl^.let_decl.count        := 0
    decl^.let_decl.capacity     := 0

    // Parse list of items
    repeat
        var item: pNode = nil

        skip_layout_breaks(p)
        item := parse_item(p, NODE_LET_ITEM)
        if item == nil then
            error_at(p, "parse_let_decl: Expected variable namae after LET", true)
        end
        arena_append_ptr(p^.arena,
                        (@decl^.let_decl.items) as ppvoid,
                        @decl^.let_decl.count,
                        @decl^.let_decl.capacity,
                        item)
    until not match(p, TOK_COMMA)

    // Apply grouped trailing type propagation
    apply_grouped_trailing_types(p, decl^.let_decl.items, decl^.let_decl.count, "let")

    if not matchEOS(p) then
        error_at(p, "parse_let_decl: Expected end-of-statement after LET declaration", true)
    end

    return decl

    ensure decl <> nil
end parse_let_decl


(**
 * Parses TYPE declarations (multi-item support per grammar)
 *
 * Grammar (simplified for phase 1):
 *  type-def = "TYPE" time-item { "," type-item } end-of-statement
 *  type-item = identifier "=" type-expression
 *)
export function parse_type_decl(p: pParser, exported: bool): pNode
begin
    require p <> nil

    var type_token: TToken = p^.current
    var decl: pNode = nil

    advance(p)

    decl := node_create(p^.arena, NODE_TYPE_DECL, type_token)
    decl^.type_decl.is_exported := exported

    // At least one type-item, more separated by commas
    loop
        var name_start: string
        var name_len: size_t = 0

        skip_layout_breaks(p)
        if p^.current.kind <> TOK_IDENT then
            error_at(p, "parse_type_decl: expected identifier after TYPE", true)
        end

        name_start  := p^.current.start
        name_len    := p^.current.length
        TParser::register_type_name(p^, name_start, name_len)
        advance(p)

        // type-item = identifier "FORWARD" | identifier "=" type-expression
        if match(p, TOK_KEYWORD_FORWARD) then
            decl^.type_decl.is_forward      := true
            decl^.type_decl.is_extern       := false
            decl^.type_decl.defined_type    := nil
            decl^.type_decl.struct_body     := nil
            decl^.type_decl.method_type     := nil
            decl^.type_decl.enum_type       := nil
        else
            consume(p, TOK_EQ, "parse_type_decl: Expected '=' after type name in TYPE declaration")
            decl^.type_decl.is_forward := false

            let is_packed: bool = match(p, TOK_KEYWORD_PACKED)

            if check(p, TOK_KEYWORD_STRUCT) then
                var struct_node: pNode = parse_struct_type(p)
                struct_node^.struct_decl.name       := name_start
                struct_node^.struct_decl.name_len   := name_len
                struct_node^.struct_decl.is_packed  := is_packed
                decl^.type_decl.struct_body     := struct_node
                decl^.type_decl.defined_type    := nil
                decl^.type_decl.method_type     := nil
                decl^.type_decl.enum_type       := nil
            elsif check(p, TOK_KEYWORD_UNION) then
                var u: pNode = parse_union_type(p)
                u^.struct_decl.name             := name_start
                u^.struct_decl.name_len         := name_len
                u^.struct_decl.is_union         := true
                decl^.type_decl.struct_body     := u
                decl^.type_decl.defined_type    := nil
                decl^.type_decl.method_type     := nil
                decl^.type_decl.enum_type       := nil
            elsif check(p, TOK_KEYWORD_PROCEDURE) or check(p, TOK_KEYWORD_FUNCTION) then
                var mtype: pNode = parse_method_type(p)
                decl^.type_decl.method_type     := mtype
                decl^.type_decl.struct_body     := nil
                decl^.type_decl.defined_type    := nil
                decl^.type_decl.enum_type       := nil
            elsif check(p, TOK_KEYWORD_ENUM) then
                var enum_node: pNode = parse_enum_type(p)
                decl^.type_decl.enum_type       := enum_node
                decl^.type_decl.struct_body     := nil
                decl^.type_decl.method_type     := nil
                decl^.type_decl.defined_type    := nil
            else
                var defined_type: pTType = TParser::parse_type_expression(p^)
                decl^.type_decl.defined_type    := defined_type
                decl^.type_decl.struct_body     := nil
                decl^.type_decl.method_type     := nil
                decl^.type_decl.enum_type       := nil
            end
        end

        decl^.type_decl.name            := name_start
        decl^.type_decl.name_len        := name_len
        decl^.type_decl.initializer     := nil

        if not match(p, TOK_COMMA) then
            break
        end
    end

    // End of statement
    if not matchEOS(p) then
        error_at(p, "parse_type_decl: Expected end-of-statement after TYPE declaration", true)
    end

    return decl

    ensure decl <> nil    
end parse_type_decl


(**
 * Parse EXTERN TYPE declaration
 * Grammar: "EXTERN" [ "EXPORT" ] "TYPE" identifier [ "=" type-expression ] EOS
 * Caller has already consumed EXTERN and optional EXPORT.
 *)
export function parse_extern_type_decl(p: pParser, exported: bool): pNode
begin
    require p <> nil

    var type_token: TToken = p^.current
    var name_start: string
    var name_len: size_t
    var decl: pNode = nil
    

    consume(p, TOK_KEYWORD_TYPE, "parse_extern_type_decl: expected TYPE after EXTERN");

    if p^.current.kind <> TOK_IDENT then
        error_at(p, "parse_extern_type_decl: expected identifier after EXTERN TYPE", true)
    end

    name_start  := p^.current.start
    name_len    := p^.current.length

    TParser::register_type_name(p^, name_start, name_len)
    advance(p)

    decl := node_create(p^.arena, NODE_TYPE_DECL, type_token)
    decl^.type_decl.is_forward      := false
    decl^.type_decl.is_exported     := exported
    decl^.type_decl.is_extern       := true
    decl^.type_decl.name            := name_start
    decl^.type_decl.name_len        := name_len
    decl^.type_decl.struct_body     := nil
    decl^.type_decl.method_type     := nil
    decl^.type_decl.initializer     := nil
    decl^.type_decl.is_extern_struct := false
    decl^.type_decl.c_tag_name      := nil
    decl^.type_decl.c_tag_name_len  := 0

    if match(p, TOK_EQ) then
        if match(p, TOK_KEYWORD_STRUCT) then
            decl^.type_decl.is_extern_struct := true
            decl^.type_decl.defined_type := nil
            if p^.current.kind == TOK_IDENT then
                decl^.type_decl.c_tag_name := p^.current.start
                decl^.type_decl.c_tag_name_len := p^.current.length
                advance(p)
            end
        else
            decl^.type_decl.defined_type := TParser::parse_type_expression(p^)
        end
    else
        decl^.type_decl.defined_type := nil             // opaque foreign type
    end

    if not matchEOS(p) then
        error_at(p, "parse_extern_type_decl: expected end-of-statement after EXTERN TYPE", true)
    end

    return decl

    ensure decl <> nil
end parse_extern_type_decl


(**
 * Parse a single parameter: identifer : type
 * Returns a NODE_PARAM node
 *)
export function parse_param(p: pParser): pNode
begin
    require p <> nil

    var name_start: string
    var name_len: size_t
    var item_type: pTType = nil
    var param_node: pNode = nil

    // Support CONST, VAR, REF before identifer name.
    let is_const: bool  = match(p, TOK_KEYWORD_CONST)
    let is_var: bool    = match(p, TOK_KEYWORD_VAR)
    let is_ref: bool    = match(p, TOK_KEYWORD_REF)

    if is_var and (is_const or is_ref) then
        error_at(p, "parse_param: VAR cannot be combined with CONST or REF", true)
    end

    if p^.current.kind <> TOK_IDENT then
        error_at(p, "parse_param: expected parameter name (identifier)", true)
    end

    name_start  := p^.current.start
    name_len    := p^.current.length

    advance(p)

    consume(p, TOK_COLON, "parse_param: expected ':' after parameter name")

    // Base type
    item_type := TParser::parse_return_type(p^)

    param_node := node_create(p^.arena, NODE_PARAM, p^.current)
    param_node^.param.name          := name_start
    param_node^.param.name_len      := name_len
    param_node^.param.param_type    := item_type
    param_node^.param.is_ref        := is_ref
    param_node^.param.is_var        := is_var
    param_node^.param.is_const      := is_const

    return param_node

    ensure param_node <> nil
end parse_param


(**
 * Parse optional parameter list: ( param, {, param } )
 * Returns nil if no opening '(' is present, otherwise returns a NODE_PARAM_LIST node.
 * The list node owns the dynamic array of parameters (allocated in arena).
 *)
export function parse_param_list(p: pParser): pNode
begin
    require p <> nil

    var list: pNode = nil

    if not match(p, TOK_LPAREN) then
        return nil          // no parameter list
    end

    list := node_create(p^.arena, NODE_PARAM_LIST, p^.current)
    list^.param_list.params     := nil
    list^.param_list.count      := 0
    list^.param_list.capacity   := 0
    list^.param_list.has_ellipsis := false

    // Parse zero or more parameters
    while not check(p, TOK_RPAREN) and not check(p, TOK_EOF) do
        var param: pNode

        skip_layout_breaks(p)

        // C varargs: ... last, and at least one named formal.
        if check(p, TOK_DOT_DOT_DOT) then
            if list^.param_list.count == 0 then
                error_at(p, "parse_param_list: '...' requires at least one named formal", true)
            end
            if list^.param_list.has_ellipsis then
                error_at(p, "parse_param_list: '...' must be the last formal", true)
            end
            advance(p)
            list^.param_list.has_ellipsis := true
            if match(p, TOK_COMMA) then
                error_at(p, "parse_param_list: '...' must be the last formal", true)
            end
            break
        end

        param := parse_param(p)
        if param == nil then
            break
        end

        arena_append_ptr(p^.arena,
                        (@list^.param_list.params) as ppvoid,
                        @list^.param_list.count,
                        @list^.param_list.capacity,
                        param)

        if not match(p, TOK_COMMA) then
            break       // no more parameters
        end
    end

    if check(p, TOK_DOT_DOT_DOT) then
        error_at(p, "parse_param_list: expected ',' before '...'", true)
    end

    consume(p, TOK_RPAREN, "parse_param_list: expected ')' after parameter list")

    return list
end parse_param_list


(**
 * Parse PROCEDURE or FUNCTION declaration.
 * Grammar:
 *      method-prototype = [ "RECURSIVE" ] ( "PROCEDURE" | "FUNCTION" )
 *          qualified-method_name formal_parameters EOS ;
 *      qualified-method-name = type-identifier "::" identifier | identifier ;
 *
 * Instance methods pass self as the first formal parameter, e.g.
 *  function Counter::get(self: Counter): integer
 *
 * Returns NODE_PROC_DECL or NODE_FUNC_DECL.
 * Exits on fatal error.
 *)
export function parse_proc_or_func_decl(p: pParser, exported: bool, is_recursive: bool, is_extern: bool): pNode
begin
    require p <> nil

    var proc_token: TToken = p^.current
    let is_function: bool = (proc_token.kind == TOK_KEYWORD_FUNCTION)
    var is_forward: bool = false
    var n: pNode = nil

    advance(p)

    n := node_create(p^.arena, is_function ? NODE_FUNC_DECL : NODE_PROC_DECL, proc_token)

    n^.proc_decl.is_exported        := exported         // union struct
    n^.proc_decl.is_function        := is_function
    n^.proc_decl.is_recursive       := is_recursive
    n^.proc_decl.is_forward         := false
    n^.proc_decl.is_extern          := is_extern
    n^.proc_decl.method_owner       := nil
    n^.proc_decl.method_owner_len   := 0
    n^.proc_decl.params             := nil

    // qualified-method-name = type-identifier "::" identifier | identifier
    if p^.current.kind <> TOK_IDENT then
        error_at(p, "parse_proc_or_func_decl: expected procedure or function name", true)
    end

    begin
        var first: TToken = p^.current
        advance(p)

        if match(p, TOK_COLON_COLON) then
            if p^.current.kind <> TOK_IDENT then
                error_at(p, "parse_proc_or_func_decl: expected method name after '::'", true)
            end
            n^.proc_decl.method_owner       := first.start
            n^.proc_decl.method_owner_len   := first.length
            n^.proc_decl.name               := p^.current.start
            n^.proc_decl.name_len           := p^.current.length
            advance(p)
        else
            n^.proc_decl.name       := first.start
            n^.proc_decl.name_len   := first.length
        end
    end

    // Parameter list (required)
    n^.proc_decl.params := parse_param_list(p)

    // Return type for FUNCTION Only
    if is_function then
        if match(p, TOK_COLON) then
            n^.proc_decl.return_type := TParser::parse_return_type(p^)
        else
            error_at(p, "parse_proc_or_func_decl: FUNCTION must have return type: TType", true)
        end
    else
        // PROCEDURE implicity returns void
        n^.proc_decl.return_type := nil
    end

    // FORWARD defined procedure/function?
    is_forward := match(p, TOK_KEYWORD_FORWARD)
    n^.proc_decl.is_forward := is_forward

    skip_empty_statements(p)

    // EXTERN and FORWARD declaration do not have BEGIN ... END
    if is_extern or is_forward then
        (matchEOS(p))
        n^.proc_decl.body := nil
    elsif check(p, TOK_KEYWORD_BEGIN) then
        // BEGIN ... END block
        n^.proc_decl.body := TParser::parse_block(p^)
    else
        // potential prototype if no block
        n^.proc_decl.body := nil
    end

    return n

    ensure n <> nil
end parse_proc_or_func_decl


(**
 * Parse STRUCT type expression (RHS of TYPE declaration)
 * Grammar:
 *      struct-type = STRUCT [EXTENDS qualident]
 *          { field-decl EOS }
 *
 * Returns a NODE_STRUCT_DECL node (is_union = false).
 *)
export function parse_struct_type(p: pParser): pNode
begin
    require p <> nil

    var struct_token: TToken = p^.current
    var is_packed: bool = match(p, TOK_KEYWORD_PACKED)
    var name: string = nil
    var name_len: size_t = 0
    var extends_type: pTType = nil
    var s: pNode = nil

    consume(p, TOK_KEYWORD_STRUCT, "parse_struct_type: expected STRUCT ... = ")

    if match(p, TOK_KEYWORD_EXTENDS) then
        if p^.current.kind <> TOK_IDENT then
            error_at(p, "parse_struct_type: expected type idnetifer after EXTENDS", true)
        end
        extends_type := type_create_named(p^.arena, p^.current.start, p^.current.length)
        advance(p)
    end

    s := node_create(p^.arena, NODE_STRUCT_DECL, struct_token)
    s^.struct_decl.name             := name
    s^.struct_decl.name_len         := name_len
    s^.struct_decl.extends_type     := extends_type
    s^.struct_decl.is_packed        := is_packed
    s^.struct_decl.fields           := nil
    s^.struct_decl.field_count      := 0
    s^.struct_decl.field_capacity   := 0
    s^.struct_decl.is_exported      := false        // set by outer type
    s^.struct_decl.is_union         := false

    // Parse zero or more field-decl
    loop
        var fname: string
        var flen: size_t
        var ftype: pTType = nil
        var finit: pNode = nil
        var field: pNode = nil

        skip_empty_statements(p)

        if check(p, TOK_KEYWORD_END) or check(p, TOK_EOF) then
            break
        end

        if p^.current.kind <> TOK_IDENT then
            error_at(p, "parse_struct_type: expected field name (identifier) in struct", true)
        end

        fname := p^.current.start
        flen := p^.current.length

        advance(p)

        if match(p, TOK_COLON) then
            ftype := TParser::parse_return_type(p^)
        end

        if match(p, TOK_EQ) then
            finit := TParser::parse_const_expression(p^)
        end

        field := node_create(p^.arena, NODE_FIELD_DECL, p^.current)
        field^.field_decl.name          := fname
        field^.field_decl.name_len      := flen
        field^.field_decl.field_type    := ftype
        field^.field_decl.initializer   := finit

        arena_append_ptr(p^.arena,
                        (@s^.struct_decl.fields) as ppvoid,
                        @s^.struct_decl.field_count,
                        @s^.struct_decl.field_capacity,
                        field)

        // Fields are separated by end-of-statement
        (matchEOS(p))
    end

    consume(p, TOK_KEYWORD_END, "parse_struct_type: expected 'END' after struct fields")

    return s

    ensure s <> nil
end parse_struct_type


(**
 * Parse UNION type expression (RHS of TYPE declaration).
 * Grammar:
 *      union-type = UNION
 *          { field-decl EOS } 
 *
 * Returns a NODE_STRUCT_DECL node with .is_union set to true
 *)
export function parse_union_type(p: pParser): pNode
begin
    require p <> nil

    var union_token: TToken = p^.current
    var name: string
    var name_len: size_t
    var u: pNode = nil

    consume(p, TOK_KEYWORD_UNION, "parse_untion_type: expected UNION")

    u := node_create(p^.arena, NODE_STRUCT_DECL, union_token)
    u^.struct_decl.name             := name         // may be fileld by outer type later
    u^.struct_decl.name_len         := name_len
    u^.struct_decl.fields           := nil
    u^.struct_decl.field_count      := 0
    u^.struct_decl.field_capacity   := 0
    u^.struct_decl.is_exported      := false        // set by outer type
    u^.struct_decl.is_union         := true         // <== This is what makes it a union.

    // Parse zero or more field-decl
    loop
        var fname: string
        var flen: size_t
        var ftype: pTType = nil
        var finit: pNode = nil
        var field: pNode = nil

        skip_empty_statements(p)

        if check(p, TOK_KEYWORD_END) or check(p, TOK_EOF) then
            break
        end

        if p^.current.kind <> TOK_IDENT then
            error_at(p, "parse_union_type: expected field name (identifier) in UNION", true)
        end

        fname := p^.current.start
        flen := p^.current.length
        advance(p)

        if match(p, TOK_COLON) then
            ftype := TParser::parse_return_type(p^)
        end

        if match(p, TOK_EQ) then
            finit := TParser::parse_const_expression(p^)
        end

        field := node_create(p^.arena, NODE_FIELD_DECL, p^.current)
        field^.field_decl.name          := fname
        field^.field_decl.name_len      := flen
        field^.field_decl.field_type    := ftype
        field^.field_decl.initializer   := finit

        arena_append_ptr(   p^.arena,
                            (@u^.struct_decl.fields) as ppvoid,
                            @u^.struct_decl.field_count,
                            @u^.struct_decl.field_capacity,
                            field)

        matchEOS(p)
    end

    consume(p, TOK_KEYWORD_END, "parse_union_type: expected 'END' after union fields")

    return u

    ensure u <> nil
end parse_union_type


(**
 * Parse a method type (PROCEDURE or FUNCTION siangature unsed as a type).
 * Grammar:
 *      method-type = ( "PROCEDRE" | "FUNCTION" ) format_parameters
 *
 * This is used on the right-hand size of TYPE declarations, and can
 * also appear in parameter types and variable declarations.
 * 
 * Returns a NODE_METHOD_TYPE node.
 *)
export function parse_method_type(p: pParser): pNode
begin
    require p <> nil

    var type_token: TToken = p^.current         // PROCEDURE or FUNCTION
    var is_function: bool = (type_token.kind == TOK_KEYWORD_FUNCTION)
    var n: pNode = nil

    advance(p)

    n := node_create(p^.arena, NODE_METHOD_TYPE, type_token)
    n^.method_type.is_function  := is_function
    n^.method_type.params       := nil
    n^.method_type.return_type  := nil

    // Parse the parameter list (required)
    n^.method_type.params := parse_param_list(p)

    // Return type (only for FUNCTION)
    if is_function then
        if match(p, TOK_COLON) then
            n^.method_type.return_type := TParser::parse_return_type(p^)
        else
            error_at(p, "parse_method_type: FUNCTION type must have a return type after ':'", true)
        end
    end

    return n

    ensure n <> nil
end parse_method_type


(**
 * Parse one enum member: identifer [ "=" const-exprssion ]
 *)
function parse_enum_item(p: pParser): pNode
begin
    require p <> nil


    var item_tok: TToken
    var name: string
    var name_len: size_t
    var item: pNode = nil

    if p^.current.kind <> TOK_IDENT then
        return nil
    end

    item_tok := p^.current
    name := p^.current.start
    name_len := p^.current.length

    advance(p)

    item := node_create(p^.arena, NODE_ENUM_ITEM, item_tok)
    item^.enum_item.name        := name
    item^.enum_item.name_len    := name_len
    item^.enum_item.value       := nil

    if match(p, TOK_EQ) then
        item^.enum_item.value := TParser::parse_const_expression(p^)
    end

    return item
end parse_enum_item


(**
 * Parse ENUM type epxression (RHOS of TYPE declaration).
 * Grammar: 
 *      enum-type = "ENUM" [ EOS ] enum-decl { "," enum-decl } [","] [ EOS ] "END" ;
 *      enum-decl = identifier [ "=" const-expression ] ;
 *
 * Returns NODE_ENUM_TYPE, Outer TYPE_DECL supplies the type name.
 *)
export function parse_enum_type(p: pParser): pNode
begin
    require p <> nil

    var enum_token: TToken = p^.current
    var e: pNode = nil

    consume(p, TOK_KEYWORD_ENUM, "parse_enum_type: expected ENUM")

    e := node_create(p^.arena, NODE_ENUM_TYPE, enum_token)
    e^.enum_type.name       := nil
    e^.enum_type.name_len   := 0
    e^.enum_type.elements   := nil
    e^.enum_type.count      := 0
    e^.enum_type.capacity   := 0

    (matchEOS(p))

    while not check(p, TOK_KEYWORD_END) and not isEOF(p) do
        var item: pNode = nil

        skip_layout_breaks(p)

        item := parse_enum_item(p)
        if item == nil then
            error_at(p, "parse_enum_type: expected enum member identifier", true)
            break
        end

        arena_append_ptr(   p^.arena,
                            (@e^.enum_type.elements) as ppvoid,
                            @e^.enum_type.count,
                            @e^.enum_type.capacity,
                            item)

        // if next token is a comma, continue loop,
        // otherwise it mus be an end token.
        if match(p, TOK_COMMA) then
            skip_layout_breaks(p)
            continue
        end

        skip_layout_breaks(p)
        if check(p, TOK_KEYWORD_END) then
            break
        end
        error_at(p, "parse_enum_type: expected ',' or END after enum member", true)
    end

    if e^.enum_type.count == 0 then
        error_at(p, "parse_enum_type: enum requires at least one member", true)
    end

    consume(p, TOK_KEYWORD_END, "parse_enum_type: expected END after enum members")

    return e

    ensure e <> nil
end parse_enum_type


begin
end declaration
