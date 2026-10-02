module expression()
(**
 * Mod-c
 * By M. Scott Reynolds
 * Date 20 July 2026
 *
 * expression.mc - Expression parsing routines.
 *)

import TParser, pParser, advance, match, error_at, check, consume, isEOF, matchEOS,
	skip_layout_breaks,
    from parser_common

import TParser::parse_designator, TParser::parse_expr, TParser::parse_parameter_type, 
	TParser::parse_return_type, TParser::is_user_type_name,
	from parser_main

// import parse_designator,
// 	parse_expr, parse_parameter_type, parse_return_type, parser_is_user_type_name,
// 	skip_layout_breaks, from "parser.h"

import Arena, pvoid, ppvoid, arena_append_ptr, 
	from arena
import type_is_builtin_name, TType 
	from ttype
import NODE_TERNARY, NODE_BINARY, NODE_SIZEOF, NODE_INC, NODE_DEC, NODE_UNARY,
	NODE_CAST, NODE_FIELD_ACCESS, NODE_CALL, NODE_IDENT, NODE_LITERAL, NODE_PAREN,
	NODE_ARRAY_LITERAL, NODE_ARRAY_INDEX, node_create, Node, NODE_COUNTOF,
	from "node.h"
import TOK_QUESTION, TOK_COLON, TOK_KEYWORD_OR, TOK_KEYWORD_AND, TOK_EQ_EQ, TOK_NOT_EQ, 
	TOK_LESS, TOK_LESS_EQ, TOK_GREATER, TOK_GREATER_EQ, TOK_BITWISE_LSHIFT, TOK_BITWISE_RSHIFT,
	TOK_ADD, TOK_SUB, TOK_BITWISE_OR, TOK_KEYWORD_XOR, TOK_MUL, TOK_DIV, TOK_MOD,
	TOK_KEYWORD_MOD, TOK_BITWISE_AND, TOK_KEYWORD_DIV, TOK_POWER, TOK_CARET,
	TOK_KEYWORD_POINTER, TOK_KEYWORD_CONST, TOK_KEYWORD_ARRAY, TOK_IDENT, TOK_KEYWORD_SIZEOF,
	TOK_LPAREN, TOK_RPAREN, TOK_KEYWORD_INC, TOK_KEYWORD_DEC, TOK_COMMA, TOK_NOT,
	TOK_KEYWORD_NOT, TOK_BITWISE_NOT, TOK_AT, TOK_KEYWORD_CAST, TOK_KEYWORD_AS,
	TOK_EOF, TOK_LBRACKET, TOK_RBRACKET, TOK_DOT, TOK_COLON_COLON, TOK_STRING,
	TOK_NUMBER, TOK_CHAR, TOK_LBRACE, TOK_RBRACE, TToken, TokenKind, TOK_KEYWORD_COUNTOF,
	from Lexer


// import from "string.h"

export type pNode = ^Node
// export type pParser = ^Parser


(* ======================================================================
 * parse_assignment is intentionally disabled.
 *
 * Decided to deliberately not allow assignments in expressions
 * (see grammar.md and the decision recorded in CURRENT.md, June 2026).
 * 
 * If future work ever wants to re-enable limited forms (e.g. only in
 * specific contexts), this funciton + the assignment-expression
 * grammar production would be the place to start.
 * =======================================================================
 *
 * Node *parse_assignment(Parser *p) {
 * 	Node *left = parse_conditional(p);
 * 
 * 	if (match(p, TOK_COLON_EQ)) {
 * 		Node *right = parse_assignment(p);		// right associative
 * 
 * 		if (right == NULL) {
 * 			error_at(p, "expected expression after :=", true);
 * 		}
 * 
 * 		Node *assign = node_create(p->arena, NODE_ASSIGN, left->token);
 * 		assign->binary.left 	= left;
 * 		assign->binary.right 	= right;
 * 		assign->binary.op 		= TOK_COLON_EQ;
 * 		return assign;
 * 	}
 * 
 * 	return left;
 * }
 *)


(**
 * Parse conditional
 *)
export recursive function parse_conditional(p: pParser): ^Node
begin
	require p <> nil

	var cond: ^Node = parse_logical_or(p)

	if match(p, TOK_QUESTION) then
		var then_expr: ^Node = nil
		var else_expr: ^Node = nil
		var ternary: ^Node = nil

		then_expr := TParser::parse_expr(p^)
		consume(p, TOK_COLON, "parse_conditional: expected ':' after ternary then branch")

		else_expr := parse_conditional(p)

		ternary := node_create(p^.arena, NODE_TERNARY, cond^.token)
		ternary^.ternary.cond 		:= cond
		ternary^.ternary.then_expr	:= then_expr
		ternary^.ternary.else_expr 	:= else_expr
		return ternary
	end

	return cond
end parse_conditional


(**
 * Parse logical OR
 *)
export function parse_logical_or(p: pParser): ^Node
begin
	require p <> nil

	var left: ^Node = parse_logical_and(p)

	while match(p, TOK_KEYWORD_OR) do
		var right: ^Node = nil
		var binary: ^Node = nil

		right := parse_logical_and(p)
		if right == nil then
			error_at(p, "parse_logical_or: expected expression after OR", true)
		end

		binary := node_create(p^.arena, NODE_BINARY, left^.token)
		binary^.binary.left 	:= left
		binary^.binary.right	:= right
		binary^.binary.op 		:= TOK_KEYWORD_OR

		left := binary
	end

	return left
end parse_logical_or


(**
 * Parse logical AND
 *)
export function parse_logical_and(p: pParser): ^Node
begin
	require p <> nil

	var left: ^Node = parse_equality(p)

	while match(p, TOK_KEYWORD_AND) do
		var right: ^Node = nil
		var binary: ^Node = nil

		right := parse_equality(p)
		if right == nil then
			error_at(p, "parse_logical_and: expected expression after AND", true)
		end

		binary := node_create(p^.arena, NODE_BINARY, left^.token)
		binary^.binary.left 	:= left
		binary^.binary.right	:= right
		binary^.binary.op 		:= TOK_KEYWORD_AND

		left := binary
	end

	return left
end parse_logical_end


(**
 * Parse equality
 *)
export function parse_equality(p: pParser): ^Node
begin
	require p <> nil

	var left: ^Node = parse_relational(p)

	while true do
		var op: TokenKind = p^.current.kind
		if op == TOK_EQ_EQ or op == TOK_NOT_EQ then
			var right: ^Node = nil
			var binary: ^Node = nil

			advance(p)

			right := parse_relational(p)
			if right == nil then
				error_at(p, "parse_equality: expected expression after equality operator", true)
			end

			binary := node_create(p^.arena, NODE_BINARY, left^.token)
			binary^.binary.left 	:= left;
			binary^.binary.right 	:= right
			binary^.binary.op 		:= op

			left := binary
		else
			break
		end
	end

	return left
end parse_equality


(**
 * Parse relational
 *)
export function parse_relational(p: pParser): ^Node
begin
	require p <> nil

	var left: ^Node = parse_shift(p)

	while true do
		var op: TokenKind = p^.current.kind

		if op == TOK_LESS or op == TOK_LESS_EQ or
				op == TOK_GREATER or op == TOK_GREATER_EQ then
			var right: ^Node = nil
			var binary: ^Node = nil

			advance(p)

			right := parse_shift(p)
			if right == nil then
				error_at(p, "parse_relational: expected expression after relational operator", true)
			end

			binary := node_create(p^.arena, NODE_BINARY, left^.token)
			binary^.binary.left 	:= left
			binary^.binary.right 	:= right
			binary^.binary.op 		:= op

			left := binary
		else
			break
		end
	end

	return left
end parse_relational


(**
 * Parse shift
 *)
export function parse_shift(p: pParser): ^Node
begin
	require p <> nil

	var left: ^Node = parse_additive(p)

	while true do
		var op: TokenKind = p^.current.kind

		if op == TOK_BITWISE_LSHIFT or op == TOK_BITWISE_RSHIFT then
			var right: ^Node = nil
			var binary: ^Node = nil

			advance(p)

			right := parse_additive(p)
			if right == nil then
				error_at(p, "parse_shift: expected expression after shift operator", true)
			end

			binary := node_create(p^.arena, NODE_BINARY, left^.token)
			binary^.binary.left 	:= left
			binary^.binary.right 	:= right
			binary^.binary.op 		:= op

			left := binary
		else
			break
		end
	end

	return left
end parse_shift


(**
 * Parse additive
 *)
export function parse_additive(p: pParser): ^Node
begin
	require p <> nil

	var left: ^Node = parse_multiplicative(p)

	while true do
		var op: TokenKind = p^.current.kind
		if op == TOK_ADD or op == TOK_SUB or
				op == TOK_BITWISE_OR or op == TOK_KEYWORD_XOR then
			var right: ^Node = nil
			var binary: ^Node = nil

			advance(p)

			right := parse_multiplicative(p)
			if right == nil then
				error_at(p, "parse_additive: expected expression after additive operator", true)
			end

			binary := node_create(p^.arena, NODE_BINARY, left^.token)
			binary^.binary.left 	:= left
			binary^.binary.right 	:= right
			binary^.binary.op 		:= op

			left := binary
		else
			break
		end
	end

	return left
end parse_additive


(**
 * Parse multiplicative
 *)
export function parse_multiplicative(p: pParser): ^Node
begin
	require p <> nil

	var left: ^Node = parse_power(p)

	while true do
		var op: TokenKind = p^.current.kind

		if op == TOK_MUL or op == TOK_DIV or
				op == TOK_MOD or op == TOK_KEYWORD_MOD or 
				op == TOK_BITWISE_AND or op == TOK_KEYWORD_DIV then
			var right: ^Node = nil
			var binary: ^Node = nil

			advance(p)

			right := parse_power(p)
			if right == nil then
				error_at(p, "parse_multiplicative: expected expression after multiplicative", true)
			end

			binary := node_create(p^.arena, NODE_BINARY, left^.token)
			binary^.binary.left 	:= left
			binary^.binary.right 	:= right
			binary^.binary.op 		:= op

			left := binary
		else
			break
		end
	end

	return left
end parse_multiplicative


(**
 * Parse Power
 *)
export recursive function parse_power(p: pParser): ^Node
begin
	require p <> nil

	var left: ^Node = parse_unary(p)

	if match(p, TOK_POWER) then
		var right: ^Node = parse_power(p)		// right associative
		var binary: ^Node = nil

		if right == nil then
			error_at(p, "parse_power: expected expression after **", true)
		end

		binary := node_create(p^.arena, NODE_BINARY, left^.token)
		binary^.binary.left 	:= left
		binary^.binary.right	:= right
		binary^.binary.op 		:= TOK_POWER

		return binary
	end

	return left
end parse_power


(**
 * True when SIZEOF '(' or COUNTOF '(' should parse a type-specifier, not a designator.
 *)
function parser_sizeof_operand_is_type(p: pParser): bool
begin
	require p <> nil

	if p^.current.kind == TOK_CARET or
			p^.current.kind == TOK_KEYWORD_POINTER or
			p^.current.kind == TOK_KEYWORD_CONST or
			p^.current.kind == TOK_KEYWORD_ARRAY then
		return true
	end
	if p^.current.kind == TOK_IDENT then
		return type_is_builtin_name(p^.current.start, p^.current.length) or
			TParser::is_user_type_name(p^, p^.current.start, p^.current.length)
	end
	return false
end parser_sizeof_operand_is_type


(**
 * Parse SIZEOF expression
 * 	Grammar: "SIZEOF" "(" ( type-identifier | designator ) ")" 
 *)
export function parse_sizeof(p: pParser): pNode
begin
	require p <> nil

	var tok: TToken = p^.current
	var n: ^Node = nil;

	consume(p, TOK_KEYWORD_SIZEOF, "parse_sizeof: expected SIZEOF")
	consume(p, TOK_LPAREN, "parse_sizeof: expected '(' afer SIZEOF")

	n := node_create(p^.arena, NODE_SIZEOF, tok)
	if parser_sizeof_operand_is_type(p) then
		n^.sizeof_expr.is_type := true
		n^.sizeof_expr.target.sizeof_type := TParser::parse_return_type(p^)
	else
		var designator: ^Node = TParser::parse_designator(p^)
		if designator == nil then
			error_at(p, "parse_sizeof: expected type or designator inside SIZEOF", true)
		end
		n^.sizeof_expr.is_type := false
		n^.sizeof_expr.target.designator := designator
	end

	consume(p, TOK_RPAREN, "parse_sizeof: expected ')' after SIZEOF")

	return n	
end parse_sizeof


(**
 * Parse COUNTOF.
 * Grammar: "COUNTOF" "(" ( type-specifier | designator ) ")"
 *)
export function parse_countof(p: pParser): pNode
begin
	require p <> nil

	var tok: TToken = p^.current
	var n: ^Node = nil

	consume(p, TOK_KEYWORD_COUNTOF, "parse_countof: expected COUNTOF")
	consume(p, TOK_LPAREN, "parse_countof: expected '(' after COUNTOF")

	n := node_create(p^.arena, NODE_COUNTOF, tok)
	if parser_sizeof_operand_is_type(p) then
		n^.sizeof_expr.is_type := true
		n^.sizeof_expr.target.sizeof_type := TParser::parse_return_type(p^)
	else
		var designator: ^Node = TParser::parse_designator(p^)
		if designator == nil then
			error_at(p, "parse_countof: expected type or designator inside COUNTOF", true)
		end
		n^.sizeof_expr.is_type := false
		n^.sizeof_expr.target.designator := designator
	end
	consume(p, TOK_RPAREN, "parse_countof: expected ')' after COUNTOF")
	return n
end parse_countof


(**
 * Parse INC / DEC as either statement or expression.
 * When used in expressions, the code generator will add protective
 * parentheses around compound forms to preserve precedence.
 *
 * Grammar (expression form):
 * 		inc-dec-expr = "INC" "(" designator [ "," expression ] ")"
 * 					 | "DEC" "(" designator [ "," expression ] ")"
 *)
export function parse_inc_dec_expr(p: pParser): pNode
begin
	require p <> nil

	var tok: TToken = p^.current
	var is_inc: bool = match(p, TOK_KEYWORD_INC)
	var designator: ^Node = nil
	var step: ^Node = nil
	var n: ^Node = nil

	if not is_inc then
		consume(p, TOK_KEYWORD_DEC, "parse_inc_dec_expr: expected INC or DEC")
	end

	consume(p, TOK_LPAREN, "parse_inc_dec_expr: expected '(' after INC/DEC")

	designator := TParser::parse_designator(p^)
	if designator == nil then
		error_at(p, "parse_inc_dec_expr: expected designator in INC/DEC", true)
	end

	if match(p, TOK_COMMA) then
		step := TParser::parse_expr(p^)
		if step == nil then
			error_at(p, "parse_inc_dec_expr: expected expression after comma in INC/DEC", true)
		end
	end

	consume(p, TOK_RPAREN, "parse_inc_dec_expr: expected ')' after INC/DEC arguments")

	n := node_create(p^.arena, is_inc ? NODE_INC : NODE_DEC, tok)
	n^.binary.left 	:= designator
	n^.binary.right := step
	n^.binary.op 	:= is_inc ? TOK_ADD : TOK_SUB

	return n
end parse_inc_dec_expr


(**
 * Parse unary
 *)
export recursive function parse_unary(p: pParser): ^Node
begin
	require p <> nil

	var op: TokenKind = {0}

	skip_layout_breaks(p)

	op := p^.current.kind

	// SIZEOF is a unary prefix operator (same level as C's sizeof)
	if op == TOK_KEYWORD_SIZEOF then
		return parse_sizeof(p)
	end
	if op == TOK_KEYWORD_COUNTOF then
		return parse_countof(p)
	end

	// INC / DEC as expression
	if op == TOK_KEYWORD_INC or op == TOK_KEYWORD_DEC then
		return parse_inc_dec_expr(p)
	end

	if op == TOK_NOT or op == TOK_SUB or op == TOK_ADD or
			op == TOK_KEYWORD_NOT or op == TOK_BITWISE_NOT or 
			op == TOK_AT then 		// @ = address-of
		var tok: TToken = {0}
		var operand: ^Node = nil
		var unary: ^Node = nil

		tok := p^.current
		advance(p)

		operand := parse_unary(p)
		if operand == nil then
			error_at(p, "parse_unary: expected expression after unary operator", true)
		end

		unary := node_create(p^.arena, NODE_UNARY, tok)
		unary^.unary.operand 	:= operand
		unary^.unary.op 		:= op

		return unary
	end

	return parse_cast(p)
end parse_unary


(**
 * Parse cast expression
 * Grammar:
 * 	cast-expression = "CAST" "(" type-specifier "," expression ")"
 * 		| postfix-expression "AS" type-specifier 
 * 		| postfix-expression ;
 *)
export function parse_cast(p: pParser): ^Node
begin
	require p <> nil

	var expr: pointer to Node

	if match(p, TOK_KEYWORD_CAST) then
		var target: pointer to TType
		var e: pointer to Node
		var cast_node: pointer to Node

		consume(p, TOK_LPAREN, "parse_cast: expected '(' after CAST")

		target := TParser::parse_parameter_type(p^)
		consume(p, TOK_COMMA, "parse_cast: expected ',' after type in CAST")

		e := TParser::parse_expr(p^)
		consume(p, TOK_RPAREN, "parse_cast: expected ')' after CAST expression")

		cast_node := node_create(p^.arena, NODE_CAST, p^.current)
		cast_node^.cast_expr.expr 			:= e
		cast_node^.cast_expr.target_type 	:= target

		return cast_node
	end

	// Normal expression + possible "AS" cast
	expr := parse_postfix(p)
	if expr == nil then
		return nil
	end

	if match(p, TOK_KEYWORD_AS) then
		var target: pointer to TType
		var cast_node: pointer to Node

		target := TParser::parse_parameter_type(p^)

		cast_node := node_create(p^.arena, NODE_CAST, expr^.token)
		cast_node^.cast_expr.expr 			:= expr
		cast_node^.cast_expr.target_type 	:= target

		return cast_node
	end

	return expr
end parse_cast


(**
 * Parse comma-separated argument list into an existing NODE_CALL.
 * Caller must have already consumed '('.
 *)
procedure parse_call_arguments(p: pParser, call: pNode)
begin
	require p <> nil

	while not check(p, TOK_RPAREN) and not check(p, TOK_EOF) do
		var arg: pNode = TParser::parse_expr(p^)

		if arg == nil then
			error_at(p, "parse_call_arguments: expected expression as function argument", true)
		end

		arena_append_ptr(p^.arena, 
				(@call^.call.args) as ppvoid,
				@call^.call.argc,
				@call^.call.arg_capacity,
				arg)

		if not match(p, TOK_COMMA) then
			break
		end
	end

	consume(p, TOK_RPAREN, "parse_call_arguments: expected ')' after function call arguments")
end parse_call_arguments


(**
 * Parse postfix
 *)
export function parse_postfix(p: pParser): pNode
begin
	require p <> nil

	var expr: pNode = parse_primary(p)
	
	if expr == nil then
		error_at(p, "parse_postfix: expected expression", true)
	end

	while true do
		// if match(p, TOK_LPAREN) then
		// 	expr := parse_call(p, expr^.token)
		// Call: base callee uses parse_call; field + '(' is instance sugar
		// obj.method(args) => NODE_CALL with receiver_expr = obj (method_owner)
		// filled later by semantic). Use check, not match: parse_call /
		// consume own the '('. 
		if check(p, TOK_LPAREN) then
			if expr^.kind == NODE_FIELD_ACCESS then
				var call: pNode = nil
				var recv: pNode = expr^.field_access.record_

				call := node_create(p^.arena, NODE_CALL, expr^.token)
				call^.call.name 			:= expr^.field_access.field_name
				call^.call.name_len 		:= expr^.field_access.field_len
				call^.call.method_owner 	:= nil
				call^.call.method_owner_len := 0
				call^.call.receiver_expr 	:= recv
				// Provisional: field path keeps this; instance path clears it in semantic
				call^.call.callee_expr 		:= expr
				call^.call.args 			:= nil
				call^.call.argc 			:= 0
				call^.call.arg_capacity 	:= 0

				consume(p, TOK_LPAREN, 
					"parse_postfix: expected '(' after method name")
				parse_call_arguments(p, call)
				expr := call
			else
				// f(...), (expr)(...), etc. - no receiver_expr
				expr := parse_call(p, expr^.token)
			end
		elsif check(p, TOK_LBRACKET) then
			expr := parse_array_index(p, expr)
			// continue to allow chaining: a[b][c] etc.
		elsif match(p, TOK_DOT) then
			var field_tok: TToken
			var field_node: pNode = nil

			// field access
			if p^.current.kind <> TOK_IDENT then
				error_at(p, "parse_postfix: expected identifier after '.'", true)
			end

			field_tok := p^.current
			advance(p)

			field_node := node_create(p^.arena, NODE_FIELD_ACCESS, field_tok)
			field_node^.field_access.record_ 	:= expr
			field_node^.field_access.field_name := field_tok.start
			field_node^.field_access.field_len	:= field_tok.length

			expr := field_node
		elsif match(p, TOK_CARET) then
			var unary: pNode = node_create(p^.arena, NODE_UNARY, p^.current);
			unary^.unary.op 		:= TOK_CARET
			unary^.unary.operand 	:= expr
			expr := unary
		else
			break
		end
	end

	return expr
end parse_postfix


(**
 * Parse primary
 *)
export function parse_primary(p: pParser): pNode
begin
	require p <> nil

	// SIZEOF (type or designator)
	if check(p, TOK_KEYWORD_SIZEOF) then
		return parse_sizeof(p)
	end
	if check(p, TOK_KEYWORD_COUNTOF) then
		return parse_countof(p)
	end

	if p^.current.kind == TOK_IDENT then
		var ident_tok: TToken = p^.current
		var ident: pNode = nil

		advance(p)

		if check(p, TOK_COLON_COLON) then
			var method_tok: TToken
			var call: pNode = nil

			advance(p)			// consume ::
			if p^.current.kind <> TOK_IDENT then
				error_at(p, "parse_primary: expected method name after '::'", true)
			end

			method_tok := p^.current
			advance(p)
			if not check(p, TOK_LPAREN) then
				error_at(p, "parse_primary: expected '(' after qualified method name", true)
			end

			call := node_create(p^.arena, NODE_CALL, method_tok)
			call^.call.name 			:= method_tok.start
			call^.call.name_len 		:= method_tok.length
			call^.call.method_owner 	:= ident_tok.start
			call^.call.method_owner_len	:= ident_tok.length
			call^.call.receiver_expr 	:= nil
			call^.call.callee_expr 		:= nil
			call^.call.args 			:= nil
			call^.call.argc 			:= 0
			call^.call.arg_capacity 	:= 0

			consume(p, TOK_LPAREN, "parse_primary: expected '(' after qualified method name")
			parse_call_arguments(p, call)
			return call
		end

		if check(p, TOK_LPAREN) then
			return parse_call(p, ident_tok)
		end

		ident := node_create(p^.arena, NODE_IDENT, ident_tok)
		ident^.ident.value 	:= ident_tok.start
		ident^.ident.length := ident_tok.length
		return ident
	elsif p^.current.kind == TOK_STRING or
			p^.current.kind == TOK_NUMBER or
			p^.current.kind == TOK_CHAR then
		var lit: pNode = node_create(p^.arena, NODE_LITERAL, p^.current)

		lit^.literal.value 	:= p^.current.start
		lit^.literal.length := p^.current.length
		advance(p)
		return lit
	elsif match(p, TOK_LPAREN) then
		var inner: pNode = TParser::parse_expr(p^)
		var paren: pNode = nil

		if inner == nil then
			error_at(p, "parse_primary: expected expression inside parentheses", true)
		end
		consume(p, TOK_RPAREN, "parse_primary: expected ')' after parenthesized expression")

		paren := node_create(p^.arena, NODE_PAREN, inner^.token)
		paren^.paren.expr := inner
		return paren
	end

	// Array literal: { expr {, expr} }
	if check(p, TOK_LBRACE) then
		return parse_array_literal(p)
	end

	if p^.current.kind == TOK_BITWISE_AND then
		error_at(p, "parse_primary: '&' is bitwise AND; use '@' for address-of", true)
	end
	error_at(p, "parse_primary: expected expression", true)
	return nil
end parse_primary


(**
 * Parse call
 *)
export function parse_call(p: pParser, ident_token: TToken): pNode
begin
	require p <> nil

	var call: pNode = node_create(p^.arena, NODE_CALL, ident_token)

	call^.call.name 			:= ident_token.start
	call^.call.name_len 		:= ident_token.length
	call^.call.method_owner 	:= nil
	call^.call.method_owner_len := 0
	call^.call.receiver_expr 	:= nil
	call^.call.callee_expr 		:= nil
	call^.call.args 			:= nil
	call^.call.argc 			:= 0
	call^.call.arg_capacity 	:= 0

	consume(p, TOK_LPAREN, "parse_call: expected '(' after function name")

	parse_call_arguments(p, call)

	return call
end parse_call


(**
 * Parse array literal: "{" expression { "," expression } [ "," ] "}" 
 * Returns NODE_ARRAY_LITERAL node.
 * Exits on fatal error (unbalanced braces, etc.).
 *)
export function parse_array_literal(p: pParser): pNode
begin
	var open_token: TToken = p^.current
	var lit: pNode = nil

	advance(p) 		// consume '{'

	lit := node_create(p^.arena, NODE_ARRAY_LITERAL, open_token)
	lit^.array_literal.elements := nil
	lit^.array_literal.count 	:= 0
	lit^.array_literal.capacity := 0

	if match(p, TOK_RBRACE) then
		return lit
	end

	repeat
		var elem: pNode = nil

		skip_layout_breaks(p)
		if check(p, TOK_RBRACE) or isEOF(p) then
			break
		end

		elem := TParser::parse_expr(p^)

		if elem == nil then
			error_at(p, "parse_array_literal: expected expression", true)
		end

		arena_append_ptr(p^.arena,
			(@lit^.array_literal.elements) as ppvoid,
			@lit^.array_literal.count,
			@lit^.array_literal.capacity,
			elem)

		match(p, TOK_COMMA)
	until check(p, TOK_RBRACE) or isEOF(p)

	consume(p, TOK_RBRACE, "parse_array_literal: expected '}' after array literal")

	return lit
end parse_array_literal


(**
 * Parse array indexing: left [ index ]
 *)
export function parse_array_index(p: pParser, left: pNode): pNode
begin
	var bracket: TToken = p^.current 		// the '['
	var index_expr: pNode = nil
	var n: pNode = nil

	advance(p)

	index_expr := TParser::parse_expr(p^)
	if index_expr == nil then
		error_at(p, "parse_array_index: expected index expression inside []", true)
	end

	consume(p, TOK_RBRACKET, "parse_array_index: expected ']' after array index")

	n := node_create(p^.arena, NODE_ARRAY_INDEX, bracket)
	n^.array_index.array_ 	:= left
	n^.array_index.index 	:= index_expr

	return n
end parse_array_index


begin
end expression
