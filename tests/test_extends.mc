program test_extends()

import printf from "stdio.h"


type Parent = struct
	base: int
	x: integer
end

type Child = struct extends Parent
	y: integer
end

type Grand = struct extends Child
	z: integer
end


procedure Parent::show(self: const Parent)
begin
	printf("show self.x=%d self.base=%d\n", self.x, self.base)
end Parent::show


procedure Parent::bump(ref self: const Parent, n: integer)
begin
	self.x += n
end Parent::bump


function Child::ownY(self: Child): integer
begin
	return self.y
end Child::ownY


function returnParent(g1: Grand): Parent
begin
	var c1 = g1.base.base
	return c1
	// return g1 		// auto-upcast Grand => Parent
end


function returnParentX(g1: Grand): Parent
begin
	return g1
end


function toChild(g1: Grand): Child
begin
	return g1
end


procedure takeParentPtr(p: const ^Parent)
begin
	printf("ptr p^.x=%d\n", p^.x)
	printf("ptr p^.base=%d\n", p^.base)
	printf("ptr p.x=%d\n", p.x)
	printf("ptr p.base=%d\n", p.base)
end


procedure takeParentRef(ref r: Parent)
begin
	printf("ref r.x=%d\n", r.x)
	printf("ref r.base=%d\n", r.base)
end


begin
	var c: Child
	var g: Grand

	var base: cardinal = 99
	printf("========= BEGIN ==========\n")
	printf("%u\n", base)

	c.x := 1; 	printf("(* c.x := 1 *)\n")
	c.y := 2;	printf("(* c.y := 2 *)\n")
	printf("c.x=%d c.y=%d\n", c.x, c.y)

	c.base.base := 42; 		printf("(* c.base.base := 42 *)\n")
	c.base.x := 3; 			printf("(* c.base.x := 3 *)\n")
	printf("c.base.x=%d c.base.base=%d\n", c.base.x, c.base.base)
	printf("c.x=%d c.y=%d c.base.base=%d\n", c.x, c.y, c.base.base)

	g.base.base.base := 43; 	printf("(* g.base.base.base := 43 *)\n")
	g.x := 10;					printf("(* g.x := 10 *)\n")
	g.y := 20;					printf("(* g.y := 20 *)\n")
	g.z := 30;					printf("(* g.z := 30 *)\n")
	printf("g.x=%d g.y=%d g.z=%d g.base.base.base=%d\n", g.x, g.y, g.z, g.base.base.base)

	let p = g
	let p2 = returnParent(p)
	// let p: Parent = g 			// Grand => Parent
	// let c2 = returnParent(g) 	// call-arg upcast
	printf("p2.base=%d\n", p2.base)

	let p3 = returnParentX(p)
	printf("cp.base=%d p3.x=%d\n", p3.base, p3.x)

	let c4 = toChild(g)
	printf("c4.base.base=%d c4.x=%d c4.y=%d\n", c4.base.base, c4.x, c4.y)

	let c5: ^Child = (@g) as ^Child
	printf("c5.base.base=%d c5.y=%d\n", c5^.base.base, c5^.y)
	printf("c5.x=%d c5^.base.x=%d\n", c5^.x, c5^.base.x)

	let p6 = g as Parent
	let c6 = g as Child
	printf("p6.base=%d p6.x=%d\n", p6.base, p6.x)
	printf("c6.base.base=%d c6.y=%d\n", c6.base.base, c6.y)

	let pg: ^Grand = @g
	let pp: ^Parent = pg
	printf("pp^.x=%d\n", pp^.x)

	takeParentPtr(@g)
	takeParentPtr(c5)
	takeParentRef(g)
	takeParentRef(c)

	let pp2 = (@g) as ^Parent
	printf("pp2^.x=%d\n", pp2^.x)

	printf("c5.x=%d c5.y=%d\n", c5.x, c5.y)
	printf("pp.x=%d\n", pp.x)
	printf("pp.z=%d pg.x=%d\n", pg.z, pg.x)

	c.show()
	g.show()
	printf("c.ownY=%d g.ownY=%d\n", c.ownY(), g.ownY())

	begin
		var pc: ^Child = @c
		pc.show()
		Parent::show(pc)
		pc.bump(5); printf("(* pc.bump(5) *)\n")
		c.show()
		Parent::bump(pc, 1); printf("(* Parent::bump(pc, 1) *)\n")
		c.show()
	end
	printf("=========- END -==========\n")
end

