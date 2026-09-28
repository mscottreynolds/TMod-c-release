program test2_Preprocessor()

import printf from "stdio.h"

#define HELLO "hello world"

extern var HELLO: ^char

begin
	printf("%s\n", HELLO)
end
