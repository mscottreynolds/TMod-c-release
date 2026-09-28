program test_mtype()

import printf from "stdio.h"

type TFunction = FUNCTION (a: int): int
type TProcedure = PROCEDURE (b: int)

procedure printInt(n: int)
begin
	printf("printInt: %d\n", n);
end

function displayInt(n: int): int
begin
	printf("DisplayInt: %d\n", n)
	return n
end

begin
	var f: TFunction = displayInt
	var p: TProcedure = printInt

	// TODO: FIX: p(3)

	// printf("{ n=%d }\n", f(3));

	printf("Testing TFunction and TProcedure succeeded.\n")
end
