program test2_mixed_params()

import printf from "stdio.h"

type pchar = ^char

procedure Complex(				\
	value: integer, 			\
	VAR count: integer,			\
	REF buffer: pchar, 			\
	CONST data: ^integer		\
)
begin
	count := count + 10
	buffer[0] := 'X'			// allowed through ref

	// value := 999 		-- error
	// buffer := nil		-- error
	// data := nil			-- error
	// data^ := 5			-- error (const)
end Complex

begin
	var n: integer = 5
	var s: char[10] = "test"
	var p: ^integer = @n

	Complex(n, @n, @s, p)

	printf("After compilex call: n=%d, s[0]='%c'\n", n, s[0])
	printf("Mixed parameter test passed.\n")
end test_mixed_params
