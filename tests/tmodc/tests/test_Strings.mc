program tmodc.tests.test_Strings()

import String, String::new, String::length, String::value
	from tmodc.lib.Strings
import printf
	from "stdio.h"

begin
	var s: String = Strings("Hello tmodc.lib.Strings.\n", 13)

	printf("%s", s.value())

	s := String::new("Good bye.")
	printf("%s\n,", s.value)
end test_Strings

