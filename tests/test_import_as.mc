program test_import_as()

import printf as say, FILE as File from "stdio.h"
import TPoint as Pt from "fixtures/tpoint.mh"
import I32 as Width from "fixtures/i32alias.mh"
import Pair as Point,
	Pair::sum, 
	Pair::sum as total, 
	from "fixtures/asmethod.mh"

begin
	var p: Pt
	var w: Width = 1
	var q: Point
	var fp: ^File = nil

	p.x := 3
	p.y := 4
	q.x := 2
	q.y := 5
	assert p.x == 3
	assert p.y == 4
	assert sizeof(w) == 4
	assert q.sum() == 7
	assert Point::sum(q) == 7
	assert total(q) == 7
	assert fp == nil
	say("test_import_as ok\n")
end
