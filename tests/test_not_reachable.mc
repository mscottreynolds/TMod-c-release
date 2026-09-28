program test_not_reachable()

(* changed not reachable ERROR to WARNING in 0.26.8.195 *)

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
			printf("not reachable, WARNING.\n")
		else
			printf("continue\n")
			continue
			printf("not reachable, WARNING\n")
		end
		printf("Did not reachable waring display?\n")
	end
end
