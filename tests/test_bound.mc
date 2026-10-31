program test_bound()

import printf from "stdio.h"

const LIM = 4

begin
	var i: integer = 0
	var n: integer = 0

	while i < 3 do
		bound LIM
		invariant i >= 0

		i := i + 1
	end

	n := 0
	repeat
		bound 3
		 n := n + 1
	until n >= 3

	loop 
		bound 0
		break
	end

	i := 0
	loop
		bound 2 + 2
		i := i + 1
		if i >= 2 then
			break
		end
	end

	printf("test_bound ok\n")
end
