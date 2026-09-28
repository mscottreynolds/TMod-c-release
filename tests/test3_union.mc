program test_union()

import printf from "stdio.h"

type Value = union extends X
	i: integer
	f: real
end

begin
	var v: Value
	v.i := 42
	printf("i=%d\n", v.i)

	v.f := 1.5
	printf("f=%f\n", v.f)
	printf("union ok\n")
end test_union
