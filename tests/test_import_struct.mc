program test_import_struct()

import printf from "stdio.h"
import TPoint from "fixtures/tpoint.mh"

begin
	var p: TPoint

	p.x := 3
	p.y := 4
	assert p.x == 3
	assert p.y == 4
	printf("test_import_struct ok\n")
end
