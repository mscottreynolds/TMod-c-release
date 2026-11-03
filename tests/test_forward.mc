program test_forward()

import printf from "stdio.h"


procedure ProcB()
begin
	ProcA()
	printf("ProcB() \n")
end

procedure ProcA()
begin
	printf("ProcA()\n")
end

procedure ProcD() forward

procedure ProcC()
begin
	ProcD()
	printf("ProcC()\n")
end

procedure ProcD()
begin
	printf("ProcD()\n")
end

begin
	ProcB()
	ProcC()
end
