program test_extern_struct()

import printf from "stdio.h"
import from "fixtures/ctag.h"

extern type bar = struct
extern type Foo = struct bar

begin
	var b: bar = {0}
	var f: Foo = {0}

	b.x := 1
	f.x := 2
	printf("b.x=%d f.x=%d\n", b.x, f.x)
	assert b.x == 1 and f.x == 2
end
