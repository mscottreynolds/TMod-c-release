module tmodc.lib.IO(): TIO

(*
 * Test of a simple wrapper around stdio.
 *)

import FILE, vfprintf, stdin, stdout, stderr, snprintf,
	from "stdio.h"
import va_list, va_copy, va_end, va_start, va_arg 
    from "stdarg.h"


export type TIO = struct
	stdin: ^FILE
	stdout: ^FILE
	stderr: ^FILE
end


export function TIO::TIO(stdin: ^FILE, stdout: ^FILE, stderr: ^FILE): TIO
begin
	var io: TIO
	io.stdin := stdin
	io.stdout := stdout
	io.stderr := stderr

	return io
end TIO::TIO


export procedure TIO::print(ref self: TIO, fmt: const ^char, ...)
begin
    var ap: va_list

	va_start(ap, fmt)
	vfprintf(self.stdout, fmt, ap)
	va_end(ap)
end TIO::printf


export procedure TIO::fprint(ref self: TIO, out: ^FILE, fmt: const ^char, ...)
begin
	require @self <> nil

    var ap: va_list

	va_start(ap, fmt)
	vfprintf(out, fmt, ap)
	va_end(ap)
end TIO::fprintf


export procedure TIO::error(ref self: TIO, fmt: const ^char, ...)
begin
    var ap: va_list

	va_start(ap, fmt)
	vfprintf(self.stderr, fmt, ap)
	va_end(ap)
end TIO::errorf


export function TIO::write_str(ref self: TIO, str: string): integer
begin
	return fprintf(self.stdout, "%s", str)
end

export function TIO::write_char(ref self: TIO, ch: char): integer
begin
	return fprintf(self.stdout, "%c", ch)
end

export function TIO::write_integer(ref self: TIO, i: integer): integer
begin
	return fprintf(self.stdout, "%d", i)
end

export function TIO::write_carddinal(ref self: TIO, u: cardinal): integer
begin
	return fprintf(self.stdout, "%u", u)
end

export function TIO::write_real(ref self: TIO, r: real): integer
begin
	return fprintf(self.stdout, "%g", r)
end

export function TIO::write_bool(ref self: TIO, b: bool): integer
begin
	return fprintf(self.stdout, "%s", (b ? "true" : "false"))
end


export function TIO::write_string(var dest: char[], str: char[]): integer
begin
	return snprintf(dest, countof(dest), "%.*s", countof(str), str)
end
	

begin
	return TIO(stdin, stdout, stderr)
end IO
