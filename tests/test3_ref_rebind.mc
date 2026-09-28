program test3_ref_rebind()

import printf from "stdio.h"

procedure Bad(REF n: integer)
begin
	n := 1
end

begin
	var x: integer = 0
	printf("x=%d\n", x)
	Bad(x)
	printf("x=%d\n", x)
end
