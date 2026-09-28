program test_loop()

import printf from "stdio.h"

var i: int

begin
	i := 0
	loop
		inc(i)
		printf("i = %d\n", i)
		if i > 10 then
			printf("breaking\n")
			break
			// printf("not reachable\n")
		else
			printf("continue\n")
			continue
			// printf("not reachable\n")
		end
		printf("not reachable\n")
	end
end
