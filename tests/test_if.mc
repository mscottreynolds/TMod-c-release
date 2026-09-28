program test_if()

import printf from "stdio.h"
import rand, srand from "stdlib.h"
import time_t, time from "time.h"

const MAX_RANDOM = 1000

begin
	var x: int
	var y: int
	var t: time_t

	t := time(nil)
	printf("Unix timestamp: %ld\n", t)

	srand(t)
	x := rand()

	printf("rand()=%d\n", x)

	y := x mod 2 == 0 ? 1 : 0

	printf("y=%d\n", y)

	if y == 1 then printf("y=one\n"); end
end
