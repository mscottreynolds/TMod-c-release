program test_discard()

import printf from "stdio.h"

procedure no_result()
begin
	printf("proc ok\n")
end

function has_result(): integer
begin
	return 7
end

begin
	var x: integer

	// Procedure - bare call OK 
	no_result()

	// untyped c Import - bare call OK (unknown result)
	printf("printf bare ok\n")

	// function - use result
	x := has_result()

	// function - explicit discard
	(has_result())

	printf("x = %d\n", x)
end
