program test_float()

import printf from "stdio.h"

// type real = double

begin
	var f: float = 3.14f
	var d: double = 2.71828
	var sum: real = f as real + d

	printf("float  = %f\n", f)
	printf("double = %f\n", d)
	printf("sum    = %f\n", sum)

	inc(f)
	printf("f after INC = %f\n", f)
end
