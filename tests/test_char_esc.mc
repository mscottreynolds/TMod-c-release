program test_char_esc()

import printf from "stdio.h"

begin
	let esc: char = '\x1b'
	let nl: char = '\n'
	let a: char = 'a'

	printf("esc=%d nl=%d a=%d\n", esc as integer, nl as integer, a as integer)
	assert (esc as integer) == 27
	assert (nl as integer) == 10
	assert a == 'a'
end
