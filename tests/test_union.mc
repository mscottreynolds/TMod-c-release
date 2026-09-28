program test_union()

import printf from "stdio.h"

type alt = struct
	c: char
	l: long
end

type Value = union
	i: integer
	f: real
	a: alt
end


begin
	var v: Value
	v.i := 42
	printf("i=%d\n", v.i)

	v.f := 1.5
	printf("f=%f\n", v.f)

	printf("sizeof(v)=%zu\n", sizeof(v))
	printf("sizeof(v.i)=%zu\n", sizeof(v.i))
	printf("sizeof(v.f)=%zu\n", sizeof(v.f))

	v.a.l := 65535
	printf("v.a.l=%ld\n", v.a.l)

end test_union
