program test_smoke()

import printf from "stdio.h"

type Counter = struct
	value: integer
end


function Counter::get(self: Counter): integer
begin
	return self.value
end Counter::get


type Point = struct
	x: integer
	y: integer
end


(**
 * Constructor function.
 * 	var newPoint: Point = Point::point(1, 2)
 * @param x: x value for new point
 * @param y: new y value for new point
 * @returns newly constructed point
 *)

function Point::new(x: integer, y: integer): Point
begin
	var p: Point
	p.x := x
	p.y := y
	return p
end


function Point::getX(self: Point): integer
begin
	return self.x
end Point::getX


function Point::getY(self: Point): integer
begin
	return self.y
end Point::getY


function Point::didIGetCalled(self: Point): integer
begin
	printf("Yes, I got called\n")
	return self.x
end Point::didIGetCalled


function Point::add(self: Point, n: Point): Point
begin
	var result: Point = self
	result.x += n.x
	result.y += n.y
	return result
end Point::add


procedure Point::print(self: Point)
begin
	printf("x, y = (%d, %d)\n", self.getX(), self.getY())
end Point::print


procedure Point::scale(ref self: Point, factor: integer)
begin
	self.x *= factor
	self.y *= factor
end

type Box = struct
	p1: Point
	p2: Point
end


function Box::topLeft(self: Box): Point
begin
	return self.p1
end Box::topLeft


function Box::bottomRight(self: Box): Point
begin
	return self.p2
end Box::bottomRight


procedure Box::print(self: Box)
begin
	printf("x1, y1 = (%d, %d)\n", self.p1.getX(), self.p1.getY())
	printf("x2, y2 = (%d, %d)\n", self.p2.getX(), self.p2.getY())
end Box::print


begin
	var c: Counter
	var p: Point = {1, 2}
	var b: Box = { {1, 2}, {3, 4}}
	var point: Point
	var pp: ^Point = @p

	c.value := 42
	printf("%d\n", c.get())
	printf("%d\n", Counter::get(c))
	printf("p.x = %d p.y = %d\n", p.getX(), p.getY())
	Point::print(p)
	p.print()
	(p.didIGetCalled())
	let q: Point = { 3, 4}
	let r: Point = p.add(q)
	printf("Added result: ")
	r.print()

	Box::print(b)
	b.print()
	Point::print(b.topLeft())
	Point::print(b.bottomRight())
	(p.getX())
	b.topLeft().print()
	b.bottomRight().print()

	// Constructor like tests.
	point := Point::new(7, 8)
	printf("point = ")
	point.print()
	Point::print(point)

	printf("pp.x = %d pp.y=%d\n", pp.getX(), pp.getY())
	pp.print()
	(pp.didIGetCalled())
	Point::print(pp^)
	pp.scale(2)
	printf("pp.x = %d pp.y=%d\n", pp.getX(), pp.getY())
	Point::print(pp^)
	Point::print(pp)
	Point::scale(pp, 3)
	printf("pp.x = %d pp.y=%d\n", Point::getX(pp), Point::getY(pp))

end smoke
