program test_dbc(): integer

import printf from "stdio.h"

(* Test DbC: Design By Contract statements *)

var n: bool = true
var i: integer = 0

begin
	// REQUIRE must be before statemnt-sequence, if any
	REQUIRE(n == true)

	printf("After REQUIRE\n");

	printf("Inside statement sequence.\n")
	n := false

	printf("Testing while loop...")
	i := 0
	while i < 10 do
		INVARIANT (i >= 0)

		printf("After INVARIANT\n");
		inc(i)
	end

	printf("Testing for loop...\n");
	for i := 0 to 1 do
		invariant i >= 0

		printf("for loop\n");
	end

	printf("Testing repeat until loop\n");
	i := 0
	repeat
		invariant i >= 0

		printf("repeat loop\n")
		inc(i)
	until i > 1

	// Do a defer and early return test
	// i := 3 		// test an early return.	
	defer printf("Defer executing.\n");
	if i > 2 then
		printf("Why is i > 2? It shouldn't be!\n")
		n := false		// trigger the ENSURE
		return 0
	end

	printf("Testing loop\n")
	i := 0
	loop
		invariant i >= 0
		
		inc(i)
		if i > 1 then
			break
		end
	end

	printf("ENSURE coming up...\n")

	// ENSURE must be after statement-sequence, and optionally after RETURN, closer to END
	return 0

	ensure n == false
end
