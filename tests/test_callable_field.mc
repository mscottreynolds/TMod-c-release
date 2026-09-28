program test_callable_field()

import printf from "stdio.h"

type THandler = procedure (n: integer)

type Box = struct
	h: THandler
	n: integer
end

procedure say(n: integer)
begin
	printf("say %d\n", n)
end

function Box::get(self: Box): integer
begin
	return self.n
end

begin
	var b: Box
	var fp: THandler

	b.n := 7
	b.h := say
	b.h(42) 						// Field call-through - no auto-self 
	fp := say
	fp(99)							// local method-type value
	printf("get %d\n", b.get())		// instance method still works
end
