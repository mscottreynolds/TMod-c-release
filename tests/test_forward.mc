program test_forward()

import printf from "stdio.h"

procedure ProcA() forward

procedure ProcB()
begin
	ProcA()
	printf("ProcB() \n")
end

procedure ProcA()
begin
	printf("ProcA()\n")
end

begin
	ProcB()
end
