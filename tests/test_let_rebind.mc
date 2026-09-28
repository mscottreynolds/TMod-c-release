program test_let_rebind()

import printf from "stdio.h"

begin
	let x: int = 1
	printf("x = %d\n", x)

	let x: int = x + 1
	printf("x = %d\n", x)

	begin
		let x: int = x + 2
		printf("x = %d\n", x)
	end
end
