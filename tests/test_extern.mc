program test_extern()

import printf from "stdio.h"
import FILE from "stdio.h"
import time_t from "time.h"


extern type FILE
extern type void

export extern function time(tloc: ^time_t): time_t

begin
	printf("test_extern ok\n")
end test_extern
