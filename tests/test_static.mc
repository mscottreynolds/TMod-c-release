program test_static()

import printf from "stdio.h"

var w: char = '2';

static var x: int = 3


function foo(): int
begin
	static var z: int = 1
	inc(z)
	return z
end

begin
	static var y: int = 4
	var i: int

	printf("x = %d, y = %d\n", x, y)

	for i := 1 to 10 do
		var n: int = 3
		if i mod 2 == 0 then
			continue
		elsif i mod n <> 0 then
			printf("i = %d, z = %d, n = %d\n", i, foo(), n)
		elsif i mod 8 == 0 then
			break
		end
	end
end