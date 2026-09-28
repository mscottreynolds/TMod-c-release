program test_const_param()

import printf from "stdio.h"

procedure ReadOnly(CONST buf: ^char, CONST buf_len: int)
begin
	printf("Length = %d, first char = '%c'\n", buf_len, buf[0])
	(* buf[0] := 'X' 	-- should be compile error or warning *)
	(* buf_len := 99 		-- should be compile error *)
end ReadOnly

begin
	var msg: char[32] = "Hello Mod-C"

	// ReadOnly(REF msg, 11)
	ReadOnly(msg, 11)
	printf("CONST parameter test passed.\n")
end test_const_param
