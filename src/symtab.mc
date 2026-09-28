module symtab()

(** symtab.mc
 * Symbol Table Definition
 *
 * Scoped symbol tables for semantic analysis.
 * Each table is one scope; parent links form a chain.
 *)


import Arena, pvoid, ppvoid, arena_alloc, arena_append_ptr from arena
import TSymbol, symbol_kind_name, pTSymbol, ppTSymbol, from symbol
import SYM_KIND_LET from symkind

import size_t from "stddef.h"
import stderr, fprintf, from "stdio.h"
import exit from "stdlib.h"
import memcmp from "string.h"
import node_print, Node from "node.h"


(** One lexical scope *)
export type TSymbolTable = struct
	parent:		^TSymbolTable
	symbols: 	ppTSymbol			// TSymbol** (dynamic array base)
	count:		size_t
	capacity:	size_t
end
export type pTSymbolTable 	= ^TSymbolTable


(**
 * Report a fatal symbol-table error and exit.
 * Location-aware errors come later (tsemantic.mc + Node.token).
 *)
export procedure symtab_fatal(symbol: ^TSymbol, msg: const ^char)
begin
	if symbol <> nil and symbol^.decl <> nil then
		node_print(symbol^.decl, 0)
	end
	fprintf(stderr, "ERROR: symtab: %s\n", msg)
	exit(1)
end


(**
 * Create a new scope. parent may be nil (program/module scope).
 *)
export function symtab_create(arena: ^Arena, parent: pTSymbolTable): pTSymbolTable
begin
	var table: pTSymbolTable

	if arena == nil then
		symtab_fatal(nil, "symtab_create: NULL arena")
	end

	table := arena_alloc(arena, sizeof(TSymbolTable)) as pTSymbolTable

	table^.parent 		:= parent
	table^.symbols		:= nil
	table^.count		:= 0
	table^.capacity		:= 0

	return table
end


(**
 * Compare identifier spelling (length + bytes). No case folding.
 *)
function symtab_names_equal(a_name: const ^char, a_len: size_t,					\
							b_name: const ^char, b_len: size_t): bool
begin
	if a_name == nil or b_name == nil then
		return false
	elsif a_len <> b_len then
		return false
	else
		return memcmp(a_name, b_name, a_len) == 0
	end
end


(**
 * Look up a name in the current scope only.
 * @return symbol, or nil if not found.
 *)
export function symtab_lookup_current(table: pTSymbolTable, 					\
 							name: const ^char, name_len: size_t): pTSymbol
begin
	var i: size_t = 0

	if table == nil or name == nil or name_len == 0 then
		return nil
	end

	for i := 1 to table^.count do
		let sym: pTSymbol = table^.symbols[i-1]
		if sym <> nil and symtab_names_equal(sym^.name, sym^.name_len, name, name_len) then
			return sym
		end
	end

	return nil
end


(**
 * Look up a name in the current scope, then parent scopes.
 * @return symbol, or nil if not found.
 *)
export function symtab_lookup(table: pTSymbolTable,								\
							  name: const ^char, name_len: size_t): pTSymbol
begin
	var current: pTSymbolTable = table
	var sym: pTSymbol = nil

	if table == nil or name == nil or name_len == 0 then
		return nil
	end

	while current <> nil do
		sym := symtab_lookup_current(current, name, name_len)
		if sym <> nil then
			return sym
		end
		current := current^.parent
	end

	return nil
end


(**
 * Insert a symbol into the current scope.
 * Fatal on duplicate name in this scope.
 *)
export procedure symtab_define(arena: ^Arena, table: pTSymbolTable, symbol: pTSymbol)
begin
	var existing: pTSymbol = nil

	if arena == nil then
		symtab_fatal(nil, "symtab_define: NULL arena")
	elsif table == nil then
		symtab_fatal(nil, "symtab_define: NULL table")
	elsif symbol == nil then
		symtab_fatal(nil, "symtab_define: NULL symbol")
	elsif symbol^.name == nil or symbol^.name_len == 0 then
		symtab_fatal(symbol, "symtab_define: symbol has no name")
	end

	existing := symtab_lookup_current(table, symbol^.name, symbol^.name_len)
	if existing <> nil then
		fprintf(stderr, "ERROR: symtab_define: duplicate '%.*s' (%s) in scope\n",			\
				symbol^.name_len as int, symbol^.name,										\
				symbol_kind_name(symbol^.kind))
		exit(1)
	end

//	arena_append_ptr(arena, @table^.symbols as ppvoid, @table^.count, @table^.capacity, symbol as pvoid)
	arena_append_ptr(arena, (@table^.symbols) as ppvoid, @table^.count, @table^.capacity, symbol as pvoid)
end


(**
 * Insert or rebind a LET symbol in the current scope.
 * Rebinds when an existing LET has the same name; fatal on any other kind.
 *)
export procedure symtab_define_let(arena: ^Arena, table: pTSymbolTable, symbol: pTSymbol)
begin
	var existing: pTSymbol = nil
	var i: size_t = 0

	if arena == nil then
		symtab_fatal(nil, "symtab_define_let: NULL arena")
	elsif table == nil then
		symtab_fatal(nil, "symtab_define_let: NULL table")
	elsif symbol == nil then
		symtab_fatal(nil, "symtab_define_let: NULL symbol")
	elsif symbol^.name == nil or symbol^.name_len == 0 then
		symtab_fatal(symbol, "symtab_define_let: symbol has no name")
	end

	existing := symtab_lookup_current(table, symbol^.name, symbol^.name_len)
	if existing == nil then
		arena_append_ptr(arena, (@table^.symbols) as ppvoid, @table^.count, @table^.capacity,symbol as pvoid)
		return
	end

	if existing^.kind == SYM_KIND_LET then
		for i := 1 to table^.count do
			if table^.symbols[i-1] == existing then
				table^.symbols[i-1] := symbol
				return
			end
		end
		symtab_fatal(symbol, "symtab_define_let: internal error: LET symbol mising from table")
	end

	if symbol^.decl <> nil then
		node_print(symbol^.decl, 0)
	end
	fprintf(stderr, "ERROR: symtab_define_let: cannot bind LET '%.*s' over existing %s\n", 		\
		symbol^.name_len as int, symbol^.name, symbol_kind_name(existing^.kind))
	exit(1)
end symtab_define_let


(**
 * Replace an existing symbol in the current scope (IMPORT refinement).
 *)
export procedure symtab_refine_symbol(arena: ^Arena, table: pTSymbolTable, 			\
								existing: pTSymbol, replacement: pTSymbol)
begin
	var i: size_t = 0

	if arena == nil then
		symtab_fatal(nil, "symtab_refine_symbol: NULL arena")
	elsif table == nil then
		symtab_fatal(nil, "symtab_refine_symbol: NULL table")
	elsif existing == nil or replacement == nil then
		symtab_fatal(nil, "symtab_refine_symbol: NULL symbol")
	end

	for i := 1 to table^.count do
		if table^.symbols[i-1] == existing then
			table^.symbols[i-1] := replacement
			return
		end
	end

	symtab_fatal(existing, "symtab_refine_symbol; symbol not found in current scope")
end symtab_refine_symbol


begin
end symtab
