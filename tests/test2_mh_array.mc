program test2_mh_array()

import printf from "stdio.h"
import Node, take_open, take_fixed, take_ptr_array, Buf, Row from "test_mh_array.mh"

var r: Row

begin
	assert countof(r.cells) == 4
	printf("test2_mh_array ok\n")
end