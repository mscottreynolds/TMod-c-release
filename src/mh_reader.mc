module mh_reader()

(**
 * mh_reader.mc - Parse modc-mh/1 export talbes for IMPORT ... FROM "*.mh".
 *)


import size_t 
	from "stddef.h"
import memcpy, strlen, memcmp, strrchr, strchr 
	from "string.h"
import malloc, exit, free, realloc, atoi, 
	from "stdlib.h"
import isalpha, isalnum, isdigit, 
	from "ctype.h"
import FILE, stderr, fclose, fopen, fprintf, snprintf, fread, fseek, ftell,
	SEEK_END, SEEK_SET, 
	from "stdio.h"
import 
	SYM_KIND_PROC, SYM_KIND_FUNC, SYM_KIND_TYPE, SYM_KIND_VAR, SYM_KIND_CONST, 
	SYM_KIND_UNKNOWN, SymbolKind, SYM_KIND_IMPORT,
	from symkind
import MH_KIND_PROCEDURE, MH_KIND_FUNCTION, MH_KIND_TYPE, MH_KIND_ENUM, 
	MH_KIND_VAR, MH_KIND_CONST, MhExportKind, MH_KIND_DEFINE,
	from mh_exportkind
import type_width_allowed 
	from ttype

export type MhCompleteness = int
const MH_COMPLETENESS_COMPLETE:		MhCompleteness = 0
const MH_COMPLETENESS_INCOMPLETE:	MhCompleteness = 1
const MH_COMPLETENESS_OPAQUE:		MhCompleteness = 2


(** One formal in an export signature: [var|ref|const] [const] [^] Name *)
export type MhFormal = struct
	is_var:				bool
	is_ref: 			bool
	is_const: 			bool 		// formal mode CONST
	type_is_const: 		bool
	type_is_pointer: 	bool
	type_name:			^char
	type_name_len:		size_t
	type_width: 		int
	is_ellipsis: 		bool
end


(** One field in an export type layout: name: [const] [^] Type *)
export type MhField = struct
	name: 				^char
	name_len:			size_t
	type_is_const:		bool
	type_is_pointer: 	bool
	type_name:			^char
	type_name_len: 		size_t
	type_width:			int
end


export type MhExport = struct
	kind: 			MhExportKind
	is_extern: 		bool
	completeness: 	MhCompleteness
	name:			^char
	name_len:		size_t

	// Type-bound method metadata (optional tail after completeness).
	is_method:			bool 		// true if instance|static Owner present
	is_instance:		bool 		// meaningful only if is_method
	method_owner:		^char 		// owner type name; nil if not a method
	method_owner_len:	size_t

	// Optional signature: ( formals ) [ : result ] (S2 writer / @format 1)
	has_signature:		bool
	formals: 			^MhFormal
	formal_count:		size_t
	has_result:			bool
	result_is_const:	bool
	result_is_pointer: 	bool
	result_name:		^char
	result_name_len:	size_t
	result_width: 		int

	// Optional type layout: struct|union [extends Name] ( fields )
	is_struct:			bool
	is_union: 			bool
	extends_name: 		^char
	extends_name_len: 	size_t
	fields: 			^MhField
	field_count: 		size_t
	is_func_type:		bool 			// TYPE = FUNCTION ... ; with has_signature

	// Optional alias RHS: export type Name complete integer 64
	has_alias: 			bool
	alias_is_const:		bool
	alias_is_pointer:	bool
	alias_name:			^char
	alias_name_len:		size_t
	alias_width:		int
end


export type MhModule = struct
	module_name: 		^char
	module_name_len: 	size_t
	format_version:		int
	exports: 			^MhExport
	count:				size_t
	capacity:			size_t
	source:				^char 		(* owned file; names point here *)
	source_len:			size_t
end


export type pchar = ^char
export type pcchar = const ^char


function mh_ends_with(s: const ^char, length: size_t, suffix: const ^char): bool
begin
	var suffix_len: size_t = 0

	if s == nil or suffix == nil then
		return false
	end

	suffix_len := strlen(suffix)
	if length < suffix_len then
		return false
	end

	return memcmp(s + (length - suffix_len), suffix, suffix_len) == 0
end mh_ends_with


(**
 * Strip optional surrounding quotes from a string-literal token.
 *)
export function mh_strip_string_literal(const path: ^char, path_len: size_t, 		\
		inner: ^pcchar, inner_len: ^size_t): bool
begin
	if path == nil or inner == nil or inner_len == nil or path_len == 0 then
		return false
	end

	if path_len >= 2 and path[0] == '"' and path[path_len - 1] == '"' then
		inner^		:= path + 1
		inner_len^ 	:= path_len - 2
		return true
	end

	inner^		:= path
	inner_len^	:= path_len
	return true
end mh_strip_string_literal


function mh_import_source_is_quoted(path: const ^char, path_len: size_t): bool
begin
	return path <> nil and path_len >= 2 and path[0] == '"'
end mh_import_source_is_quoted


(**
 * Qualident (unquoted FROM) -> relative filesystem path with .mh suffix.
 e.g. fixtures.minimod -> fixtures/minimod.mh
 *)
function mh_qualident_to_mh_relpath(inner: pcchar, inner_len: size_t,		\
		out: ^char, out_cap: size_t): bool
begin
	var i: size_t = 0
	var j: size_t = 0

	if inner == nil or out == nil or out_cap == 0 or inner_len == 0 then
		return false
	end

	while i < inner_len do
		var c: char = inner[i]
		if c == '.' then
			c := '/'
		end
		if j + 4 >= out_cap then
			return false
		end
		out[j] := c
		j := j + 1
		i := i + 1
	end

	out[j] 		:= '.'
	out[j+1]	:= 'm'
	out[j+2]	:= 'h'
	out[j+3] 	:= '\0'
	return true
end mh_qualident_to_mh_relpath


export function mh_path_is_mh(const path: ^char, path_len: size_t): bool
begin
	var inner: pcchar = nil
	var inner_len: size_t = 0

	if not mh_strip_string_literal(path, path_len, @inner, @inner_len) then
		return false
	end

	if not mh_import_source_is_quoted(path, path_len) then
		return true
	end

	return mh_ends_with(inner, inner_len, ".mh")
end mh_path_is_mh


(**
 * Format the C #include path for a Mod-c import source (.mh symtab world).
 * Quoted "*.mh" -> same path with .h; qualident -> sources + .h.
 *)
export function mh_format_h_include(from_path: const ^char, from_len: size_t,		\
	out: ^char, out_cap: size_t): bool
begin
	var inner: pcchar = nil
	var inner_len: size_t = 0
	var i: size_t = 0
	var j: size_t = 0

	if from_path == nil or out == nil or out_cap == 0 then
		return false
	end

	if not mh_strip_string_literal(from_path, from_len, @inner, @inner_len) then
		return false
	end

	if mh_import_source_is_quoted(from_path, from_len) then
		if not mh_ends_with(inner, inner_len, ".mh") or inner_len < 4 then
			return false
		end
		if inner_len - 1 >= out_cap then
			return false;
		end
		memcpy(out, inner, inner_len -3)
		out[inner_len - 3] := '.'
		out[inner_len - 2] := 'h'
		out[inner_len - 1] := '\0'
		return true
	end

	while i < inner_len do
		var c: char = inner[i]
		if c == '.' then
			c := '/'
		end
		if j + 3 >= out_cap then
			return false
		end
		out[j] := c
		inc(j)
		inc(i)
	end

	if j + 3 >= out_cap then
		return false
	end
	out[j] 		:= '.'
	out[j+1] 	:= 'h'
	out[j+2] 	:= '\0'
	return true
end mh_format_h_include


function mh_strdup_n(s: const ^char, length: size_t): ^char
begin
	var copy: ^char = malloc(length + 1)
	if copy == nil then
		return nil
	end
	memcpy(copy, s, length)
	copy[length] := '\0'
	return copy
end mh_strdup_n


procedure mh_fatal(path: const ^char, line_no: size_t, msg: const ^char)
begin
	if path <> nil then
		fprintf(stderr, "ERROR: %s:%zu: %s\n", path, line_no, msg)
	else
		fprintf(stderr, "ERROR: %s\n", msg)
	end
	exit(1)
end mh_fatal


function mh_dirname_copy(path: const ^char): ^char
begin
	var slash: ^char = nil
	var length: size_t = 0

	if path == nil or path[0] == '\0' then
		return mh_strdup_n(".", 1)
	end

	slash := strrchr(path, '/')
	if slash == nil then
		return mh_strdup_n(".", 1)
	end

	if slash == path then
		return mh_strdup_n("/", 1)
	end

	length := (slash - path) as size_t
	return mh_strdup_n(path, length)
end mh_dirname_copy


(**
 * Resolve IMPORT apth relative to the compiling .mc file directory.
 *)
export function mh_resolve_import_path(source_path: const ^char,				\
	from_path: const ^char, from_len: size_t, out: ^char, out_cap: size_t): bool
begin
	var inner: pcchar = nil
	var inner_len: size_t = 0
	var rel: array[4096] of char
	var rel_len: size_t = 0
	var dir: ^char = nil

	if out == nil or out_cap == 0 then
		return false
	end

	if not mh_strip_string_literal(from_path, from_len, @inner, @inner_len) then
		return false
	end

	// if inner_len + 1 > out_cap then
	// 	return false
	if mh_import_source_is_quoted(from_path, from_len) then
		rel_len := inner_len
		if rel_len + 1 > sizeof(rel) then
			return false
		end
		memcpy(@rel[0], inner, rel_len)
		rel[rel_len] := '\0'
	else
		if not mh_qualident_to_mh_relpath(inner, inner_len, @rel[0], sizeof(rel)) then
			return false
		end
		rel_len := strlen(@rel[0])
	end

	// if inner_len > 0 and inner[0] == '/' then
	// 	memcpy(out, inner, inner_len)
	// 	out[inner_len] := '\0'
	if rel_len > 0 and rel[0] == '/' then
		if rel_len + 1 > out_cap then
			return false
		end
		memcpy(out, @rel[0], rel_len)
		out[rel_len] := '\0'
		return true
	end

	dir := mh_dirname_copy(source_path)
	if dir == nil then
		return false
	end
	defer free(dir)

	if dir[strlen(dir) - 1] <> '/' then
		// snprintf(out, out_cap, "%s/%.*s", dir, inner_len as int, inner)
		snprintf(out, out_cap, "%s/%s", dir, @rel[0])
	else
		// snprintf(out, out_cap, "%s%.*s", dir, inner_len as int, inner)
		snprintf(out, out_cap, "%s%s", dir, @rel[0])
	end

	return true
end mh_resolve_import_path


procedure mh_module_grow(m: ^MhModule)
begin
	var new_cap: size_t = 0
	var new_exports: ^MhExport = nil

	if m^.count < m^.capacity then
		return
	end

	new_cap := m^.capacity == 0 ? 8u : m^.capacity * 2u
	new_exports := realloc(m^.exports, new_cap * sizeof(MhExport)) as ^MhExport
	if new_exports == nil then
		mh_fatal(nil, 0, "mh_reader_load: out of memory")
	end

	m^.exports 	:= new_exports
	m^.capacity	:= new_cap
end mh_module_grow


procedure mh_module_add(m: ^MhModule, exp: MhExport)
begin
	mh_module_grow(m)
	m^.exports[m^.count] := exp
	m^.count := m^.count + 1
end mh_module_add


export function mh_export_to_symkind(kind: MhExportKind): SymbolKind
begin
	switch kind of 
		case MH_KIND_PROCEDURE:	return SYM_KIND_PROC
		case MH_KIND_FUNCTION: 	return SYM_KIND_FUNC
		case MH_KIND_TYPE:		return SYM_KIND_TYPE
		case MH_KIND_ENUM:		return SYM_KIND_TYPE
		case MH_KIND_VAR:		return SYM_KIND_VAR
		case MH_KIND_CONST:		return SYM_KIND_CONST
		case MH_KIND_DEFINE:	return SYM_KIND_IMPORT
		else:					return SYM_KIND_UNKNOWN
	end
end mh_export_to_symkind


export function mh_module_find(m: const ^MhModule, name: const ^char, 				\
	name_len: size_t): const ^MhExport
begin
	var i: size_t = 0

	if m == nil or name == nil or name_len == 0 then
		return nil
	end

	for i := 1 to m^.count do
		var exp: ^MhExport = @m^.exports[i-1]
		if exp^.name_len == name_len and memcmp(exp^.name, name, name_len) == 0 then
			return exp
		end
	end

	return nil
end mh_module_find


export procedure mh_module_free(m: ^MhModule)
begin
	var i: size_t = 0

	if m == nil then
		return
	end

	m^.module_name := nil
	m^.module_name_len := 0

	for i := 1 to m^.count do
		// Signature formals + result type name
		if m^.exports[i - 1].formals <> nil then
			free(m^.exports[i - 1].formals)
			m^.exports[i - 1].formals := nil
			m^.exports[i - 1].formal_count := 0
		end
		if m^.exports[i - 1].fields <> nil then
			free(m^.exports[i - 1].fields)
			m^.exports[i - 1].fields := nil
			m^.exports[i - 1].field_count := 0
		end
	end

	if m^.exports <> nil then
		free(m^.exports)
		m^.exports := nil
	end
	if m^.source <> nil then
		free(m^.source)
		m^.source := nil
	end
	m^.source_len 		:= 0
	m^.count 			:= 0
	m^.capacity 		:= 0
	m^.format_version	:= 0
end mh_module_free


(** --- line parser helpers (kept local) --- **)

procedure mh_skip_ws(p: ^pchar, end_: pchar)
begin
	while p^ < end_ and (p^^ == ' ' or p^^ == '\t' or p^^ == '\r') do
		p^ := p^ + 1
	end
end mh_skip_ws


function mh_match_word(p: ^pchar, end_: ^char, word: const ^char): bool
begin
	var wlen: size_t = strlen(word)
	mh_skip_ws(p, end_)
	if (end_ - p^) as size_t < wlen then
		return false
	end
	if memcmp(p^, word, wlen) <> 0 then
		return false
	end
	if (end_ - p^) as size_t > wlen then
		var next: char = (p^ + wlen)^
		if isalnum(next as int) or next == '_' then
			return false
		end
	end
	p^ := p^ + wlen
	return true
end mh_match_word


function mh_read_ident(p: ^pchar, end_: ^char, name: ^pchar, name_len: ^size_t): bool
begin
	var start: ^char = nil
	
	mh_skip_ws(p, end_)
	
	if p^ >= end_ then
		return false
	end
	if not isalpha(p^^ as int) and p^^ <> '_' then
		return false
	end
	start := p^
	p^ := p^ + 1
	while p^ < end_ and (isalnum(p^^ as int) or p^^ == '_') do
		p^ := p^ + 1
	end
	name^		:= start
	name_len^	:= (p^ - start) as size_t
	if name_len^ > 255 then
		mh_fatal(nil, 0, "mh_read_ident: identifier longer than 255 characters")
	end
	return name_len^ > 0
end mh_read_ident


function mh_match_char(p: ^pchar, end_: ^char, ch: char): bool
begin
	mh_skip_ws(p, end_)
	if p^ >= end_ or p^^ <> ch then
		return false
	end
	p^ := p^ + 1
	return true
end mh_match_char


(* Peek whether next non-ws char is ch (does not advance). *)
function mh_peek_char(peek: pchar, end_: pchar, ch: char): bool
begin
	var p: pchar = peek

	while p < end_ and (p^ == ' ' or p^ == '\t' or p^ == '\r') do
		p := p + 1
	end
	return p < end_ and p^ == ch
end mh_peek_char


(*
 * Decimal width token. Caller has already seen a digit.
 * No 0x, no '_', no leading zeros (Language Report 10.1).
 *)
function mh_parse_width_number(path: const ^char, line_no: size_t,
		p: ^pchar, end_: pchar): int
begin
	var n: int = 0
	var digits: int = 0

	if p^ < end_ and p^^ == '0' then
		p^ := p^ + 1
		if p^ < end_ and isdigit(p^^ as int) then
			mh_fatal(path, line_no, "mh_parse_width_number: width must be a decimal integer")
		end
		return 0
	end

	while p^ < end_ and isdigit(p^^ as int) do
		if digits >= 2 then
			mh_fatal(path, line_no, "mh_parse_width_number: unsupported width for this type")
		end
		n := n * 10 + (p^^ - '0')
		digits := digits + 1
		p^ := p^ + 1
	end
	if digits == 0 then
		mh_fatal(path, line_no, "mh_parse_width_number: expected width")
	end
	return n
end mh_parse_width_number


(* type-spec = [ "const" ] [ "^" ] ident
 * Multi-word C types (e.g. "long long", "unsigned int") are kept as one
 * span including internal spaces (start .. end of last ident).
 *)
function mh_parse_type_spec(path: const ^char, line_no: size_t,
		p: ^pchar, end_: pchar,
		out_is_const: ^bool, out_is_pointer: ^bool,
		out_name: ^pchar, out_name_len: ^size_t,
		out_width: ^int): bool
begin
	var name: ^char = nil
	var name_len: size_t = 0
	var start: ^char = nil
	var more: ^char = nil
	var more_len: size_t = 0
	var save: ^char = nil

	out_is_const^ := false
	out_is_pointer^ := false
	out_name^ := nil
	out_name_len^ := 0
	out_width^ := 0

	if mh_match_word(p, end_, "const") then
		out_is_const^ := true
	end
	if mh_match_char(p, end_, '^') then
		out_is_pointer^ := true
	end
	if not mh_read_ident(p, end_, @name, @name_len) then
		mh_fatal(path, line_no, "mh_parse_type_spec: expected type name")
	end
	start := name

	save := p^
	mh_skip_ws(p, end_)
	if p^ < end_ and isdigit(p^^ as int) then
		var w: int = 0
		w := mh_parse_width_number(path, line_no, p, end_)
		if not type_width_allowed(name, name_len, w) then
			mh_fatal(path, line_no, "mh_parse_type_spec: unsupported width for this type")
		end
		out_width^ := w
	else
		p^ := save

		// Extend with further idents: "long long", "unsigned int", ...
		while true do
			save := p^
			mh_skip_ws(p, end_)
			if p^ >= end_ then
				p^ := save
				break
			end
			// Stop before formal/signature delimiters
			if p^^ == ',' or p^^ == ')' or p^^ == ':' then
				p^ := save
				break
			end
			// Next token must be an identifier
			if not isalpha(p^^ as int) and p^^ <> '_' then
				p^ := save
				break
			end
			if not mh_read_ident(p, end_, @more, @more_len) then
				p^ := save
				break
			end
			// Span from first ident through this one (including spaces between)
			name_len := (more + more_len - start) as size_t
		end
	end

	out_name^ := start
	out_name_len^ := name_len
	return true
end mh_parse_type_spec


(*
 * formal = [ var | ref | comst ] type-spec
 * Disambiguate leading "const":
 * 		"const ^T / "const const ^T" vs "const T" (CONST mode + type T)
 * 		If after first "const" the next char is '^', it is type-level only.
 * 		If next word is "const" or an ident, first "const" is formal mode.
 *)
function mh_parse_formal(path: const ^char, line_no: size_t,
		p: ^pchar, end_: pchar, out: ^MhFormal): bool
begin
	var t_const: bool = false
	var t_ptr: bool = false
	var t_name: ^char = nil
	var t_len: size_t = 0
	var t_width: int = 0
	var mode_const: bool = false

	out^.is_var := false
	out^.is_ref := false
	out^.is_const := false
	out^.type_is_const := false
	out^.type_is_pointer := false
	out^.type_name := nil
	out^.type_name_len := 0
	out^.type_width := 0
	out^.is_ellipsis := false
	if mh_peek_char(p^, end_, '.') then
		if not mh_match_char(p, end_, '.') or 
				not mh_match_char(p, end_, '.') or
				not mh_match_char(p, end_, '.') then
			mh_fatal(path, line_no, "mh_parse_formal: expected '...'")
		end
		out^.is_ellipsis := true
		return true
	end

	if mh_match_word(p, end_, "var") then
		out^.is_var := true
	elsif mh_match_word(p, end_, "ref") then
		out^.is_ref := true
	elsif mh_match_word(p, end_, "const") then
		// Lookahead: '^' => type-level const (re-parse type-spec including const)
		if mh_peek_char(p^, end_, '^') then
			// Put back: we alreayd consumed "const" as type-level -- parse_type_spec
			// needs "const" again. Easiest: set type_is_const and parse ^ name only.
			t_const := true
			if mh_match_char(p, end_, '^') then
				t_ptr := true
			end
			if not mh_read_ident(p, end_, @t_name, @t_len) then
				mh_fatal(path, line_no, "mh_parse_formal: expected type name after const ^")
			end
			out^.type_is_const := true
			out^.type_is_pointer := t_ptr
			out^.type_name := t_name
			out^.type_name_len := t_len
			out^.type_width := t_width
			// if out^.type_name == nil then
			// 	mh_fatal(path, line_no, "mh_parse_formal: out of memory")
			// end
			return true
		else
			// "const" is formal mode; type-spec follows (may start with const/^)
			mode_const := true
			out^.is_const := true
		end
	end

	if not mh_parse_type_spec(path, line_no, p, end_,
				@t_const, @t_ptr, @t_name, @t_len, @t_width) then
		return false
	end
	out^.type_is_const := t_const
	out^.type_is_pointer := t_ptr
	out^.type_name := mh_strdup_n(t_name, t_len)
	out^.type_name_len := t_len
	out^.type_width := t_width
	if out^.type_name == nil then
		mh_fatal(path, line_no, "mh_parse_formal: out of memory")
	end
	if mode_const then 		// silence unused if any
		// do nothing
	end
	return true
end mh_parse_formal


procedure mh_parse_signature(path: const ^char, line_no: size_t,
		p: ^pchar, end_: pchar, exp: ^MhExport)
begin
	var cap: size_t = 0
	var formals: ^MhFormal = nil
	var count: size_t = 0
	var f: MhFormal
	var t_const: bool = false
	var t_ptr: bool = false
	var t_name: ^char = nil
	var t_len: size_t = 0
	var t_width: int = 0

	exp^.has_signature := false
	exp^.formals := nil
	exp^.formal_count := 0
	exp^.has_result := false
	exp^.result_is_const := false
	exp^.result_name := nil
	exp^.result_name_len := 0
	exp^.result_width := 0

	if not mh_match_char(p, end_, '(') then
		return
	end
	exp^.has_signature := true

	// Empty () or formals
	mh_skip_ws(p, end_)
	if not mh_peek_char(p^, end_, ')') then
		while true do
			// grow
			if count >= cap then
				var new_cap: size_t = cap == 0 ? 4u : cap * 2u
				var neu: ^MhFormal = realloc(formals, new_cap * sizeof(MhFormal)) as ^MhFormal
				if neu == nil then
					mh_fatal(path, line_no, "mh_parse_signature: out of memory")
				end
				formals := neu
				cap := new_cap
			end
			if not mh_parse_formal(path, line_no, p, end_, @f) then
				mh_fatal(path, line_no, "mh_parse_signature: expected formal")
			end
			formals[count] := f
			count := count + 1
			if f.is_ellipsis then
				if mh_match_char(p, end_, ',') then
					mh_fatal(path, line_no, "mh_parse_signature: '...' must be the last formal")
				end
				break
			end
			if mh_match_char(p, end_, ',') then
				continue
			end
			break
		end
	end

	if not mh_match_char(p, end_, ')') then
		mh_fatal(path, line_no, "mh_parse_signature: expected ')'")
	end

	exp^.formals := formals
	exp^.formal_count := count

	// Optional : result-type
	if mh_match_char(p, end_, ':') then
		if not mh_parse_type_spec(path, line_no, p, end_,
					@t_const, @t_ptr, @t_name, @t_len, @t_width) then
			mh_fatal(path, line_no, "mh_parse_signature: expected result type")
		end
		exp^.has_result := true
		exp^.result_is_const := t_const
		exp^.result_is_pointer := t_ptr
		exp^.result_name := t_name
		exp^.result_name_len := t_len
		exp^.result_width := t_width
		// if exp^.result_name == nil then
		// 	mh_fatal(path, line_no, "mh_parse_signature: out of memory (result)")
		// end
	end
end mh_parse_signature


procedure mh_parse_method_type_tail(path: const ^char, line_no: size_t,
		p: ^pchar, end_: pchar, exp: ^MhExport)
begin
	exp^.is_func_type := false

	if mh_match_word(p, end_, "function") then
		exp^.is_func_type := true
	elsif mh_match_word(p, end_, "procedure") then
		exp^.is_func_type := false
	else
		return
	end

	mh_parse_signature(path, line_no, p, end_, exp)
	if not exp^.has_signature then
		mh_fatal(path, line_no, "mh_parse_method_type_tail: expected '(' after procedure/function")
	end
end mh_parse_method_type_tail


(*
 * Optional alias RHS after complete/opaque. No struct/union/method-type.
 *)
procedure mh_parse_alias_rhs(path: const ^char, line_no: size_t,
		p: ^pchar, end_: pchar, exp: ^MhExport)
begin
	var t_const: bool = false
	var t_ptr: bool = false
	var t_name: ^char = nil
	var t_len: size_t = 0
	var t_width: int = 0
	var save: pchar = nil

	if exp == nil then
		return
	end
	exp^.has_alias := false
	exp^.alias_is_const := false
	exp^.alias_is_pointer := false
	exp^.alias_name := nil
	exp^.alias_name_len := 0
	exp^.alias_width := 0

	save := p^
	mh_skip_ws(p, end_)
	if p^ >= end_ then
		p^ := save
		return
	end

	// struct/union/function/procedure already handled; leftover is type-spec.
	if not mh_parse_type_spec(path, line_no, p, end_,
			@t_const, @t_ptr, @t_name, @t_len, @t_width) then
		p^ := save
		return
	end
	exp^.has_alias := true
	exp^.alias_is_const := t_const
	exp^.alias_is_pointer := t_ptr
	exp^.alias_name := t_name
	exp^.alias_name_len := t_len
	exp^.alias_width := t_width
end mh_parse_alias_rhs


(*
 * Optional type tail: struct|union [extends ident] ( ident : type-spec { , ...} )
 * Absent => alias / opaque (caller skips). Pointers into the line / source buffer.
 *)
procedure mh_parse_field_list(path: const ^char, line_no: size_t,
		p: ^pchar, end_: pchar, exp: ^MhExport)
begin
	var cap: size_t = 0
	var fields: ^MhField = nil
	var count: size_t = 0
	var fname: ^char = nil
	var flen: size_t = 0
	var t_const: bool = false
	var t_ptr: bool = false
	var t_name: ^char = nil
	var t_len: size_t = 0
	var t_width: int = 0
	var ext: ^char = nil
	var ext_len: size_t = 0

	exp^.is_struct := false
	exp^.is_union := false
	exp^.extends_name := nil
	exp^.extends_name_len := 0
	exp^.fields := nil
	exp^.field_count := 0

	if mh_match_word(p, end_, "struct") then
		exp^.is_struct := true
	elsif mh_match_word(p, end_, "union") then
		exp^.is_union := true
	else
		return
	end

	if mh_match_word(p, end_, "extends") then
		if not mh_read_ident(p, end_, @ext, @ext_len) then
			mh_fatal(path, line_no, "mh_parse_field_list: expected parent type after extends")
		end
		exp^.extends_name := ext
		exp^.extends_name_len := ext_len
	end

	if not mh_match_char(p, end_, '(') then
		mh_fatal(path, line_no, "mh_parse_field_list: expected '(' after struct/union")
	end

	mh_skip_ws(p, end_)
	if not mh_peek_char(p^, end_, ')') then
		while true do
			if count >= cap then
				var new_cap: size_t = cap == 0 ? 4u : cap * 2u
				var neu: ^MhField = realloc(fields, new_cap * sizeof(MhField)) as ^MhField
				if neu == nil then
					mh_fatal(path, line_no, "mh_parse_field_list: out of memory")
				end
				fields := neu
				cap := new_cap
			end
			if not mh_read_ident(p, end_, @fname, @flen) then
				mh_fatal(path, line_no, "mh_parse_field_list: expected field name")
			end
			if not mh_match_char(p, end_, ':') then
				mh_fatal(path, line_no, "mh_parse_field_list: expected ':' after field name")
			end
			if not mh_parse_type_spec(path, line_no, p, end_,
					@t_const, @t_ptr, @t_name, @t_len, @t_width) then
				mh_fatal(path, line_no, "mh_parse_field_list: expected field type")
			end
			fields[count].name := fname
			fields[count].name_len := flen
			fields[count].type_is_const := t_const
			fields[count].type_is_pointer := t_ptr
			fields[count].type_name := t_name
			fields[count].type_name_len := t_len
			fields[count].type_width := t_width
			count := count + 1
			if mh_match_char(p, end_, ',') then
				continue
			end
			break
		end
	end

	if not mh_match_char(p, end_, ')') then
		mh_fatal(path, line_no, "mh_parse_field_list: expected ')'")
	end

	exp^.fields := fields
	exp^.field_count := count
end mh_parse_field_list


procedure mh_parse_export_line(path: const ^char, line_no: size_t, line: ^char, m: ^MhModule)
begin
	var p: ^char = line
	var end_: ^char = line + strlen(line)
	var name: ^char = nil
	var name_len: size_t = 0
	var is_extern: bool = false
	var kind: MhExportKind = 0
	var completeness: MhCompleteness = 0
	var exp: MhExport
	var owner: ^char = nil
	var owner_len: size_t = 0
	var is_method: bool = false
	var is_instance: bool = false

	if not mh_match_word(@p, end_, "export") then
		mh_fatal(path, line_no, "expected export")
	end

	if mh_match_word(@p, end_, "extern") then
		is_extern := true
	end

	if mh_match_word(@p, end_, "procedure") then
		kind := MH_KIND_PROCEDURE
	elsif mh_match_word(@p, end_, "function") then
		kind := MH_KIND_FUNCTION
	elsif mh_match_word(@p, end_, "type") then
		kind := MH_KIND_TYPE
	elsif mh_match_word(@p, end_, "enum") then
		kind := MH_KIND_ENUM
	elsif mh_match_word(@p, end_, "var") then
		kind := MH_KIND_VAR
	elsif mh_match_word(@p, end_, "const") then
		kind := MH_KIND_CONST
	elsif mh_match_word(@p, end_, "define") then
		kind := MH_KIND_DEFINE
	else
		mh_fatal(path, line_no, "mh_parse_export_line: expected export kind")
	end

	if not mh_read_ident(@p, end_, @name, @name_len) then
		mh_fatal(path, line_no, "mh_parse_export_line: expected export name")
	end

	if mh_match_word(@p, end_, "complete") then
		completeness := MH_COMPLETENESS_COMPLETE
	elsif mh_match_word(@p, end_, "incomplete") then
		completeness := MH_COMPLETENESS_INCOMPLETE
	elsif mh_match_word(@p, end_, "opaque") then
		completeness := MH_COMPLETENESS_OPAQUE
	else
		mh_fatal(path, line_no, "mh_parse_export_line: expected complete, incomplete, or opaque")
	end

	// Optional: instance Owner | static Owner (type-bound methods, A1 writer).
	if mh_match_word(@p, end_, "instance") then
		is_method := true
		is_instance := true
		if not mh_read_ident(@p, end_, @owner, @owner_len) then
			mh_fatal(path, line_no,
				"mh_parse_export_line: expected owner type after instance")
		end
	elsif mh_match_word(@p, end_, "static") then
		is_method := true
		is_instance := false
		if not mh_read_ident(@p, end_, @owner, @owner_len) then
			mh_fatal(path, line_no,
				"mh_parse_export_line: expected owner type after static")
		end
	end

	exp.kind 				:= kind
	exp.is_extern 			:= is_extern
	exp.completeness 		:= completeness
	exp.name 				:= mh_strdup_n(name, name_len)
	exp.name_len			:= name_len
	exp.is_method 			:= is_method
	exp.is_instance 		:= is_instance
	exp.method_owner 		:= nil
	exp.method_owner_len 	:= 0

	if exp.name == nil then
		mh_fatal(path, line_no, "mh_parse_export_line: out of memory")
	end

	if is_method then
		exp.method_owner := mh_strdup_n(owner, owner_len)
		exp.method_owner_len := owner_len
		if exp.method_owner == nil then
			mh_fatal(path, line_no, "mh_parse_export_line: out of memory (owner)")
		end
	end

	// Default signature fields (overwritten if '(' present)
	exp.has_signature := false
	exp.formals := nil
	exp.formal_count := 0
	exp.has_result := false
	exp.result_is_const := false
	exp.result_is_pointer := false
	exp.result_name := nil
	exp.result_name_len := 0
	exp.result_width := 0
	exp.is_struct := false
	exp.is_union := false
	exp.extends_name := nil
	exp.extends_name_len := 0
	exp.fields := nil
	exp.field_count := 0
	exp.is_func_type := false
	exp.has_alias := false
	exp.alias_is_const := false
	exp.alias_is_pointer := false
	exp.alias_name := nil
	exp.alias_name_len := 0
	exp.alias_width := 0

	if kind == MH_KIND_PROCEDURE or kind == MH_KIND_FUNCTION then
		mh_parse_signature(path, line_no, @p, end_, @exp)
	end
	if kind == MH_KIND_TYPE then
		mh_parse_field_list(path, line_no, @p, end_, @exp)
		if not exp.is_struct and not exp.is_union then
			mh_parse_method_type_tail(path, line_no, @p, end_, @exp)
		end
		if not exp.is_struct and not exp.is_union and not exp.is_func_type then
			mh_parse_alias_rhs(path, line_no, @p, end_, @exp)
		end
	end

	mh_module_add(m, exp)
end mh_parse_export_line


procedure mh_parse_line(path: const ^char, line_no: size_t, line: ^char, m: ^MhModule)
begin
	var hash: ^char = strchr(line, '#')
	var i: size_t = 0

	if hash <> nil then
		hash^ := '\0'
	end

	i := 0
	while line[i] <> '\0' and (line[i] == ' ' or line[i] == '\t' or line[i] == '\r') do
		i := i + 1
	end
	if line[i] == '\0' then
		return
	end

	if memcmp(line + i, "@module", 7) == 0 then
		var p: ^char = line + i
		var end_: ^char = line + strlen(line)
		var name: ^char = nil
		var name_len: size_t = 0
		if not mh_match_word(@p, end_, "@module") then
			mh_fatal(path, line_no, "mh_parse_line: expected @module")
		end
		if not mh_read_ident(@p, end_, @name, @name_len) then
			mh_fatal(path, line_no, "mh_parse_line: expected module name after @module")
		end
		if m^.module_name <> nil then
			mh_fatal(path, line_no, "mh_parse_line: duplicate @module line")
		end
		m^.module_name := name
		m^.module_name_len := name_len
		return
	end

	if memcmp(line + i, "@format", 7) == 0 then
		var p: ^char = line + i
		var end_: ^char = line + strlen(line)
		if not mh_match_word(@p, end_, "@format") then
			mh_fatal(path, line_no, "mh_parse_line: expected @format")
		end
		while p^ <> '\0' and (p^ == ' ' or p^ == '\t') do
			p := p + 1
		end

		if p^ == '\0' or not isdigit(p^ as int) then
			mh_fatal(path, line_no, "mh_parse_line: expected format version number")
		end
		if atoi(p) <> 1 then
			mh_fatal(path, line_no, "mh_parse_line: unsupported modc-mh format version")
		end
		m^.format_version := 1
		return
	end

	if memcmp(line + i, "export", 6) == 0 then
		mh_parse_export_line(path, line_no, line + i, m)
		return
	end

	mh_fatal(path, line_no, "mh_parse_line: unrecognized .mh line")
end mh_parse_line


export function mh_reader_load(resolved_path: const ^char, out: ^MhModule): bool
begin
	var fp: ^FILE = nil
	var fsize: size_t = 0
	var nread: size_t = 0
	var i: size_t = 0
	var line_start: ^char = nil
	var line_no: size_t = 0
	var file_pos: long = 0
	var file_end: long = 0

	if resolved_path == nil or out == nil then
		return false
	end

	out^.module_name 		:= nil
	out^.module_name_len 	:= 0
	out^.format_version 	:= 0
	out^.exports 			:= nil
	out^.count 				:= 0
	out^.capacity 			:= 0
	out^.source 			:= nil
	out^.source_len 		:= 0

	fp := fopen(resolved_path, "r")
	if fp == nil then
		fprintf(stderr, "ERROR: mh_reader_load: cannot open .mh file: %s\n", resolved_path)
		return false
	end

	file_pos := ftell(fp)
	if file_pos < 0 or fseek(fp, 0, SEEK_END) <> 0 then
		fclose(fp)
		fprintf(stderr, "ERROR: mh_reader_load: cannot size .mh file: %s\n", resolved_path)
		return false
	end
	file_end := ftell(fp)
	fseek(fp, file_pos, SEEK_SET)
	if file_end < 0 then
		fclose(fp)
		fprintf(stderr, "ERROR: mh_reader_load: cannot size .mh file: %s\n", resolved_path)
		return false
	end
	fsize := file_end as size_t

	out^.source := malloc(fsize + 1) as ^char
	if out^.source == nil then
		fclose(fp)
		fprintf(stderr, "ERROR: mh_reader_load: out of memory reading %s\n", resolved_path)
		return false
	end
	nread := fread(out^.source, 1, fsize, fp)
	fclose(fp)
	out^.source[nread] := '\0'
	out^.source_len := nread

	line_start := out^.source
	i := 0
	while i <= nread do
		if out^.source[i] == '\n' or out^.source[i] == '\0' then
			var at_end: bool = (out^.source[i] == '\0')
			if i > 0 and out^.source[i - 1] == '\r' then
				out^.source[i - 1] := '\0'
			end
			out^.source[i] := '\0'
			line_no := line_no + 1
			mh_parse_line(resolved_path, line_no, line_start, out)
			if at_end then
				break
			end
			line_start := out^.source + i + 1
		end
		inc(i)
	end

	if out^.module_name == nil then
		fprintf(stderr, "ERROR: mh_reader_load: %s: missing @module line\n", resolved_path)
		mh_module_free(out)
		return false
	end

	if out^.format_version <> 1 then
		fprintf(stderr, "ERROR: mh_reader_load: %s: missing @format 1 line\n", resolved_path)
		mh_module_free(out)
	end

	return true
end mh_reader_load


begin
end mh_reader

