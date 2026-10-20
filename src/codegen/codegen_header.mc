module codegen.codegen_header(ctx: CodegenContext)

(**
 * Mod-c
 * By M. Scott Reynolds
 * Date 11 July 2026
 *
 * codegen_header.mc - Generate header file from AST.
 *
 * Generation of C header files (.h) for the -H option.
 * Only emits the exported surface of a program/module.
 *)

import size_t 
	from "stddef.h"
import exit 
	from "stdlib.h"
import fprintf, stderr 
	from "stdio.h"
import Node, NODE_LET_DECL, NODE_VAR_DECL, NODE_CONST_DECL,
	NODE_PROC_DECL, NODE_FUNC_DECL, NODE_TYPE_DECL,
	NODE_DOC_COMMENT, NODE_PROGRAM, NODE_IMPORT, NODE_DEFINE,
	from "node.h"
import VERSION_BASE 
	from "version.h"

import pDynBuf, dynbuf_append_char, dynbuf_append, dynbuf_appendn 
	from dynbuf
import type_is_portable_rebindable 
	from ttype
import TOK_KEYWORD_PROGRAM, TOK_KEYWORD_MODULE, TOK_KEYWORD_HEADER,
	from lexer.Lexer

import CodegenContext, emit_indent,	emit_var_decl, emit_doc_comment_as_c, 
	codegen_common_expr, codegen_common_type_decl, codegen_common_import, 
	codegen_common_module_prototype, codegen_common_proc_or_func, 
	codegen_emit_c_prelude, codegen_common_define,
	from codegen.codegen_common


(**
 * Emit Header PROCEDURE or FUNCTION declaration.
 * All treated as a prototype.
 *)
procedure codegen_header_proc_or_func(n: const ^Node, ctx: CodegenContext)
begin
	if n == nil then
		return
	end

	codegen_common_proc_or_func(n, ctx)

	// Prototype function declaration
	dynbuf_append_char(ctx.out, ';')
	dynbuf_append(ctx.out, "\n")
end codegen_header_proc_or_func


(**
 * Generate header exported declaration
 *)
procedure codegen_header_emit_exported(n: const ^Node, ctx: CodegenContext)
begin
	if n == nil then
		return
	end

	// LET, VAR, and COST can be exported
	if (n^.kind == NODE_LET_DECL or
		n^.kind == NODE_VAR_DECL or
		n^.kind == NODE_CONST_DECL) then
		if n^.var_decl.is_exported then
			var i: integer = 0

			emit_indent(ctx.out, ctx.indent)
			dynbuf_append(ctx.out, "/* === LET/VAR/CONST EXPORT === */\n")
			for i := 0 to n^.var_decl.count-1 do
				let item: ^Node = n^.var_decl.items[i]
				if item == nil then
					continue
				end

				if i > 0 then
					emit_indent(ctx.out, ctx.indent)
				end

				if n^.var_decl.is_extern then
					dynbuf_append(ctx.out, "extern ")
				end

				// CONST declarations only. LET is not C const (27b)
				if n^.kind == NODE_CONST_DECL then
					dynbuf_append(ctx.out, "const ")
				end

				emit_var_decl(ctx.out,
					item^.var_item.name,
					item^.var_item.name_len,
					item^.var_item.item_type)

				if not n^.var_decl.is_extern then
					if item^.var_item.initializer <> nil then
						dynbuf_append(ctx.out, " = ")
						codegen_common_expr(item^.var_item.initializer, ctx)
					else
						// Zero-initialize structs/arrays by default (common pattern)
						// another safe fallback
						dynbuf_append(ctx.out, " = {0}")
					end
				end
				dynbuf_append(ctx.out, ";\n")
				dynbuf_append_char(ctx.out, '\n')
			end
		end

	// PROCEDURE/FUNCTION exported
	elsif n^.kind == NODE_PROC_DECL or n^.kind == NODE_FUNC_DECL then
		if n^.proc_decl.is_exported then
			emit_indent(ctx.out, ctx.indent)
			dynbuf_append(ctx.out, "/* === PROC/FUNC EXPORT === */\n")
			codegen_header_proc_or_func(n, ctx)
			dynbuf_append_char(ctx.out, '\n')
		end

	// TYPE declaration exported
	elsif n^.kind == NODE_TYPE_DECL then
		if n^.type_decl.is_exported or
				(n^.type_decl.name <> nil and
					type_is_portable_rebindable(n^.type_decl.name, n^.type_decl.name_len) and
					not n^.type_decl.is_forward and not n^.type_decl.is_extern) then
			emit_indent(ctx.out, ctx.indent)
			dynbuf_append(ctx.out, "/* === TYPE EXPORT === */\n")
			codegen_common_type_decl(n, ctx)
			dynbuf_append_char(ctx.out, '\n')
		end

	// DOC_COMMENTS
	elsif n^.kind == NODE_DOC_COMMENT then
		emit_doc_comment_as_c(ctx.out, n)
		dynbuf_append_char(ctx.out, '\n')
	elsif n^.kind == NODE_DEFINE then
		if n^.define_stmt.is_exported then
			emit_indent(ctx.out, ctx.indent)
			dynbuf_append(ctx.out, "/* === DEFINE EXPORT === */\n")
			codegen_common_define(n, ctx)
			dynbuf_append_char(ctx.out, '\n')
		end
	end
end codegen_header_emit_exported


(*
 * MODC_<KIND>_<stem>_H. A dot or other non-identifier in the stem becomes '_'.
 *)
procedure emit_header_guard_name(out: pDynBuf, header_type: const ^char,
	base: const ^char, base_len: size_t)
begin
	var i: size_t = 0
	var c: char = 0

	dynbuf_append(out, "MODC_")
	dynbuf_append(out, header_type)
	dynbuf_append_char(out, '_')
	for i := 0 to base_len - 1 do
		c := base[i]
		if (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or
				(c >= '0' and c <= '9') or c == '_' then
			dynbuf_append_char(out, c)
		else
			dynbuf_append_char(out, '_')
		end
	end
	dynbuf_append(out, "_H")
end emit_header_guard_name


(**
 * Walk the AST, create header file, and emit only exported declarations.
 *)
procedure codegen_header_program(n: const ^Node, ctx: CodegenContext)
begin
	var header_type: const ^char = "UNKNOWN"
	var guard_base: const ^char = nil
	var guard_len: size_t = 0

	if n == nil or n^.kind <> NODE_PROGRAM then
		fprintf(stderr, "ERROR: codegen_header_program: expected PROGRAM node\n")
		return
	end

	// - Emit includes (from the IMPORT Nodes)
	// - Walk n->program_decl.decls and only emit items where is_exported == true
	// - For procedures/functions -> emit prototypes
	// - For TYPE/CONST -> emit full defiitions
	// - For VAR/LET -> emit extern declarations

	header_type := "UNKNOWN"
	if n^.program_decl.unit_kind == TOK_KEYWORD_PROGRAM then
		header_type := "PROGRAM"
	elsif n^.program_decl.unit_kind == TOK_KEYWORD_MODULE then
		header_type := "MODULE"
	elsif n^.program_decl.unit_kind == TOK_KEYWORD_HEADER then
		header_type := "HEADER"
	end

	dynbuf_append(ctx.out, "/* =====================================\n")
	dynbuf_append(ctx.out, " * Generated by Mod-c ")
	dynbuf_append(ctx.out, VERSION_BASE)
	dynbuf_append(ctx.out, "\n")
	dynbuf_append(ctx.out, " * HEADER ")
	dynbuf_appendn(ctx.out, n^.program_decl.name, n^.program_decl.name_len)
	dynbuf_append_char(ctx.out, ' ')
	dynbuf_append(ctx.out, header_type)

	dynbuf_append_char(ctx.out, '\n')
	dynbuf_append(ctx.out, " * ===================================== */\n\n")

	// Guard uses the header filename stem. A single-identifer file keeps the unit name.
	guard_base := n^.program_decl.name
	guard_len := n^.program_decl.name_len
	if ctx.header_base <> nil and ctx.header_base_len > 0 then
		guard_base := ctx.header_base
		guard_len := ctx.header_base_len
	end
	dynbuf_append(ctx.out, "#ifndef ")
	// dynbuf_append(ctx.out, header_type)
	// dynbuf_append_char(ctx.out, '_')
	// dynbuf_appendn(ctx.out, n^.program_decl.name, n^.program_decl.name_len)
	// dynbuf_append(ctx.out, "_H\n")
	emit_header_guard_name(ctx.out, header_type, guard_base, guard_len)
	dynbuf_append(ctx.out, "\n")
	dynbuf_append(ctx.out, "#define ")
	// dynbuf_append(ctx.out, header_type)
	// dynbuf_append_char(ctx.out, '_')
	// dynbuf_appendn(ctx.out, n^.program_decl.name, n^.program_decl.name_len)
	// dynbuf_append(ctx.out, "_H\n\n")
	emit_header_guard_name(ctx.out, header_type, guard_base, guard_len)
	dynbuf_append(ctx.out, "\n\n")

	codegen_emit_c_prelude(ctx.out, n)

	// Declaration sequence. It is possible for decls to be NULL.
	if n^.program_decl.decls <> nil then
		var i: size_t = 0
		for i := 0 to n^.program_decl.count-1 do
			let d: ^Node = n^.program_decl.decls[i]
			if d^.kind == NODE_IMPORT then
				dynbuf_append(ctx.out, "/* === IMPORT === */\n")
				codegen_common_import(d, ctx)
				dynbuf_append_char(ctx.out, '\n')
			else
				codegen_header_emit_exported(d, ctx)
			end
		end
	end

	// HEADER has no entry function. PROGRAM and MODULE still emit one.
	if n^.program_decl.unit_kind <> TOK_KEYWORD_HEADER then
		codegen_common_module_prototype(n, ctx)
	end

	// endif for header guard.
	// dynbuf_append(ctx.out, "#endif /* MODC_")
	// dynbuf_append(ctx.out, header_type)
	// dynbuf_append_char(ctx.out, '_')
	// dynbuf_appendn(ctx.out, n^.program_decl.name, n^.program_decl.name_len)
	// dynbuf_append(ctx.out, "_H */\n")
	dynbuf_append(ctx.out, "#endif /* ")
	emit_header_guard_name(ctx.out, header_type, guard_base, guard_len)
	dynbuf_append(ctx.out, " */\n")
end codegen_header_program


(**
 * Generate a C header file from the given AST.
 * This is the entry point called when TARGET_HEADER is
 * selected.
 *)
begin
	if ctx.ast == nil or ctx.out == nil then
		fprintf(stderr, "FATAL ERROR: codegen_header: NULL argument\n")
		exit(1)
	end

	// Walk the AST and emit only exported declarations
	// This is where the real work will go.
	codegen_header_program(ctx.ast, ctx)
end codegen_header


(* msr/gk/msr *)
