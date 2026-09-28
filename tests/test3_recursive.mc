program test3_recursive()

(* Direct self-call without RECURSIVE must fail *)

import printf from "stdio.h"

function fact(n: integer): integer
begin
	if n <= 1 then
		return 1
	else
		return n * fact(n - 1)
	end
end

begin
	printf("fact(5) = %d\n", fact(5))
end
