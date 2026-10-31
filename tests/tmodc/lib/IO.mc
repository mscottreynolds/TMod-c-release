module tmodc.lib.IO(): TIO

(*
 * Test of a simple IO lib.
 *)

import FILE, printf, vfprintf, fprintf, stdin, stdout, stderr, 
	from "stdio.h"
import va_list, va_copy, vsnprintf, va_end, va_start, va_arg 
    from "stdarg.h"


export type TIO = struct
	stdin: ^FILE
	stdout: ^FILE
	stderr: ^FILE
end


export procedure TIO::WriteF(ref self: TIO, fmt: const ^char, ...)
begin
    var ap: va_list

	va_start(ap, fmt)
	vfprintf(self.stdout, fmt, ap)
	va_end(ap)
end TIO::WriteF


export procedure TIO::Write(ref self: TIO, s: string)
begin
	fprintf(self.stdout, "%s", s)
end TIO::Write


export procedure TIO::WriteLn(ref self: TIO, s: string)
begin
	fprintf(self.stdout, "%s\n", s)
end TIO::WriteLn


begin
	var tio: TIO
	tio.stdin := stdin
	tio.stdout := stdout
	tio.stderr := stderr
	return tio
end IO
