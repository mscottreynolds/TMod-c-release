module statement()
(**
 * Mod-c
 * By M. Scott Reynolds
 * Date 17 July 2026
 *
 * statement.mc - Statement parsing routines.
 *)


import Arena, pvoid, ppvoid, arena_alloc, arena_append_ptr 
	from arena
import utils_parse_integer_literal 
	from utils

import Node, SwitchCase, NODE_DEFER, NODE_DEBUG, NODE_SWITCH, NODE_IMPORT,
	NODE_IMPORT_ITEM, NODE_BREAK, NODE_CONTINUE, NODE_RETURN, NODE_IF,
	NODE_ELSIF, NODE_WHILE, NODE_LITERAL, NODE_FOR, NODE_REPEAT_UNTIL,
	NODE_LOOP, NODE_INC, NODE_DEC, node_create,
	from "node.h"
import TParser, pParser, advance, match, error_at, check, consume, isEOF, checkEOS, matchEOS,
	skip_empty_statements, skip_layout_breaks,
    from parser_common

import TParser::parse_const_expression, TParser::parse_designator, TParser::parse_expr, 
	TParser::parse_statement_sequence, TParser::parse_stmt,  
	from parser_main

// import parse_const_expression, parse_designator, parse_expr, parse_statement_sequence, 
// 	parse_stmt, skip_empty_statements, skip_layout_breaks, 
// 	from "parser.h"
import TToken, TOK_KEYWORD_DEFER, TOK_KEYWORD_DEBUG, TOK_KEYWORD_SWITCH,
	TOK_KEYWORD_OF, TOK_KEYWORD_CASE, TOK_COMMA, TOK_COLON, TOK_KEYWORD_ELSE,
	TOK_KEYWORD_END, TOK_IDENT, TOK_DOT, TOK_KEYWORD_FROM, TOK_STRING,
	TOK_KEYWORD_AS, TOK_KEYWORD_BREAK, TOK_KEYWORD_CONTINUE, TOK_KEYWORD_RETURN,
	TOK_KEYWORD_IF, TOK_KEYWORD_THEN, TOK_KEYWORD_ELSIF, TOK_KEYWORD_DO,
	TOK_KEYWORD_INVARIANT, TOK_KEYWORD_FOR, TOK_COLON_EQ, TOK_KEYWORD_DOWNTO,
	TOK_KEYWORD_TO, TOK_KEYWORD_BY, TOK_NUMBER, TOK_KEYWORD_REPEAT,
	TOK_KEYWORD_UNTIL, TOK_KEYWORD_LOOP, TOK_KEYWORD_INC, TOK_KEYWORD_DEC,
	TOK_LPAREN, TOK_RPAREN, TOK_ADD, TOK_SUB, TOK_COLON_COLON,
	from Lexer

import size_t from "stddef.h"
import strtol from "stdlib.h"
import fprintf, stderr from "stdio.h"


export type pNode = ^Node
type pcchar = const ^char


(**
 * Parse DEFER statement.
 * Grammar: "DEFER" statement ;
 * The deferred statement is stored in the currenb block's defer list.
 *)
export function parse_defer_stmt(p: pParser): pNode
begin
	require p <> nil

	var defer_tok: TToken
	var action, n: ^Node

	defer_tok := p^.current
	consume(p, TOK_KEYWORD_DEFER, "parse_defer_stmt: expected DEFER")

	action := TParser::parse_stmt(p^)
	if action == nil then
		error_at(p, "parse_defer_stmt: expected statement after DEFER", true)
	end

	n := node_create(p^.arena, NODE_DEFER, defer_tok)
	n^.defer_stmt.action := action

	return n

	ensure n^.kind == NODE_DEFER
end parse_defer_stmt


(**
 * Parse DEBUG statement.
 * Grammar: "DEBUG" statement ;
 * The debug statement is generated in code when a debug flag is set.
 *)
export function parse_debug_stmt(p: pParser): pNode
begin
	require p <> nil

	var debug_tok: TToken
	var action, n: pNode

	debug_tok := p^.current
	consume(p, TOK_KEYWORD_DEBUG, "parse_debug_stmt: expected DEBUG")

	action := TParser::parse_stmt(p^)
	if action == nil then
		error_at(p, "parse_debug_stmt: expected statement after DEBUG", true)
	end

	n := node_create(p^.arena, NODE_DEBUG, debug_tok)
	n^.debug_stmt.action := action

	return n

	ensure n^.kind == NODE_DEBUG
end parse_debug_stmt


(**
 * Parse SWITCH statement.
 * Grammar:
 * 	"SWITCH" expression "OF"
 * 		{ "CASE" case-labels ":" statement-sequence }
 *		"ELSE" ":" statement-sequence
 * 	"END" ;
 *
 * 	case-labels = const-expression { "," const-expression } ;
 *
 * No fallthrough. ELSE is required.
 *)
export function parse_switch_stmt(p: pParser): ^Node
begin
	require p <> nil

	var expr: pNode
	var switch_tok: TToken
	var n: pNode

	switch_tok := p^.current
	consume(p, TOK_KEYWORD_SWITCH, "parse_switch_stmt: expected SWITCH")

	expr := TParser::parse_expr(p^)
	if expr == nil then
		error_at(p, "parse_switch_stmt: expected expression after SWITCH", true)
	end

	consume(p, TOK_KEYWORD_OF, "parse_switch_stmt: expected OF after SWITCH expression")

	n := node_create(p^.arena, NODE_SWITCH, switch_tok)
	n^.switch_stmt.expr := expr
	n^.switch_stmt.cases := nil
	n^.switch_stmt.case_count := 0
	n^.switch_stmt.case_capacity := 0
	n^.switch_stmt.else_body := nil

	skip_empty_statements(p)

	// Zero or more case arms
	while check(p, TOK_KEYWORD_CASE) do
		var labels: ^pNode = nil
		var label_count: size_t = 0
		var label_capacity: size_t = 0
		var lab: pNode = nil
		var body: pNode = nil
		var case_arm: ^SwitchCase = nil

		consume(p, TOK_KEYWORD_CASE, "parse_switch_stt: expected CASE")

		// Parse case-labels: const-expression { "," const-expression }
		lab := TParser::parse_const_expression(p^)
		if lab == nil then
			error_at(p, "parse_switch_stmt: expected const-expression in CASE label", true)
		end
		arena_append_ptr(p^.arena, (@labels) as ppvoid, @label_count, @label_capacity, lab as pvoid)

		while match(p, TOK_COMMA) do
			lab := TParser::parse_const_expression(p^)
			if lab == nil then
				error_at(p, "parse_switch_stmt: expected const-expression afer ','", true)
			end
			arena_append_ptr(p^.arena, (@labels) as ppvoid, @label_count, @label_capacity, lab as pvoid)
		end

		consume(p, TOK_COLON, "parse_switch_stmt: expected ':' after CASE labels")

		body := TParser::parse_statement_sequence(p^)

		// Allocate the case arm from the arena and append the pointer
		case_arm := arena_alloc(p^.arena, sizeof(SwitchCase))
		case_arm^.labels := labels
		case_arm^.label_count := label_count
		case_arm^.label_capacity := label_capacity
		case_arm^.body := body

		arena_append_ptr(p^.arena, 						\
			(@n^.switch_stmt.cases) as ppvoid,			\
			@n^.switch_stmt.case_count,					\
			@n^.switch_stmt.case_capacity,				\
			case_arm as pvoid)

		skip_empty_statements(p)
	end

	// ELSE is required
	consume(p, TOK_KEYWORD_ELSE, "parse_switch_stmt: expected ELSE (required)")
	consume(p, TOK_COLON, "parse_switch_stmt: expected ':' after ELSE")

	n^.switch_stmt.else_body := TParser::parse_statement_sequence(p^)

	consume(p, TOK_KEYWORD_END, "parse_switch_stmt: expected END after SWITCH")

	// Optional trailing identifier after END (ignore, like other END statements)
	if p^.current.kind == TOK_IDENT then
		advance(p)
	end

	return n

	ensure n^.kind == NODE_SWITCH
end parse_switch_stmt


(**
 * Parse qualident = identifier { "." identifier } starting at current IDENT.
 * Returns false if current token is not TOK_IDENT.
 *)
function parse_qualident_span(p: pParser, start: ^pcchar, length: ^size_t): bool
begin
	require p <> nil

	if p^.current.kind <> TOK_IDENT then
		return false
	end

	start^ := p^.current.start
	length^ := p^.current.length
	advance(p)

	while match(p, TOK_DOT) do
		if p^.current.kind <> TOK_IDENT then
			error_at(p, "parse_qualident_span: expected identifier after '.' in qualident", true)
		end
		length^ := (p^.current.start + p^.current.length - start^) as size_t
		advance(p)
	end

	return true
end parse_qualident_span


(**
 * Parse IMPORT statement
 * Grammar:
 * 		IMPORT [ import-item { , import-item } ] FROM import-source;
 *		import-source = string-literal | qualident ;
 * 		import-item = (identifier { "," identifier } | type-identifier "::" identifier) [ AS identifier ] ;
 *
 * Returns NODE_IMPORT node or nil if no IMPORT seen.
 *)
export function parse_import_stmt(p: pParser): ^Node
begin
	require p <> nil

	var import_token: TToken = p^.current
	var imp: ^Node = nil
	var has_item: bool = false

	advance(p)

	imp := node_create(p^.arena, NODE_IMPORT, import_token)
	imp^.import_stmt.items 		:= nil
	imp^.import_stmt.count 		:= 0
	imp^.import_stmt.capacity 	:= 0
	imp^.import_stmt.from_path	:= nil
	imp^.import_stmt.path_len	:= 0

	// Parse import-items until FROM (anchor). Newlines are layout only.
	while not check(p, TOK_KEYWORD_FROM) and not isEOF(p) do
		var item: ^Node = nil

		skip_layout_breaks(p)
		if check(p, TOK_KEYWORD_FROM) then
			break
		end

		item := parse_import_item(p)
		if item == nil then
			if not has_item then
				error_at(p, "parse_import_stmt: expected identifier in IMPORT", true)
			end
			break
		end

		arena_append_ptr(p^.arena,
						(@imp^.import_stmt.items) as ppvoid,
						@imp^.import_stmt.count,
						@imp^.import_stmt.capacity,
						item)
		match(p, TOK_COMMA)
	end

	// Required FROM import-source
	if not match(p, TOK_KEYWORD_FROM) then
		error_at(p, "parse_import_stmt: IMPORT rquires FROM import-source", true)
	end

	if p^.current.kind == TOK_STRING then
		imp^.import_stmt.from_path 	:= p^.current.start
		imp^.import_stmt.path_len 	:= p^.current.length
		advance(p)
	elsif not parse_qualident_span(p, @imp^.import_stmt.from_path, @imp^.import_stmt.path_len) then
		error_at(p, "parse_import_stmt: expected stringliteral or module qualident after FROM", true)
	end

	if not matchEOS(p) then
		error_at(p, "parse_import_stmt: expected end-of-statement after IMPORT statement", true)
	end

	return imp

	ensure imp^.kind == NODE_IMPORT
end parse_import_stmt


(**
 * Parse one import item:
 * 		plain: ident { "." ident } [ AS ident ]
 * 		method: Type "::" name [ AS ident ]
 *)
export function parse_import_item(p: pParser): ^Node
begin
	require p <> nil

	var qual_start: pcchar = nil
	var qual_len: size_t = 0
	var owner_start: pcchar = nil
	var owner_len: size_t = 0
	var alias_start: pcchar = nil
	var alias_len: size_t = 0
	var item: ^Node = nil

	if p^.current.kind <> TOK_IDENT then
		return nil
	end

	// First identifier (plain name start, or Type in Type::name)
	qual_start := p^.current.start
	qual_len := p^.current.length
	advance(p)

	if match(p, TOK_COLON_COLON) then
		// Type::method -- owner is first ident; method is second
		owner_start := qual_start
		owner_len := qual_len
		if p^.current.kind <> TOK_IDENT then
			error_at(p, "parse_import_item: expected method name after '::'", true)
		end
		qual_start := p^.current.start
		qual_len := p^.current.length
		advance(p)
	else
		// Optional dotted qualident tail (fixtures.minimond style names on import list)
		while match(p, TOK_DOT) do
			if p^.current.kind <> TOK_IDENT then
				error_at(p, "parse_import_item: expected identifier after '.' in import name", true)
			end
			qual_len := (p^.current.start + p^.current.length - qual_start) as size_t
			advance(p)
		end
	end

	if match(p, TOK_KEYWORD_AS) then
		if p^.current.kind <> TOK_IDENT then
			error_at(p, "parse_import_item: expected identifier after AS", true)
		end
		alias_start := p^.current.start
		alias_len := p^.current.length
		advance(p)
	end

	item := node_create(p^.arena, NODE_IMPORT_ITEM, p^.current)
	item^.import_item.qualident 		:= qual_start
	item^.import_item.qualident_len 	:= qual_len
	item^.import_item.method_owner 		:= owner_start
	item^.import_item.method_owner_len	:= owner_len
	item^.import_item.import_alias 		:= alias_start
	item^.import_item.import_alias_len 	:= alias_len

	return item

	ensure item^.kind == NODE_IMPORT_ITEM
end parse_import_item


(**
 * Parse break statement
 *)
export function parse_break_stmt(p: pParser): ^Node
begin
	require p <> nil

	var break_tok: TToken = p^.current
	var n: ^Node = nil

	consume(p, TOK_KEYWORD_BREAK, "parse_break_stmt: expected BREAK")

	if not matchEOS(p) then
		error_at(p, "parse_break_statement: expected end-of-statement after BREAK", true)
	end

	n := node_create(p^.arena, NODE_BREAK, break_tok)
	// no extra fields needed for simple BREAK (can be exted later for labeled break)

	return n

	ensure n^.kind == NODE_BREAK
end parse_break_stmt


(**
 * Parse CONTINUE statement
 *)
export function parse_continue_stmt(p: pParser): ^Node
begin
	require p <> nil

	var cont_tok: TToken = p^.current
	var n: ^Node = nil

	consume(p, TOK_KEYWORD_CONTINUE, "parse_continue_stmt: expected CONTINUE")

	if not matchEOS(p) then
		error_at(p, "parse_continue_stmt: expected end-of-statement after CONTINUE", true)
	end

	n := node_create(p^.arena, NODE_CONTINUE, cont_tok)

	return n

	ensure n^.kind == NODE_CONTINUE
end parse_continue_stmt


(**
 * Parse RETURN statement
 *)
export function parse_return_stmt(p: pParser): ^Node
begin
	require p <> nil

	var ret_tok: TToken = p^.current
	var expr: ^Node = nil
	var n: ^Node = nil

	consume(p, TOK_KEYWORD_RETURN, "parse_return_stmt: expected RETURN")

	// RETURN may be followed by an expression (especially inside FUNCTION)
	if not checkEOS(p) then
		expr := TParser::parse_expr(p^)
	end

	if not matchEOS(p) then
		error_at(p, "parse_return_stmt: expected end-of-statement after RETURN", true)
	end

	n := node_create(p^.arena, NODE_RETURN, ret_tok)
	n^.ret.expr := expr

	return n

	ensure n^.kind == NODE_RETURN
end parse_return_stmt


(**
 * Parse IF statement
 *)
export function parse_if_stmt(p: pParser): ^Node
begin
	require p <> nil

	var if_tok: TToken = p^.current
	var cond: ^Node = nil
	var then_block: ^Node = nil
	var last_elsif: ^Node = nil
	var n: ^Node = nil

	consume(p, TOK_KEYWORD_IF, "parse_if_stmt: expected IF")

	cond := TParser::parse_expr(p^)
	if cond == nil then
		error_at(p, "parse_if_stmt: expected condition after IF", true)
	end

	consume(p, TOK_KEYWORD_THEN, "parse_if_stmt: expected THEN after IF condition")

	then_block := TParser::parse_statement_sequence(p^)

	n := node_create(p^.arena, NODE_IF, if_tok)
	n^.if_stmt.cond 	:= cond
	n^.if_stmt.then_ 	:= then_block
	n^.if_stmt.elsif_ 	:= nil
	n^.if_stmt.else_ 	:= nil

	// ELSIF chaining (opitonal)
	last_elsif := n
	while match(p, TOK_KEYWORD_ELSIF) do
		var elsif_cond: ^Node = TParser::parse_expr(p^)
		var elsif_then: ^Node = nil
		var elsif_node: ^Node = nil

		if elsif_cond == nil then
			error_at(p, "parse_if_stmt: expected condition after ELSIF", true)
		end
		consume(p, TOK_KEYWORD_THEN, "parse_if_stmt: expected THEN after ELSIF condition")

		elsif_then := TParser::parse_statement_sequence(p^)

		elsif_node := node_create(p^.arena, NODE_ELSIF, p^.current)
		elsif_node^.if_stmt.cond 	:= elsif_cond
		elsif_node^.if_stmt.then_ 	:= elsif_then
		elsif_node^.if_stmt.elsif_ 	:= nil
		elsif_node^.if_stmt.else_ 	:= nil

		last_elsif^.if_stmt.elsif_ 	:= elsif_node
		last_elsif := elsif_node
	end

	// optional ELSE
	if match(p, TOK_KEYWORD_ELSE) then
		var else_block: ^Node = TParser::parse_statement_sequence(p^)
		last_elsif^.if_stmt.else_ := else_block
	end

	consume(p, TOK_KEYWORD_END, "parse_if_stmt: expected END after IF condition")

	return n

	ensure n^.kind == NODE_IF
end parse_if_stmt


(**
 * Parse WHILE ... DO ... END statement
 * Grammar:
 * 		"WHILE" expression "DO" statement-sequence "END"
 *
 * Returns NODE_WHILE node
 * Exits on fatal error (missing DO, END, etc).
 *)
export function parse_while_stmt(p: pParser): ^Node
begin
	require p <> nil

	var while_token: TToken = p^.current
	var n: ^Node = nil

	advance(p)

	n := node_create(p^.arena, NODE_WHILE, while_token)
	n^.while_stmt.invariants 			:= nil
	n^.while_stmt.invariant_count 		:= 0
	n^.while_stmt.invariant_capacity 	:= 0

	// Condition
	n^.while_stmt.cond := TParser::parse_expr(p^)
	if n^.while_stmt.cond == nil then
		error_at(p, "parse_while_stmt: expected expression after WHILE", true)
	end

	// DO keyword
	consume(p, TOK_KEYWORD_DO, "parse_while_stmt: expected DO after WHILE condition")

	skip_empty_statements(p)

	// Optional invariant clauses
	while check(p, TOK_KEYWORD_INVARIANT) do
		var expr: ^Node = nil

		advance(p)

		expr := TParser::parse_expr(p^)
		if expr == nil then
			error_at(p, "parse_while_stmt: expected expression after INVARIANT ...", true)
		end

		if not matchEOS(p) then
			error_at(p, "parse_while_stmt: expected end-of-statement after INVARIANT expression", true)
		end

		arena_append_ptr(p^.arena, 
							(@n^.while_stmt.invariants) as ppvoid,
							@n^.while_stmt.invariant_count,
							@n^.while_stmt.invariant_capacity,
							expr)

		skip_empty_statements(p)
	end

	n^.while_stmt.body := TParser::parse_statement_sequence(p^)

	// END
	consume(p, TOK_KEYWORD_END, "parse_while_stmt: expected END after WHILE body")

	// Optional name after END (for named blocks - ingore for now)
	if p^.current.kind == TOK_IDENT then
		advance(p)
	end

	if not matchEOS(p) then
		// Allow trailing comment or newline
	end

	return n

	ensure n^.kind == NODE_WHILE
end parse_while_stmt


(**
 * Parse FOR statement with optional BY step
 * Grammar:
 *		"FOR" identifier ":=" expression ( "TO" | "DOWNTO" ) expression
 *			[ "BY" const-expression ] "DO" statement-sequence "END"
 *)
export function parse_for_stmt(p: pParser): ^Node
begin
	require p <> nil

	var for_tok: TToken = p^.current
	var var_name: pcchar = nil
	var var_len: size_t = 0
	var start_expr: ^Node = nil
	var end_expr: ^Node = nil
	var step: int = 0
	var n: ^Node = nil

	consume(p, TOK_KEYWORD_FOR, "parse_for_stmt: expected FOR")

	if p^.current.kind <> TOK_IDENT then
		error_at(p, "parse_for_stmt: expected variable name after FOR", true)
	end
	var_name := p^.current.start
	var_len := p^.current.length
	advance(p)

	consume(p, TOK_COLON_EQ, "parse_for_stmt: expected ':='' afer FOR variable")

	start_expr := TParser::parse_expr(p^)
	if start_expr == nil then
		error_at(p, "parse_for_stmt: expected expression after ':='", true)
	end

	skip_layout_breaks(p)
	let is_downto: bool = match(p, TOK_KEYWORD_DOWNTO)
	if not is_downto then
		consume(p, TOK_KEYWORD_TO, "parse_for_stmt: expected TO or DOWNTO after start expression")
	end

	end_expr := TParser::parse_expr(p^)
	if end_expr == nil then
		error_at(p, "parse_for_stmt: expected end expression after TO/DOWNTO", true)
	end

	step := 1 		// default step

	skip_layout_breaks(p)
	if match(p, TOK_KEYWORD_BY) then
		var step_expr: ^Node = TParser::parse_const_expression(p^)
		if step_expr == nil then
			error_at(p, "parse_for_stmt: expected constant expession after BY", true)
		end

		// Simple literal integer support for now
		if step_expr^.kind == NODE_LITERAL and step_expr^.token.kind == TOK_NUMBER then
			step := utils_parse_integer_literal(step_expr^.token.start, step_expr^.token.length) as int
			if step == 0 then
				step := 1 		// safety
			end 				// else ... need further sanity testing?
		else
			// TODO: Full const folding
			step := 1
		end
	end

	consume(p, TOK_KEYWORD_DO, "parse_for_stmt: expected DO after FOR header")

	n := node_create(p^.arena, NODE_FOR, for_tok)
	n^.for_stmt.var_name 	:= var_name
	n^.for_stmt.var_len 	:= var_len
	n^.for_stmt.start_ 		:= start_expr
	n^.for_stmt.end_ 		:= end_expr
	n^.for_stmt.step 		:= is_downto ? -step : step

	n^.for_stmt.invariants 			:= nil
	n^.for_stmt.invariant_count 	:= 0
	n^.for_stmt.invariant_capacity	:= 0

	// Optional invariant clauses
	skip_empty_statements(p)
	while check(p, TOK_KEYWORD_INVARIANT) do
		var expr: ^Node = nil
		advance(p)

		expr := TParser::parse_expr(p^)
		if expr == nil then
			error_at(p, "parse_for_stmt: expected expression afer INVARIANT", true)
		end

		if not matchEOS(p) then
			error_at(p, "parse_for_stmt: expected end-of-statement after INVARIANT expression", true)
		end

		arena_append_ptr(p^.arena, (@n^.for_stmt.invariants) as ppvoid,
							@n^.for_stmt.invariant_count,
							@n^.for_stmt.invariant_capacity,
							expr)

		skip_empty_statements(p)
	end

	n^.for_stmt.body := TParser::parse_statement_sequence(p^)

	consume(p, TOK_KEYWORD_END, "parse_for_stmt: expected END at end of FOR statements")

	// Optional identifier after END
	if check(p, TOK_IDENT) then
		advance(p)
	end

	if not matchEOS(p) then
		// Allow trailing comment
	end

	return n

	ensure n^.kind == NODE_FOR
end parse_for_stmt


(**
 * Parse REPEAT ... UNTIL statement
 *)
export function parse_repeat_until_stmt(p: pParser): ^Node
begin
	require p <> nil

	var repeat_tok: TToken = p^.current
	var n: ^Node = nil
	var cond: ^Node = nil

	consume(p, TOK_KEYWORD_REPEAT, "parse_repeat_until_stmt: expected REPEAT")

	n := node_create(p^.arena, NODE_REPEAT_UNTIL, repeat_tok)
	n^.repeat_until.invariants 			:= nil
	n^.repeat_until.invariant_count 	:= 0
	n^.repeat_until.invariant_capacity 	:= 0

	// Optional invariant clauses
	skip_empty_statements(p)
	while check(p, TOK_KEYWORD_INVARIANT) do
		var expr: ^Node = nil

		advance(p)
		expr := TParser::parse_expr(p^)
		if expr == nil then
			error_at(p, "parse_repeat_until_stmt: expected expression after INVARIANT", true)
		end

		if not matchEOS(p) then
			error_at(p, "parse_repeat_until_stmt: expected end-of-statement after INVARIANT expression", true)
		end

		arena_append_ptr(p^.arena, (@n^.repeat_until.invariants) as ppvoid,
									@n^.repeat_until.invariant_count,
									@n^.repeat_until.invariant_capacity,
									expr)

		skip_empty_statements(p)
	end

	n^.repeat_until.body := TParser::parse_statement_sequence(p^)

	consume(p, TOK_KEYWORD_UNTIL, "parse_repeat_until_stmt: expected UNTIL after REPEAT body")

	cond := TParser::parse_expr(p^)
	if cond == nil then
		error_at(p, "parse_repeat_until_stmt: expected condition after UNTIL", true)
	end

	n^.repeat_until.cond := cond

	return n

	ensure n^.kind == NODE_REPEAT_UNTIL
end parse_repeat_until_stmt


(**
 * Parse LOOP statement
 *)
export function parse_loop_stmt(p: pParser): ^Node
begin
	require p <> nil

	var n: ^Node = nil
	var loop_tok: TToken = p^.current

	consume(p, TOK_KEYWORD_LOOP, "parse_loop_stmt: expected LOOP")

	n := node_create(p^.arena, NODE_LOOP, loop_tok)
	n^.loop_stmt.invariants 		:= nil
	n^.loop_stmt.invariant_count 	:= 0
	n^.loop_stmt.invariant_capacity := 0

	// Optional invariant clauses
	skip_empty_statements(p)
	while check(p, TOK_KEYWORD_INVARIANT) do
		var expr: ^Node = nil

		advance(p)

		expr := TParser::parse_expr(p^)
		if expr == nil then
			error_at(p, "parse_loop_stmt: expected expression after INVARIANT", true)
		end

		if not matchEOS(p) then
			error_at(p, "parse_loop_stmt: expected end-of-statement after INVARIANT expression", true)
		end

		arena_append_ptr(p^.arena, (@n^.loop_stmt.invariants) as ppvoid,
									@n^.loop_stmt.invariant_count,
									@n^.loop_stmt.invariant_capacity,
									expr)

		skip_empty_statements(p)
	end

	n^.loop_stmt.body := TParser::parse_statement_sequence(p^)

	consume(p, TOK_KEYWORD_END, "parse_loop_stmt: expected END after LOOP statements")

	return n

	ensure n^.kind == NODE_LOOP
end parse_loop_stmt


(**
 * Parse INC / DEC statement
 * Grammar:
 * 		inc-stmt = "INC" "(" designator [ "," expression ] ")"
 * 		dec-stmt = "DEC" "(" designator [ "," expression ] ")"
 *)
export function parse_inc_dec_stmt(p: pParser): ^Node
begin
	require p <> nil

	var n: ^Node = nil
	var tok: TToken = p^.current
	var designator: ^Node = nil
	var step: ^Node = nil
	var is_inc: bool = match(p, TOK_KEYWORD_INC)

	if not is_inc then
		consume(p, TOK_KEYWORD_DEC, "parse_inc_dec_stmt: expected INC or DEC")
	end

	consume(p, TOK_LPAREN, "parse_inc_dec_stmt: expected '(' after INC/DEC")

	designator := TParser::parse_designator(p^)
	if designator == nil then
		error_at(p, "parse_inc_dec_stmt: expected designator in INC/DEC", true)
	end

	if match(p, TOK_COMMA) then
		step := TParser::parse_expr(p^)
		if step == nil then
			error_at(p, "parse_inc_dec_stmt: expected expression afer comma in INC/DEC", true)
		end
	end

	consume(p, TOK_RPAREN, "parse_inc_dec_stmt: expected ')' after INC/DEC arguments")

	if not matchEOS(p) then
		error_at(p, "parse_inc_dec_stmt: expected end-of-statement after INC/DEC", true)
	end

	n := node_create(p^.arena, is_inc ? NODE_INC : NODE_DEC, tok)
	n^.binary.left 	:= designator 		// reuse binary untion for simplicity
	n^.binary.right := step 			// NULL means step = 1
	n^.binary.op 	:= is_inc ? TOK_ADD : TOK_SUB

	// TODO: FIX: When `is_inc` was declared as `let is_inc:bool` the mangling routines didn't catch the 
	// instance used in the `ensure` statement.
	return n

	ensure n^.kind == NODE_INC or n^.kind == NODE_DEC
end parse_inc_dec_stmt


begin
end statement
