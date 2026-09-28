program test_let_field()

import printf from "stdio.h"

type Point = struct
	x: integer
end

begin
	var n: integer = 0
	let p: Point = {0}

	p.x := 1
	printf("p.x=%d\n", p.x)
	assert p.x == 1

	let pc: ^integer = @n
	printf("pc^=%d\n", pc^)
	pc^ := 2
	printf("n=%d\n", n)
	assert n == 2
end

