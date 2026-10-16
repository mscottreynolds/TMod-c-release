program test_define()

import printf from "stdio.h"

#define INIT = 0

define CTRL_KEY(k) = ((k) & 0x1f)
define ANSWER=42
define SUM = 1 + \
 2
export define PUBLIC_FLAG = 1
define CAT(a, b)  =  a##b
define FIRST(a, ...) =    (a)
define MARK = 
define ID(x) =(x MARK)
define APPLY(x)=((x) INIT)


begin
	var c: integer
	var n: integer

	assert ANSWER == 42
	assert SUM == 3
	assert PUBLIC_FLAG == 1
	assert CAT(4, 2) == 42
	assert FIRST(7, 8, 9) == 7
	assert ID(6) == 6
	
	n := 5
	APPLY(n)
	assert n == 0

	c := CTRL_KEY('q')
	switch c of 
		case CTRL_KEY('q'):
			printf("test_define ok\n")
		else:
			printf("test_define FAIL c=%d\n", c)
	end
end

(* gk/msr *)
