program test2_ast(argc: int, argv: ^char[])

import printf from "stdio.h"

// import Math, Utils
// import Math as M, Utils from "lib/core.mc"

type pchar = ^char
type array_of_pchar = pchar[]
// type real = double
// type integer = long

var x: int, y: int

var a: int,			\
	b = 1,			\
	c: int = 3

const pi = 31415

begin
	var base: real = 3.0
	let exponent: integer = 2
	// var n: real = pow(base, exponent)
	var n: real = exponent ** base
	var i: integer = n

	var d: double

	x := 2; y := 3
	assert x == 2, "X <> 2!"
	printf("x = %d\n", x)

	ASSERT x + 3 * 4 == 2 + 3 * 4


	printf("%d\n", pi)

	// d := base ** exponent
	printf("base ** exponent = %f\n", n)
	printf("i=%ld\n", i)
	return 0
end
