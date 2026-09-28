program Shapes()

(**
 * Tiny tagged scene — EXTENDS, auto-deref, methods, DbC, defer.
 * Kind is a programmer tag (no RTTI / no IS).
 *)

import printf from "stdio.h"
import malloc, free from "stdlib.h"


type Kind = enum
	KindCircle,
	KindRect
end

type Color = enum
	Red,
	Green,
	Blue
end

type Point = struct
	x: integer
	y: integer
end

type Shape = struct
	kind: Kind
	color: Color
	origin: Point
	next: ^Shape
end

type Circle = struct extends Shape
	radius: integer
end

type Rect = struct extends Shape
	w: integer
	h: integer
end


function Point::new(x: integer, y: integer): Point
begin
	var p: Point
	p.x := x
	p.y := y
	return p
end Point::new


procedure Point::print(self: Point)
begin
	printf("(%d, %d)", self.x, self.y)
end Point::print


function color_name(c: Color): const ^char
begin
	switch c of
		case Red:	return "red"
		case Green:	return "green"
		case Blue:	return "blue"
		else:		return "?"
	end
end color_name


procedure describe(s: Shape)
begin
	printf("  origin=")
	s.origin.print()
	printf(" color=%s\n", color_name(s.color))
end describe


function area(p: ^Shape): integer
begin
	require p <> nil
	switch p.kind of
		case KindCircle:
			begin
				let c = p as ^Circle
				return 3 * c.radius * c.radius
			end
		case KindRect:
			begin
				let r = p as ^Rect
				return r.w * r.h
			end
		else:
			return 0
	end
end area


procedure print_item(p: ^Shape)
begin
	require p <> nil
	switch p.kind of
		case KindCircle:
			begin
				let c = p as ^Circle
				printf("circle r=%d area=%d\n", c.radius, area(p))
			end
		case KindRect:
			begin
				let r = p as ^Rect
				printf("rect %d x %d area=%d\n", r.w, r.h, area(p))
			end
		else:
			printf("unknown shape\n")
	end
	describe(p^)
end print_item


procedure print_list(head: ^Shape)
begin
	var p: ^Shape = head
	while p <> nil do
		print_item(p)
		p := p.next
	end
end print_list


recursive procedure free_list(p: ^Shape)
begin
	if p == nil then
		return
	end
	free_list(p.next)
	free(p)
end free_list


begin
	var head: ^Shape = nil
	var c: ^Circle = malloc(sizeof(Circle))
	var r: ^Rect = malloc(sizeof(Rect))

	assert c <> nil
	c.kind := KindCircle
	c.color := Red
	c.origin := Point::new(10, 20)
	c.radius := 5
	c.next := nil

	assert r <> nil
	r.kind := KindRect
	r.color := Blue
	r.origin := Point::new(0, 0)
	r.w := 4
	r.h := 7
	r.next := nil

	(* ^Circle / ^Rect where ^Shape is required — pointer upcast *)
	c.next := r
	head := c
	defer free_list(head)

	printf("scene:\n")
	print_list(head)
end Shapes

(* gk/gk *)
