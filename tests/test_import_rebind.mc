program test_import_rebind()

import integer, cardinal, real, string from "fixtures/lp64.mh"

begin
	var i: integer = 1
	var c: cardinal = 2
	var r: real = 1.5
	var s: string = "OK"

	assert sizeof(i) == 8
	assert sizeof(c) == 8
	assert sizeof(r) == 8
	assert sizeof(integer) == 8
	assert sizeof(s) == sizeof(string)
end
