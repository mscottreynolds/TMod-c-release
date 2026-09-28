/**
 * Mod-c
 * By M. Scott Reynolds
 * Date 18 April 2026
 *
 * codegen_c.c - 	Basic C code generator from Mod-c AST
 * 				Phase 1: simple translation of program, declarations,
 *				statements, expressions, and array indexing.
 *				Updated 23 April 2026: WHILE, FOR, REPEAT, LOOP
 *				full IF/ELSIF/ELSE, array literals beyond {0}, and
 * 				compound assignments, ASSERT, SIZEOF, and
 *				remaining small self-hosting fixes.
 * 07 May 2026 	Add NODE_BREAK, NODE_CONTINUE
 * 14 May 2026 	Refactored to use CodegenContext (DynBuf*, indent, parent, etc.)
 *				for cleaner recursion and future scope/defer support.
 * 30 May 2026  RENAMED from codegen.c to codegen_c.c
 * 10 June 2026 Add codegen for SWITCH (explicit breaks for no-fallthrough,
 * 				ELSE required -> default:, comma labels as cascaded cases).
 */

#include "codegen_dbc.h"
#include "codegen_c.h"
#include "codegen_common.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <iso646.h>
#include "dynbuf.h"
#include "node.h"
#include "version.h"
#include "ttype.h"
#include "utils.h"
#include "Lexer.h"


/* =====================================
 * Forward declarations 
 * ===================================== */


// static void codegen_node(const Node *n, DynBuf *out, int indent);
static void codegen_c_stmt(const Node *n, CodegenContext ctx);
static void codegen_c_block(const Node *n, CodegenContext ctx);
static void codegen_c_if_stmt(const Node *n, CodegenContext ctx);
static void codegen_c_while_stmt(const Node *n, CodegenContext ctx);
static void codegen_c_for_stmt(const Node *n, CodegenContext ctx);
static void codegen_c_repeat_until_stmt(const Node *n, CodegenContext ctx);
static void codegen_c_loop_stmt(const Node *n, CodegenContext ctx);
static void codegen_c_switch_stmt(const Node *n, CodegenContext ctx);
static void codegen_c_defer_stmt(const Node *n, CodegenContext ctx);
static void codegen_c_assert_stmt(const Node *n, CodegenContext ctx);
static void codegen_c_proc_or_func(const Node *n, CodegenContext ctx);
static void codegen_c_program(const Node *n, CodegenContext ctx);
static void codegen_c_type_decl(const Node *n, CodegenContext ctx);			// ?



/* ==============================================
 * Codegen Node and Context routines
 * ============================================== */


/**
 * Emit PROCEDURE or FUNCTION declaration.
 * Maps to C function with proper return type and parameters.
 * Body is emitted as a block. 
 * If no body is defined, treat it as a prototype.
 */
static void codegen_c_proc_or_func(const Node *n, CodegenContext ctx)
{
	if (n == NULL) {
		return;
	}

    codegen_common_proc_or_func(n, ctx);

	// Body block
	if (n->proc_decl.body != NULL) {
		dynbuf_append_char(ctx.out, '\n');
		CodegenContext child = ctx_push(&ctx, n);
		codegen_c_block(n->proc_decl.body, child);
	} else {
		// Prototype function declaration
		dynbuf_append_char(ctx.out, ';');
	}
	dynbuf_append(ctx.out, "\n");
}


/**
 * Emit DEFER (phase 1: simple comment wrapper).
 */
static void codegen_c_defer_stmt(const Node *n, CodegenContext ctx)
{
	if (n == NULL) {
		return;
	}

	dynbuf_append(ctx.out, "/* DEFER begin */\n");
}


/**
 * Emit DEBUG statements if debug flag has been set in the context.
 */
static void codegen_c_debug_stmt(const Node *n, CodegenContext ctx)
{
	if (n == NULL) {
		return;
	}

	if (ctx.debug_enabled) {
		// Generate code that followed a debug statement
		dynbuf_append(ctx.out, "/* DEBUG */\n");
		codegen_c_stmt(n->debug_stmt.action, ctx);
	}
}


/**
 * Emit ASSERT (cond [, hint])
 */
static void codegen_c_assert_stmt(const Node *n, CodegenContext ctx)
{
	if (n == NULL or n->kind != NODE_ASSERT or ctx.assert_off) {
		return;
	}

	// emit_indent(ctx.out, ctx.indent);
	dynbuf_append(ctx.out, "assert(");
	codegen_common_expr(n->assert_stmt.condition, ctx);
	dynbuf_append(ctx.out, ");");

	if (n->assert_stmt.const_expr != NULL) {
		dynbuf_append(ctx.out, " /* ");
		codegen_common_expr(n->assert_stmt.const_expr, ctx);
		dynbuf_append(ctx.out, " */");
	}

	dynbuf_append(ctx.out, "\n");
}


/**
 * Emit IF/ ELSIF / ELSE chain.
 * Handles the full Mod-c if-then-elsif-else-end structure.
 */
static void codegen_c_if_stmt(const Node *n, CodegenContext ctx)
{
	if (n == NULL or n->kind != NODE_IF) {
		dynbuf_append(ctx.out, "/* TODO: codegen_c_if_stmt: invalid if node */\n");
		return;
	}

	// emit_indent(ctx.out, ctx.indent);
	dynbuf_append(ctx.out, "if (");
	codegen_common_expr(n->if_stmt.cond, ctx);
	dynbuf_append(ctx.out, ")\n");

	// if statements are stored as BLOCKS, which will take care of the matching {} pairs.
	{
		CodegenContext child = ctx_push(&ctx, n);
		// child.indent = ctx.indent;
		codegen_c_stmt(n->if_stmt.then_, child);		
	}

	// ELSIF chain. 
	// Final else statement is parsed onto the last elsif.
	const Node *else_ = n->if_stmt.else_;
	const Node *elsif = n->if_stmt.elsif_;
	while (elsif != NULL) {
		emit_indent(ctx.out, ctx.indent);
		dynbuf_append(ctx.out, "else if (");

		codegen_common_expr(elsif->if_stmt.cond, ctx);
		dynbuf_append(ctx.out, ")\n");

		CodegenContext child = ctx_push(&ctx, elsif);
		// child.indent = ctx.indent;
		codegen_c_stmt(elsif->if_stmt.then_, child);

		else_ = elsif->if_stmt.else_;
		elsif = elsif->if_stmt.elsif_;
	}

	// Optional ELSE
	if (else_ != NULL) {
		emit_indent(ctx.out, ctx.indent);
		dynbuf_append(ctx.out, "else\n");

		CodegenContext child = ctx_push(&ctx, n);
		// child.indent = ctx.indent;
		codegen_c_stmt(else_, child);
	}
}


/**
 * Emit WHILE ... DO ... END
 */
static void codegen_c_while_stmt(const Node *n, CodegenContext ctx)
{
	if (n == NULL or n->kind != NODE_WHILE) {
		return;
	}

	// emit_indent(ctx.out, ctx.indent);
	dynbuf_append(ctx.out, "while (");
	codegen_common_expr(n->while_stmt.cond, ctx);
	dynbuf_append(ctx.out, ")\n");

	emit_indent(ctx.out, ctx.indent);
	dynbuf_append(ctx.out, "{\n");
	ctx.indent += 1;
	CodegenContext child = ctx_push(&ctx, n);
	child.enclosing_loop = n;					// important for BREAK/CONTINUE
	codegen_dbc_emit_invariants(n, child);
	codegen_c_stmt(n->while_stmt.body, child);
	ctx.indent -= 1;
	emit_indent(ctx.out, ctx.indent);
	dynbuf_append(ctx.out, "}\n");
	codegen_dbc_emit_invariants(n, ctx);
}


/**
 * Emit FOR ... TO/DOWNTO ... BY ... DO ... END
 */
static void codegen_c_for_stmt(const Node *n, CodegenContext ctx)
{
	char buf[32];

	if (n == NULL or n->kind != NODE_FOR) {
		return;
	}

	// emit_indent(ctx.out, ctx.indent);
	dynbuf_append(ctx.out, "{\n");
	ctx.indent += 1;

	// Evaluate end bound once
	emit_indent(ctx.out, ctx.indent);
	dynbuf_append(ctx.out, "const long long __for_end_l");
	snprintf(buf, sizeof(buf), "%d", n->token.line);
	dynbuf_append(ctx.out, buf);
	dynbuf_append(ctx.out, " = (long long)(");
	codegen_common_expr(n->for_stmt.end_, ctx);
	dynbuf_append(ctx.out, ");\n");

	emit_indent(ctx.out, ctx.indent);
	dynbuf_append(ctx.out, "for (");
	dynbuf_appendn(ctx.out, n->for_stmt.var_name, n->for_stmt.var_len);
	dynbuf_append(ctx.out, " = ");
	codegen_common_expr(n->for_stmt.start_, ctx);
	dynbuf_append(ctx.out, "; ");

	// condition
	dynbuf_append(ctx.out, "(long long)(");
	dynbuf_appendn(ctx.out, n->for_stmt.var_name, n->for_stmt.var_len);
	dynbuf_append(ctx.out, ")");
	
	if (n->for_stmt.step >= 0) {
		dynbuf_append(ctx.out, " <= __for_end_l");
	} else {
		dynbuf_append(ctx.out, " >= __for_end_l");
	}
	snprintf(buf, sizeof(buf), "%d", n->token.line);
	dynbuf_append(ctx.out, buf);
	dynbuf_append(ctx.out, "; ");

	// increment / decrement by step
	dynbuf_appendn(ctx.out, n->for_stmt.var_name, n->for_stmt.var_len);
	if (n->for_stmt.step == 1) {
		dynbuf_append(ctx.out, "++");
	} else if (n->for_stmt.step == -1) {
		dynbuf_append(ctx.out, "--");
	} else if (n->for_stmt.step > 0) {
		dynbuf_append(ctx.out, " += ");
		// Simple integer literal for step
		snprintf(buf, sizeof(buf), "%d", n->for_stmt.step);
		dynbuf_append(ctx.out, buf);
	} else {
		dynbuf_append(ctx.out, " -= ");
		snprintf(buf, sizeof(buf), "%d", -n->for_stmt.step);
		dynbuf_append(ctx.out, buf);
	}

	dynbuf_append(ctx.out, ")\n");

	emit_indent(ctx.out, ctx.indent);
	dynbuf_append(ctx.out, "{\n");
	ctx.indent += 1;
	CodegenContext child = ctx_push(&ctx, n);
	child.enclosing_loop = n;
	codegen_dbc_emit_invariants(n, child);
	codegen_c_stmt(n->for_stmt.body, child);
	ctx.indent -= 1;
	emit_indent(ctx.out, ctx.indent);
	dynbuf_append(ctx.out, "}\n");
	codegen_dbc_emit_invariants(n, ctx);

	ctx.indent -= 1;
	emit_indent(ctx.out, ctx.indent);
	dynbuf_append(ctx.out, "}\n");
}


/**
 * Emit REMEAT ... UNTIL ...
 */
static void codegen_c_repeat_until_stmt(const Node *n, CodegenContext ctx)
{
	if (n == NULL or n->kind != NODE_REPEAT_UNTIL) {
		return;
	}

	// emit_indent(ctx.out, ctx.indent);
	dynbuf_append(ctx.out, "do\n");

	emit_indent(ctx.out, ctx.indent);
	dynbuf_append(ctx.out, "{\n");
	ctx.indent += 1;
	CodegenContext child = ctx_push(&ctx, n);
	// child.enclosing_loop = n;
	codegen_dbc_emit_invariants(n, child);
	codegen_c_stmt(n->repeat_until.body, child);
	ctx.indent -= 1;
	emit_indent(ctx.out, ctx.indent);
	dynbuf_append(ctx.out, "}\n");

	emit_indent(ctx.out, ctx.indent);
	dynbuf_append(ctx.out, "while (!(");
	codegen_common_expr(n->repeat_until.cond, ctx);
	dynbuf_append(ctx.out, "));\n");
	codegen_dbc_emit_invariants(n, ctx);
}


/**
 * Emit LOOP ... END (infinite loop)
 */
static void codegen_c_loop_stmt(const Node *n, CodegenContext ctx)
{
	if (n == NULL or n->kind != NODE_LOOP) {
		return;
	}

	// emit_indent(ctx.out, ctx.indent);
	dynbuf_append(ctx.out, "while (1)\n");

	emit_indent(ctx.out, ctx.indent);
	dynbuf_append(ctx.out, "{\n");
	ctx.indent += 1;
	CodegenContext child = ctx_push(&ctx, n);
	child.enclosing_loop = n;
	codegen_dbc_emit_invariants(n, child);
	codegen_c_stmt(n->loop_stmt.body, child);
	ctx.indent -= 1;
	emit_indent(ctx.out, ctx.indent);
	dynbuf_append(ctx.out, "}\n");
	codegen_dbc_emit_invariants(n, ctx);
}


/**
 * Emit SWITCH ... OF ... CASE ... ELSE ... END
 * Maps to a C switch. No fallthrough (we emit explicit break; afer each arm's body).
 * Comma labels become successive "case X:" (they share the following body until the break).
 * ELSE (required in source) becomes "default:". A break; is emitted afgter the dfault arm for symetry.
 */
static void codegen_c_switch_stmt(const Node *n, CodegenContext ctx)
{
	if (n == NULL or n->kind != NODE_SWITCH) {
		dynbuf_append(ctx.out, "/* TODO: codegen_c_switch_stmt: invalid switch node */\n");
		return;
	}

	// The caller (codegen_c_stmt) has already done emit_indent for the statement start.
	dynbuf_append(ctx.out, "switch (");
	codegen_common_expr(n->switch_stmt.expr, ctx);
	dynbuf_append(ctx.out, ")\n");

	// Opening { for the switch (at the same indent level as the "switch" line).
	emit_indent(ctx.out, ctx.indent);
	dynbuf_append(ctx.out, "{\n");

	// Everything for cases/default/breaks + the arm bodies (which are NODE_BLOCKS) lives at +1
	CodegenContext arm_ctx = ctx_push(&ctx, n);
	arm_ctx.indent = ctx.indent + 1;

	// CASE arms (zero or more)
	for (size_t i = 0; i < n->switch_stmt.case_count; i++) {
		SwitchCase *c = n->switch_stmt.cases[i];
		if (c == NULL) {
			continue;
		}

		for (size_t j = 0; j < c->label_count; j++) {
			emit_indent(ctx.out, arm_ctx.indent);
			dynbuf_append(ctx.out, "case ");
			codegen_common_expr(c->labels[j], arm_ctx);
			dynbuf_append(ctx.out, ":\n");
		}

		// Body is a statement-sequence -> NODE_BLOCK from parse_statement_sequence.
		// It will emit its own { ... } (with inner indent + 1) and handle any defers i the arm.
		codegen_c_stmt(c->body, arm_ctx);

		// Enforce Mod-c "no fallthrough" semantics in the generated C.
		emit_indent(ctx.out, arm_ctx.indent);
		dynbuf_append(ctx.out, "break;\n");
	}

	// ELSE (required) -> default
	emit_indent(ctx.out, arm_ctx.indent);
	dynbuf_append(ctx.out, "default:\n");
	codegen_c_stmt(n->switch_stmt.else_body, arm_ctx);

	// Explicit break after the final arm too (symmetry + matches "after each arm" comment).
	emit_indent(ctx.out, arm_ctx.indent);
	dynbuf_append(ctx.out, "break;\n");

	// Close the switch compound statement.
	emit_indent(ctx.out, ctx.indent);
	dynbuf_append(ctx.out, "}\n");
}


/**
 * Emit a TYPE declaration.
 * Simple types for now.
 */
static void codegen_c_type_decl(const Node *n, CodegenContext ctx)
{
	if (n == NULL) {
		return;
	}

	// If type is exported, skip because they will be exported in the definition header
	if (not n->type_decl.is_exported) {
		codegen_common_type_decl(n, ctx);
	}

	return;
}


/**
 * Index of stmt in block->block.stmts, or (size_t) - 1 if not a direct child.
 * DEFER nodes are stored both in stmts[] and in defers[]; pointer equality
 * is the link.
 */
static size_t codegen_c_block_stmt_index(const Node *block, const Node *stmt)
{
	size_t i;

	if (block == NULL or block->kind != NODE_BLOCK or stmt == NULL) {
		return (size_t)-1;
	}
	for (i = 0; i < block->block.count; i++) {
		if (block->block.stmts[i] == stmt) {
			return i;
		}
	}
	return (size_t)-1;
}


static bool codegen_c_block_has_reached_defer(const Node *block, size_t cutoff)
{
	size_t i;
	size_t at;

	if (block == NULL or block->kind != NODE_BLOCK) {
		return false;
	}
	for (i = 0; i < block->block.defer_count; i++) {
		const Node *d = block->block.defers[i];
		if (d == NULL) {
			continue;
		}
		at = codegen_c_block_stmt_index(block, d);
		if (at != (size_t) -1 and at < cutoff) {
				return true;
		}
	}
	return false;
}


/**
 * Emit a DEFER statment.
 * C2y / Language Report 7.3: a defer runs only if control passed the
 * DEFER statement. ctx.stmt_index is the cutoff in this block (see 
 * CodegenContext.stmt_index). LIFO among those that quality.
 */
static void codegen_c_emit_defers(const Node *block_node, CodegenContext ctx)
{
	size_t cutoff;

	if (block_node == NULL or block_node->kind != NODE_BLOCK) {
		return;
	}

	cutoff = ctx.stmt_index;

	// Emit in reverse order (LIFO)
	for (size_t i = block_node->block.defer_count; i > 0; i--) {
		const Node *d = block_node->block.defers[i - 1];
		size_t at;

		if (d == NULL) {
			continue;
		}
		at = codegen_c_block_stmt_index(block_node, d);
		if (at == (size_t)-1 or at >= cutoff) {
			continue;
		}

		emit_indent(ctx.out, ctx.indent);
		dynbuf_append(ctx.out, "/* DEFER end */\n");
		codegen_c_stmt(d->defer_stmt.action, ctx);
	}
}


/**
 * Emit defers by walking up the context chain until we reach the 
 * enclosing function. Uned by RETURN statements.
 */
static void codegen_c_emit_defers_to_func(CodegenContext ctx)
{
	CodegenContext current = ctx;
	const Node *target_func = ctx.enclosing_func;

	while (current.parent_ctx != NULL) {
		if (current.parent_node != NULL and current.parent_node->kind == NODE_BLOCK) {
			if (codegen_c_block_has_reached_defer(current.parent_node, current.stmt_index)) {
				emit_indent(ctx.out, ctx.indent);
				dynbuf_append(ctx.out, "/* DEFER cleanup (unwinding to function) */\n");
				codegen_c_emit_defers(current.parent_node, current);
			}
		}

		// Stop when we reach the function body block
		if (current.enclosing_func != NULL and current.parent_node == target_func) {
			// current.parent_node == current.enclosing_func->proc_decl.body) {
			break;
		}

		current = *current.parent_ctx;
	}
}


/**
 * Emit defers by walking up the context chain until we reach the
 * enclosing loop. Used by BREAK and CONTINUE statements.
 */
static void codegen_c_emit_defers_to_loop(CodegenContext ctx) 
{
	CodegenContext current = ctx;
	const Node *target_loop = ctx.enclosing_loop;

	while (current.parent_ctx != NULL) {
		if (current.parent_node != NULL and current.parent_node->kind == NODE_BLOCK) {
			if (codegen_c_block_has_reached_defer(current.parent_node, current.stmt_index)) {
				dynbuf_append(ctx.out, "/* DEFER cleanup (unwinding to loop) */\n");
				codegen_c_emit_defers(current.parent_node, current);
			}
		}

		// Stop before processing the loop's own block
		if (current.parent_node != NULL and current.parent_node == target_loop) {
			break;
		}

		current = *current.parent_ctx;
	}

}


/**
 * Emit RETURN statement with proper DEFER cleanup.
 * Grammar: "RETURN" [ expression ]
 */
static void codegen_c_return_stmt(const Node *n, CodegenContext ctx)
{
	if (n == NULL or n->kind != NODE_RETURN) {
		return;
	}

	codegen_dbc_emit_ensures_to_func(ctx);

	if (n->ret.expr != NULL) {
		// Evaluate return expression into a temporary first
		// (prevents defer from modifying the return value or
		// free resources the expression depends on).
		int line = n->token.line;

		// emit_indent(ctx.out, ctx.indent);
		dynbuf_append(ctx.out, "/* return value captured before defers */\n");

		emit_indent(ctx.out, ctx.indent);

		// Emit the correct return type for the temporary

		TType *ret_type = NULL;
		if (ctx.enclosing_func != NULL) {
			ret_type = ctx.enclosing_func->func_decl.return_type;
		} else if (ctx.ast != NULL and ctx.ast->kind == NODE_PROGRAM) {
			ret_type = ctx.ast->program_decl.return_type;
		}
		emit_return_type(ctx.out, ret_type);

		dynbuf_append_char(ctx.out, ' ');
		dynbuf_append(ctx.out, "__ret_l");
		{
			char buf[32];
			snprintf(buf, sizeof(buf), "%d", line);
			dynbuf_append(ctx.out, buf);
		}
		dynbuf_append(ctx.out, " = ");
		codegen_common_expr(n->ret.expr, ctx);
		dynbuf_append(ctx.out, ";\n");

		// Now run any pending defers
		codegen_c_emit_defers_to_func(ctx);

		// Finally return the captured value
		emit_indent(ctx.out, ctx.indent);
		dynbuf_append(ctx.out, "return __ret_l");
		{
			char buf[32];
			snprintf(buf, sizeof(buf), "%d", line);
			dynbuf_append(ctx.out, buf);
		}
		dynbuf_append(ctx.out, ";\n");
	} else {
		// Plain return with no value
		codegen_c_emit_defers_to_func(ctx);

		emit_indent(ctx.out, ctx.indent);
		dynbuf_append(ctx.out, "return;\n");
	}
}


/**
 * Emit BREAK statement with proper DEFER cleanup
 * Grammar: "BREAK"
 */
static void codegen_c_break_stmt(const Node *n, CodegenContext ctx)
{
	if (n == NULL or n->kind != NODE_BREAK) {
		return;
	}

	// emit_indent(ctx.out, ctx.indent);

	// 1. Run any pending DEFERs for the current enclosing block
	codegen_c_emit_defers_to_loop(ctx);

	codegen_dbc_emit_invariants_to_loop(ctx);

	// 2. Emit the actual break
	emit_indent(ctx.out, ctx.indent);
	dynbuf_append(ctx.out, "break;\n");
}


/**
 * Emit CONTINUE statement with proper DEFER cleanup.
 * Grammar: "CONTINUE"
 */
static void codegen_c_continue_stmt(const Node *n, CodegenContext ctx)
{
	if (n == NULL or n->kind != NODE_CONTINUE) {
		return;
	}

	// emit_indent(ctx.out, ctx.indent);

	// 1. Run any pending DEFERs for the current enclosing block
	codegen_c_emit_defers_to_loop(ctx);

	codegen_dbc_emit_invariants_to_loop(ctx);

	// 2. Emit the actual continue
	emit_indent(ctx.out, ctx.indent);
	dynbuf_append(ctx.out, "continue;\n");
}


/**
 * Emit a single statement
 */
static void codegen_c_stmt(const Node *n, CodegenContext ctx)
{
	if (n == NULL) {
		return;
	}

	emit_indent(ctx.out, ctx.indent);

	switch (n->kind) {
		case NODE_DOC_COMMENT:
			emit_doc_comment_as_c(ctx.out, n);
			break;

		case NODE_PREPROCESSOR:
			codegen_common_preprocessor(n, ctx);
			break;

		case NODE_DEFINE:
			codegen_common_define(n, ctx);
			break;

		case NODE_EXPR_STMT:
			codegen_common_expr(n->expr_stmt.expr, ctx);
			dynbuf_append(ctx.out, ";\n");
			break;

		case NODE_ASSIGN:
			codegen_common_expr(n, ctx);
			dynbuf_append(ctx.out, ";\n");
			break;

		case NODE_RETURN:
			codegen_c_return_stmt(n, ctx);
			break;

		case NODE_BREAK:
			codegen_c_break_stmt(n, ctx);
			break;

		case NODE_CONTINUE:
			codegen_c_continue_stmt(n, ctx);
			break;

		case NODE_DEFER:
			 codegen_c_defer_stmt(n, ctx); 	// Only puts a comment in output.
			break;

		case NODE_DEBUG:
			codegen_c_debug_stmt(n, ctx);	// Handle debug statements.
			break;

		case NODE_IF:
			codegen_c_if_stmt(n, ctx);
			break;

		case NODE_WHILE:
			codegen_c_while_stmt(n, ctx);
			break;

		case NODE_FOR:
			codegen_c_for_stmt(n, ctx);
			break;

		case NODE_REPEAT_UNTIL:
			codegen_c_repeat_until_stmt(n, ctx);
			break;

		case NODE_LOOP:
			codegen_c_loop_stmt(n, ctx);
			break;

		case NODE_SWITCH:
			codegen_c_switch_stmt(n, ctx);
			break;

		case NODE_ASSERT:
			codegen_c_assert_stmt(n, ctx);
			break;

		case NODE_LET_DECL:
		case NODE_VAR_DECL:
		case NODE_CONST_DECL:
			for (size_t i = 0; i < n->var_decl.count; i++) {
				const Node *item = n->var_decl.items[i];
				if (item == NULL) {
					continue;
				}
				if (i > 0) {
					emit_indent(ctx.out, ctx.indent);
				}

				// fprintf(stderr, "debug: name = %.*s, enclosing_func = %p, parent_node = %p, parent_ctx = %p\n",
				// 	(int) item->var_item.name_len, item->var_item.name,
				// 	(void*) ctx.enclosing_func, (void*) ctx.parent_node, (void*) ctx.parent_ctx);

				if (n->var_decl.is_extern) {
					dynbuf_append(ctx.out, "extern ");
				} else if (n->var_decl.is_static or ctx.parent_node == NULL) {
					dynbuf_append(ctx.out, "static ");
				}

				// CONST declarations only (item 19). LET Is a rebind lock in
				// TMod-c (0.26.5.181); C must not freeze the object or pointee.
				if (n->kind == NODE_CONST_DECL) {
					dynbuf_append(ctx.out, "const ");
				}

				if (n->kind == NODE_LET_DECL) {
					if (item->var_item.item_type != NULL) {
						emit_type_specifier(ctx.out, item->var_item.item_type,
							NULL, 0, false, false, false, false);
						dynbuf_append_char(ctx.out, ' ');
					} else {
						dynbuf_append(ctx.out, "int ");
					}
					emit_let_binding_name(ctx.out,
						item->var_item.name,
						item->var_item.name_len,
						item);
				} else {
					emit_var_decl(ctx.out, 
						item->var_item.name,
						item->var_item.name_len,
						item->var_item.item_type);
				}

				if (!n->var_decl.is_extern) {
					if (item->var_item.initializer != NULL) {
						dynbuf_append(ctx.out, " = ");
						codegen_common_expr(item->var_item.initializer, ctx);
					} else {
						// Zero-initialize structs/arrays by default (common pattern) another safe fallback
						// TODO: if non-struct/array...
						dynbuf_append(ctx.out, " = {0}");
					}
				}
				dynbuf_append(ctx.out, ";\n");

			}
			break;

		case NODE_PROC_DECL:
		case NODE_FUNC_DECL:
			codegen_c_proc_or_func(n, ctx);
			break;

		case NODE_BLOCK:
			codegen_c_block(n, ctx);
			break;

		case NODE_TYPE_DECL:
			codegen_c_type_decl(n, ctx);
			break;

		// case NODE_STRUCT_DECL:
		// 	codegen_common_struct_decl(n, ctx);
		// 	break;

		case NODE_INC:
		case NODE_DEC:
			codegen_common_inc_dec(n, ctx, true);		// statement context
			break;

		// supress unhandled case warnings.
		case NODE_STRUCT_DECL:
		case NODE_PROGRAM:
		case NODE_VAR_ITEM:
		case NODE_CONST_ITEM:
		case NODE_LET_ITEM:
		case NODE_PARAM:
		case NODE_PARAM_LIST:
		case NODE_IMPORT:
		case NODE_IMPORT_ITEM:
		case NODE_FIELD_DECL:
		case NODE_METHOD_TYPE:
		case NODE_ARRAY_TYPE:
		case NODE_ARRAY_LITERAL:
		case NODE_ARRAY_INDEX:
		case NODE_FIELD_ACCESS:
		case NODE_ELSIF:
		case NODE_ELSE:
		case NODE_SIZEOF:
		case NODE_LEN:
		case NODE_BINARY:
		case NODE_UNARY:
		case NODE_TERNARY:
		case NODE_CAST:
		case NODE_LITERAL:
		case NODE_IDENT:
		case NODE_CALL:
		case NODE_PAREN:
		default:
			dynbuf_append(ctx.out, "/* TODO: codegen_c_stmt: stmt kind ");
			dynbuf_append(ctx.out, TokenKind__string((TokenKind)n->token.kind));
			dynbuf_append(ctx.out, " */\n");
			break;
	}
}


/**
 * Emit BEGIN ... END block (statement sequence)
 */
static void codegen_c_block(const Node *n, CodegenContext ctx)
{
	if (n == NULL) {
		return;
	}

	// emit_indent(ctx.out, ctx.indent);
	dynbuf_append(ctx.out, "{\n");

	CodegenContext child_ctx = ctx_push(&ctx, n);
	child_ctx.indent = ctx.indent + 1;

	codegen_dbc_emit_requires(n, child_ctx);

	for (size_t i = 0; i < n->block.count; i++) {
		child_ctx.stmt_index = i;
		codegen_c_stmt(n->block.stmts[i], child_ctx);
	}

	// C2y-style: emit defers at block exit UNLESS we arleady did so via early exit
	bool early_exit_in_block = false;
	if (n->block.count > 0) {
		const Node *last = n->block.stmts[n->block.count -1];
		if (last != NULL and
			(last->kind == NODE_RETURN or
			 last->kind == NODE_BREAK or
			 last->kind == NODE_CONTINUE)) {
			early_exit_in_block = true;
		}
	}

	if (not early_exit_in_block) {
		child_ctx.stmt_index = n->block.count;		// all DEFERs in thisblock were reached
		codegen_dbc_emit_ensures(n, child_ctx);
		codegen_c_emit_defers(n, child_ctx);
	}

	emit_indent(ctx.out, ctx.indent);
	dynbuf_append(ctx.out, "}\n");
}


/**
 * Generate a separate main(...) wrapper for NODE_PROGRAM
 */
static void codegen_c_main_wrapper(const Node *n, CodegenContext ctx)
{
	// Return type
	if (n->program_decl.return_type != NULL) {
		emit_return_type(ctx.out, n->program_decl.return_type);
		dynbuf_append_char(ctx.out, ' ');
	} else {
		dynbuf_append(ctx.out, "void ");
	}

	// Program/module name
	dynbuf_appendn(ctx.out, n->program_decl.name, n->program_decl.name_len);

	// Parameter list
	emit_param_list(ctx.out, n->program_decl.params, n->program_decl.param_count, true, false);

	// dynbuf_append(out, ")\n");
	dynbuf_append_char(ctx.out, '\n');

	// Body
	if (n->program_decl.block != NULL) {
		codegen_c_block(n->program_decl.block, ctx);
	} else {
		dynbuf_append(ctx.out, "{\n");
		emit_indent(ctx.out, ctx.indent + 1);
		dynbuf_append(ctx.out, "/* Empty body */\n");
		dynbuf_append(ctx.out, "}\n");
	}

	dynbuf_append(ctx.out, "\n");

	// Now generate the main(...) wrapper.
	dynbuf_append(ctx.out, "int main");

	// Use the same parameter list for main as supplied by the program header.
	emit_param_list(ctx.out, n->program_decl.params, n->program_decl.param_count, true, false);

	dynbuf_append_char(ctx.out, '\n');
	dynbuf_append(ctx.out, "{\n");
	emit_indent(ctx.out, ctx.indent + 1);
	if (n->program_decl.return_type != NULL) {
		// Assuming program returns same type as main(...)
		dynbuf_append(ctx.out, "return ");
	}
	dynbuf_appendn(ctx.out, n->program_decl.name, n->program_decl.name_len);
	dynbuf_append_char(ctx.out, '(');
	if (n->program_decl.param_count > 0) {
		dynbuf_append(ctx.out, "argc");
	}
	if (n->program_decl.param_count > 1) {
		dynbuf_append(ctx.out, ", argv");
	}
	dynbuf_append(ctx.out, ");\n");
	if (n->program_decl.return_type == NULL) {
		// default return value from main.
		emit_indent(ctx.out, 1);
		dynbuf_append(ctx.out, "return 0;\n");
	}
	dynbuf_append(ctx.out, "}\n");
}


/**
 * Generate program as main
 */
// static void codegen_c_as_main(const Node *n, CodegenContext ctx)
// {
// 	// Return type for main must always be int
// 	dynbuf_append(ctx.out, "int main");

// 	// Parameter list
// 	emit_param_list(ctx.out, n->program_decl.params, n->program_decl.param_count, false);

// 	// Body
// 	if (n->program_decl.block != NULL) {
// 		codegen_c_block(n->program_decl.block, ctx);
// 	} else {
// 		dynbuf_append(ctx.out, "{\n");
// 		emit_indent(ctx.out, ctx.indent + 1);
// 		dynbuf_append(ctx.out, "/* Empty body */\n");
// 		dynbuf_append(ctx.out, "}\n");
// 	}
// }


/**
 * Generate module entry point using module name, parameters, and block.
 */
static void codegen_c_module(const Node *n, CodegenContext ctx)
{
	// Return type
	if (n->program_decl.return_type != NULL) {
		emit_return_type(ctx.out, n->program_decl.return_type);
		dynbuf_append_char(ctx.out, ' ');
	} else {
		dynbuf_append(ctx.out, "void ");
	}

	// module name
	dynbuf_appendn(ctx.out, n->program_decl.name, n->program_decl.name_len);

	// Parameter list
	emit_param_list(ctx.out, n->program_decl.params, n->program_decl.param_count, true, false);

	dynbuf_append_char(ctx.out, '\n');

	// Body
	if (n->program_decl.block != NULL) {
		codegen_c_block(n->program_decl.block, ctx);			// TODO: FLAG
	} else {
		dynbuf_append(ctx.out, "{\n");
		emit_indent(ctx.out, ctx.indent + 1);
		dynbuf_append(ctx.out, "/* Empty body */\n");
		dynbuf_append(ctx.out, "}\n");
	}
}


/**
 * Emit top-level program / module
 */
static void codegen_c_program(const Node *n, CodegenContext ctx)
{
	if (n == NULL or n->kind != NODE_PROGRAM) {
		fprintf(stderr, "FATAL ERROR: codegen_c_program: expected NODE_PROGRAM\n");
		exit(1);
	}

    dynbuf_append(ctx.out, "/* =====================================\n");
    dynbuf_append(ctx.out, " * Generated by Mod-c " VERSION_BASE "\n");

	if (n->program_decl.unit_kind == TOK_KEYWORD_PROGRAM) {
		dynbuf_append(ctx.out, " * PROGRAM ");
	} else if (n->program_decl.unit_kind == TOK_KEYWORD_MODULE) {
		dynbuf_append(ctx.out, " * MODULE ");
	} else {
		dynbuf_append(ctx.out, " * UNKNOWN ");
	}
	dynbuf_appendn(ctx.out, n->program_decl.name, n->program_decl.name_len);
	dynbuf_append_char(ctx.out, '\n');
    dynbuf_append(ctx.out, " * ===================================== */\n\n");

	dynbuf_append(ctx.out, "#include \"");
	dynbuf_appendn(ctx.out, n->program_decl.name, n->program_decl.name_len);
	dynbuf_append(ctx.out, ".h\"\n\n");

	// does it make sense to have the module prototype between imports and declarations? Assuming there are any?
	if (ctx.debug_enabled) { dynbuf_append(ctx.out, "/********** Module Prototype ****************/\n\n"); }

	// If MODULE, include module defintion header, which will have the prototype.
	if (n->program_decl.unit_kind == TOK_KEYWORD_MODULE) {
		codegen_common_module_prototype(n, ctx);
	}

	// dynbuf_append_char(ctx.out, '\n');

	// Declaration sequence. It is possible for decls to be NULL.
	if (n->program_decl.decls != NULL) {
		// Count imports and declarations
		// int i_count = 0;
		// int d_count = 0;

		// for (size_t i = 0; i < n->program_decl.count; i++) {
		// 	const Node *d = n->program_decl.decls[i];

		// 	if (d->kind == NODE_IMPORT) {
		// 		i_count++;
		// 	} else {
		// 		d_count++;
		// 	}
		// }

		// Emit imports and declarations.
		if (ctx.debug_enabled) { dynbuf_append(ctx.out, "/********** Top Level Declarations ********/\n\n"); }
		for (size_t i = 0; i < n->program_decl.count; i++) {
			const Node *d = n->program_decl.decls[i];
			if (d->kind == NODE_IMPORT) {
				codegen_common_import(d, ctx);
			} else {
				codegen_c_stmt(d, ctx);
			}
		}
		dynbuf_append_char(ctx.out, '\n');

		// Emit all imports before any other declarations.
		// if (i_count > 0) {
			// if (ctx.debug_enabled) { dynbuf_append(ctx.out, "/********** Imports ***********/\n\n"); }
			// for (size_t i = 0; i < n->program_decl.count; i++) {
			// 	const Node *d = n->program_decl.decls[i];
			// 	if (d->kind == NODE_IMPORT) {
			// 		codegen_common_import(d, ctx);
			// 	}
			// }
		// }

		// All other declarations
		// if (d_count > 0) {
			// if (ctx.debug_enabled) { dynbuf_append(ctx.out, "/********** Declaration Sequence **********/\n"); }
			// for (size_t i = 0; i < n->program_decl.count; i++) {
			// 	const Node *d = n->program_decl.decls[i];
			// 	if (d->kind != NODE_IMPORT) {
			// 		codegen_c_stmt(d, ctx);
			// 	}
			// }
			// if (ctx.debug_enabled) { dynbuf_append(ctx.out, "/********** Declaration Sequence End **********/\n\n"); }
		// }
	}

	// Program/module function.
	if (n->program_decl.unit_kind == TOK_KEYWORD_PROGRAM) {
		// Always create a main() wrapper.
		codegen_c_main_wrapper(n, ctx);

		// // If program has any kind of return type, wrap it around a separate main() 
		// if (n->program_decl.return_type != NULL) {
		// 	if (ctx.debug_enabled) { dynbuf_append(ctx.out, "/********** Program Body with Wrapper **********/\n\n"); }
		// 	codegen_c_main_wrapper(n, ctx);
		// } else {
		// 	if (ctx.debug_enabled) { dynbuf_append(ctx.out, "/********** Program Body as Main **********/\n\n"); }
		// 	codegen_c_as_main(n, ctx);
		// }

	} else if (n->program_decl.unit_kind == TOK_KEYWORD_MODULE) {
		if (ctx.debug_enabled) { dynbuf_append(ctx.out, "/********** Module Body **********/\n\n"); }
		codegen_c_module(n, ctx);
	}
}


/**
 * Public entry point: generate C code from AST
 * Writes to the provided DynBuf.
 * Exits on fatal error.
 */
void codegen_c(CodegenContext ctx)
{
    if (ctx.ast == NULL or ctx.out == NULL) {
        fprintf(stderr, "FATAL ERROR: codegen_c: NULL argument\n");
        exit(1);
    }

	// TODO: Check AST and call codegen_program for PROGRAM or
	// call codegen_c_module for MODULE.
	codegen_c_program(ctx.ast, ctx);
}
