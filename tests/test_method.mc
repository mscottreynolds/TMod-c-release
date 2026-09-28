program test_method()

import printf from "stdio.h"

type Counter = struct
	value: integer
end

function Counter::get(self: Counter): integer
begin
	return self.value
end

procedure Counter::put(self: Counter, n: integer) begin 
	self.value := n; 
end

procedure writeln(s: string)
begin
	printf("%s\n", s as ^char)
end

begin
	var c: Counter
	c.value := 42
	printf("test_method: n=%ld\n", Counter::get(c))
end test_method
