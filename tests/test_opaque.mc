program test_opaque()

import printf from "stdio.h"

type Handle = opaque
type address = ^opaque

begin
	var h: Handle = nil
	var a: address = nil
	if h == nil and a == nil then
		printf("opaque ok\n")
	end
end test_opaque

