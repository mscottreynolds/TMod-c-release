program test_external()

import printf from "stdio.h"
import time_t from "time.h"

extern type time_t
type time_t2 = integer
var t: time_t

export extern function time(tloc: ^time_t): time_t

begin

	t := time(nil)
	printf("sizeof(time_t), sizeof(t), sizeof(integer): %d, %d, %d\n", sizeof(time_t), sizeof(t), sizeof(integer))
	printf("t = %d\n", t)
	printf("sizeof(time_t2): %d, sizeof(integer): %d\n", sizeof(time_t2), sizeof(integer))
end


