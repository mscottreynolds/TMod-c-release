program test_proc_order()

import printf from "stdio.h"

procedure Use()
begin
	var b: Box = Make()
	printf("%d\n", b.n)
end

type Box = struct
	n: integer
end

function Make(): Box
begin
	var b: Box = {7}
	return b
end

procedure Pong(n: integer)
begin
	if n > 0 then
		Ping(n - 1)
	end
end

procedure Ping(n: integer)
begin
	if n > 0 then
		Pong(n - 1)
	end
	printf("ping\n")
end

begin
	Use()
	Ping(1)
end test_proc_order

