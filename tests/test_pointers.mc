program test_pointers(argc: int, argv: ^pchar)

import printf from "stdio.h"

export type pchar = ^char

export type ppchar = ^pchar

type pppchar = ^ppchar

// doesn't work
// type pppchar = ^^pchar

export function double_pointer(): ^char
begin
	return nil
end

begin
	printf("Types pass: argc=%d\n", argc)
	if argc > 0 then
		printf("argv[0] = %s\n", argv[0])
	end
end

