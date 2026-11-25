module tmodc.lib.Strings()

(**
 * Some string utils. 
 *)


import vsnprintf, va_list, size_t
	from System
import va_start, va_end 
	from "stdarg.h"


(**
 * Write to buffer.
 *)
export procedure write_to(buf: array[] of char, fmt: const ^char, ...)
begin
    var ap: va_list
    var n: integer = countof(buf)

	va_start(ap, fmt)
	vsnprintf(buf, n as size_t, fmt, ap)
	va_end(ap)
end


begin
end Strings
