program test_ptr_index()

import printf from "stdio.h"

type Cell = struct
	n: integer
end

type pCell = ^Cell


procedure Cell::bump(ref c: Cell)
begin
	inc(c.n)
end Cell::bump


function Cell::get(self: Cell): integer
begin
	return self.n
end Cell::get


begin
	var cells: array[3] of Cell
	var p: pCell
	var q: ^Cell

	cells[0].n := 10
	cells[1].n := 20
	cells[2].n := 30

	p := @cells[0]
	q := @cells[0]

	p[1].n := 21
	assert p[1].n == 21
	assert cells[1].n == 21

	p[1].bump()
	assert p[1].n == 22
	assert p[1].get() == 22

	Cell::bump(p[2])
	assert p[2].n == 31

	q[0].bump()
	assert q[0].n == 11

	(@p[1]).bump()
	assert p[1].n == 23

	printf("test_ptr_index ok\n")
end test_ptr_index


(* gk/msr *)
