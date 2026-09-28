program test_import_ilp32()

import integer, cardinal, real, string from "fixtures/ilp32.mh"

begin
	var i: integer = 1
	var c: cardinal = 2
	var r: real = 1.5
	var s: string = "OK"

	assert sizeof(i) == 4
	assert sizeof(c) == 4
	assert sizeof(r) == 4
	assert sizeof(integer) == 4
	assert sizeof(s) == sizeof(string)
end
