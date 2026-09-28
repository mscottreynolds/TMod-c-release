program test_cast()

import printf from "stdio.h"

begin
	let x: real = 314
	let i: int = x as int
	var y: int

	// y.n := 3
	// y.z[z(5).n[3].n[4+3]] := 4
	y := cast(int, 3.14)
	// y.n(3+4/23) := 4
	printf("i = %d\n", i)
	printf("y = %d\n", y)
end
