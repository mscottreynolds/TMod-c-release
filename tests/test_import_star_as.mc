program test_import_star_as()

import * as st from fixtures.starpack

begin
	var p: st.Point

	p.x := 3
	p.y := 4
	assert st.answer() == 42
	assert st.Point::getX(p) == 3
	assert st() == 7
	assert sizeof(st.Point) == sizeof(p)
end
