program tmodc.tests.test_String()

import TString, TString::new, TString::length, TString::value
	from tmodc.lib.String
import printf
	from "stdio.h"

begin
	var s: TString = String("Hello tmodc.lib.String.\n", 13)

	printf("%s", s.value())

	s := TString::new("Good bye.")
	printf("%s\n,", s.value)
end test_String

