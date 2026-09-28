program test_bitwise()

import printf from "stdio.h"

begin
	let x = 4 & 5
	let y = 5 | 6
	let z = 7 xor 8
	let a = 3 and 4
	let b = 4 or 5
	let c = not 6
	let d = 6 mod 2
	let e = 6 div 3
	let f = 4 & 5 | 6
	printf("f = %d\n", f)
end
