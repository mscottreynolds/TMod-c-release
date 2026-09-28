program test_import_fn_type()

import printf from "stdio.h"
import TFn, TBox from "fixtures/fnbox.mh"

function twice(n: integer): integer
begin
	return n * 2
end

begin
	var b: TBox

	b.fn := twice
	assert b.fn(21) == 42
	printf("test_import_fn_type ok\n")
end
