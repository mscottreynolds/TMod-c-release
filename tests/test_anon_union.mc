program test_anon_union()

import fprintf, stderr from "stdio.h"
import exit from "stdlib.h"

type Arm = struct
	n: integer
end

type Box = struct
	tag: integer
	union
		a: Arm
		b: integer
	end
end

begin
	var box: Box

	box.tag := 1
	box.a.n := 7
	if box.tag <> 1 or box.b <> 7 then
		fprintf(stderr, "FAIL: anon union tag %d b %d\n", box.tag, box.b)
		exit(1)
	end
end

