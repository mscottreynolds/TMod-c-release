module parser_main()
(**
 * TMod-c
 * By M. Scott Reynolds
 * Date 28 March 2026
 *
 * Parser.mc - Recursive descent parser for Mod-c source code.
 * 10 August 2026 - Conversion to .mc
 *)


import 
    TLexer, TToken, TokenKind, TLexer::next, TLexer::init, TOK_COMMENT_SINGLE, TOK_COMMENT_MULTI,
    TOK_COMMENT_PASCAL, TOK_COMMENT, TOK_DOC_COMMENT, TOK_SEMICOLON, TOK_NEWLINE,
    TOK_COLON_EQ, TOK_MUL_EQ, TOK_DIV_EQ, TOK_MOD_EQ, TOK_ADD_EQ, TOK_SUB_EQ,
    TOK_LSHIFT_EQ, TOK_RSHIFT_EQ, TOK_AND_EQ, TOK_OR_EQ, TOK_BITWISE_NOT_EQ, TOK_EOF,
    TToken::print, TokenKind::string, TOK_LPAREN, TOK_RPAREN, TOK_KEYWORD_CONST, TOK_CARET,
    TOK_KEYWORD_POINTER, TOK_KEYWORD_TO, TOK_KEYWORD_ARRAY, TOK_LBRACKET, TOK_NUMBER,
    TOK_RBRACKET, TOK_KEYWORD_OF, TOK_IDENT, TOK_KEYWORD_PACKED, TOK_KEYWORD_STRUCT,
    TOK_KEYWORD_END, TOK_KEYWORD_PROCEDURE, TOK_KEYWORD_FUNCTION, TOK_COLON, TOK_KEYWORD_BEGIN,
    TOK_COLON_COLON, TOK_KEYWORD_EXPORT, TOK_KEYWORD_EXTERN, TOK_KEYWORD_STATIC, 
    TOK_KEYWORD_RECURSIVE, TOK_KEYWORD_TYPE, TOK_EQ, TOK_COMMA, TOK_KEYWORD_IMPORT,
    TOK_KEYWORD_VAR, TOK_KEYWORD_LET, TOK_KEYWORD_OPAQUE, TOK_DOT, TOK_KEYWORD_REQUIRE,
    TOK_PREPROCESSOR, TOK_KEYWORD_ENSURE, TOK_KEYWORD_UNTIL, TOK_KEYWORD_ELSIF,
    TOK_KEYWORD_ELSE, TOK_KEYWORD_CASE, TOK_KEYWORD_ASSERT, TOK_KEYWORD_INC, TOK_KEYWORD_DEC,
    TOK_KEYWORD_IF, TOK_KEYWORD_WHILE, TOK_KEYWORD_FOR, TOK_KEYWORD_REPEAT, TOK_KEYWORD_LOOP,
    TOK_KEYWORD_SWITCH, TOK_KEYWORD_BREAK, TOK_KEYWORD_CONTINUE, TOK_KEYWORD_RETURN,
    TOK_KEYWORD_DEFER, TOK_KEYWORD_DEBUG, TOK_KEYWORD_PROGRAM, TOK_KEYWORD_MODULE,
    TOK_KEYWORD_DEFINE, TLexer::capture_line_from,
    from Lexer
import 
    Arena, pArena, arena_alloc, arena_append_ptr, ppvoid 
    from arena
import 
    DynBuf, pDynBuf 
    from dynbuf
import 
    pTType, type_create_array, type_create_array_expr, type_create_opaque,
    type_create_named, type_is_width_base, type_width_allowed,
    from ttype
import TParser::error_at, TParser::consume, TParser::advance, TParser::check, TParser::match,
    TParser::checkEOS, TParser::matchEOS, TParser::check_comment, TParser::match_comment,
    TParser::check_assignment, TParser::skip_empty_statements, TParser::skip_layout_breaks,
    pParser, pParserTypeName, TParser, TParserTypeName, SIZE_PARSER_TYPE_NAME,
    from parser_common
import 
    parse_var_decl, parse_const_decl, parse_let_decl, parse_param_list,
    parse_extern_type_decl, parse_proc_or_func_decl, parse_type_decl,
    from declaration
import 
    parse_conditional, parse_primary, parse_array_index, parse_call, 
    from expression
import 
    parse_inc_dec_stmt, parse_if_stmt, parse_while_stmt, parse_for_stmt,
    parse_repeat_until_stmt, parse_loop_stmt, parse_switch_stmt, parse_break_stmt, 
    parse_continue_stmt, parse_return_stmt, parse_defer_stmt, parse_debug_stmt,
    parse_import_stmt, 
    from statement
import 
    utils_parse_integer_literal 
    from utils
import 
    pNode, node_create, NODE_DOC_COMMENT, NODE_PREPROCESSOR, NODE_LITERAL, NODE_FIELD_ACCESS,
    NODE_UNARY, NODE_BLOCK, NODE_DEFER, NODE_RETURN, NODE_BREAK, NODE_CONTINUE, NODE_ASSIGN, 
    NODE_IDENT, NODE_CALL, NODE_EXPR_STMT, NODE_PROGRAM, NODE_ASSERT, NODE_DEFINE,
    from "node.h"
import size_t 
    from "stddef.h"
import stderr, fprintf 
    from "stdio.h"
import exit 
    from "stdlib.h"
import memcmp, memcpy 
    from "string.h"


(**
 * Skip simple type 
 *)
recursive procedure TParser::skip_simple_type(ref p: TParser)
begin
    if p.match(TOK_KEYWORD_CONST) then
        ;
    end
    if p.match(TOK_CARET) then
        ;
    elsif p.match(TOK_KEYWORD_POINTER) then
        (p.match(TOK_KEYWORD_TO))
    end

    if p.match(TOK_KEYWORD_ARRAY) then
        if p.match(TOK_LBRACKET) then
            if p.check(TOK_NUMBER) then
                p.advance()
            end
            (p.match(TOK_RBRACKET))
        end
        (p.match(TOK_KEYWORD_OF))
        p.skip_simple_type()
        return
    end

    while p.check(TOK_IDENT) do
        p.advance()
    end
    if p.match(TOK_NUMBER) then
        ;
    end

    if p.match(TOK_LBRACKET) then
        if not p.match(TOK_RBRACKET) then
            if p.check(TOK_NUMBER) then
                p.advance()
            end
            (p.match(TOK_RBRACKET))
        end
    end
end TParser::skip_simple_type


(**
 * skipped balanced parens
 *)
procedure TParser::skip_balanced_parens(ref p: TParser)
begin
    var depth: integer = 0;

    if not p.check(TOK_LPAREN) then
        return
    end

    repeat
        if p.check(TOK_LPAREN) then
            inc(depth)
        elsif p.check(TOK_RPAREN) then
            dec(depth)
        end
        p.advance()
    until depth <= 0 or p.check(TOK_EOF)
end TParser::skip_balanced_parens


(**
 * Skip type RHS
 *)
procedure TParser::skip_type_rhs(ref p: TParser)
begin
    p.skip_empty_statements()

    if p.match(TOK_KEYWORD_PACKED) then
        ;
    end

    if p.check(TOK_KEYWORD_STRUCT) then
        p.advance()
        while not p.check(TOK_KEYWORD_END) and not p.check(TOK_EOF) do
            p.advance()
        end
        if p.check(TOK_KEYWORD_END) then
            p.advance()
        end
        return
    end

    if p.check(TOK_KEYWORD_PROCEDURE) or p.check(TOK_KEYWORD_FUNCTION) then
        var is_function: bool = p.check(TOK_KEYWORD_FUNCTION)
        p.advance()
        p.skip_balanced_parens()
        if is_function and p.match(TOK_COLON) then
            p.skip_simple_type()
        end
        return
    end

    p.skip_simple_type()
end TParser::skip_type_rhs


(**
 * Skip to EOS
 *)
procedure TParser::skip_to_eos(ref p: TParser)
begin
    while not p.checkEOS() and not p.check(TOK_EOF) and
            not p.check(TOK_KEYWORD_BEGIN) do
        p.advance()
    end
    (p.matchEOS())
end TParser::skip_to_eos


(**
 * Skip BEGIN END block
 *)
procedure TParser::skip_begin_end_block(ref p: TParser)
begin
    var depth: integer = 1

    if not p.match(TOK_KEYWORD_BEGIN) then
        return
    end

    while depth > 0 and not p.check(TOK_EOF) do
        if p.match(TOK_KEYWORD_BEGIN) THEN
            inc(depth)
        elsif p.match(TOK_KEYWORD_END) then
            dec(depth)
        else
            p.advance()
        end
    end
end TParser::skip_begin_end_block


(**
 * Skip PROC decl
 *)
procedure TParser::skip_proc_decl(ref p: TParser)
begin
    var is_function: bool = false

    if p.check(TOK_KEYWORD_FUNCTION) then
        is_function := true
    end

    if not p.check(TOK_KEYWORD_PROCEDURE) and not p.check(TOK_KEYWORD_FUNCTION) then
        return
    end

    p.advance()

    if p.check(TOK_IDENT) then
        p.advance()
        if p.check(TOK_COLON_COLON) then
            p.advance()
            if p.check(TOK_IDENT) then
                p.advance()
            end
        end
    end

    p.skip_balanced_parens()

    if is_function and p.match(TOK_COLON) then
        p.skip_simple_type()
    end

    p.skip_empty_statements()

    if p.check(TOK_KEYWORD_BEGIN) then
        p.skip_begin_end_block()
    end
end TParser::skip_proc_decl


(**
 * Prescan type names
 *)
procedure TParser::prescan_type_names(ref p: TParser)
begin
    var saved_lexer: TLexer = p.lexer
    var saved_current: TToken = p.current

    while not p.check(TOK_KEYWORD_BEGIN) and
            not p.check(TOK_KEYWORD_END) and
            not p.check(TOK_EOF) do

        p.skip_empty_statements()

        if p.check(TOK_KEYWORD_BEGIN) or
                p.check(TOK_KEYWORD_END) or
                p.check(TOK_EOF) then
            break
        end

        (p.match(TOK_KEYWORD_EXPORT))

        if p.check(TOK_KEYWORD_DEFINE) then
            p.advance()
            while p.check_comment() do
                p.advance()
            end
            if p.check(TOK_IDENT) then
                (TLexer::capture_line_from(p.lexer, p.current.start, 
                    p.current.line, p.current.column))
                p.advance()
            end
            continue
        end

        if p.check(TOK_KEYWORD_EXTERN) then
            (p.match(TOK_KEYWORD_EXTERN))
        elsif p.check(TOK_KEYWORD_STATIC) then
            (p.match(TOK_KEYWORD_STATIC))
        end

        (p.match(TOK_KEYWORD_RECURSIVE))

        if p.check(TOK_KEYWORD_EXTERN) then
            p.advance()
            (p.match(TOK_KEYWORD_EXPORT))
            if p.check(TOK_KEYWORD_TYPE) then
                p.advance()
                if p.check(TOK_IDENT) then
                    p.register_type_name(p.current.start, p.current.length)
                end
                p.skip_to_eos()
                continue
            end
        end

        if p.check(TOK_KEYWORD_TYPE) then
            p.advance()
            repeat
                if p.check(TOK_IDENT) then
                    p.register_type_name(p.current.start, p.current.length)
                    p.advance()
                end
                if not p.match(TOK_EQ) then
                    break
                end
                p.skip_type_rhs()
            until not p.match(TOK_COMMA)
            p.skip_to_eos()
        elsif p.check(TOK_KEYWORD_PROCEDURE) or p.check(TOK_KEYWORD_FUNCTION) then
            p.skip_proc_decl()
            p.skip_to_eos()
        elsif p.check(TOK_KEYWORD_IMPORT) then
            p.advance()
            p.skip_to_eos()
        elsif p.check(TOK_KEYWORD_VAR) or
                p.check(TOK_KEYWORD_CONST) or
                p.check(TOK_KEYWORD_LET) then
            p.advance()
            p.skip_to_eos()
        else
            p.advance()
        end
    end

    p.lexer := saved_lexer
    p.current := saved_current
end TParser::prescan_type_names


(**
 * Parse doc comments
 *)
function TParser::parse_doc_comment(ref p: TParser): pNode
begin
    var n: pNode = nil

    if not p.check(TOK_DOC_COMMENT) then
        return nil
    end

    n := node_create(p.arena, NODE_DOC_COMMENT, p.current)

    // Store the raw token text (including original (** *) or /** */)
    // Will normalize on emission to C.
    n^.doc_comment.text     := p.current.start
    n^.doc_comment.text_len := p.current.length

    p.advance()
    return n
end TParser::parse_doc_comment


(*
 * Parse DEFINE identifier RestOfLine.
 * Body is C; do not tokenize it as TMod-c.
 *)
function TParser::parse_define(ref p: TParser, exported: bool): pNode
begin
    var def_tok: TToken = p.current
    var ident_tok: TToken
    var span: TToken
    var n: pNode = nil

    (p.match(TOK_KEYWORD_DEFINE))
    while p.check_comment() do
        p.advance()
    end
    if not p.check(TOK_IDENT) then
        p.error_at("TParser::parse_define: expected identifier after DEFINE", true)
    end
    ident_tok := p.current
    span := TLexer::capture_line_from(p.lexer, ident_tok.start,
        ident_tok.line, ident_tok.column)
    n := node_create(p.arena, NODE_DEFINE, def_tok)
    n^.define_stmt.name := ident_tok.start
    n^.define_stmt.name_len := ident_tok.length
    n^.define_stmt.text := span.start
    n^.define_stmt.length := span.length
    n^.define_stmt.is_exported := exported
    p.advance()
    return n
end TParser::parse_define


(*
 * Parse a preprocessor directive.
 *)
function TParser::parse_preprocessor(ref p: TParser): pNode
begin
    var n: pNode = nil

    n := node_create(p.arena, NODE_PREPROCESSOR, p.current)

    // Store the full directive text.
    n^.preprocessor.text := p.current.start
    n^.preprocessor.length := p.current.length
    p.advance()

    return n
end TParser::parse_preprocessor


(*
 * Parse array size inside '[' ... ']'.
 * Caller has alreayd consumed '['.
 * Empty => open array: bare integer literal => fixed_size now;
 * otherwise store size_expr for semantic_eval_const_expr.
 *)
function TParser::parse_array_type_after_lbracket(ref p: TParser, element: pTType): pTType
begin
    var bound: pNode = nil
    var fixed_size: size_t = 0

    if p.match(TOK_RBRACKET) then
        return type_create_array(p.arena, element, 0)
    end

    bound := p.parse_const_expression()
    if bound == nil then
        p.error_at("TParser::parse_array_type_after_lbracket: expected const-expression array size", true)
    end
    p.consume(TOK_RBRACKET, "TParser::parse_array_type_after_lbracket: expected ']' after array size")

    if bound^.kind == NODE_LITERAL and bound^.token.kind == TOK_NUMBER then
        fixed_size := utils_parse_integer_literal(bound^.token.start,
            bound^.token.length) as size_t
        return type_create_array(p.arena, element, fixed_size)
    end

    return type_create_array_expr(p.arena, element, bound)
end TParser::parse_array_type_after_lbracket


(**
 * Parse a return type.
 * 
 * This is the most restricted of the parsing functions. It only accepts 
 * syntax that is valid (or can be reasonably lowered) as a C return type.
 *
 * In particular:
 *  - Direct array types (T[], T[N], array[...] of T) are accepted syntactically,
 *    but are expected to be lowered to pointer types during code generation.
 *  - Method types (PROCEDURE / FUNCTION signatures) are NOT accepted here.
 *
 * Intended usage:
 *  - Return types of FUNCTION declarations
 *  - Return type of PROGRAM/MODULE.
 *
 * For parameter types, use parse_parameter_type().
 * For general type expressions (including method types, struct types, etc.),
 * use parse_type_expression().
 *
 * Allow opaque: true only only for a TYPE RHS (parse_type_expression).
 * Bare OPAQUE that is RHS only.
 * ^OPAQUE and POINTER TO OPAQUE are type-specifiers. is_pointer is already 
 * set, so they are accepted here when allow_opaque is false.
 *
 * Exits on fatal parse error. 
 *)
recursive function TParser::parse_return_type_ex(ref p: TParser, allow_opaque: bool): pTType
begin
    var is_const: bool = false
    var is_pointer: bool = false
    var is_array_keyword: bool = false
    var element: pTType = nil

    if p.match(TOK_KEYWORD_CONST) then
        is_const := true
    end
    if p.match(TOK_CARET) then
        is_pointer := true
    elsif p.match(TOK_KEYWORD_POINTER) then
        p.consume(TOK_KEYWORD_TO, "TParser::parse_return_type_ex: expected 'TO' after POINTER")
        is_pointer := true
    end

    is_array_keyword := p.match(TOK_KEYWORD_ARRAY)

    if is_array_keyword then
        // array [bound] of ElementType | array of ElementType
        var arr: pTType = nil
        var bound: pNode = nil
        var had_brackets: bool = false
        var open_brackets: bool = false

        if p.match(TOK_LBRACKET) then
            had_brackets := true
            if p.match(TOK_RBRACKET) then
                open_brackets := true
            else
                bound := p.parse_const_expression()
                if bound == nil then
                    p.error_at("TParser::parse_return_type_ex: expected const-expression array size", true)
                end
                p.consume(TOK_RBRACKET, "TParser::parse_return_type_ex: expected ']' after array size")
            end
        end

        p.consume(TOK_KEYWORD_OF, "TParser::parse_return_type_ex: expected 'OF' after array[...]")
        element := p.parse_return_type_ex(false)

        if not had_brackets or open_brackets then
            arr := type_create_array(p.arena, element, 0)
        elsif bound^.kind == NODE_LITERAL and bound^.token.kind == TOK_NUMBER then
            arr := type_create_array(p.arena, element, 
                utils_parse_integer_literal(bound^.token.start, bound^.token.length) as size_t)
        else
            arr := type_create_array_expr(p.arena, element, bound)
        end

        arr^.is_const := is_const
        arr^.is_pointer := is_pointer
        return arr
    end

    // if allow_opaque and p.match(TOK_KEYWORD_OPAQUE) then
    //     var t: pTType = type_create_opaque(p.arena)
    //     t^.is_pointer := is_pointer
    //     t^.is_const := is_const
    //     return t

    // Bare OPAQUE: TYPE RHS only.
    // ^OPAQUE / POINTER TO OPAQUE: any type-specifier (is_pointer is already set).
    if allow_opaque or is_pointer then
        if p.match(TOK_KEYWORD_OPAQUE) then
            element := type_create_opaque(p.arena)
            element^.is_pointer := is_pointer
            element^.is_const := is_const
            if p.match(TOK_LBRACKET) then
                element := p.parse_array_type_after_lbracket(element)
            end
            return element
        end
    end

    if p.check(TOK_KEYWORD_OPAQUE) then
        p.error_at("TParser::parse_return_type_ex: bare opaque is only legal on a TYPE right-hand side", true)
    end

    // Normal type identifier (possibly with pointer ^ already handled)
    if p.current.kind <> TOK_IDENT then
        p.error_at("TParser::parse_return_type_ex: expected type identifier", true)
    end

    begin
        var start: const ^char = p.current.start
        var length: size_t = p.current.length
        p.advance()

        if type_is_width_base(start, length) and p.check(TOK_NUMBER) then
            var i: size_t = 0
            var w: integer = 0

            while i < p.current.length do
                var ch: char = p.current.start[i]
                if ch < '0' or ch > '9' then
                    p.error_at("TParser::parse_return_type_ex: width must be a decimal integer", true)
                end
                inc(i)
            end
            if p.current.length > 1 and p.current.start[0] == '0' then
                p.error_at("TParser::parse_return_type_ex: widht must be a decimal integer", true)
            end

            w := utils_parse_integer_literal(p.current.start, p.current.length) as integer
            if not type_width_allowed(start, length, w) then
                p.error_at("TParser::parse_return_type_ex: unsupported width for this type", true)
            end
            p.advance()
            element := type_create_named(p.arena, start, length)
            element^.width := w
        else
            // Compund C types: long long, unsigned int, long double, etc.
            while p.current.kind == TOK_IDENT do
                length := (p.current.start + p.current.length - start) as size_t
                p.advance()
            end
            element := type_create_named(p.arena, start, length)
        end
        element^.is_pointer := is_pointer
        element^.is_const := is_const
    end

    // Array suffix: T[N], T[], or T[const-expr]
    if p.match(TOK_LBRACKET) then
        element := p.parse_array_type_after_lbracket(element)
    end

    return element
end TParser::parse_return_type_ex


(*
 * Optional tag after END (not validated against a declared name in v1):
 *  end
 *  end name
 *  end Type::name
 *
 * Matches procedure/function declaration spelling (Type::method).
 * A single identifier such as Point__getX still works (one IDENT token)
 *)
procedure TParser::parse_optional_end_tag(ref p: TParser)
begin
    if not p.check(TOK_IDENT) then
        return
    end
    p.advance()         // bare name, or type owner before '::'

    if p.match(TOK_COLON_COLON) then
        if p.current.kind <> TOK_IDENT then
            p.error_at("TParser::parse_optional_end_tag: expected identifer after '::'", true)
        end
        p.advance()     // method / member name
    end
end TParsre::parse_optional_end_tag


(*
 * Parse a single declaration (top-level).
 *)
function TParser::parse_decl(ref p: TParser): pNode
begin
    var exported: bool = false
    var is_extern: bool = false
    var is_static: bool = false
    var is_recursive: bool = false

    // Top-level doc comment?
    if p.check(TOK_DOC_COMMENT) then
        return p.parse_doc_comment()
    end

    // Pass through compiler directives unchanged.
    if p.check(TOK_PREPROCESSOR) then
        return p.parse_preprocessor()
    end

    // IMPORT statement?
    if p.check(TOK_KEYWORD_IMPORT) then
        return parse_import_stmt(@p)
    end

    if p.check(TOK_KEYWORD_DEFINE) then
        return p.parse_define(false)
    end

    // Standalone EXTERN decls: EXTERN [EXPORT] TYPE|VAR|PROCEDURE|FUNCTION
    if p.check(TOK_KEYWORD_EXTERN) then
        var ext_exported: bool = false

        p.advance()
        ext_exported := p.match(TOK_KEYWORD_EXPORT)

        if p.check(TOK_KEYWORD_TYPE) then
            return parse_extern_type_decl(@p, ext_exported)
        end
        if p.check(TOK_KEYWORD_VAR) then
            return parse_var_decl(@p, ext_exported, true, false)
        end
        if p.check(TOK_KEYWORD_PROCEDURE) or p.check(TOK_KEYWORD_FUNCTION) then
            return parse_proc_or_func_decl(@p, ext_exported, false, true)
        end

        p.error_at("TParser::parse_decl: EXTERN requires TYPE, VAR, PROCEDURE or FUNCTION", true)
    end

    // EXPORT prefix (optional)
    exported := p.match(TOK_KEYWORD_EXPORT)

    if p.check(TOK_KEYWORD_EXTERN) then
        is_extern := p.match(TOK_KEYWORD_EXTERN)
    elsif p.check(TOK_KEYWORD_STATIC) then
        is_static := p.match(TOK_KEYWORD_STATIC)
    end

    // RECURSIVE (optional for procedures/functions, 
    // but required if a procedure/function actually is recursive.)
    is_recursive := p.match(TOK_KEYWORD_RECURSIVE)

    if p.check(TOK_KEYWORD_DEFINE) then
        return p.parse_define(exported)
    end

    if p.check(TOK_KEYWORD_VAR) then
        return parse_var_decl(@p, exported, is_extern, is_static)
    end
    if p.check(TOK_KEYWORD_CONST) then
        return parse_const_decl(@p, exported)
    end
    if p.check(TOK_KEYWORD_LET) then
        return parse_let_decl(@p, exported)
    end
    if p.check(TOK_KEYWORD_TYPE) then
        return parse_type_decl(@p, exported)
    end
    // PROCEDURE or FUNCTION
    if p.check(TOK_KEYWORD_PROCEDURE) or p.check(TOK_KEYWORD_FUNCTION) then
        return parse_proc_or_func_decl(@p, exported, is_recursive, is_extern)
    end

    // Fallback - should almost never hit for valid TMod-c for now
    p.error_at("TParser::parse_decl: unexpected token at top level (expected declaration)", true)
    return nil
end TParser::parse_decl


(*
 * Parse a sequence of declarations.
 *)
function TParser::parse_decl_sequence(ref p:TParser): pNode
begin
    return p.parse_decl()
end TParser::parse_decl_sequence


(*
 * Parse top-level PROGRAM or MODULE unit.
 *)
function TParser::parse_program(ref p: TParser): pNode
begin
    var prog: pNode = node_create(p.arena, NODE_PROGRAM, p.current)
    var param_list: pNode = nil

    p.skip_empty_statements()

    // MUST start with PROGRAM or MODULE (even before comments)
    if not p.match(TOK_KEYWORD_PROGRAM) and not p.match(TOK_KEYWORD_MODULE) then
        p.error_at("TParser::parse_program: expected PROGRAM or MODULE at top level", true)
    end

    prog^.program_decl.unit_kind := prog^.token.kind;

    // Module/program name (identifier)
    if p.current.kind == TOK_IDENT then
        prog^.program_decl.name     := p.current.start
        prog^.program_decl.name_len := p.current.length
        p.advance()
    else
        p.error_at("TParser::parse_program: expected PROGRAM/MODULE name", true)
    end

    // Formal parameter list: (name: type, ...)
    param_list := parse_param_list(@p)
    if param_list <> nil then
        if param_list^.param_list.has_ellipsis then
            p.error_at("TParser::parse_program: '...' is not allowed on PROGRAM/ODULE parameter lists", true)
        end
        prog^.program_decl.params           := param_list^.param_list.params
        prog^.program_decl.param_count      := param_list^.param_list.count
        prog^.program_decl.param_capacity   := param_list^.param_list.capacity
    else
        p.error_at("TParser::parse_program: formal parameters expected", false)
        prog^.program_decl.params           := nil
        prog^.program_decl.param_count      := 0
        prog^.program_decl.param_capacity   := 0
    end

    // Optional return type: : TType
    if p.match(TOK_COLON) then
        prog^.program_decl.return_type := p.parse_return_type_ex(false)
        p.advance()
    end

    p.skip_empty_statements()
    p.prescan_type_names()

    // Parse declarations until we hit BEGIN, END, or EOF
    while not p.check(TOK_KEYWORD_BEGIN) and
            not p.check(TOK_KEYWORD_END) and
            not p.check(TOK_EOF) do
        var decl: pNode = p.parse_decl_sequence()

        if decl == nil then
            break
        end

        // Grow declarations array (simple doubling)
        arena_append_ptr(p.arena,
                (@prog^.program_decl.decls) as ppvoid,
                @prog^.program_decl.count,
                @prog^.program_decl.capacity,
                decl)
        p.skip_empty_statements()
    end

    // BEGIN block is required for PROGRAM. Although optional for
    // MODULE, a warning will still be generated.
    if p.check(TOK_KEYWORD_BEGIN) then
        prog^.program_decl.block := p.parse_block()
    elsif prog^.program_decl.unit_kind == TOK_KEYWORD_PROGRAM then
        p.error_at("TParser::parse_program: PROGRAM requires a BEGIN ... END block", true)
    elsif prog^.program_decl.unit_kind == TOK_KEYWORD_MODULE then
        if not p.check(TOK_KEYWORD_END) then
            p.error_at("TParser::parse_program: expected END at end of MODULE", true)
        else
            p.error_at("TParser::parse_program: MODULE expects a BEGIN ... END block", false)
        end
    else
        // Allow processing moutiple modules per input file???
        p.advance()
    end

    return prog
end TParser::parse_program


(**
 * Initialize parser state.
 * Primes the lexer and advances to the first token.
 * Does NOT take ownership of source or out - they must remain valid.
 *
 * @param p         Parser to initialize
 * @param arena     Arena for all AST node allocations (must be initialized)
 * @param source    Null-terminated source code buffer (must remain valid)
 * @param out       Optional output buffer for debug/codegen (may be NULL)
 *)
export procedure TParser::init(ref p: TParser, arena: pArena, source: const ^char, out: pDynBuf)
begin
    if arena == nil or source == nil then
        fprintf(stderr, "TParser::init: ERROR: NULL pointer argument\n")
        exit(1)
    end
    TLexer::init(p.lexer, source)
    p.arena := arena
    p.out := out
    p.show_tokens := true
    p.type_names := nil
    p.type_name_count := 0
    p.type_name_capacity := 0
end TParser::init


(**
 * Register a user TYPE spelling for sizeof() operand disambiguation.
 * Case-sensitive; duplicates are ignored.
 *)
export procedure TParser::register_type_name(ref p: TParser, start: const ^char, length: size_t)
begin
    var i: size_t = 0

    if start == nil or length == 0 then
        return
    end

    for i := 1 to p.type_name_count do
        if p.type_names[i-1].length == length and
                memcmp(p.type_names[i-1].start, start, length) == 0 then
            return
        end
    end

    if p.type_name_count >= p.type_name_capacity then
        var new_capacity: size_t = p.type_name_capacity ? p.type_name_capacity * 2u : 8u
        var new_names: pParserTypeName = arena_alloc(p.arena,
            new_capacity * SIZE_PARSER_TYPE_NAME()) as pParserTypeName

        if p.type_names <> nil and p.type_name_count > 0 then
            memcpy(new_names, p.type_names, p.type_name_count * SIZE_PARSER_TYPE_NAME())
        end

        p.type_names := new_names
        p.type_name_capacity := new_capacity
    end    

    p.type_names[p.type_name_count].start := start
    p.type_names[p.type_name_count].length := length
    inc(p.type_name_count)
end TParser::register_type_name


(**
 * Is user type name?
 * True when start/len is a registered user TYPE name (not a builtin).
 *)
export function TParser::is_user_type_name(ref p: TParser, start: const ^char, length: size_t): bool
begin
    var i: size_t = 0

    if start == nil or length == 0 then
        return false
    end

    for i := 1 to p.type_name_count do
        if p.type_names[i-1].length == length and memcmp(p.type_names[i-1].start, start, length) == 0 then
            return true
        end
    end

    return false
end TParser::is_user_type_name


(**
 * Parse expression
 *)
export function TParser::parse_expr(ref p: TParser): pNode
begin
    // Assignments are statements only (not expressions) - see
    // decision in grammar.md + CURRENT.MD (June 2026)
    // Compounds and ":=" are handled exclusively in parse_stmt
    // via check_assignment() + direct NODE_ASSIGN construction.

    return parse_conditional(@p)
end TParser::parse_expr


(**
 * Parse a return type
 *
 * Narrow parser used only where a C return type is expected.
 * See the header declaration for full rationale and restrictions.
 *)
export function TParser::parse_return_type(ref p: TParser): pTType
begin
    return p.parse_return_type_ex(false)
end TParser::parse_return_type


(**
 * Parse parameter types: Type specified in formal parameters, grammar may
 * allow more than just parse_return_type. Returns fully constructed ^TType
 * Exits on fatal parse error.
 *)
export function TParser::parse_parameter_type(ref p: TParser): pTType
begin
    return p.parse_return_type_ex(false)
end TParser::parse_parameter_type


(**
 * Parse full type expression. Used for full type declarations.
 * Returns fully constructed ^TType.
 * Exits on fatal parse error.
 *)
export function TParser::parse_type_expression(ref p: TParser): pTType
begin
    return p.parse_return_type_ex(true)
end TParser::parse_type_expression


(**
 * Parse a const expression.
 * Same as normal expression for now. Semantics will enforce later.
 *)
export function TParser::parse_const_expression(ref p: TParser): pNode
begin
    return p.parse_expr()
end TParser::parse_const_expression


(**
 * Parse a designator (for left-hand side of assignment, etc.)
 * Supports: ident, ident.field, ident[index], ^designator
 *)
export function TParser::parse_designator(ref p: TParser): pNode
begin
    var d: pNode = parse_primary(@p)        // Start with ident, literal, etc.

    loop
        if p.match(TOK_DOT) then
            var fa: pNode = nil

            // field access
            if p.current.kind <> TOK_IDENT then
                p.error_at("TParser::parse_designator: expected identifer after '.'", true)
            end

            let field_tok: TToken = p.current
            p.advance()

            fa := node_create(p.arena, NODE_FIELD_ACCESS, field_tok)
            fa^.field_access.record_ := d
            fa^.field_access.field_name := field_tok.start
            fa^.field_access.field_len := field_tok.length
            d := fa
        elsif p.check(TOK_LBRACKET) then
            d := parse_array_index(@p, d)
        elsif p.check(TOK_CARET) then
            var unary: pNode = nil
            unary := node_create(p.arena, NODE_UNARY, p.current)        // previous token was ^
            unary^.unary.op := TOK_CARET
            unary^.unary.operand := d
            d := unary
            p.advance()
        else
            break
        end
    end
    return d
end TParser::parse_designator


(**
 * Parse block: BEGIN statement-list END
 * 
 * Allocates and grows stmts array dynamically.
 * Exits on fatal parse errors.
 *
 * @param p     Parser state (current token should be BEGIN)
 * @return      BLOCK node with parsed statements.
 *)
export function TParser::parse_block(ref p: TParser): pNode
begin
    var begin_token: TToken = p.current
    var block: pNode = nil
    var saw_early_exit: pNode = nil

    p.consume(TOK_KEYWORD_BEGIN, "TParser::parse_block: expected BEGIN")

    block := node_create(p.arena, NODE_BLOCK, begin_token)
    block^.block.stmts          := nil
    block^.block.count          := 0
    block^.block.capacity       := 0
    block^.block.defers         := nil
    block^.block.defer_count    := 0
    block^.block.defer_capacity := 0

    block^.block.requires           := nil
    block^.block.require_count      := 0
    block^.block.require_capacity   := 0

    block^.block.ensures            := nil
    block^.block.ensure_count       := 0
    block^.block.ensure_capacity    := 0

    p.skip_empty_statements()

    // DbC: REQUIRE clauses (must appear right after BEGIN, before any definition/statements)
    while p.check(TOK_KEYWORD_REQUIRE) do
        var expr: pNode = nil
        p.consume(TOK_KEYWORD_REQUIRE, "TParser::parse_block: expected REQUIRE")

        expr := p.parse_expr()
        if expr == nil then
            p.error_at("TParser::parse_block: expected expression after REQUIRE ...", true)
        end

        if not p.matchEOS() then
            p.error_at("TParser::parse_block: expected end-of-statement after REQUIRE", true)
        end

        arena_append_ptr(p.arena,
                (@block^.block.requires) as ppvoid,
                @block^.block.require_count,
                @block^.block.require_capacity,
                expr)

        p.skip_empty_statements()
    end

    // First: definition-sequence (VAR/LET/CONST at block start)
    loop
        var is_static: bool = p.match(TOK_KEYWORD_STATIC)
        var exported: bool = false      // local declarations are never exported/external
        var is_extern: bool = false
        var decl: pNode = nil

        if p.check(TOK_KEYWORD_VAR) then
            decl := parse_var_decl(@p, exported, is_extern, is_static)
        elsif is_static then
            p.error_at("TParser::parse_block: STATIC can only be used with VAR here", true)
        elsif p.check(TOK_KEYWORD_CONST) then
            decl := parse_const_decl(@p, exported)
        elsif p.check(TOK_KEYWORD_LET) then
            decl := parse_let_decl(@p, exported)
        elsif p.check(TOK_PREPROCESSOR) then
            decl := p.parse_preprocessor()
        else
            break
        end

        if decl <> nil then
            // Grow block statement array (simple doubling)
            arena_append_ptr(p.arena,
                    (@block^.block.stmts) as ppvoid,
                    @block^.block.count,
                    @block^.block.capacity,
                    decl)
        end

        p.skip_empty_statements()
    end

    // Second: statement-sequence
    while not p.check(TOK_KEYWORD_END) and
            not p.check(TOK_EOF) and 
            not p.check(TOK_KEYWORD_ENSURE) do
        var stmt: pNode = p.parse_stmt()
        if stmt <> nil then
            if stmt^.kind == NODE_DEFER then
                // Collect defer for LIFO execution at block END
                // Also put it into the main AST, below.
                arena_append_ptr(p.arena,
                        (@block^.block.defers) as ppvoid,
                        @block^.block.defer_count,
                        @block^.block.defer_capacity,
                        stmt)
            end
            if saw_early_exit <> nil then
                p.error_at("WARNING: TParser::parse_block: unreachable statement after RETURN/BREAK/CONTINUE", false)
            end
            // else
                arena_append_ptr(p.arena,
                        (@block^.block.stmts) as ppvoid,
                        @block^.block.count,
                        @block^.block.capacity,
                        stmt)
            // end

            if saw_early_exit == nil and (
                stmt^.kind == NODE_RETURN or
                stmt^.kind == NODE_BREAK or
                stmt^.kind == NODE_CONTINUE) then
                saw_early_exit := stmt
            end
        else
            fprintf(stderr, "WARNING: TParser::parse_block: unrecognized statement %.*s\n",
                p.current.length as int, p.current.start)
            p.advance()
        end
        p.skip_empty_statements()
    end

    // DbC: ENSURE clauses (after the statement-sequence, before END)
    while p.check(TOK_KEYWORD_ENSURE) do
        var expr: pNode = nil

        p.consume(TOK_KEYWORD_ENSURE, "TParser::parse_block: expected ENSURE")

        expr := p.parse_expr()
        if expr == nil then
            p.error_at("TParser::parse_block: expected expression after ENSURE ...", true)
        end

        if not p.matchEOS() then
            p.error_at("TParser::parse_block: expected end-of-statement after ENSURE", true)
        end

        arena_append_ptr(p.arena,
                (@block^.block.ensures) as ppvoid,
                @block^.block.ensure_count,
                @block^.block.ensure_capacity,
                expr)
        p.skip_empty_statements()
    end

    p.consume(TOK_KEYWORD_END, "TParser::parse_block: expected END")

    // Optional identifer after END
    p.parse_optional_end_tag()

    if not p.matchEOS() then
        // allow trailing comment or end-of-statement after END
    end

    return block
end TParser::parse_block


(**
 * Parse statement_sequence - statements until a terminating key word (NED, UNTIL, etc.)
 * This is what IF/THEN, FOR/DO, REPEAT, ELSIF, ELSE use.
 * No BEGIN is required.
 * This is similar to TParser::parse_block; any changes there will need to also go here.
 *)
export function TParser::parse_statement_sequence(ref p: TParser): pNode
begin
    var block: pNode = nil
    var saw_early_exit: pNode = nil

    block := node_create(p.arena, NODE_BLOCK, p.current)

    block^.block.stmts          := nil
    block^.block.count          := 0
    block^.block.capacity       := 0
    block^.block.defers         := nil
    block^.block.defer_count    := 0
    block^.block.defer_capacity := 0

    block^.block.requires           := nil
    block^.block.require_count      := 0
    block^.block.require_capacity   := 0

    block^.block.ensures            := nil
    block^.block.ensure_count       := 0
    block^.block.ensure_capacity    := 0

    p.skip_empty_statements()

    // Definition-sequence (VAR/LET/CONST at block start)
    loop
        var is_static: bool = p.match(TOK_KEYWORD_STATIC)
        var exported: bool = false       // local declarations are never exported/extern
        var is_extern: bool = false
        var decl: pNode = nil

        if p.check(TOK_KEYWORD_VAR) then
            decl := parse_var_decl(@p, exported, is_extern, is_static)
        elsif is_static then
            p.error_at("TParser::parse_statement_sequence: STATIC can only bu used with VAR here", true)
        elsif p.check(TOK_KEYWORD_CONST) then
            decl := parse_const_decl(@p, exported)
        elsif p.check(TOK_KEYWORD_LET) then
            decl := parse_let_decl(@p, exported)
        elsif p.check(TOK_PREPROCESSOR) then
            decl := p.parse_preprocessor()
        else
            break
        end

        if decl <> nil then
            arena_append_ptr(p.arena,
                        (@block^.block.stmts) as ppvoid,
                        @block^.block.count,
                        @block^.block.capacity,
                        decl)
        end

        p.skip_empty_statements()
    end

    // Statement sequence with early-exit detection
    while not p.check(TOK_KEYWORD_END) and
            not p.check(TOK_KEYWORD_UNTIL) and
            not p.check(TOK_KEYWORD_ELSIF) and
            not p.check(TOK_KEYWORD_ELSE) and
            not p.check(TOK_EOF) and
            not p.check(TOK_KEYWORD_CASE) do

        var stmt: pNode = p.parse_stmt()

        if stmt <> nil then
            if stmt^.kind == NODE_DEFER then
                // Collect defer for LIFO execution at block END
                arena_append_ptr(p.arena,
                        (@block^.block.defers) as ppvoid,
                        @block^.block.defer_count,
                        @block^.block.defer_capacity,
                        stmt)
                // Defer nodes get placed into the main AST as well.
                // May still need to put into block.stmts so it can
                // show up in the AST.
            end
            if saw_early_exit <> nil then
                p.error_at("TParser::parse_statement_sequence: unreachable statement after RETURN/BREAK/CONTINUE", false)
            end
            // else
                arena_append_ptr(p.arena,
                        (@block^.block.stmts) as ppvoid,
                        @block^.block.count,
                        @block^.block.capacity,
                        stmt)
            // end

            // Mark that we saw an early exit. Just point to the first node that triggers.
            if saw_early_exit == nil and (
                    stmt^.kind == NODE_RETURN or
                    stmt^.kind == NODE_BREAK or
                    stmt^.kind == NODE_CONTINUE) then
                saw_early_exit := stmt
            end
        else
            p.advance()
        end
        p.skip_empty_statements()
    end

    return block
end TParser::parse_statement_sequence


(**
 * Parse a single statement.
 * Recognizes:
 *  - expression / assignment statements / call statements
 *  - contorl structure (if, for, repeat, loop) -- TODO
 *  - empty statements (just ; or newline)
 *
 * Returns statement node or nil for empty / skiped lines.
 *)
export function TParser::parse_stmt(ref p: TParser): pNode
begin
    if p.check(TOK_PREPROCESSOR) then
        return p.parse_preprocessor()
    end
    if p.check(TOK_KEYWORD_DEFINE) then
        p.error_at("TParser::parse_stmt: DEFINE is a top-level declaration", true)
    end

    // Built in statements
    if p.check(TOK_KEYWORD_ASSERT) then
        return p.parse_builtin_stmt()
    end

    if p.check(TOK_KEYWORD_INC) or p.check(TOK_KEYWORD_DEC) then
        return parse_inc_dec_stmt(@p)
    end

    if p.check(TOK_KEYWORD_LET) then
        return parse_let_decl(@p, false)
    end

    if p.check(TOK_KEYWORD_IF) then
        return parse_if_stmt(@p)
    end

    if p.check(TOK_KEYWORD_WHILE) then
        return parse_while_stmt(@p)
    end

    if p.check(TOK_KEYWORD_FOR) then
        return parse_for_stmt(@p)
    end

    if p.check(TOK_KEYWORD_REPEAT) then
        return parse_repeat_until_stmt(@p)
    end

    if p.check(TOK_KEYWORD_LOOP) then
        return parse_loop_stmt(@p)
    end

    if p.check(TOK_KEYWORD_SWITCH) then
        return parse_switch_stmt(@p)
    end

    if p.check(TOK_KEYWORD_BREAK) then
        return parse_break_stmt(@p)
    end

    if p.check(TOK_KEYWORD_CONTINUE) then
        return parse_continue_stmt(@p)
    end

    if p.check(TOK_KEYWORD_RETURN) then
        return parse_return_stmt(@p)
    end

    // Assignment or call or expression statement
    // TODO: Handle TOK_RPAREN when current token is LPAREN
    if p.check(TOK_IDENT) or p.check(TOK_CARET) or p.check(TOK_LPAREN) then
        var left: pNode = p.parse_designator()
        var stmt: pNode = nil


        // Check for compound assignment
        if p.check_assignment() then
            var assign_tok: TokenKind = p.current.kind
            var right: pNode = nil
            var assign: pNode = nil

            p.advance()

            right := p.parse_expr()
            if right == nil then
                p.error_at("TParser::parse_stmt: expected expression after assignment", true)
            end

            assign := node_create(p.arena, NODE_ASSIGN, left^.token)
            assign^.binary.left     := left
            assign^.binary.right    := right
            assign^.binary.op       := assign_tok

            if not p.matchEOS() then
                p.error_at("TParser::parse_stmt expected end-of-statement after assignment", true)
            end
            return assign;
        end

        // Statement-level postfix chain, same shape as parse_postfix:
        //  designator { call | '[' index ']' | '.' ident | '^' }
        //
        // Enables:
        //  p.print()
        //  b.topLeft().print()         => Point::print(Box::topLeft(b))
        //
        // Still static Type__method dispatch (no vtable). Only when not
        // assigning, so "p.x := 1" stays a pure designator LHS.
        loop
            if p.check(TOK_LPAREN) then
                if left^.kind == NODE_FIELD_ACCESS then
                    var fa: pNode = left
                    var call: pNode = parse_call(@p, left^.token)

                    call^.call.receiver_expr := fa^.field_access.record_
                    call^.call.callee_expr := fa            // Provisional field designator
                    left := call
                elsif left^.kind == NODE_IDENT then
                    // Defensive: base name + '(' if primary did not form a call
                    left := parse_call(@p, left^.token)
                elsif left^.kind == NODE_CALL then
                    // Chained free-call style f()(...) -- rare; keep parse_postfix parity
                    left := parse_call(@p, left^.token)
                else
                    p.error_at("TParser::parse_stmt: unexpected '(' after expression", true)
                end
            elsif p.check(TOK_LBRACKET) then
                left := parse_array_index(@p, left)
            elsif p.match(TOK_DOT) THEN
                var field_tok: TToken
                var field_node: pNode = nil

                if p.current.kind <> TOK_IDENT then
                    p.error_at("TParser::parse_stmt: expected identifier after '.'", true)
                end
                field_tok := p.current
                p.advance()

                field_node := node_create(p.arena, NODE_FIELD_ACCESS, field_tok)
                field_node^.field_access.record_        := left
                field_node^.field_access.field_name     := field_tok.start
                field_node^.field_access.field_len      := field_tok.length
                field_node^.field_access.base_depth     := 0
                left := field_node
            elsif p.match(TOK_CARET) then
                var unary: pNode = node_create(p.arena, NODE_UNARY, p.current)

                // Note: match already advanced; token on unary is post-^ current.
                // Mirror designator: use CARET op; operand is left
                unary^.unary.op         := TOK_CARET
                unary^.unary.operand    := left
                left := unary
            else
                break
            end
        end

        // Otherwise treat as expression statement (e.g. procedure call)
        stmt := node_create(p.arena, NODE_EXPR_STMT, left^.token)
        stmt^.expr_stmt.expr := left

        if not p.matchEOS() then
            p.error_at("TParser::parse_stmt: expected end-of-statement after expression", true)
        end
        return stmt
    end

    if p.check(TOK_KEYWORD_DEFER) then
        return parse_defer_stmt(@p)
    end

    if p.check(TOK_KEYWORD_DEBUG) then
        return parse_debug_stmt(@p)
    end

    if p.check(TOK_KEYWORD_BEGIN) then
        return p.parse_block()
    end

    // Fallback - on unrecognized keywords, just return nil and don't advance.
    return nil
end TParser::parse_stmt


(**
 * Parse built-in statements: ASSERT 
 *)
export function TParser::parse_builtin_stmt(REF p: TParser): pNode
begin
    var tok: TToken = p.current

    if p.match(TOK_KEYWORD_ASSERT) then
        var cond: pNode = p.parse_expr()
        var const_expr: pNode = nil
        var n: pNode = nil

        if cond == nil then
            p.error_at("TParser::parse_builtin_stmt: expected expression after ASSERT", true)
        end

        if p.match(TOK_COMMA) then
            const_expr := p.parse_const_expression()
        end

        if not p.matchEOS() then
            p.error_at("TParser::parse_builtin_stmt: expected end-of-statement after ASSERT", true)
        end

        n := node_create(p.arena, NODE_ASSERT, tok)
        n^.assert_stmt.condition := cond
        n^.assert_stmt.const_expr := const_expr
        return n
    end
    return nil
end TParser::parse_builtin_stmt


(**
 * Entry point. Parse the entire source into an AST.
 * Returns the root PROGRAM node (or NULL on fatal error - exits via error handlers).
 * Caller owns the returned node (allocated in p->arena).
 *)
export function TParser::parse(ref p: TParser): pNode
begin
    if p.lexer.start == p.lexer.current then
        p.advance()         // Prime lexer with first token
    end

    // First skip any empty statements.
    p.skip_empty_statements()

    return p.parse_program()
end TParser::parse


begin
end parser_main
