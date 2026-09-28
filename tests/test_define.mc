program test_define()

import printf from "stdio.h"

define CTRL_KEY(k) ((k) & 0x1f)
define ANSWER 42
define SUM 1 + \
	2
export define PUBLIC_FLAG 1

begin
	var c: integer

	assert ANSWER == 42
	assert SUM == 3
	assert PUBLIC_FLAG == 1
	c := CTRL_KEY('q')
	switch c of 
		case CTRL_KEY('q'):
			printf("test_define ok\n")
		else:
			printf("test_define FAIL c=%d\n", c)
	end
end
