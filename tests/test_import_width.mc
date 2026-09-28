program test_import_width()

import TWPoint from "fixtures/wpoint.mh"

begin
	var p: TWPoint
	p.x := 3
	p.y := 4
	assert p.x == 3
	assert sizeof(p.x) == 4
	assert sizeof(p) == 8
end
