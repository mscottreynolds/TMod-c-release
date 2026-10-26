module tmodc.lib.IO()

(*
 * Test of a simple IO lib.
 *)

import printf from "stdio.h"

export procedure Write(s: string)
begin
	printf("%s", s)
end

export procedure WriteLn(s: string)
begin
	printf("%s\n", s)
end

begin
end IO
