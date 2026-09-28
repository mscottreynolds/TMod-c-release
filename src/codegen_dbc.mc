module codegen_dbc()

(**
 * Mod-c
 * By M. Scott Reynolds
 * Date 18 April 2026
 *
 * codegen_dbc.c - Desing By Contract routines.	
 *)


import size_t from "stddef.h"
import DynBuf, dynbuf_append from dynbuf

import Node, NODE_BLOCK, NODE_WHILE, NODE_FOR, NODE_REPEAT_UNTIL, NODE_LOOP from "node.h"
import CodegenTarget, CodegenContext, codegen_common_expr, emit_indent, from "codegen_common.h"


(* Pointer to a Node *)
export type pNode = ^Node


(**
 * Generate REQUIRE clauses
 *)
export procedure codegen_dbc_emit_requires(n: const ^Node, ctx: CodegenContext)
begin
	var i: size_t = 0

	if n == nil or n^.kind <> NODE_BLOCK or 	\
		n^.block.require_count == 0 or 			\
		ctx.dbc_off then
		return
	end

	for i := 1 to n^.block.require_count do
		let e: pNode = n^.block.requires[i-1]
		if ctx.debug_enabled then
			emit_indent(ctx.out, ctx.indent)
			dynbuf_append(ctx.out, "/* REQUIRE */\n")
		end
		emit_indent(ctx.out, ctx.indent)
		dynbuf_append(ctx.out, "assert(")
		codegen_common_expr(e, ctx)
		dynbuf_append(ctx.out, "); /* precondition */\n")
	end
end codegen_dbc_emit_requires


(**
 * Generate ENSURE clauses
 *)
export procedure codegen_dbc_emit_ensures(n: const ^Node, ctx: CodegenContext)
begin
	var i: size_t = 0

	if n == nil or n^.kind <> NODE_BLOCK or 		\
			n^.block.ensure_count == 0 or ctx.dbc_off then
		return
	end

	for i := 1 to n^.block.ensure_count do
		let e: pNode = n^.block.ensures[i-1]
		if ctx.debug_enabled then
			emit_indent(ctx.out, ctx.indent)
			dynbuf_append(ctx.out, "/* ENSURE */\n")
		end
		emit_indent(ctx.out, ctx.indent)
		dynbuf_append(ctx.out, "assert(")
		codegen_common_expr(e, ctx)
		dynbuf_append(ctx.out, "); /* postcodition */\n")
	end
end codegen_dbc_emit_ensures


(**
 * Emit Ensures to Func
 *)
export procedure codegen_dbc_emit_ensures_to_func(ctx: CodegenContext)
begin
	var current: CodegenContext = ctx
	let target_func: const ^Node = ctx.enclosing_func

	if ctx.dbc_off then
		return
	end

	while current.parent_ctx <> nil do
		if current.parent_node <> nil and current.parent_node^.kind == NODE_BLOCK then
			if current.parent_node^.block.ensure_count > 0 then
				dynbuf_append(ctx.out, "/* ENSURE (on return) */\n")
				codegen_dbc_emit_ensures(current.parent_node, current)
			end
		end

		// Stop when we reach the enclosing function body (same pattern as defers)
		if current.enclosing_func <> nil and current.parent_node == target_func then
			break
		end

		current := current.parent_ctx^
	end
end codegen_dbc_emit_ensures_to_func



(**
 * Emit INVARIANT checks for a loop node.
 * Called at the "invariant point" inside the generated loop (before body for most loops).
 *)
export procedure codegen_dbc_emit_invariants(n: const ^Node, ctx: CodegenContext)
begin
	var invs: ^pNode = nil
	var count: size_t = 0
	var i: size_t = 0

	if n == nil or ctx.dbc_off then
		return
	end

	if n^.kind == NODE_WHILE then
		invs := n^.while_stmt.invariants
		count := n^.while_stmt.invariant_count
	elsif n^.kind == NODE_FOR then
		invs := n^.for_stmt.invariants
		count := n^.for_stmt.invariant_count
	elsif n^.kind == NODE_REPEAT_UNTIL then
		invs := n^.repeat_until.invariants
		count := n^.repeat_until.invariant_count
	elsif n^.kind == NODE_LOOP then
		invs := n^.loop_stmt.invariants
		count := n^.loop_stmt.invariant_count
	else
		return
	end

	for i := 1 to count do
		let e: pNode = invs[i-1]
		if ctx.debug_enabled then
			emit_indent(ctx.out, ctx.indent)
			dynbuf_append(ctx.out, "/* INVARIANT */\n")
		end
		emit_indent(ctx.out, ctx.indent)
		dynbuf_append(ctx.out, "assert(")
		codegen_common_expr(e, ctx)
		dynbuf_append(ctx.out, "); /* invariant */\n")
	end
end codegen_dbc_emit_invariants


(**
 * Emit invariants for the loop being exited (called before BREAK/CONTINUE).
 * Mirros the structure of the defers_to_loop wlaker.
 *)
export procedure codegen_dbc_emit_invariants_to_loop(ctx: CodegenContext)
begin
	var current: CodegenContext = ctx

	if ctx.dbc_off then
		return
	end

	while current.parent_ctx <> nil do
		if current.parent_node <> nil then
			if 	current.parent_node^.kind == NODE_WHILE or 			\
				current.parent_node^.kind == NODE_FOR or 			\
				current.parent_node^.kind == NODE_REPEAT_UNTIL or 	\
				current.parent_node^.kind == NODE_LOOP then

				emit_indent(ctx.out, ctx.indent)
				dynbuf_append(ctx.out, "/* INVARIANT (on loop exit) */\n")
				codegen_dbc_emit_invariants(current.parent_node, current)
				break
			end
		end

		// Stop before unwinding pass the loop itself (same spirit as defers_to_loop)
		current := current.parent_ctx^
	end
end codegen_dbc_emit_invariants_to_loop

begin
end codegen_dbc
