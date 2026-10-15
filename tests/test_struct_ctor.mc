program test_struct_ctor()

type Point = struct
	x: integer
	y: integer
end

function Point::Point(x: integer, y: integer): Point
begin
	var p: Point = { x, y }
	return p
end Point::Point

function add(a: integer, b: integer): integer
begin
	return a + b
end add

begin
	var p: Point = Point(3, 4)
	var q: Point = Point::Point(1, 2)

	assert p.x == 3
	assert p.y == 4
	assert q.x == 1
	assert add(1, 2) == 3
end test_struct_ctor

