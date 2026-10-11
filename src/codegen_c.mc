module codegen_c(ctx: CodegenContext)

(**
 * TMod-c
 * By M. Scott Reynolds
 * Date 18 April 2026
 *
 * codegen_c.c -    Basic C code generator from Mod-c AST
 *              Phase 1: simple translation of program, declarations,
 *              statements, expressions, and array indexing.
 *              Updated 23 April 2026: WHILE, FOR, REPEAT, LOOP
 *              full IF/ELSIF/ELSE, array literals beyond {0}, and
 *              compound assignments, ASSERT, SIZEOF, and
 *              remaining small self-hosting fixes.
 * 07 May 2026  Add NODE_BREAK, NODE_CONTINUE
 * 14 May 2026  Refactored to use CodegenContext (DynBuf*, indent, parent, etc.)
 *              for cleaner recursion and future scope/defer support.
 * 30 May 2026  RENAMED from codegen.c to codegen_c.c
 * 10 June 2026 Add codegen for SWITCH (explicit breaks for no-fallthrough,
 *              ELSE required -> default:, comma labels as cascaded cases).
 * Port to TMod-c started 6 Oct 2026.
 *)

import CodegenContext, codegen_common_proc_or_func, ctx_push, codegen_common_expr,
    emit_indent, codegen_common_type_decl, emit_return_type, emit_doc_comment_as_c,
    codegen_common_preprocessor, codegen_common_define, emit_type_specifier,
    emit_let_binding_name, emit_var_decl, codegen_common_inc_dec, emit_param_list,
    codegen_common_module_prototype, codegen_common_import,
    from codegen_common
import codegen_dbc_emit_invariants, codegen_dbc_emit_ensures_to_func,
    codegen_dbc_emit_invariants_to_loop, codegen_dbc_emit_requires, 
    codegen_dbc_emit_ensures,
    from codegen_dbc
import dynbuf_append_char, dynbuf_appendn, dynbuf_append, 
    from dynbuf
import TokenKind, TokenKind::string, TOK_KEYWORD_PROGRAM, TOK_KEYWORD_MODULE,
    from Lexer
import Node, NODE_ASSERT, NODE_IF, NODE_WHILE, NODE_FOR, NODE_REPEAT_UNTIL, NODE_LOOP,
    NODE_SWITCH, SwitchCase, NODE_BLOCK, NODE_RETURN, NODE_PROGRAM, NODE_BREAK,
    NODE_CONTINUE, NODE_DOC_COMMENT, NODE_PREPROCESSOR, NODE_DEFINE, NODE_EXPR_STMT,
    NODE_ASSIGN, NODE_DEFER, NODE_DEBUG, NODE_LET_DECL, NODE_VAR_DECL, NODE_CONST_DECL,
    NODE_PROC_DECL, NODE_FUNC_DECL, NODE_TYPE_DECL, NODE_INC, NODE_DEC, NODE_STRUCT_DECL,
    NODE_VAR_ITEM, NODE_CONST_ITEM, NODE_LET_ITEM, NODE_PARAM, NODE_PARAM_LIST,
    NODE_IMPORT, NODE_IMPORT_ITEM, NODE_FIELD_DECL, NODE_METHOD_TYPE, NODE_ARRAY_TYPE,
    NODE_ARRAY_LITERAL, NODE_ARRAY_INDEX, NODE_FIELD_ACCESS, NODE_ELSIF, NODE_ELSE,
    NODE_SIZEOF, NODE_COUNTOF, NODE_BINARY, NODE_UNARY, NODE_TERNARY, NODE_CAST,
    NODE_LITERAL, NODE_IDENT, NODE_CALL, NODE_PAREN,
    from "node.h"
import size_t
    from "stddef.h"
import snprintf, fprintf, stderr,
    from "stdio.h"
import exit 
    from "stdlib.h"
import TType 
    from ttype
import VERSION_BASE 
    from "version.h"


// import from "string.h"
// import from utils


(**
 * Generate C source code from the given AST in the CodegenContext.
 * The output is written into the provided DynBuf (which must be initialized),
 * also set in the CodegenContext.
 * Exits program on fatal error.
 *)
// export procedure codegen_c(ctx: CodegenContext) forward


procedure codegen_c_stmt(n: const ^Node, ctx: CodegenContext) forward
procedure codegen_c_block(n: const ^Node, ctx: CodegenContext) forward
procedure codegen_c_if_stmt(n: const ^Node, ctx: CodegenContext) forward
procedure codegen_c_while_stmt(n: const ^Node, ctx: CodegenContext) forward
procedure codegen_c_for_stmt(n: const ^Node, ctx: CodegenContext) forward
procedure codegen_c_repeat_until_stmt(n: const ^Node, ctx: CodegenContext) forward
procedure codegen_c_loop_stmt(n: const ^Node, ctx: CodegenContext) forward
procedure codegen_c_switch_stmt(n: const ^Node, ctx: CodegenContext) forward
procedure codegen_c_defer_stmt(n: const ^Node, ctx: CodegenContext) forward
procedure codegen_c_assert_stmt(n: const ^Node, ctx: CodegenContext) forward
procedure codegen_c_proc_or_func(n: const ^Node, ctx: CodegenContext) forward
procedure codegen_c_program(n: const ^Node, ctx: CodegenContext) forward
procedure codegen_c_type_decl(n: const ^Node, ctx: CodegenContext) forward


(* ================================================
 * Codegen Node and Context routines
 * ================================================ *)


(**
 * Emit PROCEDURE or FUNCTION declaration.
 * Maps to C function with proper return type and parameters.
 * Body is emitted as a block.
 * If no body is defined, treat it as a prototype.
 *)
procedure codegen_c_proc_or_func(n: const ^Node, ctx: CodegenContext)
begin
    if n == nil then
        return
    end

    codegen_common_proc_or_func(n, ctx)

    // Body block
    if n.proc_decl.body <> nil then
        var child: CodegenContext;

        dynbuf_append_char(ctx.out, '\n')
        child := ctx_push(@ctx, n)
        codegen_c_block(n.proc_decl.body, child)
    else
        // Prototype function declaration
        dynbuf_append_char(ctx.out, ';')
    end
    dynbuf_append(ctx.out, "\n")
end codegen_c_proc_or_func


(**
 * Emit DEFER (phase 1: simple comment wrapper).
 *)
procedure codegen_c_defer_stmt(n: const ^Node, ctx: CodegenContext)
begin
    if n == nil then
        return
    end

    dynbuf_append(ctx.out, "/* DEFER begin */\n")
end codegen_c_defer_stmt


(**
 * Emit DEBUG statements if debug flag has been set in the context.
 *)
procedure codegen_c_debug_stmt(n: const ^Node, ctx: CodegenContext)
begin
    if n == nil then
        return
    end

    if ctx.debug_enabled then
        // Generate code that followed a debug statement
        dynbuf_append(ctx.out, "/* DEBUG */\n")
        codegen_c_stmt(n.debug_stmt.action, ctx)
    end
end codegen_c_debug_stmt


(**
 * Emit ASSERT (cond [, hint])
 *)
procedure codegen_c_assert_stmt(n: const ^Node, ctx: CodegenContext)
begin
    if n == nil or n.kind <> NODE_ASSERT or ctx.assert_off then
        return
    end

    dynbuf_append(ctx.out, "assert(")
    codegen_common_expr(n.assert_stmt.condition, ctx)
    dynbuf_append(ctx.out, ");")

    if n.assert_stmt.const_expr <> nil then
        dynbuf_append(ctx.out, " /* ")
        codegen_common_expr(n.assert_stmt.const_expr, ctx)
        dynbuf_append(ctx.out, " */")
    end

    dynbuf_append(ctx.out, "\n")
end codegen_c_assert_stmt


(**
 * Emit IF / ELSIF / ELSE chain.
 * Handles the full TMod-c if-then-elsif-else-end structure.
 *)
procedure codegen_c_if_stmt(n: const ^Node, ctx: CodegenContext)
begin
    var else_: const ^Node
    var elsif_: const ^Node

    if n == nil or n.kind <> NODE_IF then
        dynbuf_append(ctx.out, "/* TODO: codegen_c_if_stmt: invalid if node */\n")
        return
    end

    dynbuf_append(ctx.out, "if (")
    codegen_common_expr(n.if_stmt.cond, ctx)
    dynbuf_append(ctx.out, ")\n")

    // if statements are stored as BLOCKs, with will take care of the matching {} pairs.
    begin
        var child: CodegenContext = ctx_push(@ctx, n)
        codegen_c_stmt(n.if_stmt.then_, child)
    end

    // ELSIF chain.
    // Final else statement is parsed onto the last elsif.
    else_ := n.if_stmt.else_
    elsif_ := n.if_stmt.elsif_
    while elsif_ <> nil do
        var child: CodegenContext

        emit_indent(ctx.out, ctx.indent)
        dynbuf_append(ctx.out, "else if (")

        codegen_common_expr(elsif_.if_stmt.cond, ctx)
        dynbuf_append(ctx.out, ")\n")

        child := ctx_push(@ctx, elsif_)
        codegen_c_stmt(elsif_.if_stmt.then_, child)

        else_ := elsif_.if_stmt.else_
        elsif_ := elsif_.if_stmt.elsif_
    end

    // Optional ELSE
    if else_ <> nil then
        var child: CodegenContext

        emit_indent(ctx.out, ctx.indent)
        dynbuf_append(ctx.out, "else\n")

        child := ctx_push(@ctx, n)
        codegen_c_stmt(else_, child)
    end
end codegen_c_if_stmt


(**
 * Emit WHILE ... DO ... END
 *)
procedure codegen_c_while_stmt(n: const ^Node, ctx: CodegenContext)
begin
    if n == nil or n.kind <> NODE_WHILE then
        return
    end

    dynbuf_append(ctx.out, "while (")
    codegen_common_expr(n.while_stmt.cond, ctx)
    dynbuf_append(ctx.out, ")\n")

    emit_indent(ctx.out, ctx.indent)
    dynbuf_append(ctx.out, "{\n")
    inc(ctx.indent)

    begin
        var child: CodegenContext = ctx_push(@ctx, n)

        child.enclosing_loop := n               // important for BREAK/CONTINUE
        codegen_dbc_emit_invariants(n, child)
        codegen_c_stmt(n.while_stmt.body, child)
        dec(ctx.indent)
        emit_indent(ctx.out, ctx.indent)
        dynbuf_append(ctx.out, "}\n")
        codegen_dbc_emit_invariants(n, ctx)
    end
end codegen_c_while_stmt


(**
 * Emit FOR ... TO/DOWNTO ... BY ... DO ... END
 *)
procedure codegen_c_for_stmt(n: const ^Node, ctx: CodegenContext)
begin
    var buf: array[32] of char

    if n == nil or n.kind <> NODE_FOR then
        return
    end

    dynbuf_append(ctx.out, "{\n")
    inc(ctx.indent)

    // Evaluate end bound once
    emit_indent(ctx.out, ctx.indent)
    dynbuf_append(ctx.out, "const long long __for_end_l")
    snprintf(buf, sizeof(buf), "%d", n.token.line)
    dynbuf_append(ctx.out, buf)
    dynbuf_append(ctx.out, " = (long long)(")
    codegen_common_expr(n.for_stmt.end_, ctx)
    dynbuf_append(ctx.out, ");\n")

    emit_indent(ctx.out, ctx.indent)
    dynbuf_append(ctx.out, "for (")
    dynbuf_appendn(ctx.out, n.for_stmt.var_name, n.for_stmt.var_len)
    dynbuf_append(ctx.out, " = ")
    codegen_common_expr(n.for_stmt.start_, ctx)
    dynbuf_append(ctx.out, "; ")

    // Condition
    dynbuf_append(ctx.out, "(long long)(")
    dynbuf_appendn(ctx.out, n.for_stmt.var_name, n.for_stmt.var_len)
    dynbuf_append(ctx.out, ")")

    if n.for_stmt.step >= 0 then
        dynbuf_append(ctx.out, " <= __for_end_l")
    else
        dynbuf_append(ctx.out, " >= __for_end_l")
    end
    snprintf(buf, sizeof(buf), "%d", n.token.line)
    dynbuf_append(ctx.out, buf)
    dynbuf_append(ctx.out, "; ")

    // increment / decrement by step
    dynbuf_appendn(ctx.out, n.for_stmt.var_name, n.for_stmt.var_len)
    if n.for_stmt.step == 1 then
        dynbuf_append(ctx.out, "++")
    elsif n.for_stmt.step == -1 then
        dynbuf_append(ctx.out, "--")
    elsif n.for_stmt.step > 0 then
        dynbuf_append(ctx.out, " += ")
        // Simple integer literal for step
        snprintf(buf, sizeof(buf), "%d", n.for_stmt.step)
        dynbuf_append(ctx.out, buf)
    else
        dynbuf_append(ctx.out, " -= ")
        snprintf(buf, sizeof(buf), "%d", -n.for_stmt.step)
        dynbuf_append(ctx.out, buf)
    end

    dynbuf_append(ctx.out, ")\n")

    emit_indent(ctx.out, ctx.indent)
    dynbuf_append(ctx.out, "{\n")
    inc(ctx.indent)
    begin
        var child: CodegenContext = ctx_push(@ctx, n)

        child.enclosing_loop := n
        codegen_dbc_emit_invariants(n, child)
        codegen_c_stmt(n.for_stmt.body, child)
        dec(ctx.indent)
    end

    emit_indent(ctx.out, ctx.indent)
    dynbuf_append(ctx.out, "}\n")
    codegen_dbc_emit_invariants(n, ctx)

    dec(ctx.indent)
    emit_indent(ctx.out, ctx.indent)
    dynbuf_append(ctx.out, "}\n")
end codegen_c_for_stmt


(**
 * Emit REPEAT ... UNTIL ...
 *)
procedure codegen_c_repeat_until_stmt(n: const ^Node, ctx: CodegenContext)
begin
    if n == nil or n.kind <> NODE_REPEAT_UNTIL then
        return
    end

    dynbuf_append(ctx.out, "do\n")

    emit_indent(ctx.out, ctx.indent)
    dynbuf_append(ctx.out, "{\n")
    inc(ctx.indent)
    begin
        var child: CodegenContext = ctx_push(@ctx, n)

        codegen_dbc_emit_invariants(n, child)
        codegen_c_stmt(n.repeat_until.body, child)
        dec(ctx.indent)
    end
    emit_indent(ctx.out, ctx.indent)
    dynbuf_append(ctx.out, "}\n")

    emit_indent(ctx.out, ctx.indent)
    dynbuf_append(ctx.out, "while (!(")
    codegen_common_expr(n.repeat_until.cond, ctx)
    dynbuf_append(ctx.out, "));\n")
    codegen_dbc_emit_invariants(n, ctx)
end codegen_c_repeat_until_stmt


(**
 * Emit LOOP ... END (infinite loop)
 *)
procedure codegen_c_loop_stmt(n: const ^Node, ctx: CodegenContext)
begin
    if n == nil or n.kind <> NODE_LOOP then
        return
    end

    dynbuf_append(ctx.out, "while (1)\n")

    emit_indent(ctx.out, ctx.indent)
    dynbuf_append(ctx.out, "{\n")
    inc(ctx.indent)
    begin
        var child: CodegenContext = ctx_push(@ctx, n)
        child.enclosing_loop := n
        codegen_dbc_emit_invariants(n, child)
        codegen_c_stmt(n.loop_stmt.body, child)
        dec(ctx.indent)
    end
    emit_indent(ctx.out, ctx.indent)
    dynbuf_append(ctx.out, "}\n")
    codegen_dbc_emit_invariants(n, ctx)
end codegen_c_loop_stmt


(**
 * Emit SWITCH ... OF ... CASE ... ELSE ... END
 * Maps to a C switch. No fallthrough (we emit explic break; after each arm's body).
 * Comma lables become successive "case X:" (they share the following body until the break)
 * ELSE (required in source) becomes "default:". A break; is emitted after the default arm
 * for symetry.
 *)
procedure codegen_c_switch_stmt(n: const ^Node, ctx: CodegenContext)
begin
    if n == nil or n.kind <> NODE_SWITCH then
        dynbuf_append(ctx.out, "/* TODO: codegen_c_switch_stmt: invalid switch node */\n")
        return
    end

    // The caller (codegen_c_stmt) has already done emit_indent for the statement start.
    dynbuf_append(ctx.out, "switch (")
    codegen_common_expr(n.switch_stmt.expr, ctx)
    dynbuf_append(ctx.out, ")\n")

    // Opening { for the switch (at the same indent level as the "switch" line).
    emit_indent(ctx.out, ctx.indent)
    dynbuf_append(ctx.out, "{\n")

    // Everything for cases/default/breaks + the arm bodies (which are NODE_BLOCKS)
    // lives at +1
    begin
        var arm_ctx: CodegenContext = ctx_push(@ctx, n)
        var i: size_t

        arm_ctx.indent := ctx.indent + 1

        // CASE arms (zero or more)
        for i := 0 to n.switch_stmt.case_count - 1 do 
            var c: ^SwitchCase = n.switch_stmt.cases[i]
            var j: size_t

            if c == nil then
                continue
            end

            for j := 0 to c.label_count - 1 do
                emit_indent(ctx.out, arm_ctx.indent)
                dynbuf_append(ctx.out, "case ")
                codegen_common_expr(c.labels[j], arm_ctx)
                dynbuf_append(ctx.out, ":\n")
            end

            // Body is a statement-sequence -> NODE_BLOCK from parse_statement_sequence.
            // It will emit its own { ... } (with inner indent + 1) and handle
            // any defers in the arm.
            codegen_c_stmt(c.body, arm_ctx)

            // Envorce TMod-c "no fallthrough" semantics in the generated C.
            emit_indent(ctx.out, arm_ctx.indent)
            dynbuf_append(ctx.out, "break;\n")
        end

        // ELSE (required) -> default
        emit_indent(ctx.out, arm_ctx.indent)
        dynbuf_append(ctx.out, "default:\n")
        codegen_c_stmt(n.switch_stmt.else_body, arm_ctx)

        // Explicit break after the final arm too (symmetry + matches "after each arm"
        // comment)
        emit_indent(ctx.out, arm_ctx.indent)
        dynbuf_append(ctx.out, "break;\n")
    end

    // Close the switch compound statement.
    emit_indent(ctx.out, ctx.indent)
    dynbuf_append(ctx.out, "}\n")
end codegen_c_switch_stmt


(**
 * Emit a TYPE declaration.
 * Simple types for now.
 *)
procedure codegen_c_type_decl(n: const ^Node, ctx: CodegenContext)
begin
    if n == nil then
        return
    end

    // If type is exported, skip because they will be exported in the definition header.
    if not n.type_decl.is_exported then
        codegen_common_type_decl(n, ctx)
    end

end codegen_c_type_decl


(**
 * Index of stmt in block->block.stmts, or (size_t) - 1 if not direct child.
 * DEFER nodes are stored both in stmts[] and in defers[]; pointer equality
 * is the link.
 *)
function codegen_c_block_stmt_index(block: const ^Node, stmt: const ^Node): size_t
begin
    var i: size_t

    if block == nil or block.kind <> NODE_BLOCK or stmt == nil then
        return (-1) as size_t
    end

    for i := 0 to block.block.count-1 do
        if block.block.stmts[i] == stmt then
            return i
        end
    end
    return (-1) as size_t

end codegen_c_block_stmt_index


function codegen_c_block_has_reached_defer(block: const ^Node, cutoff: size_t): bool
begin
    var i: size_t
    var at: size_t

    if block == nil or block.kind <> NODE_BLOCK then
        return false
    end

    for i := 0 to block.block.defer_count -1 do
        var d: const ^Node = block.block.defers[i]
        if d == nil then
            continue
        end
        at := codegen_c_block_stmt_index(block, d)
        if at <> (-1) as size_t and at < cutoff then
            return true
        end
    end
    return false

end codegen_c_block_has_reached_defer


(**
 * Emit a DEFER statement.
 * C2y / Language Report 7.3: a defer runs only if contorl passed the
 * DEFER stateent. ctx.stmt_index is the cutoff in this block (see
 * CodegenContext.stmt_index); LIFO amongh those that qualify.
 *)
procedure codegen_c_emit_defers(block_node: const ^Node, ctx: CodegenContext)
begin
    var cutoff: size_t
    var i: size_t

    if block_node == nil or block_node.kind <> NODE_BLOCK then
        return
    end

    cutoff := ctx.stmt_index

    // Emit in reverse order (LIFO)
    for i := block_node.block.defer_count downto 1 do
        var d: const ^Node = block_node.block.defers[i - 1]
        var at: size_t

        if d == nil then
            continue
        end
        at := codegen_c_block_stmt_index(block_node, d)
        if at == (-1) as size_t or at >= cutoff then
            continue
        end

        emit_indent(ctx.out, ctx.indent)
        dynbuf_append(ctx.out, "/* DEFER end */\n")
        codegen_c_stmt(d.defer_stmt.action, ctx)
    end
end codegen_c_emit_defers


(**
 * Emit defers by walking up the context chain until we reach the
 * enclosing function. Used by RETURN statements.
 *)
procedure codegen_c_emit_defers_to_func(ctx: CodegenContext)
begin
    var current: CodegenContext = ctx
    var target_func: const ^Node = ctx.enclosing_func

    while current.parent_ctx <> nil do
        if current.parent_node <> nil and current.parent_node.kind == NODE_BLOCK then
            if codegen_c_block_has_reached_defer(current.parent_node, current.stmt_index) then
                emit_indent(ctx.out, ctx.indent)
                dynbuf_append(ctx.out, "/* DEFER cleanup (unwinding to function) */\n")
                codegen_c_emit_defers(current.parent_node, current)
            end
        end

        // Stop when w ereach the function body block
        if current.enclosing_func <> nil and current.parent_node == target_func then
            break
        end

        current := current.parent_ctx^
    end
end codegen_c_emit_defers_to_func


(**
 * Emit defers by walking up the context chain until we reach the
 * enclosing loop. Used by BREAK and CONTINUE statements.
 *)
procedure codegen_c_emit_defers_to_loop(ctx: CodegenContext)
begin
    var current: CodegenContext = ctx
    var target_loop: const ^Node = ctx.enclosing_loop

    while current.parent_ctx <> nil do
        if current.parent_node <> nil and current.parent_node.kind == NODE_BLOCK then
            if codegen_c_block_has_reached_defer(current.parent_node, current.stmt_index) then
                dynbuf_append(ctx.out, "/* DEFER cleanup (unwinding to loop) */\n")
                codegen_c_emit_defers(current.parent_node, current)
            end
        end

        // Stop before processing the loop's own block
        if current.parent_node <> nil and current.parent_node == target_loop then
            break
        end

        current := current.parent_ctx^
    end
end codegen_c_emit_defers_to_loop


(**
 * Emit RETURN statement with proper DEFER cleanup.
 * Grammar: "RETURN" [ expression ]
 *)
procedure codegen_c_return_stmt(n: const ^Node, ctx: CodegenContext)
begin
    if n == nil or n.kind <> NODE_RETURN then
        return
    end

    codegen_dbc_emit_ensures_to_func(ctx)

    if n.ret.expr <> nil then
        // Evaluate return expression into a temporary first
        // (prevents defer from modifying the return value or
        // free resources the expression depends on).
        var line: int = n.token.line
        var ret_type: ^TType = nil
        var buf: array[32] of char

        dynbuf_append(ctx.out, "/* return value captured before defers */\n")

        emit_indent(ctx.out, ctx.indent)

        // Emit the correct return type for the temporary
        if ctx.enclosing_func <> nil then
            ret_type := ctx.enclosing_func.func_decl.return_type
        elsif ctx.ast <> nil and ctx.ast.kind == NODE_PROGRAM then
            ret_type := ctx.ast.program_decl.return_type
        end
        emit_return_type(ctx.out, ret_type)

        dynbuf_append_char(ctx.out, ' ')
        dynbuf_append(ctx.out, "__ret_l")

        snprintf(buf, sizeof(buf), "%d", line)
        dynbuf_append(ctx.out, buf)

        dynbuf_append(ctx.out, " = ")
        codegen_common_expr(n.ret.expr, ctx)
        dynbuf_append(ctx.out, ";\n")

        // Now run any pending defers
        codegen_c_emit_defers_to_func(ctx)

        // Finally return the captured value
        emit_indent(ctx.out, ctx.indent)
        dynbuf_append(ctx.out, "return __ret_l")
        dynbuf_append(ctx.out, buf)                 // reuse previous buf line
        dynbuf_append(ctx.out, ";\n")
    else
        // Plain return with no value
        codegen_c_emit_defers_to_func(ctx)

        emit_indent(ctx.out, ctx.indent)
        dynbuf_append(ctx.out, "return;\n")
    end
end codegen_c_return_stmt


(**
 * Emit BREAK statement with proper DEFER cleaup
 * Grammar "BREAK"
 *)
procedure codegen_c_break_stmt(n: const ^Node, ctx: CodegenContext)
begin
    if n == nil or n.kind <> NODE_BREAK then
        return
    end

    // 1. Run any pending DEFERs for the current enclosing block
    codegen_c_emit_defers_to_loop(ctx)

    codegen_dbc_emit_invariants_to_loop(ctx)

    // 2. Emit the actual break
    emit_indent(ctx.out, ctx.indent)
    dynbuf_append(ctx.out, "break;\n")
end codegen_c_break_stmt


(**
 * Emit CONTINUE statement wiht proper DEFER cleanup.
 * Grammar: "CONTINUE"
 *)
procedure codegen_c_continue_stmt(n: const ^Node, ctx: CodegenContext)
begin
    if n == nil or n.kind <> NODE_CONTINUE then
        return
    end

    // 1. Run any pending DEFERs for the current enclosing block
    codegen_c_emit_defers_to_loop(ctx)

    codegen_dbc_emit_invariants_to_loop(ctx)

    // 2. Emit the actual continue
    emit_indent(ctx.out, ctx.indent)
    dynbuf_append(ctx.out, "continue;\n")
end codegen_c_continue_stmt


(**
 * Emit a single statement
 *)
procedure codegen_c_stmt(n: const ^Node, ctx: CodegenContext)
begin
    if n == nil then
        return
    end

    emit_indent(ctx.out, ctx.indent)

    switch n.kind of
        case NODE_DOC_COMMENT:
            emit_doc_comment_as_c(ctx.out, n)

        case NODE_PREPROCESSOR:
            codegen_common_preprocessor(n, ctx)

        case NODE_DEFINE:
            codegen_common_define(n, ctx)

        case NODE_EXPR_STMT:
            codegen_common_expr(n.expr_stmt.expr, ctx)
            dynbuf_append(ctx.out, ";\n")

        case NODE_ASSIGN:
            codegen_common_expr(n, ctx)
            dynbuf_append(ctx.out, ";\n")

        case NODE_RETURN:
            codegen_c_return_stmt(n, ctx)

        case NODE_BREAK:
            codegen_c_break_stmt(n, ctx)

        case NODE_CONTINUE:
            codegen_c_continue_stmt(n, ctx)

        case NODE_DEFER:
            codegen_c_defer_stmt(n, ctx)        // Only puts a comment i noutput.

        case NODE_DEBUG:
            codegen_c_debug_stmt(n, ctx)        // Handle debug statements

        case NODE_IF:
            codegen_c_if_stmt(n, ctx)

        case NODE_WHILE:
            codegen_c_while_stmt(n, ctx)

        case NODE_FOR:
            codegen_c_for_stmt(n, ctx)

        case NODE_REPEAT_UNTIL:
            codegen_c_repeat_until_stmt(n, ctx)

        case NODE_LOOP:
            codegen_c_loop_stmt(n, ctx)

        case NODE_SWITCH:
            codegen_c_switch_stmt(n, ctx)

        case NODE_ASSERT:
            codegen_c_assert_stmt(n, ctx)

        case NODE_LET_DECL, NODE_VAR_DECL, NODE_CONST_DECL:
            var i: size_t

            for i := 0 to n.var_decl.count -1 do
                var item: const ^Node = n.var_decl.items[i]

                if item == nil then
                    continue
                end
                if i > 0 then
                    emit_indent(ctx.out, ctx.indent)
                end

                if n.var_decl.is_extern then
                    dynbuf_append(ctx.out, "extern ")
                elsif n.var_decl.is_static or ctx.parent_node == nil then
                    dynbuf_append(ctx.out, "static ")
                end

                // CONST declarations only. LET is a rebind lock in
                // TMod-c; C must not freeze the object or pointee.
                if n.kind == NODE_CONST_DECL then
                    dynbuf_append(ctx.out, "const ")
                end

                if n.kind == NODE_LET_DECL then
                    if item.var_item.item_type <> nil then
                        emit_type_specifier(ctx.out, item.var_item.item_type,
                            nil, 0, false, false, false, false)
                        dynbuf_append_char(ctx.out, ' ')
                    else
                        dynbuf_append(ctx.out, "int ")
                    end
                    emit_let_binding_name(ctx.out, 
                        item.var_item.name,
                        item.var_item.name_len,
                        item)
                else
                    emit_var_decl(ctx.out,
                        item.var_item.name,
                        item.var_item.name_len,
                        item.var_item.item_type)
                end

                if not n.var_decl.is_extern then
                    if item.var_item.initializer <> nil then
                        dynbuf_append(ctx.out, " = ")
                        codegen_common_expr(item.var_item.initializer, ctx)
                    else
                        // Zero-initialize structs/arrays by defualt (common pattern)
                        // another safe fallback
                        // TODO: if non-struct/array...
                        dynbuf_append(ctx.out, " = {0}")
                    end
                end
                dynbuf_append(ctx.out, ";\n")
            end

        case NODE_PROC_DECL, NODE_FUNC_DECL:
            codegen_c_proc_or_func(n, ctx)

        case NODE_BLOCK:
            codegen_c_block(n, ctx)

        case NODE_TYPE_DECL:
            codegen_c_type_decl(n, ctx)

        case NODE_INC, NODE_DEC:
            codegen_common_inc_dec(n, ctx, true)            // statement context

        // Supress unhandled case warnings.
        case NODE_STRUCT_DECL, NODE_PROGRAM, NODE_VAR_ITEM, NODE_CONST_ITEM, NODE_LET_ITEM,
            NODE_PARAM, NODE_PARAM_LIST, NODE_IMPORT, NODE_IMPORT_ITEM, NODE_FIELD_DECL,
            NODE_METHOD_TYPE, NODE_ARRAY_TYPE, NODE_ARRAY_LITERAL, NODE_ARRAY_INDEX,
            NODE_FIELD_ACCESS, NODE_ELSIF, NODE_ELSE, NODE_SIZEOF, NODE_COUNTOF, 
            NODE_BINARY, NODE_UNARY, NODE_TERNARY, NODE_CAST, NODE_LITERAL, NODE_IDENT,
            NODE_CALL, NODE_PAREN:

            dynbuf_append(ctx.out, "/* TODO: codegen_c_stmt: stmt kind ")
            dynbuf_append(ctx.out, TokenKind__string(n.token.kind as TokenKind))
            dynbuf_append(ctx.out, " */\n")

        else:
            dynbuf_append(ctx.out, "/* TODO: codegen_c_stmt: stmt kind ")
            dynbuf_append(ctx.out, TokenKind__string(n.token.kind as TokenKind))
            dynbuf_append(ctx.out, " */\n")
    end
end codegen_c_stmt


(**
 * Emit BEGIN ... END block (statement sequence)
 *)
procedure codegen_c_block(n: const ^Node, ctx: CodegenContext)
begin
    if n == nil then
        return
    end

    dynbuf_append(ctx.out, "{\n")

    begin
        var child_ctx: CodegenContext = ctx_push(@ctx, n)
        var i: size_t
        var early_exit_in_block: bool = false

        child_ctx.indent := ctx.indent + 1

        codegen_dbc_emit_requires(n, child_ctx)

        for i := 0 to n.block.count-1 do
            child_ctx.stmt_index := i
            codegen_c_stmt(n.block.stmts[i], child_ctx)
        end

        // C2y-style: emit defers at block exit UNLESS we already did so via early exit.
        if n.block.count > 0 then
            var last: const ^Node = n.block.stmts[n.block.count - 1]

            if last <> nil and 
                    (last.kind == NODE_RETURN or
                        last.kind == NODE_BREAK OR
                        last.kind == NODE_CONTINUE) then
                early_exit_in_block := true
            end
        end

        if not early_exit_in_block then
            child_ctx.stmt_index := n.block.count       // All DEFERs in this block were reached.
            codegen_dbc_emit_ensures(n, child_ctx)
            codegen_c_emit_defers(n, child_ctx)
        end
    end

    emit_indent(ctx.out, ctx.indent)
    dynbuf_append(ctx.out, "}\n")
end codegen_c_block


(**
 * Generate a separate main(...) wraper for NODE_PROGRAM
 *)
procedure codegen_c_main_wrapper(n: const ^Node, ctx: CodegenContext)
begin
    // Return type
    if n.program_decl.return_type <> nil then
        emit_return_type(ctx.out, n.program_decl.return_type)
        dynbuf_append_char(ctx.out, ' ')
    else
        dynbuf_append(ctx.out, "void ")
    end

    // Program / module name
    dynbuf_appendn(ctx.out, n.program_decl.name, n.program_decl.name_len)

    // Parameter list
    emit_param_list(ctx.out, n.program_decl.params, n.program_decl.param_count,
        true, false)

    dynbuf_append_char(ctx.out, '\n')

    // Body
    if n.program_decl.block <> nil then
        codegen_c_block(n.program_decl.block, ctx)
    else
        dynbuf_append(ctx.out, "{\n")
        emit_indent(ctx.out, ctx.indent + 1)
        dynbuf_append(ctx.out, "/* Empty body */\n")
        dynbuf_append(ctx.out, "}\n")
    end

    dynbuf_append(ctx.out, "\n")

    // Now generate the main(...) wrapper.
    dynbuf_append(ctx.out, "int main")

    // Use the same parameter list for main as supplied by the program header.
    emit_param_list(ctx.out, n.program_decl.params, n.program_decl.param_count,
        true, false)

    dynbuf_append_char(ctx.out, '\n')
    dynbuf_append(ctx.out, "{\n")
    emit_indent(ctx.out, ctx.indent + 1)
    if n.program_decl.return_type <> nil then
        // Assuming program returns same type as main(...)
        dynbuf_append(ctx.out, "return ")
    end
    dynbuf_appendn(ctx.out, n.program_decl.name, n.program_decl.name_len)
    dynbuf_append_char(ctx.out, '(')
    if n.program_decl.param_count > 0 then
        dynbuf_append(ctx.out, "argc")
    end
    if n.program_decl.param_count > 1 then
        dynbuf_append(ctx.out, ", argv")
    end
    dynbuf_append(ctx.out, ");\n")
    if n.program_decl.return_type == nil then
        // default return value from main.
        emit_indent(ctx.out, 1)
        dynbuf_append(ctx.out, "return 0;\n")
    end
    dynbuf_append(ctx.out, "}\n")
end codegen_c_main_wrapper


(**
 * Generate module entry point using module name, parameters, and block.
 *)
procedure codegen_c_module(n: const ^Node, ctx: CodegenContext)
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

    // Parameter list
    emit_param_list(ctx.out, n.program_decl.params, n.program_decl.param_count,
        true, false)

    dynbuf_append_char(ctx.out, '\n')

    // Body
    if n.program_decl.block <> nil then
        codegen_c_block(n.program_decl.block, ctx)
    else
        dynbuf_append(ctx.out, "{\n")
        emit_indent(ctx.out, ctx.indent + 1)
        dynbuf_append(ctx.out, "/* Empty body */\n")
        dynbuf_append(ctx.out, "}\n")
    end
end codegen_c_module


(**
 * Emit top-level program / module
 *)
procedure codegen_c_program(n: const ^Node, ctx: CodegenContext)
begin
    if n == nil or n.kind <> NODE_PROGRAM then
        fprintf(stderr, "FATAL ERROR: codegen_c_program: expected NODE_PROGRAM\n")
        exit(1)
    end

    dynbuf_append(ctx.out, "/* =====================================\n")
    dynbuf_append(ctx.out, " * Generated by Mod-c ")
    dynbuf_append(ctx.out, VERSION_BASE)
    dynbuf_append(ctx.out, "\n")

    if n.program_decl.unit_kind == TOK_KEYWORD_PROGRAM then
        dynbuf_append(ctx.out, " * PROGRAM ")
    elsif n.program_decl.unit_kind == TOK_KEYWORD_MODULE then
        dynbuf_append(ctx.out, " * MODULE ")
    else
        dynbuf_append(ctx.out, " * UNKNOWN ")
    end
    dynbuf_appendn(ctx.out, n.program_decl.name, n.program_decl.name_len)
    dynbuf_append_char(ctx.out, '\n')
    dynbuf_append(ctx.out, " * ===================================== */\n\n")

    dynbuf_append(ctx.out, "#include \"")
    dynbuf_appendn(ctx.out, n.program_decl.name, n.program_decl.name_len)
    dynbuf_append(ctx.out, ".h\"\n\n")

    // Does it make sense to have the module prototype between imports and
    // declarations? Assuming there are any?
    if ctx.debug_enabled then
        dynbuf_append(ctx.out, "/********** Module Prototype ****************/\n\n")
    end

    // if MODULE, include module definition header, which will have the prototype.
    if n.program_decl.unit_kind == TOK_KEYWORD_MODULE then
        codegen_common_module_prototype(n, ctx)
    end

    // Declaration sequence. It is possible for decls to be NIL.
    if n.program_decl.decls <> nil then
        var i: size_t

        // Emit imports and declarations.
        if ctx.debug_enabled then
            dynbuf_append(ctx.out, "/********** Top Level Declarations ********/\n\n")
        end

        for i := 0 to n.program_decl.count - 1 do
            var d: const ^Node = n.program_decl.decls[i]

            if d.kind == NODE_IMPORT then
                codegen_common_import(d, ctx)
            else
                codegen_c_stmt(d, ctx)
            end
        end
        dynbuf_append_char(ctx.out, '\n')
    end

    // Program / module function.
    if n.program_decl.unit_kind == TOK_KEYWORD_PROGRAM then
        // Always create a main() wrapper.
        codegen_c_main_wrapper(n, ctx)
    elsif n.program_decl.unit_kind == TOK_KEYWORD_MODULE then
        if ctx.debug_enabled then
            dynbuf_append(ctx.out, "/********** Module Body **********/\n\n")
        end
        codegen_c_module(n, ctx)
    end
end codegen_c_program


(**
 * Public entry point: generate C code from AST
 * Writes to the provided DynBuf.
 * Exits on fatal error.
 *)
begin
    if ctx.ast == nil or ctx.out == nil then
        fprintf(stderr, "FATAL ERROR: codegen_c_ NULL arguments\n")
        exit(1)
    end

    // TODO: Check AST and call codegen_program for PROGRAM or 
    // call codegen_c_module for MODULE.
    codegen_c_program(ctx.ast, ctx)
end codegen_c
