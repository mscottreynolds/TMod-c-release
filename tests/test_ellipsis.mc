program test_ellipsis()

import printf, vprintf from "stdio.h"
import va_list, va_start, va_end from "stdarg.h"


export procedure log_msg(fmt: string, ...)
begin
	var ap: va_list

	va_start(ap, fmt)
	vprintf(fmt, ap)
	va_end(ap)
end


begin
	var n: integer = 7

	log_msg("hello\n")
	log_msg("hello extra %d, %s\n", n, "x")
	printf("n=%d\n", n)
	printf("test_ellipsis ok\n")
end
	