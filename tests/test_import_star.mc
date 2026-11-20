program test_import_star()

import * from fixtures.starpack
import answer from fixtures.starpack

begin
	var p: fixtures.starpack.Point

	p.x := 3
	p.y := 4
	assert fixtures.starpack.answer() == 42
	assert answer() == 42
	assert fixtures.starpack.Point::getX(p) == 3
	assert fixtures.starpack() == 7
	assert sizeof(fixtures.starpack.Point) == sizeof(p)
end

