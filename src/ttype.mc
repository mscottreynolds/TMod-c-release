module ttype()

(**
 * Mod-c
 * By M. Scott Reynolds
 * 20 February 2026
 *
 * type.mc - Basic type representations.
 * 13 May 2026 - Extend for floating-point support.
 *)
 

import Arena, arena_alloc, pvoid from arena

import size_t from "stddef.h"
import printf from "stdio.h"
import memset, memcmp from "string.h"
import from "stdbool.h"

(**
 * Simple type descriptor (v1 - string-based)
 * Later can become a tagged union with primitive, pointer, record, etc.
 * Future extensions:
 * fields, generics, etc.
 *)
export type TType = struct
	name: 			const ^char	// e.g. "INTEGER", "STRING", "TypeName"
	name_len: 		size_t		// length (safe, no null assumption)
	is_pointer: 	bool		// future: * syntax
	is_array: 		bool		// future
	is_const:		bool		// const variable
	is_opaque:		bool 		// TYPE ... = opaque / ^opaque (not a layout)
	// bool		is_floating;	// floating point value.
	array_size:		size_t		// 0 = open/dynamic, >0 = fixed size.
	size_expr:		pvoid 		// Node* until semantic folds; nil if open or already numeric	TODO: Change VOID to something else
	element_type:	^TType		// for arrays and pointers
	base_type:		^TType		// for EXTENDS support (NULL if none)
	resolved_type:	^TType 		// semantic pass: fully expanded alias (nil - not resolved yet)
	width:			int 		// 0 = not a width form; else exact bit count
end


export type pTType = ^TType

// export type string = const ^char


(**
 * Shallow arena copy of src.
 *)
export function type_copy_shell(arena: ^Arena, src: const ^TType): ^TType
begin
	var t: ^TType 	= arena_alloc(arena, sizeof(TType))

	// memset(t, 0, sizeof(TType))			// important. arena_alloc now memset's memory.

	t^.name 			:= src^.name
	t^.name_len 		:= src^.name_len
	t^.is_pointer 		:= src^.is_pointer
	t^.is_array			:= src^.is_array
	t^.is_const			:= src^.is_const
	t^.is_opaque 		:= src^.is_opaque
	t^.array_size 		:= src^.array_size
	t^.size_expr		:= src^.size_expr
	t^.element_type 	:= src^.element_type
	t^.base_type 		:= src^.base_type
	t^.width 			:= src^.width
	t^.resolved_type 	:= nil

	return t
end type_copy_shell


(**
 * True for a builtin type spelling (grammar prelude). Case-sensitive: only
 * lowercase spellings are reserved; e.g. String may be a user TYPE name.
 *)
export function type_is_builtin_name(name: const ^char, name_len: size_t): bool
begin
	if name == nil or name_len == 0 then
		return false
	elsif name_len == 3 then
		return memcmp(name, "bit", 3) == 0 or 		\
			memcmp(name, "int", 3) == 0
	elsif name_len == 4 then
		return memcmp(name, "bool", 4) == 0 or		\
			memcmp(name, "byte", 4) == 0 or 		\
			memcmp(name, "char", 4) == 0 or 		\
			memcmp(name, "real", 4) == 0 or 		\
			memcmp(name, "long", 4) == 0
	elsif name_len == 5 then
		return memcmp(name, "float", 5) == 0 or 		\
			memcmp(name, "short", 5) == 0
	elsif name_len == 6 then
		return memcmp(name, "string", 6) == 0 or 	\
			memcmp(name, "double", 6) == 0
	elsif name_len == 7 then
		return memcmp(name, "integer", 7) == 0
	elsif name_len == 8 then
		return memcmp(name, "cardinal", 8) == 0
	else
		return false
	end
end type_is_builtin_name


(**
 * Portable names that may be bound once per compilation unit (Language Report 5.5)
 * Not C names -- only integer/ cardinal / real / string.
 *)
export function type_is_portable_rebindable(name: const ^char, name_len: size_t): bool
begin
	if name == nil or name_len == 0 then
		return false
	elsif name_len == 4 then
		return memcmp(name, "real", 4) == 0
	elsif name_len == 6 then
		return memcmp(name, "string", 6) == 0
	elsif name_len == 7 then
		return memcmp(name, "integer", 7) == 0
	elsif name_len == 8 then
		return memcmp(name, "cardinal", 8) == 0
	else
		return false
	end
	
end type_is_portable_rebindable


(**
 * Width constructors: integer N / cardinal n /real N (Langauge Report 10.1).
 *)
export function type_is_width_base(name: const ^char, name_len: size_t): bool
begin
	if name == nil or name_len == 0 then
		return false
	elsif name_len == 4 then
		return memcmp(name, "real", 4) == 0
	elsif name_len == 7 then
		return memcmp(name, "integer", 7) == 0
	elsif name_len == 8 then
		return memcmp(name, "cardinal", 8) == 0
	else
		return false
	end
end type_is_width_base


export function type_width_allowed(name: const ^char, name_len: size_t, n: int): bool
begin
	if not type_is_width_base(name, name_len) then
		return false
	end
	if name_len == 4 then
		return n == 32 or n == 64
	end
	return n == 8 or n == 16 or n == 32 or n == 64
end type_width_allowed


(**
 * C spelling for codegen. Width forms -> stdint / float / double.
 * Unqualified names stay as stored (integer, long long, ...).
 *)
export function type_c_spelling(t: const ^TType, out_s: ^string, out_len: ^size_t): bool
begin
	if t == nil or out_s == nil or out_len == nil then
		return false
	end

	if t^.width > 0 and type_is_width_base(t^.name, t^.name_len) then
		if t^.name_len == 7 then		// integer
			if t^.width == 8 then
				out_s^ := "int8_t"; out_len^ := 6
			elsif t^.width == 16 then
				out_s^ := "int16_t"; out_len^ := 7
			elsif t^.width == 32 then
				out_s^ := "int32_t"; out_len^ := 7
			elsif t^.width == 64 then
				out_s^ := "int64_t"; out_len^ := 7
			else
				return false
			end
			return true
		elsif t^.name_len == 8 then		// cardinal
			if t^.width == 8 then
				out_s^ := "uint8_t"; out_len^ := 7
			elsif t^.width == 16 then
				out_s^ := "uint16_t"; out_len^ := 8
			elsif t^.width == 32 then
				out_s^ := "uint32_t"; out_len^ := 8
			elsif t^.width == 64 then
				out_s^ := "uint64_t"; out_len^ := 8
			else
				return false
			end
			return true
		elsif t^.name_len == 4 then		// real
			if t^.width == 32 then
				out_s^ := "float"; out_len^ := 5
			elsif t^.width == 64 then
				out_s^ := "double"; out_len^ := 6
			else
				return false
			end
			return true
		end
		return false
	end

	out_s^ := t^.name
	out_len^ := t^.name_len
	return t^.name <> nil and t^.name_len > 0
end type_c_spelling


(**
 * Create a simple named type (copies name pointer + length)
 * Uses arena for allocation.
 *)
export function type_create_named(arena: ^Arena, name_start: const ^char, name_len: size_t): ^TType
begin
	var t: ^TType    = arena_alloc(arena, sizeof(TType))

	t^.name 			:= name_start
	t^.name_len 		:= name_len
	t^.is_pointer 		:= false
	t^.is_array			:= false
	t^.is_const			:= false
	t^.is_opaque 		:= false
	t^.array_size 		:= 0			// 0 means dynamic/open
	t^.size_expr		:= nil
	t^.element_type 	:= nil
	t^.base_type 		:= nil
	t^.resolved_type 	:= nil
	t^.width 			:= 0

	// Auto-detect floating point primitives (case-sensitive for now)
	// if (name_len == 5 and memcmp(name_start, "float", 5) == 0) {
	// 	t->is_floating = true;
	// } else if (name_len == 6 and memcmp(name_start, "double", 6) == 0) {
	// 	t->is_floating = true;
	// }

	return t
end


(**
 * Create an array type (array_of_T or fixed-size).
 *)
export function type_create_array(arena: ^Arena, element: ^TType, fixed_size: size_t): ^TType
begin
	var t: ^TType		= arena_alloc(arena, sizeof(TType))

	// memset(t, 0, sizeof(TType))			// important.

	t^.is_array 		:= true
	t^.array_size 		:= fixed_size	// 0 = open [], >0 = fixed [N]
	t^.size_expr		:= nil
	t^.element_type 	:= element
	t^.is_const			:= element ? element^.is_const : false
	t^.is_opaque 		:= false
	t^.base_type 		:= nil
	t^.resolved_type	:= nil
	// t^.is_floating		= element ? element->is_floating : false;
	return t
end


(**
 * Create a fixed array whose size is a const-expression (folded in semantic).
 * size_expr is a Node* stored as ^void (avoids ttype <==> node import cycle).
 *)
export function type_create_array_expr(arena: ^Arena, element: ^TType, size_expr: pvoid): ^TType
begin
	var t: ^TType = arena_alloc(arena, sizeof(TType))

	// memset(t, 0, sizeof(TType))

	t^.is_array 		:= true
	t^.array_size 		:= 0
	t^.size_expr 		:= size_expr
	t^.element_type 	:= element
	t^.is_const 		:= element ? element^.is_const : false
	t^.is_opaque		:= false
	t^.base_type 		:= nil
	t^.resolved_type 	:= nil
	return t
end type_create_array_expr


(**
 * Create opaque
 *)
export function type_create_opaque(arena: ^Arena): ^TType
begin
	require arena <> nil

	var t: ^TType = arena_alloc(arena, sizeof(TType))

	// memset(t, 0, sizeof(TType))
	t^.is_opaque := true
	// name nil - alias name lives on TYPE_DECL
	return t

end type_create_opaque


(**
 * Compare two types (name + structure).
 *)
export recursive function type_equals(a: const ^TType, b: const ^TType): bool
begin
	if a == b then
		return true
	elsif a == nil or b == nil then
		return false
	elsif a^.is_pointer <> b^.is_pointer then
		return false
	elsif a^.is_const <> b^.is_const then
		return false
	elsif a^.is_opaque <> b^.is_opaque then
		return false
	elsif a^.is_array <> b^.is_array then
		return false
	// if (a->is_floating != b->is_floating) { return false; }
	elsif a^.is_array then
		if a^.size_expr <> nil or b^.size_expr <> nil then
			return false
		end
		if a^.array_size <> b^.array_size then
			return false
		else
			return type_equals(a^.element_type, b^.element_type)
		end
	end

	if a^.name_len <> b^.name_len then
		return false
	end
	if a^.width <> b^.width then
		return false
	end
	return memcmp(a^.name, b^.name, a^.name_len) == 0
end


(**
 * Print type
 *)
export recursive procedure type_print(t: const ^TType)
begin
	if t == nil then
		printf("(unknown)")
		return
	end

	if t^.is_const then
		printf("CONST ")
	end

	if t^.is_pointer then
		printf("^")
	end

	if t^.is_opaque then
		printf("OPAQUE ")
	end

	if t^.is_array then
		printf("ARRAY")
		if t^.size_expr <> nil then
			printf("[...]")
		elsif t^.array_size > 0 then
			printf("[%zu]", t^.array_size)
		end
		printf(" OF ")
		type_print(t^.element_type)
	elsif t^.name <> nil then
		printf("%.*s", t^.name_len as int, t^.name)
		if t^.width > 0 then
			printf(" %d", t^.width)
		end
	end

	if t^.resolved_type <> nil then
		printf(" => ")
		type_print(t^.resolved_type)
	end
end type_print

begin
end ttype
