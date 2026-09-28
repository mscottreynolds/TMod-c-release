program test_const()

import printf from "stdio.h"
import strcmp from "string.h"

function string_equals(s1: const ^char, const s2: ^char): bool
begin
    if s1 == nil or s2 == nil then
        return false
    end

    // Use standard library strcmp
    return strcmp(s1, s2) == 0
end string_equals 

begin
	var c1: const ^char = "hello"
	const c2: ^char = "bye"

	if string_equals(c1, c2) then
		printf("c1 == c2\n")
	else
		printf("c1 <> c2\n")
	end
end
