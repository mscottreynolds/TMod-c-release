program test_debug()
(* Test the debug statement. Any statement after the debug will be generated in code if a debug flag is set
 * otherwise the code will be left out. 
 * debug flag is set via external means, like a command line parameter. 
 *)

import printf from "stdio.h"

begin
//	defer printf("last of all...\n");
	printf("1 Before debug statement.\n")
	printf("2 Before debug statement.\n")
	printf("3 Before debug statement.\n")
	DEBUG printf("This is a debug statement.\n")
	printf("1 After debug statement.\n")
	printf("2 After debug statement.\n")
	printf("3 After debug statement.\n")
end test_debug
