program test_for()

import stderr, printf, fprintf from "stdio.h"
import exit from "stdlib.h"

var calls: integer = 0

function limit(): integer
begin
	printf("limit() called\n")
	calls := calls + 1
	return 5
end

var i, j: integer

begin
	var nested: integer = 0

	for i := 1 to limit() do
		printf("i = %d\n", i)
	end

	if calls <> 1 then
		fprintf(stderr, "FAIL: limit() called %d times, expected 1\n", calls)
		exit(1)
	end
	printf("FOR end-once test passed.\n")

	for i := 1 to 2 do for j := 1 to 3 do nested := nested + 1; end end
	printf("nested=%d\n", nested)
	if nested <> 6 then
		fprintf(stderr, "FAIL: nexted one-line FOR count %d, expected 6\n", nested)
		exit(1)
	end
	printf("FOR nested test passed.\n")
end
