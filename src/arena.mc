module arena()
(**
 * Mod-c
 * By M. Scott Reynolds
 * Date 20 February 2026
 *
 * arena.c - Linear / bump allocator with linked chunks
 * 
 * 25 July 2026
 * Growth never relocates existing slabs (pointer-stable).
 * Old bug: single-slab realloc invalidated interior pointers (AST, symtab).
 *)


import size_t, void from "stddef.h"
import memset, memcpy, strlen, memcmp, strchr, memchr, from "string.h"
import calloc, free, exit from "stdlib.h"
import fprintf, stderr from "stdio.h"


const ARENA_ALIGNMENT: cardinal = 8
const ARENA_MIN_SIZE: cardinal = 1_048_576		// Default / first chunk floor
// const ARENA_MIN_SIZE: cardinal = 16_384			// Debug value

export type pchar = ^char
export type pvoid = ^void
export type ppvoid = ^pvoid


(** One malloc'd slab: header + payload. Never realloc this block *)
export type ArenaChunk = struct
	next: 	^ArenaChunk
	size:	size_t			// Payload capacity
	used: 	size_t 			// Payload used
	// Payload follows.
end
type pArenaChunk = ^ArenaChunk


(** 
 * Opaque arena allocator structure.
 *)
export type Arena = struct
	head: 		^ArenaChunk
	current: 	^ArenaChunk
end
export type pArena = ^Arena

(**
 * Payload starts immediately after the chunk header. 
 *)
function arena_chunk_data(c: pArenaChunk): pchar
begin
	return (c as pchar) + sizeof(ArenaChunk)
end arena_chunk_data


(**
 * Allocate a new chunk with at least payload_size bytes of payload.
 * Links are left nil; caller attaches to the list.
 *)
function arena_chunk_create(payload_size: size_t): pArenaChunk
begin
	var total: size_t
	var raw: pvoid
	var c: pArenaChunk
	var ps: size_t = payload_size

	if ps < ARENA_MIN_SIZE then
		ps := ARENA_MIN_SIZE
	end

	total := sizeof(ArenaChunk) + ps
	// overflow: sizeof + payload wrapped
	if total < ps then
		fprintf(stderr, "ERROR: arena_chunk_create: size overflow\n")
		exit(1)
	end

	DEBUG fprintf(stderr, "DEBUG: arena_chunk_create: total = %zu\n", total)

	raw := calloc(1, total)
	if raw == nil then
		fprintf(stderr, "ERROR: arena_chunk_create: calloc(1, %zu) failed\n", total)
		exit(1)
	end

	c := raw as pArenaChunk
	c^.next := nil
	c^.size := ps
	c^.used := 0

	return c
end arena_chunk_create


(**
 * Initialize an arena with given initial capacity.
 * Exits program on allocation failure.
 *)
export procedure arena_init(a: pArena, initial_size: size_t)
begin
	require a <> nil

	var n: size_t = initial_size

	if a == nil then
		fprintf(stderr, "ERROR: arena_init: NULL arena\n")
		exit(1)
	end

	if n < ARENA_MIN_SIZE then
		n := ARENA_MIN_SIZE
	end

	a^.head := arena_chunk_create(n)
	a^.current := a^.head
end arena_init


(**
 * Append a new chunk large enough for 'needed' payload bytes.
 * Previous chunks are left intact (pointers into them stay valid).
 *)
procedure arena_add_chunk(a: pArena, needed: size_t)
begin
	var chunk_size: size_t
	var doubled: size_t
	var c: pArenaChunk

	if a == nil or a^.current == nil then
		fprintf(stderr, "ERROR: arena_add_chunk: arena not initialized\n")
		exit(1)
	end

	// Prefer at least doubled previous payload capacity (fewer chunks).
	chunk_size := ARENA_MIN_SIZE
	if a^.current^.size > chunk_size then
		chunk_size := a^.current^.size
	end
	doubled := chunk_size * 2u
	if doubled / 2u == chunk_size and doubled > chunk_size then
		chunk_size := doubled
	end
	if needed > chunk_size then
		chunk_size := needed
	end

	c := arena_chunk_create(chunk_size)
	a^.current^.next := c
	a^.current := c
end arena_add_chunk


(**
 * Allocate 'size' bytes with ARENA_ALIGNMENT alignment.
 * Automatically grows arena if needed.
 * Never returns NULL (exits on failure).
 *)
export function arena_alloc(a: pArena, size: size_t): pvoid
begin
	require a <> nil

	var aligned: size_t
	var ptr: pvoid
	var cur: pArenaChunk
	var n: size_t = size

	if a == nil then
		fprintf(stderr, "ERROR: arena_alloc: NULL arena\n")
		exit(1)
	end

	if n == 0 then
		n := 1
	end

	aligned := (n + ARENA_ALIGNMENT - 1u) & ~(ARENA_ALIGNMENT - 1u)
	cur := a^.current

	if cur == nil then
		fprintf(stderr, "ERROR: arena_alloc: arena not initialized\n")
		exit(1)
	end

	if cur^.used + aligned > cur^.size then
		arena_add_chunk(a, aligned)
		cur := a^.current
	end

	ptr := (arena_chunk_data(cur) + cur^.used) as pvoid
	memset(ptr, 0, aligned)					// make sure memory is clean
	cur^.used := cur^.used + aligned

	return ptr
end arena_alloc


(**
 * Reset: keep the first chunk, free any extra chunks, bump from head again.
 * Safe for multi-file compiles in one process.
 *)
export procedure arena_reset(a: pArena)
begin
	var c: pArenaChunk
	var next: pArenaChunk

	if a == nil or a^.head == nil then
		return
	end

	c := a^.head^.next
	while c <> nil do
		next := c^.next
		free(c)
		c := next
	end

	a^.head^.next := nil
	a^.head^.used := 0
	a^.current := a^.head
end arena_reset


(**
 * Free all memory owned the arena.
 * Safe to call multiple times.
 *)
export procedure arena_free(a: pArena)
begin
	var c: pArenaChunk
	var next: pArenaChunk

	if a == nil then
		return
	end

	c := a^.head
	while c <> nil do
		next := c^.next
		free(c)
		c := next
	end

	a^.head := nil
	a^.current := nil
end arena_free


(**
 * arena_ensure_capacity - grow pointer array if needed (doubling strategy)
 *)
export procedure arena_ensure_capacity(arena: ^Arena, array_ptr: ppvoid,
										count: ^size_t, capacity: ^size_t)
begin
	var new_capacity: size_t
	var new_array: ppvoid

	if count^ < capacity^ then
		return; 		// already enough room
	end

	new_capacity := capacity^ ? capacity^ * 2u : 8u;

	// Safety: prevent overflow in size calculation
	// Only perform overflow check when we are doubling an existing capacity.
	// The initial case (*capacity == 0) is allowed and sets new capacity = 8.
	if capacity^ > 0 and new_capacity / 2u != capacity^ then
		fprintf(stderr, "ERROR: arena_ensure_capacity: capacity overflow\n");
		exit(1);
	end

	new_array := arena_alloc(arena, new_capacity * sizeof(pvoid)) as ppvoid

	if array_ptr^ != nil then
		memcpy(new_array, array_ptr^, count^ * sizeof(pvoid));
	end

	array_ptr^ := new_array;
	capacity^  := new_capacity;
end arena_ensure_capacity



(**
 * arena_append_ptr - Append one pointer to a dynamic array of pointers.
 * Grows the array using doubling strategy (min 8) if needed.
 * Never returns NULL - exits on fatal error.
 *
 * @param arena 	Initialized arena
 * @param array_ptr	Pointer to the array base pointer (Node**, TType**, etc.)
 * @param count 	Current element count (will be incremented)
 * @param capacity 	Current allocated slots (will be updated if grown)
 * @param item 		Pointer to value to append
 *)
export procedure arena_append_ptr(arena: ^Arena, array_ptr: ppvoid,
					  count: ^size_t, capacity: ^size_t, item: pvoid)
begin
	arena_ensure_capacity(arena, array_ptr, count, capacity);

	let p: ppvoid = array_ptr^ as ppvoid
	p[count^] := item
	count^ := count^ + 1
end arena_append_ptr

	
begin
	// Hack: Mod-C cannot handle the ((void**)( *array_ptr))... on the left hand side of an assignment.
	// #define ARRAY_PTR ((void **)( *array_ptr))
	// ARRAY_PTR[count^] := item;
	// count^ := count^ + 1
	// 
	// the resulting Mod-C code above, also works.
end arena
