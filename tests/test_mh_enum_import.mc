program test_mh_enum_import()

import printf from "stdio.h"
import Color, Green from "fixtures/colors.mh"

begin
	var c: Color = Green
	if c == Green then
		printf("ok\n")
	else
		printf("not ok\n")
	end
end
