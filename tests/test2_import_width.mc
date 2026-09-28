program test2_import_width()

import TWPoint, take32, from test2_export_width

var p: TWPoint

begin
	p.x := 1
	p.y := 2
	take32(p.x)
end