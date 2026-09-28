module parser_common()
(**
 * TMod-c
 * By M. Scott Reynolds
 * Date 28 March 2026
 *
 * parser_common.mc - Common routines used by parser, declaration, expression, and statement
 * 22 August 2026 - Conversion to .mc
 *)


import 
    TLexer, TToken, TokenKind, TLexer::next, TLexer::init, TOK_COMMENT_SINGLE, TOK_COMMENT_MULTI,
    TOK_COMMENT_PASCAL, TOK_COMMENT, TOK_DOC_COMMENT, TOK_SEMICOLON, TOK_NEWLINE, TOK_COLON_EQ,
    TOK_MUL_EQ, TOK_DIV_EQ, TOK_MOD_EQ, TOK_ADD_EQ, TOK_SUB_EQ, TOK_LSHIFT_EQ, TOK_RSHIFT_EQ, 
    TOK_AND_EQ, TOK_OR_EQ, TOK_BITWISE_NOT_EQ, TOK_EOF, TToken::print, TokenKind::string, TOK_ERROR,
    from Lexer
import 
    pArena
    from arena
import 
    pDynBuf 
    from dynbuf
import size_t 
    from "stddef.h"
import stderr, fprintf 
    from "stdio.h"
import exit 
    from "stdlib.h"

(**
 * One user TYPE name registered for sizeof() disambiguation at parse time.
 * Points into the source buffer (case-sensitive spelling).
 *)
export type TParserTypeName = struct
    start: const ^char
    length: size_t
end
export type pParserTypeName = ^TParserTypeName


export function SIZE_PARSER_TYPE_NAME(): size_t
begin
    return sizeof(TParserTypeName)
end

(**
 * Parser state for recursive descent parsing.
 * Holds lexer state, current token, arena for AST nodes, and optional output buffer.
 *)
export type TParser = struct
    lexer: TLexer               // Source lexer (non-owning reference to source)
    current: TToken             // Current lookahead token
    arena: pArena               // Owns all allocated AST nodes (never null after init)
    out: pDynBuf                // Optional: for debug printing, pretty-print, or code gen.
                                // May be NULL if no output is needed.
    show_tokens: bool           // Show debug tokens if true.
    debug_enabled: bool         // Generate debug statements
    type_names: pParserTypeName // User TYPE names (sizeof disambiguation)
    type_name_count: size_t
    type_name_capacity: size_t
end
export type pParser = ^TParser


////////////////////////////////////////////////////////////
// implementation
////////////////////////////////////////////////////////////


(**
 * Advance to the next token (and print it if debug set show-tokens).
 *)
export procedure advance(p: pParser)
begin
    p^.current := TLexer::next(p^.lexer)
    if p^.show_tokens then
        TToken::print(p^.current)
    end
end advance


(**
 * Advance to the next token (and print it if debug set show-tokens).
 *)
export procedure TParser::advance(ref p: TParser)
begin
    p.current := TLexer::next(@p.lexer)
    if p.show_tokens then
        TToken::print(@p.current)
    end
end TParser::advance


(**
 * Check if the current token matches kind without consuming it.
 *)
export function check(p: pParser, kind: TokenKind): bool
begin
    return p^.current.kind == kind
end check


(**
 * Check if the current token matches kind without consuming it.
 *)
export function TParser::check(ref p: TParser, kind: TokenKind): bool
begin
    return p.current.kind == kind
end TParser::check


(**
 * If current token matches, consume it and return true
 *)
export function match(p: pParser, kind: TokenKind): bool
begin
    if check(p, kind) then
        advance(p)
        return true
    end
    return false
end match


(**
 * If current token matches, consume it and return true
 *)
export function TParser::match(ref p: TParser, kind: TokenKind): bool
begin
    if p.check(kind) then
        p.advance()
        return true
    end
    return false
end TParser::match


(**
 * Check if the current token is one of the comments.
 * Doc comments are processed into their own nodes.
 *)
export function check_comment(p: pParser): bool
begin
    if check(p, TOK_COMMENT_SINGLE) or check(p, TOK_COMMENT_MULTI) or
            check(p, TOK_COMMENT_PASCAL) or check(p, TOK_COMMENT) then
        return true
    end
    return false
end check_comment


(**
 * Check if the current token is one of the comments.
 * Doc comments are processed into their own nodes.
 *)
export function TParser::check_comment(ref p: TParser): bool
begin
    if p.check(TOK_COMMENT_SINGLE) or p.check(TOK_COMMENT_MULTI) or
            p.check(TOK_COMMENT_PASCAL) or p.check(TOK_COMMENT) then
        return true
    end
    return false
end TParser::check_comment


(**
 * Match if one of the comment types
 *)
export function match_comment(p: pParser): bool
begin
    if check_comment(p) then
        advance(p)
        return true
    end
    return false
end match_comment


(**
 * Match if one of the comment types
 *)
export function TParser::match_comment(ref p: TParser): bool
begin
    if p.check_comment() then
        p.advance()
        return true
    end
    return false
end TParser::match_comment


(**
 * Return true if end-of-statement (EOS)
 *)
export function checkEOS(p: pParser): bool
begin
    if check(p, TOK_SEMICOLON) or check(p, TOK_NEWLINE) or
            check_comment(p) then
        return true
    end
    return false
end checkEOS


(**
 * Return true if end-of-statement (EOS)
 *)
export function TParser::checkEOS(ref p: TParser): bool
begin
    if p.check(TOK_SEMICOLON) or p.check(TOK_NEWLINE) or
            p.check_comment() then
        return true
    end
    return false
end TParser::checkEOS


(**
 * Match end-of-statement (semicolon or newline)
 * Return true if either was consumed.
 * This allows comments to appear after a statement on the same line.
 *)
export function matchEOS(p: pParser): bool
begin
    var consumed: bool = false

    // Consume semicolon if present
    if match(p, TOK_SEMICOLON) then
        consumed := true
    end

    // Consume newline if present
    if match(p, TOK_NEWLINE) then
        consumed := true
    end

    // Skip any trailing comments on the same line
    while check_comment(p) do
        advance(p)
        consumed := true
    end

    return consumed
end matchEOS


(**
 * Match end-of-statement (semicolon or newline)
 * Return true if either was consumed.
 * This allows comments to appear after a statement on the same line.
 *)
export function TParser::matchEOS(ref p: TParser): bool
begin
    var consumed: bool = false

    // Consume semicolon if present
    if p.match(TOK_SEMICOLON) then
        consumed := true
    end

    // Consume newline if present
    if p.match(TOK_NEWLINE) then
        consumed := true
    end

    // Skip any trailing comments on the same line
    while p.check_comment() do
        p.advance()
        consumed := true
    end

    return consumed
end TParser::matchEOS


(**
 * Skip empty statements: blank lines, comments, etc.
 *)
export procedure skip_empty_statements(p: pParser)
begin
    // Skip empty lines, semicolons, and all comment types
    while check(p, TOK_NEWLINE) or check(p, TOK_SEMICOLON) or check_comment(p) do
        advance(p)
    end
end skip_empty_statements


(**
 * Skip empty statements: blank lines, comments, etc.
 *)
export procedure TParser::skip_empty_statements(ref p: TParser)
begin
    // Skip empty lines, semicolons, and all comment types
    while p.check(TOK_NEWLINE) or p.check(TOK_SEMICOLON) or p.check_comment() do
        p.advance()
    end
end TParser::skip_empty_statements


(**
 * Skip layout-only breaks between list items (newlines, comments).
 * Does not consume ';' - that remains a statement terminator.
 *)
export procedure skip_layout_breaks(p: pParser)
begin
    while check(p, TOK_NEWLINE) or check_comment(p) do
        advance(p)
    end
end skip_layout_breaks


(**
 * Skip layout-only breaks between list items (newlines, comments).
 * Does not consume ';' - that remains a statement terminator.
 *)
export procedure TParser::skip_layout_breaks(ref p: TParser)
begin
    while p.check(TOK_NEWLINE) or p.check_comment() do
        p.advance()
    end
end TParser::skip_layout_breaks


(**
 * Check if current token is an assignment
 *)
export function check_assignment(p: pParser): bool
begin
    if check(p, TOK_COLON_EQ) or
            check(p, TOK_MUL_EQ) or
            check(p, TOK_DIV_EQ) or
            check(p, TOK_MOD_EQ) or
            check(p, TOK_ADD_EQ) or
            check(p, TOK_SUB_EQ) or
            check(p, TOK_LSHIFT_EQ) or
            check(p, TOK_RSHIFT_EQ) or
            check(p, TOK_AND_EQ) or
            check(p, TOK_OR_EQ) or
            check(p, TOK_BITWISE_NOT_EQ) then
        return true
    end
    return false
end check_assignment


(**
 * Check if current token is an assignment
 *)
export function TParser::check_assignment(ref p: TParser): bool
begin
    if p.check(TOK_COLON_EQ) or
            p.check(TOK_MUL_EQ) or
            p.check(TOK_DIV_EQ) or
            p.check(TOK_MOD_EQ) or
            p.check(TOK_ADD_EQ) or
            p.check(TOK_SUB_EQ) or
            p.check(TOK_LSHIFT_EQ) or
            p.check(TOK_RSHIFT_EQ) or
            p.check(TOK_AND_EQ) or
            p.check(TOK_OR_EQ) or
            p.check(TOK_BITWISE_NOT_EQ) then
        return true
    end
    return false
end check_assignment


(**
 * Report error. Fatal errors cause immediate program exit.
 *)
export procedure error_at(p: pParser, msg: const ^char, fatal: bool)
begin
    if fatal then
        if p^.current.kind == TOK_ERROR and p^.current.error_msg <> nil then
            fprintf(stderr, "FATAL ERROR: line %d col %d: %s\n", 
                p^.current.line, p^.current.column, p^.current.error_msg)
        else
            fprintf(stderr, "FATAL ERROR: line %d col %d: %s (got %s)\n",
                p^.current.line, p^.current.column, msg, TokenKind::string(p^.current.kind))
        end
        exit(1)
    else
        fprintf(stderr, "WARNING: line %d col %d: %s (got %s)\n",
            p^.current.line, p^.current.column, msg, TokenKind::string(p^.current.kind))
    end
end error_at


(**
 * Report error. Fatal errors cause immediate program exit.
 *)
export procedure TParser::error_at(ref p: TParser, msg: const ^char, fatal: bool)
begin
    if fatal then
        if p.current.kind == TOK_ERROR and p.current.error_msg <> nil then
            fprintf(stderr, "FATAL ERROR: line %d col %d: %s\n", 
                p.current.line, p.current.column, p.current.error_msg)
        else
            fprintf(stderr, "FATAL ERROR: line %d col %d: %s (got %s)\n",
                p.current.line, p.current.column, msg, TokenKind::string(p.current.kind))
        end
        exit(1)
    else
        fprintf(stderr, "WARNING: line %d col %d: %s (got %s)\n",
            p.current.line, p.current.column, msg, TokenKind::string(p.current.kind))
    end
end TParser::error_at


(**
 * Consume a token of the expected kind or report fata error.
 *)
export procedure consume(p: pParser, kind: TokenKind, msg: const ^char)
begin
    skip_layout_breaks(p)
    if not match(p, kind) then
        error_at(p, msg, true)
    end
end consume


(**
 * Consume a token of the expected kind or report fata error.
 *)
export procedure TParser::consume(ref p: TParser, kind: TokenKind, msg: const ^char)
begin
    p.skip_layout_breaks()
    if not p.match(kind) then
        p.error_at(msg, true)
    end
end TParser::consume


(**
 * Return true if we've reached the end of the input.
 *)
export function isEOF(p: pParser): bool
begin
    return check(p, TOK_EOF)
end isEOF


(**
 * Return true if we've reached the end of the input.
 *)
export function TParser::isEOF(ref p: TParser): bool
begin
    return p.check(TOK_EOF)
end TParser::isEOF


begin
end parser_common
