program test_countof_import()

import Quad, Alias, Grid from "fixtures/arralias.mh"
import * from fixtures.arralias

begin
	var a: Alias
	var q: Quad
	var g: Grid
	var b: array[countof(Alias)] of integer

	assert countof(Quad) == 4
	assert countof(Alias) == 4
	assert countof(a) == 4
	assert countof(q) == 4
	assert countof(Grid) == 2
	assert countof(g) == 2
	assert countof(g[0]) == 3
	assert countof(b) == 4
	assert countof(fixtures.arralias.Quad) == 4
	assert countof(fixtures.arralias.Alias) == 4
	assert countof(fixtures.arralias.Grid) == 2
end
