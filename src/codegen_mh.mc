module codegen_mh(ctx: CodegenContext)

(**
 * codegen_mh.mc - Emit modc-mh/1 symbol export files for EXPORT declarations.
 *)

import DynBuf, dynbuf_append, dynbuf_appendn, dynbuf_append_char from dynbuf
import TOK_KEYWORD_PROGRAM, TOK_KEYWORD_MODULE from Lexer
import TType from ttype

import size_t from "stddef.h"
import stderr, fprintf, snprintf, from "stdio.h"
import exit from "stdlib.h"
import memcmp from "string.h"
import VERSION_BASE from "version.h"
import Node, NODE_PROGRAM, NODE_PROC_DECL, NODE_FUNC_DECL, NODE_TYPE_DECL, 
	NODE_ENUM_TYPE, NODE_ENUM_ITEM, NODE_VAR_DECL, NODE_CONST_DECL, 
	NODE_LET_DECL, NODE_PARAM_LIST, NODE_PARAM, NODE_STRUCT_DECL, NODE_FIELD_DECL,
	NODE_METHOD_TYPE, NODE_DEFINE,
	from "node.h"
import CodegenContext from "codegen_common.h"


function mh_proc_complete(n: const ^Node): bool
begin
	if n^.proc_decl.is_forward then
		return false
	end
	if n^.proc_decl.is_extern and n^.proc_decl.params == nil then
		return false
	end
	return true
end mh_proc_complete


function mh_type_opaque(n: const ^Node): bool
begin
	var ty: const ^TType = nil

	if n^.type_decl.is_extern then
		return true
	end
	ty := n^.type_decl.defined_type
	if ty <> nil then
		if (ty^.name == nil or ty^.name_len == 0) and ty^.resolved_type <> nil then
			ty := ty^.resolved_type
		end
		// type T = opaque -- type P = ^opaque stays complete
		if ty^.is_opaque and not ty^.is_pointer then
			return true
		end
	end
	return false
end mh_type_opaque


// type string = const ^char
type pcchar = const ^char

(*
 * First formal type name if written named type (not ^ / array).
 * Do not chase resolved_type: `sds = ^char` still counts as name sds.
 *)
function mh_first_formal_type_name(n: const ^Node, out_name: ^pcchar, out_len: ^size_t): bool
begin
	var pl: const ^Node = nil
	var self_param: const ^Node = nil
	var pt: const ^TType = nil

	out_name^ := nil
	out_len^ := 0
	if n == nil then
		return false
	end
	pl := n^.proc_decl.params
	if pl == nil or pl^.kind <> NODE_PARAM_LIST or pl^.param_list.count == 0 then
		return false
	end
	self_param := pl^.param_list.params[0]
	if self_param == nil or self_param^.kind <> NODE_PARAM then
		return false
	end
	pt := self_param^.param.param_type
	if pt == nil then
		return false
	end
	// if pt^.resolved_type <> nil then
	// 	pt := pt^.resolved_type
	// end
	if pt^.is_pointer or pt^.is_array then
		return false
	end
	if pt^.name == nil or pt^.name_len == 0 then
		return false
	end
	out_name^ := pt^.name
	out_len^ := pt^.name_len
	return true
end mh_first_formal_type_name


(* True if type-bound and first formal type name equals owner (instance). *)
function mh_method_is_instance(n: const ^Node): bool
begin
	var ft_name: const ^char = nil
	var ft_len: size_t = 0

	if n == nil or n^.proc_decl.method_owner == nil or n^.proc_decl.method_owner_len == 0 then
		return false
	end
	if not mh_first_formal_type_name(n, @ft_name, @ft_len) then
		return false
	end
	if ft_len <> n^.proc_decl.method_owner_len then
		return false
	end
	return memcmp(ft_name, n^.proc_decl.method_owner, ft_len) == 0
end mh_method_is_instance


(*
 * Append type-spec for .mh: [const] [^] Name
 * Prefer the surface type name (aliases like long_long). Do not peel
 * resolved_type: that can turn one ident into multi-word C ("long long"),
 * which the .mh type-spec grammar cannot parse as a single ident at this time.
 *)
procedure mh_append_type_spec(out: ^DynBuf, t: const ^TType)
begin
	var ty: const ^TType = t

	if out == nil or ty == nil then
		return
	end
	// if ty^.resolved_type <> nil then
	// 	ty := ty^.resolved_type
	// end
	// Only peel resolution when this node has no name of its own.
	if (ty^.name == nil or ty^.name_len == 0) and ty^.resolved_type <> nil then
		ty := ty^.resolved_type
	end
	if ty^.is_const then
		dynbuf_append(out, "const ")
	end
	if ty^.is_pointer then
		dynbuf_append_char(out, '^')
	end
	if ty^.name <> nil and ty^.name_len > 0 then
		dynbuf_appendn(out, ty^.name, ty^.name_len)
		if ty^.width > 0 then
			var wbuf: array[16] of char
			snprintf(@wbuf[0], 16, " %d", ty^.width)
			dynbuf_append(out, @wbuf[0])
		end
	elsif ty^.is_opaque then
		dynbuf_append(out, "opaque")
	else
		dynbuf_append(out, "?")
	end
end mh_append_type_spec


(*
 * Append one formal: [var|ref|const] type-spec (no parameter name).
 *)
procedure mh_append_formal(out: ^DynBuf, param: const ^Node)
begin
	if out == nil or param == nil or param^.kind <> NODE_PARAM then
		return
	end
	if param^.param.is_var then
		dynbuf_append(out, "var ")
	elsif param^.param.is_ref then
		dynbuf_append(out, "ref ")
	elsif param^.param.is_const then
		dynbuf_append(out, "const ")
	end
	mh_append_type_spec(out, param^.param.param_type)
end mh_append_formal


(*
 * Append ( formal { , formal } ) and optional : result-type.
 * param_list is NODE_PARAM_LIST or nil.
 *)
procedure mh_append_signature(out: ^DynBuf, params_list: const ^Node,
		return_type: const ^TType, emit_result: bool)
begin
	var i: size_t = 0
	var p: const ^Node = nil
	var count: size_t = 0

	if out == nil then
		return
	end

	if params_list <> nil and params_list^.kind == NODE_PARAM_LIST then
		count := params_list^.param_list.count
	end

	// Omit empty () unless there is a result type to attach (function).
	if count == 0 and not (emit_result and return_type <> nil) then
		return
	end

	dynbuf_append_char(out, ' ')
	dynbuf_append_char(out, '(')
	for i := 1 to count do
		p := params_list^.param_list.params[i - 1]
		if i > 1 then
			dynbuf_append(out, ", ")
		end
		mh_append_formal(out, p)
	end
	if params_list <> nil and params_list^.kind == NODE_PARAM_LIST and
			params_list^.param_list.has_ellipsis then
		if count > 0 then
			dynbuf_append(out, ", ")
		end
		dynbuf_append(out, "...")
	end
	dynbuf_append_char(out, ')')

	if emit_result and return_type <> nil then
		dynbuf_append(out, " : ")
		mh_append_type_spec(out, return_type)
	end
end mh_append_signature


procedure mh_append_type_signature(out: ^DynBuf, mt: const ^Node)
begin
	var i: size_t = 0
	var p: const ^Node = nil
	var count: size_t = 0
	var pl: const ^Node = nil

	if out == nil or mt == nil or mt^.kind <> NODE_METHOD_TYPE then
		return
	end

	if mt^.method_type.is_function then
		dynbuf_append(out, " function")
	else
		dynbuf_append(out, " procedure")
	end

	pl := mt^.method_type.params
	if pl <> nil and pl^.kind == NODE_PARAM_LIST then
		count := pl^.param_list.count
	end

	dynbuf_append_char(out, ' ')
	dynbuf_append_char(out, '(')
	for i := 1 to count do
		p := pl^.param_list.params[i - 1]
		if i > 1 then
			dynbuf_append(out, ", ")
		end
		mh_append_formal(out, p)
	end
	if pl <> nil and pl^.kind == NODE_PARAM_LIST and
			pl^.param_list.has_ellipsis then
		if count > 0 then
			dynbuf_append(out, ", ")
		end
		dynbuf_append(out, "...")
	end
	dynbuf_append_char(out, ')')

	if mt^.method_type.is_function and mt^.method_type.return_type <> nil then
		dynbuf_append(out, " : ")
		mh_append_type_spec(out, mt^.method_type.return_type)
	end
end mh_append_type_signature


(*
 * Module/program entry: params are a flat array on program_decl, not PARAM_LIST.
 *)
procedure mh_append_unit_signature(out: ^DynBuf, n: const ^Node)
begin
	var i: size_t = 0
	var p: const ^Node = nil
	var count: size_t = 0
	var ret: const ^TType = nil
	var emit_result: bool = false

	if out == nil or n == nil or n^.kind <> NODE_PROGRAM then
		return
	end

	count := n^.program_decl.param_count
	ret := n^.program_decl.return_type
	emit_result := (ret <> nil)

	if count == 0 and not emit_result then
		return
	end

	dynbuf_append_char(out, ' ')
	dynbuf_append_char(out, '(')
	for i := 1 to count do
		p := n^.program_decl.params[i - 1]
		if i > 1 then
			dynbuf_append(out, ", ")
		end
		mh_append_formal(out, p)
	end
	dynbuf_append_char(out, ')')

	if emit_result then
		dynbuf_append(out, " : ")
		mh_append_type_spec(out, ret)
	end
end mh_append_unit_signature


procedure mh_emit_line(out: ^DynBuf,line: const ^char)
begin
	dynbuf_append(out, line)
	dynbuf_append_char(out, '\n')
end mh_emit_line


procedure mh_append_ident(out: ^DynBuf, s: const ^char, length: size_t)
begin
	if out == nil or s == nil or length == 0 then
		return
	end
	dynbuf_appendn(out, s, length)
end mh_append_ident


(*
 * Append struct/union field tail: struct|union [extends Name] (f: T {, ...})
 * Same physical line as export type. Type-spec is [const] [^] Name (6a).
 *)
procedure mh_append_field_list(out: ^DynBuf, st: const ^Node)
begin
	var i: size_t = 0
	var f: const ^Node = nil
	var ext: const ^TType = nil
	var emitted: size_t = 0

	if out == nil or st == nil or st^.kind <> NODE_STRUCT_DECL then
		return
	end

	dynbuf_append_char(out, ' ')
	if st^.struct_decl.is_union then
		dynbuf_append(out, "union")
	else
		dynbuf_append(out, "struct")
	end

	ext := st^.struct_decl.extends_type
	if ext <> nil then
		if (ext^.name == nil or ext^.name_len == 0) and ext^.resolved_type <> nil then
			ext := ext^.resolved_type
		end
		if ext^.name <> nil and ext^.name_len > 0 then
			dynbuf_append(out, " extends ")
			mh_append_ident(out, ext^.name, ext^.name_len)
		end
	end

	dynbuf_append(out, " (")
	for i := 1 to st^.struct_decl.field_count do
		f := st^.struct_decl.fields[i - 1]
		if f == nil or f^.kind <> NODE_FIELD_DECL then
			continue
		end
		if emitted > 0 then
			dynbuf_append(out, ", ")
		end
		mh_append_ident(out, f^.field_decl.name, f^.field_decl.name_len)
		dynbuf_append(out, ": ")
		if f^.field_decl.field_type <> nil then
			mh_append_type_spec(out, f^.field_decl.field_type)
		else
			dynbuf_append(out, "?")
		end
		emitted := emitted + 1
	end
	dynbuf_append_char(out, ')')
end mh_append_field_list


procedure mh_emit_export_proc(out:^DynBuf, n: const ^Node)
begin
	var name: const ^char = n^.proc_decl.name
	var name_len: size_t = n^.proc_decl.name_len
	var kind_word: const ^char = "procedure"
	var complete_word: const ^char = "complete"
	var binding: const ^char = nil 				// "instance" | "static" | nil
	var owner: const ^char = nil
	var owner_len: size_t = 0


	if n^.kind == NODE_FUNC_DECL then
		kind_word := "function"
	end
	if not mh_proc_complete(n) then
		complete_word := "incomplete"
	end

	if n^.proc_decl.method_owner <> nil and n^.proc_decl.method_owner_len > 0 then
		owner := n^.proc_decl.method_owner
		owner_len := n^.proc_decl.method_owner_len
		if mh_method_is_instance(n) then
			binding := "instance"
		else
			binding := "static"
		end
	end

	dynbuf_append(out, "export ")
	if n^.proc_decl.is_extern then
		dynbuf_append(out, "extern ")
	end
	dynbuf_append(out, kind_word)
	dynbuf_append_char(out, ' ')
	if owner <> nil and owner_len > 0 then
		mh_append_ident(out, owner, owner_len)
		dynbuf_append(out, "__")
		mh_append_ident(out, n^.proc_decl.name, n^.proc_decl.name_len)
	else
		mh_append_ident(out, name, name_len)
	end
	dynbuf_append_char(out, ' ')
	dynbuf_append(out, complete_word)
	if binding <> nil then
		dynbuf_append_char(out, ' ')
		dynbuf_append(out, binding)
		dynbuf_append_char(out, ' ')
		mh_append_ident(out, owner, owner_len)
	end
	mh_append_signature(out, n^.proc_decl.params, n^.proc_decl.return_type,
		n^.kind == NODE_FUNC_DECL)
	dynbuf_append_char(out, '\n')
end mh_emit_export_proc


procedure mh_emit_export_enum_members(out: ^DynBuf, en: const ^Node)
begin
	var i: size_t = 0
	var item: ^Node = nil

	if en == nil or en^.kind <> NODE_ENUM_TYPE then
		return
	end

	for i := 1 to en^.enum_type.count do
		item := en^.enum_type.elements[i - 1]
		if item == nil or item^.kind <> NODE_ENUM_ITEM then
			continue
		end
		dynbuf_append(out, "export const ")
		mh_append_ident(out, item^.enum_item.name, item^.enum_item.name_len)
		dynbuf_append(out, " complete")
		dynbuf_append_char(out, '\n')
	end
end mh_emit_export_enum_members


procedure mh_emit_export_type(out: ^DynBuf, n: const ^Node)
begin
	var flag: const ^char = "complete"

	if n^.type_decl.is_forward then
		return
	end

	if n^.type_decl.enum_type <> nil then
		dynbuf_append(out, "export enum ")
		mh_append_ident(out, n^.type_decl.name, n^.type_decl.name_len)
		dynbuf_append(out, " complete")
		dynbuf_append_char(out, '\n')
		mh_emit_export_enum_members(out, n^.type_decl.enum_type)
		return
	end

	if mh_type_opaque(n) then
		flag := "opaque"
	end
	dynbuf_append(out, "export type ")
	mh_append_ident(out, n^.type_decl.name, n^.type_decl.name_len)
	dynbuf_append_char(out, ' ')
	dynbuf_append(out, flag)
	if n^.type_decl.struct_body <> nil then
		mh_append_field_list(out, n^.type_decl.struct_body)
	end
	if n^.type_decl.method_type <> nil then
		mh_append_type_signature(out, n^.type_decl.method_type)
	end
	if n^.type_decl.defined_type <> nil and
			n^.type_decl.struct_body == nil and
			n^.type_decl.method_type == nil and
			n^.type_decl.enum_type == nil and
			not mh_type_opaque(n) then
		dynbuf_append_char(out, ' ')
		mh_append_type_spec(out, n^.type_decl.defined_type)
	end
	dynbuf_append_char(out, '\n')
end mh_emit_export_type


procedure mh_emit_export_binding(out: ^DynBuf, n: const ^Node, kind_word: const ^char)
begin
	var i: size_t = 0
	var complete_word: const ^char = "complete"

	if n^.var_decl.is_extern then
		complete_word := "incomplete"
	end

	for i := 1 to n^.var_decl.count do
		var item: ^Node = n^.var_decl.items[i - 1]
		dynbuf_append(out, "export ")
		dynbuf_append(out, kind_word)
		dynbuf_append_char(out, ' ')
		mh_append_ident(out, item^.var_item.name, item^.var_item.name_len)
		dynbuf_append_char(out, ' ')
		dynbuf_append(out, complete_word)
		dynbuf_append_char(out, '\n')
	end
end mh_emit_export_binding


(**
 * Emit MODULE/PROGRAM unit entry (name matches unit; not an EXPORT decl in source).
 * Mirros codegen_common_module_prototype() in generated .h files.
 *)
procedure mh_emit_unit_entry(out: ^DynBuf, n: const ^Node)
begin
	var kind_word: const ^char = "procedure"

	if n^.program_decl.return_type <> nil then
		kind_word := "function"
	end
	dynbuf_append(out, "export ")
	dynbuf_append(out, kind_word)
	dynbuf_append_char(out, ' ')
	mh_append_ident(out, n^.program_decl.name, n^.program_decl.name_len)
	dynbuf_append(out, " complete")
	mh_append_unit_signature(out, n)
	dynbuf_append_char(out, '\n')
end mh_emit_unit_entry


procedure mh_emit_exported_decl(out: ^DynBuf, d: const ^Node)
begin
	if d == nil then
		return
	end

	if d^.kind == NODE_PROC_DECL or d^.kind == NODE_FUNC_DECL then
		if d^.proc_decl.is_exported then
			mh_emit_export_proc(out, d)
		end
	elsif d^.kind == NODE_TYPE_DECL then
		if d^.type_decl.is_exported then
			mh_emit_export_type(out, d)
		end
	elsif d^.kind == NODE_VAR_DECL then
		if d^.var_decl.is_exported then
			mh_emit_export_binding(out, d, "var")
		end
	elsif d^.kind == NODE_CONST_DECL then
		if d^.const_decl.is_exported then
			mh_emit_export_binding(out, d, "const")
		end
	elsif d^.kind == NODE_LET_DECL then
		if d^.let_decl.is_exported then
			mh_emit_export_binding(out, d, "const")
		end
	elsif d^.kind == NODE_DEFINE then
		if d^.define_stmt.is_exported then
			dynbuf_append(out, "export define ")
			mh_append_ident(out, d^.define_stmt.name, d^.define_stmt.name_len)
			dynbuf_append(out, " complete\n")
		end
	end
end mh_emit_exported_decl


export function codegen_mh_has_exports(root: const ^Node): bool
begin
	var i: size_t = 0

	if root == nil or root^.kind <> NODE_PROGRAM then
		return false
	end

	for i := 1 to root^.program_decl.count do
		var d: ^Node = root^.program_decl.decls[i - 1]
		if d^.kind == NODE_PROC_DECL or d^.kind == NODE_FUNC_DECL then
			if d^.proc_decl.is_exported then
				return true
			end
		elsif d^.kind == NODE_TYPE_DECL then
			if d^.type_decl.is_exported then 
				return true
			end
		elsif d^.kind == NODE_VAR_DECL then
			if d^.var_decl.is_exported then
				return true
			end
		elsif d^.kind == NODE_CONST_DECL then
			if d^.const_decl.is_exported then
				return true
			end
		elsif d^.kind == NODE_LET_DECL then
			if d^.let_decl.is_exported then
				return true
			end
		elsif d^.kind == NODE_DEFINE then
			if d^.define_stmt.is_exported then
				return true
			end
		end
	end

	return false
end codegen_mh_has_exports


(**
 * Main entry point for this module, codegen_mh()
 *)
begin
	var n: const ^Node = ctx.ast
	var out: ^DynBuf = ctx.out
	var line_buf: array[256] of char
	var i: size_t = 0

	if n == nil or out == nil or n^.kind <> NODE_PROGRAM then
		fprintf(stderr, "FATAL ERROR: codegen_mh: expected PROGRAM node\n")
		exit(1)
	end

	mh_emit_line(out, "# modc-mh/1")
	snprintf(@line_buf[0], 256, "# Generated by Mod-c %s", VERSION_BASE)
	mh_emit_line(out, @line_buf[0])
	dynbuf_append(out, "@module ")
	mh_append_ident(out, n^.program_decl.name, n^.program_decl.name_len)
	dynbuf_append_char(out, '\n')
	mh_emit_line(out, "@format 1")

	for i := 1 to n^.program_decl.count do
		mh_emit_exported_decl(out, n^.program_decl.decls[i - 1])
	end
	mh_emit_unit_entry(out, n)
end codegen_mh

