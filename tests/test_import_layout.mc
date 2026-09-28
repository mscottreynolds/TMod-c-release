program test_import_layout()

import
	printf,
	fprintf,
	stderr
from "stdio.h"

var
	x, 
	y: integer

begin
	printf("x = %ld, y = %ld\n", x, y)
	fprintf(stderr, "Just checking :)\n")
end
