program test2_opaque_import()

import printf from "stdio.h"
import Box, show, id from "fixtures/opqview.mh"

begin
	var b: Box
	var p: ^opaque = nil
	b.p := nil
	p := id(p)
	show(p)
	if b.p == nil and p == nil then
		printf("test2_opaque_import OK\n")
	end
end

