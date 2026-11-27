program test_bare_param()

(* A bare formal is a local copy. Assigning it does not change the caller. *)

type Point = struct
	x: integer
	y: integer
end

function step(n: integer): integer
begin
	n := n + 1
	inc(n)
	return n
end

function replace(p: Point): integer
begin
	var q: Point

	q.x := 9
	q.y := 8
	p := q
	return p.x
end

begin
	var n: integer = 10
	var p: Point

	p.x := 1
	p.y := 2
	assert step(n) == 12
	assert n == 10
	assert replace(p) == 9
	assert p.x == 1
	assert p.y == 2
end
