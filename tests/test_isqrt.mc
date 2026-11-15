program test_isqrt()

(** Integer square root. *)

import printf from "stdio.h"

function isqrt(i: cardinal): cardinal
begin
	var res: cardinal = 0
	var bit: cardinal = 1u << 30
	var n: cardinal = i

	while bit > n do
		bit >>= 2
	end

	while bit do
		if n >= res + bit then
			n -= res + bit
			res := (res >> 1) + bit
		else
			res >>= 1
		end
		bit >>= 2
	end
	return res
end isqrt


begin
	var n: cardinal = 25

	for n := 1 to 42 do
		var r: cardinal = n * n
		var s: cardinal = isqrt(r)
		printf("isqrt(%u) = %u\n", r, s)
		assert s == n
	end
end test_isqrt
