program test3_const_param()

import printf from "stdio.h"

procedure Bad(CONST n: integer)
begin
	n := 1
end


begin
	Bad(0)
end 
