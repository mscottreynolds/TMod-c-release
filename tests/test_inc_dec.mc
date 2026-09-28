program test_inc_dec()

import printf from "stdio.h"

begin
	var i: int = 0
	var x: int = 0
	var y: int = 0
	var z: int = 0
	var a: int[5]

	INC(x)
	printf("x: %d\n", x)

	y := INC(z, 5) * 2
	printf("y: %d, z: %d\n", y, z)

	INC(a[i])
	printf("a[i]: %d\n", a[i])


	inc(i)
	printf("i: %d\n", i);
	dec(i, 5)
	printf("i: = %d\n", i);
end
