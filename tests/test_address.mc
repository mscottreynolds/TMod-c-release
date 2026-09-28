program test_address()

import printf from "stdio.h"

type pInt = ^int

begin
	var n: int = 3
	// var o: int = 4
	var p: pInt

	p := @n

	printf("p^ = %d\n", p^)

	printf("2 * 2 = %d\n", 2 * 2)
//	printf("n & o = %d\n", n & o)

	p^ := 5
	let q = p^
	printf("p^ = %d\n", p^)
	printf("q = %d\n", q)
end
