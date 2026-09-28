program test_structs()

import printf from "stdio.h"


type TIntInt = struct
	x: int
	y: int
end


var n: integer

type TStruct = struct
	z: int
end

begin
	var s1: TIntInt
	var s2: TStruct

	s1.x := 1
	s1.y := 2
	printf(".x=%d, .y=%d\n", s1.x, s1.y)

	s2.z := 3
	printf(".z=%d\n", s2.z)
end
