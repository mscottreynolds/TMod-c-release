program test2_opaque_parse()

import printf from "stdio.h"


type T = opaque
type P = ^opaque
type Q = POINTER TO opaque
begin
	var z: Q
	if z == nil then
		printf("test2_opaque_parse OK\n")
	end
end

