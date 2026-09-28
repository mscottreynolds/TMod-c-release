program test_import_alias()

import I32 from "fixtures/i32alias.mh"

begin
	var x: I32 = 1
	assert sizeof(x) == 4
end
