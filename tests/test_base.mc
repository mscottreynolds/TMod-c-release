program test_base()

import printf from "stdio.h"

begin
	var O: int
	var B: int
	var X: int

	O := 0o7777
	B := 0b1111_1111
	X := 0xFF_FF

	printf("O: %d, B: %d, X: %d\n", O, B, X)
end
