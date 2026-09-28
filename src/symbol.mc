module symbol()
(**
 * Symbol table related stuff.
 *)


import size_t from "stddef.h"
import Arena, arena_alloc from arena
import TType from ttype
import SYM_KIND_CONST, SYM_KIND_FIELD, SYM_KIND_FUNC, SYM_KIND_IMPORT,
	SYM_KIND_LET, SYM_KIND_PARAM, SYM_KIND_PROC, SYM_KIND_RECEIVER,
	SYM_KIND_STRUCT, SYM_KIND_TYPE, SYM_KIND_UNKNOWN, SYM_KIND_VAR, SymbolKind,
from symkind

import Node, NodeKind,  from "node.h"


export type pNode = ^Node


(** TTymbol structure *)
export type TSymbol = struct
	kind: 				SymbolKind
	name: 				const ^char
	name_len:			size_t
	symbol_type:		^TType			// nil until resolved
	decl:				pNode			// defining AST node
	is_exported: 		bool
	has_const_value:	bool 			// true for enum members / folded CONST (Phase B)
	const_value:		integer			// valid when has_const_value
	// .mh type-bound method import (A2/A3): true => obj.method instance sugar (A4)
	is_method_instance: bool
end

export type pTSymbol		= ^TSymbol
export type ppTSymbol		= ^pTSymbol


(**
 * Function symbol_create()
 * @param arena
 * @param kind
 * @param name
 * @param name_len
 * @param decl
 * @return ^TSymbol
 *)
export function symbol_create(arena: ^Arena, kind: SymbolKind, name: const ^char, name_len: size_t, decl: pNode): ^TSymbol
begin
	var s: ^TSymbol = arena_alloc(arena, sizeof(TSymbol))
	s^.kind 				:= kind
	s^.name 				:= name
	s^.name_len 			:= name_len
	s^.symbol_type 			:= nil
	s^.decl 				:= decl
	s^.is_exported 			:= false
	s^.has_const_value		:= false
	s^.const_value 			:= 0
	s^.is_method_instance 	:= false

	return s
end


(**
 * Function symbol_kind_name()
 * @param kind
 * @return const ^char
 *)
export function symbol_kind_name(kind: SymbolKind): const ^char
begin
	switch kind of
		case SYM_KIND_CONST:	return "CONST"
		case SYM_KIND_FIELD:	return "FIELD"
		case SYM_KIND_FUNC:		return "FUNC"
		case SYM_KIND_IMPORT:	return "IMPORT"
		case SYM_KIND_LET:		return "LET"
		case SYM_KIND_PARAM:	return "PARAM"
		case SYM_KIND_PROC:		return "PROC"
		case SYM_KIND_RECEIVER:	return "RECEIVER"
		case SYM_KIND_STRUCT:	return "STRUCT"
		case SYM_KIND_TYPE:		return "TYPE"
		case SYM_KIND_UNKNOWN:	return "UNKNOWN"
		case SYM_KIND_VAR: 		return "VAR"
		else: return "UNKNOWN"
	end
end

begin
end symbol

