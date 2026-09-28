program Test2_Extends()

import printf from "stdio.h"

type Parent = struct 
	name: array[20] of char
end 

type Child = struct extends Parent
	age: int
end

begin
	var p: Parent
	var c: Child 

	printf("Compiles. Age=%d\n", c.age);
end
