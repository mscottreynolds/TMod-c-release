module Lexer(ref lexer: TLexer, source: const ^char)
(**
 * Mod-c
 * By M. Scott Reynolds
 * Date 27 July 2026
 *
 * lexer.mc - Lexer/tokenizer for Mod-c source code
 * 27 July 2026 - Conversion to .mc started.
 *)


import printf from "stdio.h"
import strlen, memcmp from "string.h"
import size_t from "stddef.h"
import from "stdbool.h"
import toupper, isalnum, isalpha, isdigit, isspace, isxdigit from "ctype.h"

(**
 * Token kinds recognized by the TMod-c lexer.
 * Ordered roughly by category for readability.
 * Updated 28 March 2026 for grammar 0.6.2
 *)
export type TokenKind = enum
	TOK_EOF = 0,				// End of file/input

	// Identifiers, literals, comments
	TOK_IDENT,
	TOK_NUMBER,
	TOK_REAL,
	TOK_CHAR,
	TOK_STRING,
	TOK_PREPROCESSOR,			// #include, #define, etc.
	TOK_COMMENT,
	TOK_COMMENT_SINGLE,			// single line comment
	TOK_COMMENT_MULTI,			// non-nesting C-style comments
	TOK_COMMENT_PASCAL,			// (* *) nesting allowed Pascal style
	TOK_DOC_COMMENT,			// /** */ or (** *) preserved document comments

	// Punctuation and delimiters
	TOK_SEMICOLON,
	TOK_COLON,
	TOK_COLON_COLON,
	TOK_COLON_EQ,
	TOK_COMMA,
	TOK_LPAREN, TOK_RPAREN,
	TOK_LBRACKET, TOK_RBRACKET,
	TOK_LBRACE, TOK_RBRACE,
	TOK_NEWLINE,
	TOK_QUESTION,

	// Arithmetic / comparison / assignment operators
	TOK_ADD,		// +
	TOK_SUB,		// -
	TOK_MUL,		// *
	TOK_DIV,		// /
	TOK_MOD,		// %
	TOK_EQ,			// =
	TOK_EQ_EQ,		// ==
	TOK_LESS_EQ,	// <=
	TOK_LESS,		// <
	TOK_GREATER_EQ,	// >=
	TOK_GREATER,	// >
	TOK_NOT_EQ,		// !=   (also supports <> via grammar)
	TOK_DOT,		// .
	TOK_DOT_DOT,	// ..
	TOK_DOT_DOT_DOT,// ... last formal (C varargs pass-through)
	TOK_NOT,		// !
	TOK_POWER,		// ** (Mod-c exponentiation)
	TOK_CARET,		// ^	pointer dereference
	TOK_AT,			// @	address-of

	// Compound assignment operators
	TOK_MUL_EQ,		// *=
	TOK_DIV_EQ,		// /=
	TOK_MOD_EQ,		// %=
	TOK_ADD_EQ,		// +=
	TOK_SUB_EQ,		// -=
	TOK_LSHIFT_EQ,	// <<=
	TOK_RSHIFT_EQ,	// >>=
	TOK_AND_EQ,		// &=
	TOK_OR_EQ,		// |=
	TOK_BITWISE_NOT_EQ,	// ~=

	// Keywords (case-insensitive in lookup, stored UPPERCASE in table)
	TOK_KEYWORD_BEGIN,
	// TOK_KEYWORD_DOUBLE,
	TOK_KEYWORD_END,
	TOK_KEYWORD_IF,
	TOK_KEYWORD_THEN,
	TOK_KEYWORD_ELSE,
	TOK_KEYWORD_ELSIF,
	// TOK_KEYWORD_FLOAT,
	TOK_KEYWORD_FOR,
	TOK_KEYWORD_TO,
	TOK_KEYWORD_BY,
	TOK_KEYWORD_DO,
	TOK_KEYWORD_DOWNTO,
	TOK_KEYWORD_PROGRAM,
	TOK_KEYWORD_MODULE,
	TOK_KEYWORD_HEADER,
	TOK_KEYWORD_IMPORT,
	TOK_KEYWORD_FROM,
	TOK_KEYWORD_PROCEDURE,
	TOK_KEYWORD_FUNCTION,
	TOK_KEYWORD_FORWARD,
	TOK_KEYWORD_EXPORT,
	TOK_KEYWORD_VAR,
	TOK_KEYWORD_LET,
	TOK_KEYWORD_COUNTOF,
	TOK_KEYWORD_CONST,
	TOK_KEYWORD_WHILE,
	TOK_KEYWORD_LOOP,
	TOK_KEYWORD_REPEAT,
	TOK_KEYWORD_UNTIL,
	TOK_KEYWORD_INC,
	TOK_KEYWORD_DEC,
	TOK_KEYWORD_TYPE,
	TOK_KEYWORD_AS,
	// TOK_KEYWORD_TYPEDEF,
	TOK_KEYWORD_CAST,
	TOK_KEYWORD_DIV,
	TOK_KEYWORD_MOD,
	TOK_KEYWORD_AND,
	TOK_KEYWORD_OR,
	TOK_KEYWORD_NOT,
	TOK_KEYWORD_XOR,
	TOK_KEYWORD_REQUIRE,
	TOK_KEYWORD_ENSURE,
	TOK_KEYWORD_INVARIANT,
	TOK_KEYWORD_SWITCH,
	TOK_KEYWORD_CASE,
	TOK_KEYWORD_DEFAULT,
	TOK_KEYWORD_BREAK,
	TOK_KEYWORD_CONTINUE,
	TOK_KEYWORD_RETURN,
	TOK_KEYWORD_DEFER,
	TOK_KEYWORD_DEBUG,
	TOK_KEYWORD_RECURSIVE,
	TOK_KEYWORD_STRUCT,
	TOK_KEYWORD_EXTENDS,
	TOK_KEYWORD_UNION,
	TOK_KEYWORD_ARRAY,
	TOK_KEYWORD_POINTER,
	TOK_KEYWORD_OPAQUE,
	TOK_KEYWORD_REF,
	TOK_KEYWORD_IN,
	TOK_KEYWORD_IS,
	TOK_KEYWORD_OF,
	TOK_KEYWORD_ENUM,
	TOK_KEYWORD_ASSERT,
	TOK_KEYWORD_SIZEOF,
	TOK_KEYWORD_EXTERN,
	TOK_KEYWORD_PACKED,
	TOK_KEYWORD_STATIC,
	TOK_KEYWORD_DEFINE,

	// Bitwise operators
	TOK_BITWISE_AND, 		// &
	TOK_BITWISE_OR,			// |
	TOK_BITWISE_NOT,		// ~
	TOK_BITWISE_LSHIFT,		// <<
	TOK_BITWISE_RSHIFT,		// >>

	TOK_ERROR,				// invalid token - error_msg is set
end


(**
 * Single token produced by the lexer.
 * Points into the original source buffer (no copying of text).
 * For TOK_ERROR, error_msg points to a static or pre-allocated error string.
 *)
export type TToken = struct
	kind: 		TokenKind
	start: 		const ^char 	// Points into source buffer.
	length: 	size_t 			// Byte length of token text
	line:		int 			// 1-based line number
	column: 	int 			// 1-based column (byte offset in line)
	error_msg: 	const ^char 	// Non-NULL only when kind == TOK_ERROR
end
export type pToken = ^TToken


(**
 * Lexer state.
 * Non-owning pointer to source buffer; does not copy or modify it.
 *)
export type TLexer = struct
	start: 		const ^char 	// Beginning of entire source
	current: 	const ^char 	// Current read position
	line: 		int
	column: 	int
end
export type pLexer = ^TLexer


(* Struct type for the keyword table *)
type TKeywordTable = struct
	keyword: const ^char
	kind: TokenKind
end

(* Alphabetical list for easy search. *)
var keyword_table: array of TKeywordTable = {
	{ "AND",        TOK_KEYWORD_AND        },
	{ "ARRAY",      TOK_KEYWORD_ARRAY      },
	{ "AS",         TOK_KEYWORD_AS         },
	{ "ASSERT", 	TOK_KEYWORD_ASSERT     },
	{ "BEGIN",      TOK_KEYWORD_BEGIN      },
	{ "BREAK",      TOK_KEYWORD_BREAK      },
	{ "BY",         TOK_KEYWORD_BY         },
	{ "CASE",       TOK_KEYWORD_CASE       },
	{ "CAST",   	TOK_KEYWORD_CAST	   },
	{ "CONST",      TOK_KEYWORD_CONST      },
	{ "CONTINUE",   TOK_KEYWORD_CONTINUE   },
	{ "COUNTOF", 	TOK_KEYWORD_COUNTOF	   },
	{ "DEBUG", 		TOK_KEYWORD_DEBUG      },
	{ "DEC",        TOK_KEYWORD_DEC        },
	{ "DEFAULT",    TOK_KEYWORD_DEFAULT    },
	{ "DEFER",      TOK_KEYWORD_DEFER      },
	{ "DEFINE",     TOK_KEYWORD_DEFINE     },
	{ "DIV",        TOK_KEYWORD_DIV        },
	{ "DO",         TOK_KEYWORD_DO         },
	// { "DOUBLE",     TOK_KEYWORD_DOUBLE	   },
	{ "DOWNTO",     TOK_KEYWORD_DOWNTO     },
	{ "ELSE",       TOK_KEYWORD_ELSE       },
	{ "ELSIF",      TOK_KEYWORD_ELSIF      },
	{ "END",        TOK_KEYWORD_END        },
	{ "ENSURE",     TOK_KEYWORD_ENSURE     },
	{ "ENUM", 		TOK_KEYWORD_ENUM	   },
	{ "EXPORT",     TOK_KEYWORD_EXPORT     },
	{ "EXTENDS",    TOK_KEYWORD_EXTENDS    },
	{ "EXTERN", 	TOK_KEYWORD_EXTERN	   },
	// { "FLOAT", 		TOK_KEYWORD_FLOAT	   },
	{ "FOR",        TOK_KEYWORD_FOR        },
	{ "FORWARD",    TOK_KEYWORD_FORWARD    },
	{ "FROM",       TOK_KEYWORD_FROM       },
	{ "FUNCTION",   TOK_KEYWORD_FUNCTION   },
	{ "IF",         TOK_KEYWORD_IF         },
	{ "IMPORT",     TOK_KEYWORD_IMPORT     },
	{ "IN",			TOK_KEYWORD_IN 		   },
	{ "INC",        TOK_KEYWORD_INC        },
	{ "INVARIANT",  TOK_KEYWORD_INVARIANT  },
	{ "IS", 		TOK_KEYWORD_IS 		   },
	{ "LET",        TOK_KEYWORD_LET        },
	{ "LOOP",       TOK_KEYWORD_LOOP       },
	{ "MOD",        TOK_KEYWORD_MOD        },
	{ "MODULE",     TOK_KEYWORD_MODULE     },
	{ "NOT",        TOK_KEYWORD_NOT        },
	{ "OF",         TOK_KEYWORD_OF         },   // future
	{ "OPAQUE",		TOK_KEYWORD_OPAQUE 	   },
	{ "OR",         TOK_KEYWORD_OR         },
	{ "PACKED", 	TOK_KEYWORD_PACKED	   },
	{ "POINTER",    TOK_KEYWORD_POINTER    },
	{ "PROCEDURE",  TOK_KEYWORD_PROCEDURE  },
	{ "PROGRAM",    TOK_KEYWORD_PROGRAM    },
	{ "RECURSIVE",  TOK_KEYWORD_RECURSIVE  },
	{ "REF",        TOK_KEYWORD_REF        },
	{ "REPEAT",     TOK_KEYWORD_REPEAT     },
	{ "REQUIRE",    TOK_KEYWORD_REQUIRE    },
	{ "RETURN",     TOK_KEYWORD_RETURN     },
	{ "SIZEOF",		TOK_KEYWORD_SIZEOF     },
	{ "STATIC",     TOK_KEYWORD_STATIC	   },
	{ "STRUCT",     TOK_KEYWORD_STRUCT     },
	{ "SWITCH",     TOK_KEYWORD_SWITCH     },
	{ "THEN",       TOK_KEYWORD_THEN       },
	{ "TO",         TOK_KEYWORD_TO         },
	{ "TYPE",       TOK_KEYWORD_TYPE       },
	{ "UNION", 		TOK_KEYWORD_UNION      },
	{ "UNTIL",      TOK_KEYWORD_UNTIL      },
	{ "VAR",        TOK_KEYWORD_VAR        },
	{ "WHILE", 		TOK_KEYWORD_WHILE	   },
	{ "XOR",		TOK_KEYWORD_XOR 	   },
}


(**
 * Initialize lexer state with source buffer.
 * Source must remain valid for the lifetime of the lexer.
 *
 * @param lexer 			Lexer state to initialize
 * @param source 			Null-terminated source code buffer.
 *)
export procedure TLexer::init(ref lexer: TLexer, source: const ^char) forward


(**
 * Get the next token from the source.
 * Advance internal position; returns TOK_EOF when exhausted.
 * Sets error_msg on TOK_ERROR.
 *)
export function TLexer::next(ref lexer: TLexer): TToken forward


(**
 * Debug: return human-readable string for a TokenKind.
 *)
export function TokenKind::string(k: TokenKind): const ^char forward


(**
 * Debug print a token (kind, location, text snippet).
 * For debugging and error reporting.
 *)
export procedure TToken::print(ref tok: TToken) forward


(* Number of entries in keyword list. *)
function NUM_KEYWORDS(): int
begin
	return (sizeof(keyword_table) / sizeof(keyword_table[0]))
end


(* Max keyword length for searching the keyword_table *)
const KEYWORD_MAX_LEN: size_t = 255
(* Source identifiers: at most 255 characters (Language Report 2.2). *)
const IDENT_MAX_LEN: size_t = 255


type uchar = unsigned char
type pcchar = const ^char


(**
 * Lookup keyword by case-insensitive comparison.
 * Keywords in table are UPPERCASE.
 * Returns TOK_IDENT if no match (preserves original case for identifiers).
 *)
function lookup_keyword(start: const ^char, length: size_t): TokenKind
begin
	var upper_token: char[KEYWORD_MAX_LEN + 1]
	var i: size_t

	if length == 0 or length > KEYWORD_MAX_LEN then
		return TOK_IDENT
	end

	for i := 1 to length do
		upper_token[i-1] := toupper(start[i-1] as uchar) as char
	end
	upper_token[length] := '\0'

	for i := 1 to NUM_KEYWORDS() do
		var kw: pcchar = keyword_table[i-1].keyword
		var kw_len: size_t = strlen(kw)

		if length == kw_len and memcmp(upper_token, kw, length) == 0 then
			return keyword_table[i-1].kind
		end
	end

	return TOK_IDENT
end lookup_keyword


(**
 * Advance offsets to the next character, updating line/column.
 *)
procedure advance(ref l: TLexer)
begin
	if l.current^ <> '\0' then
		if l.current^ == '\n' then
			inc(l.line)
			l.column := 1
		else
			inc(l.column)
		end
		inc(l.current)
	end
end advance


(**
 * Peek at the current character (safe).
 *)
function peek(ref l: TLexer): char
begin
	return l.current^
end peek


(**
 * Peek at the next character (safe at EOF).
 *)
function peek2(ref l: TLexer): char
begin
	if l.current^ == '\0' then
		return '\0'
	end
	return l.current[1]
end peek2


(**
 * Is character valid start of identifier?
 *)
function is_ident_start(c: char): bool
begin
	return isalpha(c as uchar) or c == '_'
end is_ident_start


(**
 * Is character valid inside identifier?
 *)
function is_ident_char(c: char): bool
begin
	return isalnum(c as uchar) or c == '_'
end is_ident_char


(**
 * Check for line continuation: \ followed by newline.
 *)
function is_line_continuation(ref l: TLexer): bool
begin
	return peek(l) == '\\' and (peek2(l) == '\n' or peek2(l) == '\r')
end is_line_continuation


(**
 * Match expected character and advance if it matches.
 *)
function match(ref l: TLexer, expected: char): bool
begin
	if l.current^ != expected then
		return false
	end

	advance(l)
	return true
end match


(**
 * Current char is '\'. Consume the escape. Hex is \x + two hex digits (EBNF).
 * Octal is \ + 1...3 digits 0..7. Other escapes are \ + 1 char.
 *)
function scan_char_escape(ref l: TLexer): bool
begin
	var n: integer = 0

	advance(l)
	if l.current^ == '\0' or l.current^ == '\n' then
		return false
	end

	if l.current^ == 'x' or l.current^ == 'X' then
		advance(l)
		for n := 1 to 2 do
			if not isxdigit(l.current^ as uchar) then
				return false
			end
			advance(l)
		end
		return true
	end

	if l.current^ >= '0' and l.current^ <= '7' then
		advance(l)
		if l.current^ >= '0' and l.current^ <= '7' then
			advance(l)
			if l.current^ >= '0' and l.current^ <= '7' then
				advance(l)
			end
		end
		return true
	end

	advance(l)
	return true
end scan_char_escape


(**
 * Create a zero-length token (used for single-char tokens).
 *)
function make_token(ref l: TLexer, kind: TokenKind, start: pcchar): TToken
begin
	var t: TToken
	t.kind 		:= kind
	t.start 	:= start
	t.length 	:= 0
	t.line 		:= l.line
	t.column 	:= l.column
	return t
end make_token


(**
 * Create token with explicit length.
 *)
function make_token_len(ref l: TLexer, kind: TokenKind, start: pcchar, length: size_t): TToken
begin
	var t: TToken = make_token(l, kind, start)
	t.length := length
	return t
end make_token_len


(**
 * Capture from `from` through end of line, including '\' continuations.
 * Caller supplies the identifier's start, line, and column (rewind).
 * Leaves the lexer on the terminating newline or at EOF (not consumed).
 *)
export function TLexer::capture_line_from(ref l: TLexer, from_: const ^char,
		line: int, column: int): TToken
begin
	require from_ <> nil

	l.current := from_
	l.line := line
	l.column := column

	while l.current^ <> '\0' do
		if is_line_continuation(l) then
			advance(l)
			if peek(l) == '\r' then
				advance(l)
			end
			if peek(l) == '\n' then
				advance(l)
			end
			continue
		end
		if peek(l) == '\n' then
			break
		end
		advance(l)
	end
	return make_token_len(l, TOK_IDENT, from_, (l.current - from_) as size_t)
end TLexer::capture_line_from


(**
 * Create error token.
 *)
function error_token(ref l: TLexer, msg: pcchar): TToken
begin
	var t: TToken = make_token(l, TOK_ERROR, l.current)
	t.error_msg := msg
	return t
end error_token


(**
 * Initialize lexer state.
 *)
export procedure TLexer::init(ref l: TLexer, source: const ^char)
begin
	require source <> nil

	l.start 	:= source
	l.current	:= source
	l.line 	:= 1
	l.column 	:= 1
end TLexer::init


// Editor (Sublime) parser doesn't like \' ?!?!?!
CONST SINGLE_QUOTE: char = "\'"[0]
CONST DOUBLE_QUOTE: char = "\""[0] 


(**
 * Return the next token from source
 *)
export function TLexer::next(ref l: TLexer): TToken
begin
	// Skip whitespace (except newlines) and line continuations.
	while l.current^ <> '\0' do
		if is_line_continuation(l) then
			advance(l)
			if peek(l) == '\r' then
				advance(l)
			end
			advance(l)
			continue
		end
		if isspace(l.current^ as uchar) and l.current^ <> '\n' then
			advance(l)
			continue
		end
		break
	end

	let start: const ^char = l.current
	let c: char = l.current^

	if c == '\0' then
		return make_token(l, TOK_EOF, start)
	end

	// Newline
	if c == '\n' then
		advance(l)
		return make_token(l, TOK_NEWLINE, start)
	end

	// Preprocessor directive (only at start of line)
	if c == '#' and l.column == 1 then
		while l.current^ != '\0' and l.current^ <> '\n' do
			if is_line_continuation(l) then
				advance(l)
				continue
			end
			advance(l)
		end
		return make_token_len(l, TOK_PREPROCESSOR, start, (l.current - start) as size_t)
	end


	// Identifier / keyword (case-insensitive lookup)
	if is_ident_start(c) then
		while is_ident_char(l.current^) do
			advance(l)
		end
		let length: size_t = (l.current - start) as size_t
		if length > IDENT_MAX_LEN then
			var t: TToken = make_token_len(l, TOK_ERROR, start, length)
			t.error_msg := "identifier longer than 255 characters"
			return t
		end
		return make_token_len(l, lookup_keyword(start, length), start, length)
	end

	// Number (integer only for phase 1; extend later for floats, bases, etc.)
	if isdigit(c as uchar) or
			(c == '0' and (peek2(l) == 'x' or peek2(l) == 'X' or
				peek2(l) == 'o' or peek2(l) == 'O' or
				peek2(l) == 'b' or peek2(l) == 'B')) then
		// 0x, 0X, 0o, 0O, 0b, 0B pefix
		if c == '0' and (peek2(l) == 'x' or peek2(l) == 'X' or
				peek2(l) == 'o' or peek2(l) == 'O' or
				peek2(l) == 'b' or peek2(l) == 'B') then
			DEBUG printf("DEBUG: {TOK_NUMBER=%.*s}\n", 2, start)
			advance(l)			// consume 0
			advance(l)			// consume x/o/b
		end

		while isdigit(l.current^ as uchar) or
				l.current^ == '_' or l.current^ == '.' or
				l.current^ == 'u' or l.current^ == 'U' or 		// unsigned
				l.current^ == 'l' or l.current^ == 'L' or 		// long
				(l.current^ >= 'a' and l.current^ <= 'f') or
				(l.current^ >= 'A' and l.current^ <= 'F') do
			advance(l)
		end
		return make_token_len(l, TOK_NUMBER, start, (l.current - start) as size_t)
	end

	// Character literal
	if c == SINGLE_QUOTE then
		advance(l)
		if l.current^ == '\0' or l.current^ == '\n' then
			return error_token(l, "TLexer::next: Unterminated character literal.")
		end
		// if l.current^ == '\\' then advance(l); end 		// skip escape
		// advance(l)
		if l.current^ == '\\' then
			if not scan_char_escape(l) then
				return error_token(l, "TLexer::next: Invalid character escape.")
			end
		else
			advance(l)
		end
		if not match(l, SINGLE_QUOTE) then
			return error_token(l, "TLexer::next: Unterminated character literal.")
		end
		return make_token_len(l, TOK_CHAR, start, (l.current - start) as size_t)
	end

	// String literal
	if c == DOUBLE_QUOTE then
		advance(l)
		while l.current^ <> '\0' and l.current^ <> DOUBLE_QUOTE do
			if l.current^ == '\\' and peek2(l) == DOUBLE_QUOTE then
				advance(l)
			elsif l.current^ == '\\' and peek2(l) == '\\' then
				advance(l)
			elsif l.current^ == '\n' then
				return error_token(l, "TLexer::next: Unterminated string literal.")
			end
			advance(l)
		end
		if l.current^ <> DOUBLE_QUOTE then
			return error_token(l, "TLexer::next: Unterminated string literal,")
		end
		advance(l)
		return make_token_len(l, TOK_STRING, start, (l.current - start) as size_t)
	end

	// Single-line comment
	if c == '/' and peek2(l) == '/' then
		advance(l)
		advance(l)
		while l.current^ and l.current^ <> '\n' do
			advance(l)
		end
		return make_token_len(l, TOK_COMMENT_SINGLE, start, (l.current - start) as size_t)
	end

	// Multi-line comment, C-style, non-nesting
	if c == '/' and peek2(l) == '*' then
		advance(l)
		advance(l)

		let is_doc: bool = peek(l) == '*'		// /** ... */

		while l.current^ <> '\0' do
			if l.current^ == '*' and peek2(l) == '/' then
				advance(l)
				advance(l)
				break
			end
			advance(l)
		end
		if l.current^ == '\0' then
			return error_token(l, "TLexer::next: Unterminated multi-line comment. /* */")
		end

		return make_token_len(l, (is_doc ? TOK_DOC_COMMENT : TOK_COMMENT_MULTI), 
			start, (l.current - start) as size_t)
	end

	// Pascal-style comments (* ... *) supports nesting
	if c == '(' and peek2(l) == '*' then
		var nesting: integer
		advance(l)
		advance(l)

		let is_doc: bool = peek(l) == '*' 		// (** ... *)

		nesting := 1
		while l.current^ <> '\0' and nesting > 0 do
			if l.current^ == '(' and peek2(l) == '*' then
				inc(nesting)
				advance(l)
				advance(l)
				continue
			end
			if l.current^ == '*' and peek2(l) == ')' then
				dec(nesting)
				advance(l)
				advance(l)
				continue
			end
			advance(l)
		end
		if nesting > 0 then
			return error_token(l, "TLexer::next: Unterminated Pascal-style comment (* *)")
		end
		return make_token_len(l, (is_doc ? TOK_DOC_COMMENT : TOK_COMMENT_PASCAL),
			start, (l.current - start) as size_t)
	end

	// Operators and punctuation (including compound assignments)
	switch c of
		case '(': advance(l); return make_token_len(l, TOK_LPAREN, start, 1)
		case ')': advance(l); return make_token_len(l, TOK_RPAREN, start, 1)
		case '{': advance(l); return make_token_len(l, TOK_LBRACE, start, 1)
		case '}': advance(l); return make_token_len(l, TOK_RBRACE, start, 1)
		case '[': advance(l); return make_token_len(l, TOK_LBRACKET, start, 1)
		case ']': advance(l); return make_token_len(l, TOK_RBRACKET, start, 1)
		case ';': advance(l); return make_token_len(l, TOK_SEMICOLON, start, 1)
		case ',': advance(l); return make_token_len(l, TOK_COMMA, start, 1)
		case '+':
			advance(l)
			if match(l, '=') then
				return make_token_len(l, TOK_ADD_EQ, start, 2)
			else
				return make_token_len(l, TOK_ADD, start, 1)
			end
		case '-':
			advance(l)
			if match(l, '=') then
				return make_token_len(l, TOK_SUB_EQ, start, 2)
			else
				return make_token_len(l, TOK_SUB, start, 1)
			end
		case '*':
			advance(l)
			if match(l, '*') then return make_token_len(l, TOK_POWER, start, 2); end
			if match(l, '=') then return make_token_len(l, TOK_MUL_EQ, start, 2); end
			return make_token_len(l, TOK_MUL, start, 1)
		case '/':
			advance(l)
			if match(l, '=') then 
				return make_token_len(l, TOK_DIV_EQ, start, 2)
			else
				return make_token_len(l, TOK_DIV, start, 1)
			end
		case '%':
			advance(l)
			if match(l, '=') then
				return make_token_len(l, TOK_MOD_EQ, start, 2)
			else
				return make_token_len(l, TOK_MOD, start, 1)
			end
		case '=':
			advance(l)
			if match(l, '=') then
				return make_token_len(l, TOK_EQ_EQ, start, 2)
			else
				return make_token_len(l, TOK_EQ, start, 1)
			end
		case '!':
			advance(l)
			if match(l, '=') then
				return make_token_len(l, TOK_NOT_EQ, start, 2)
			else
				return make_token_len(l, TOK_NOT, start, 1)
			end
		case '<':
			advance(l)
			if match(l, '<') then
				if match(l, '=') then
					return make_token_len(l, TOK_LSHIFT_EQ, start, 3)
				else
					return make_token_len(l, TOK_BITWISE_LSHIFT, start, 2)
				end
			elsif match(l, '>') then
				return make_token_len(l, TOK_NOT_EQ, start, 2)		// same as !=
			elsif match(l, '=') then
				return make_token_len(l, TOK_LESS_EQ, start, 2)
			else
				return make_token_len(l, TOK_LESS, start, 1)
			end
		case '>':
			advance(l)
			if match(l, '>') then
				if match(l, '=') then
					return make_token_len(l, TOK_RSHIFT_EQ, start, 3)
				else
					return make_token_len(l, TOK_BITWISE_RSHIFT, start, 2)
				end
			elsif match(l, '=') then
				return make_token_len(l, TOK_GREATER_EQ, start, 2)
			else
				return make_token_len(l, TOK_GREATER, start, 1)
			end
		case ':':
			advance(l)
			if match(l, ':') then
				return make_token_len(l, TOK_COLON_COLON, start, 2)
			elsif match(l, '=') then
				return make_token_len(l, TOK_COLON_EQ, start, 2)
			else
				return make_token_len(l, TOK_COLON, start, 1)
			end
		case '.':
			advance(l)
			if match(l, '.') then
				if match(l, '.') then
					return make_token_len(l, TOK_DOT_DOT_DOT, start, 3)
				else
					return make_token_len(l, TOK_DOT_DOT, start, 2)
				end
			else
				return make_token_len(l, TOK_DOT, start, 1)
			end
		case '&':
			advance(l)
			if match(l, '&') then
				return make_token_len(l, TOK_KEYWORD_AND, start, 2)		// logical AND
			elsif match(l, '=') then
				return make_token_len(l, TOK_AND_EQ, start, 2)
			else
				return make_token_len(l, TOK_BITWISE_AND, start, 1)
			end
		case '|':
			advance(l)
			if match(l, '|') then
				return make_token_len(l, TOK_KEYWORD_OR, start, 2)		// logical OR
			elsif match(l, '=') then
				return make_token_len(l, TOK_OR_EQ, start, 2)
			else
				return make_token_len(l, TOK_BITWISE_OR, start, 1)
			end
		case '^': advance(l); return make_token_len(l, TOK_CARET, start, 1)
		case '~': advance(l); return make_token_len(l, TOK_BITWISE_NOT, start, 1)
		case '?': advance(l); return make_token_len(l, TOK_QUESTION, start, 1)
		case '@': advance(l); return make_token_len(l, TOK_AT, start, 1)

		else: 
			advance(l)
			return error_token(l, "TLexer::next: Unexpected character")
	end
end TLexer::next


(**
 * Return human-readable string for TokenKind.
 *)
export function TokenKind::string(k: const TokenKind): const ^char
begin
	switch k of
		case TOK_EOF:               return "EOF"
		case TOK_IDENT:             return "IDENT"
		case TOK_NUMBER:            return "NUMBER"
		case TOK_REAL:				return "REAL"
		case TOK_CHAR:              return "CHAR"
		case TOK_STRING:            return "STRING"
		case TOK_PREPROCESSOR:      return "PREPROC"
		case TOK_COMMENT:           return "COMMENT"
		case TOK_COMMENT_SINGLE:	return "// COMMENT"
		case TOK_COMMENT_MULTI:		return "/* COMMENT */"
		case TOK_COMMENT_PASCAL:	return "(* COMMENT *)"
		case TOK_DOC_COMMENT:		return "/** DOC COMMENT */"
		case TOK_NEWLINE:           return "NEWLINE"
		case TOK_SEMICOLON:         return ";"
		case TOK_COLON:             return ":"
		case TOK_COLON_COLON:       return "::"
		case TOK_COLON_EQ:          return ":="
		case TOK_COMMA:             return ","
		case TOK_LPAREN:            return "("
		case TOK_RPAREN:            return ")"
		case TOK_LBRACKET:          return "["
		case TOK_RBRACKET:          return "]"
		case TOK_LBRACE:            return "{"
		case TOK_RBRACE:            return "}"
		case TOK_QUESTION:          return "?"
		case TOK_ADD:               return "+"
		case TOK_SUB:               return "-"
		case TOK_MUL:               return "*"
		case TOK_DIV:               return "/"
		case TOK_MOD:               return "%"
		case TOK_CARET:				return "^"
		case TOK_AT:				return "@"
		case TOK_EQ:                return "="
		case TOK_EQ_EQ:             return "=="
		case TOK_LESS_EQ:           return "<="
		case TOK_LESS:              return "<"
		case TOK_GREATER_EQ:        return ">="
		case TOK_GREATER:           return ">"
		case TOK_NOT_EQ:            return "!="
		case TOK_DOT:               return "."
		case TOK_DOT_DOT:           return ".."
		case TOK_DOT_DOT_DOT:       return "..."
		case TOK_NOT:               return "!"
		case TOK_POWER:             return "**"
		case TOK_MUL_EQ:            return "*="
		case TOK_DIV_EQ:            return "/="
		case TOK_MOD_EQ:            return "%="
		case TOK_ADD_EQ:            return "+="
		case TOK_SUB_EQ:            return "-="
		case TOK_LSHIFT_EQ:         return "<<="
		case TOK_RSHIFT_EQ:         return ">>="
		case TOK_AND_EQ:            return "&="
		case TOK_OR_EQ:             return "|="
		case TOK_BITWISE_NOT_EQ:	return "~|"
		case TOK_KEYWORD_BEGIN:     return "BEGIN"
		case TOK_KEYWORD_END:       return "END"
		case TOK_KEYWORD_IF:        return "IF"
		case TOK_KEYWORD_THEN:      return "THEN"
		case TOK_KEYWORD_ELSE:      return "ELSE"
		case TOK_KEYWORD_ELSIF:     return "ELSIF"
		case TOK_KEYWORD_FOR:       return "FOR"
		case TOK_KEYWORD_TO:        return "TO"
		case TOK_KEYWORD_BY:        return "BY"
		case TOK_KEYWORD_DO:        return "DO"
		case TOK_KEYWORD_DOWNTO:    return "DOWNTO"
		case TOK_KEYWORD_PROGRAM:   return "PROGRAM"
		case TOK_KEYWORD_MODULE:    return "MODULE"
		case TOK_KEYWORD_HEADER:	return "HEADER"
		case TOK_KEYWORD_IMPORT:    return "IMPORT"
		case TOK_KEYWORD_FROM:      return "FROM"
		case TOK_KEYWORD_PROCEDURE: return "PROCEDURE"
		case TOK_KEYWORD_FUNCTION:  return "FUNCTION"
		case TOK_KEYWORD_FORWARD:	return "FORWARD"
		case TOK_KEYWORD_EXPORT:    return "EXPORT"
		case TOK_KEYWORD_VAR:       return "VAR"
		case TOK_KEYWORD_COUNTOF:	return "COUNTOF"
		case TOK_KEYWORD_LET:       return "LET"
		case TOK_KEYWORD_CONST:     return "CONST"
		case TOK_KEYWORD_WHILE:		return "WHILE"
		case TOK_KEYWORD_LOOP:      return "LOOP"
		case TOK_KEYWORD_REPEAT:    return "REPEAT"
		case TOK_KEYWORD_UNTIL:     return "UNTIL"
		case TOK_KEYWORD_INC:       return "INC"
		case TOK_KEYWORD_DEC:       return "DEC"
		case TOK_KEYWORD_TYPE:      return "TYPE"
		case TOK_KEYWORD_AS:        return "AS"
		case TOK_KEYWORD_CAST:		return "CAST"
		case TOK_KEYWORD_DIV:       return "DIV"
		case TOK_KEYWORD_MOD:       return "MOD"
		case TOK_KEYWORD_XOR:		return "XOR"
		case TOK_KEYWORD_AND:       return "AND"
		case TOK_KEYWORD_OF:		return "OF"
		case TOK_KEYWORD_OR:        return "OR"
		case TOK_KEYWORD_NOT:       return "NOT"
		case TOK_KEYWORD_REQUIRE:   return "REQUIRE"
		case TOK_KEYWORD_ENSURE:    return "ENSURE"
		case TOK_KEYWORD_INVARIANT: return "INVARIANT"
		case TOK_KEYWORD_SWITCH:    return "SWITCH"
		case TOK_KEYWORD_CASE:      return "CASE"
		case TOK_KEYWORD_DEFAULT:   return "DEFAULT"
		case TOK_KEYWORD_BREAK:     return "BREAK"
		case TOK_KEYWORD_CONTINUE:  return "CONTINUE"
		case TOK_KEYWORD_RETURN:    return "RETURN"
		case TOK_KEYWORD_DEFER:     return "DEFER"
		case TOK_KEYWORD_DEBUG:		return "DEBUG"
		case TOK_KEYWORD_RECURSIVE: return "RECURSIVE"
		case TOK_KEYWORD_STRUCT:    return "STRUCT"
		case TOK_KEYWORD_EXTENDS:   return "EXTENDS"
		// case TOK_KEYWORD_DOUBLE:	return "DOUBLE"
		// case TOK_KEYWORD_FLOAT:		return "FLOAT"
		case TOK_KEYWORD_ARRAY:     return "ARRAY"
		case TOK_KEYWORD_POINTER:   return "POINTER"
		case TOK_KEYWORD_OPAQUE:	return "OPAQUE"
		case TOK_KEYWORD_REF:       return "REF"
		case TOK_KEYWORD_IN: 		return "IN"
		case TOK_KEYWORD_IS:		return "IS"
		case TOK_KEYWORD_ENUM:		return "ENUM"
		case TOK_KEYWORD_ASSERT:	return "ASSERT"
		case TOK_KEYWORD_SIZEOF:	return "SIZEOF"
		case TOK_KEYWORD_EXTERN:	return "EXTERN"
		case TOK_KEYWORD_STATIC:	return "STATIC"
		case TOK_KEYWORD_PACKED:	return "PACKED"
		case TOK_KEYWORD_DEFINE: 	return "DEFINE"
		case TOK_BITWISE_AND:       return "&"
		case TOK_BITWISE_OR:        return "|"
		case TOK_BITWISE_NOT:       return "~"
		case TOK_BITWISE_LSHIFT:    return "<<"
		case TOK_BITWISE_RSHIFT:    return ">>"
		case TOK_ERROR:             return "ERROR"
		else:                    	return "UNKNOWN"
	end
end TokenKind::string


(**
 * Print token info.
 *)
export procedure TToken::print(ref t: const TToken)
begin
	// if t == nil then
	// 	printf("<NULL token>\n")
	// 	return
	// end

	let kind_name: const ^char = t.kind.string()
	// TokenKind::string(t.kind)

	printf("Token { kind: '%-12s', line: %3d, column: %3d, ", kind_name, t.line, t.column)
	if t.length > 0 and t.start <> nil then
		printf("text: '%.*s', ", t.length as int, t.start)
	else
		printf("text: %s, ", "''")
	end
	if t.kind == TOK_ERROR and t.error_msg <> nil then
		printf("\terror_msg: '%s', ", t.error_msg)
	else
		printf("\terror_msg: '', ")
	end
	printf(" }, \n")
end TToken::print


begin
	lexer.init(source)
	// lexer^.init(source)
	// TLexer::init(lexer^, source)
end Lexer
