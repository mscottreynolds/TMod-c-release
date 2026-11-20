program test_import_star2()

import * from fixtures.starpack
import Point, answer, Point::getX from fixtures.starpack

begin
	var p: Point

	p.x := 3
	p.y := 4
	assert fixtures.starpack.answer() == 42
	assert answer() == 42
	assert fixtures.starpack.Point::getX(p) == 3
	assert Point::getX(p) == 3
	assert p.getX() == 3
	assert fixtures.starpack() == 7
	assert starpack() == 7
	assert sizeof(fixtures.starpack.Point) == sizeof(p)
	assert sizeof(Point) == sizeof(p)
end

