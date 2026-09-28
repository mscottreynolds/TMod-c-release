program test_rebind()

import printf from "stdio.h"

type integer = long
type cardinal = unsigned int
type real = float
type string = const ^char

begin
	var i: integer = 1
	var c: cardinal = 2
	var r: real = 1.5
	var s: string = "ok"
	printf("%ld %u %g %s\n", i, c, r as double, s)
end
