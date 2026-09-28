program test_repeat_until(): int

import printf from "stdio.h"

var i: int

begin
	i := 0
	repeat
		printf("i = %d\n", i)
		i := i + 1
	until i >= 10
	printf("Done.\n");
	return 0
end
