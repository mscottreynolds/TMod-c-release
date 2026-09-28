program test3_let_addr()

import printf from "stdio.h"


begin
	let n: integer = 0
	let pc: ^integer = @n 			// not legal.

end

