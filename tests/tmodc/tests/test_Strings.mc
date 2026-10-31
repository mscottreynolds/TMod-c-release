program tmodc.tests.test_Strings()

import String, String::new, String::length, String::value
	from tmodc.lib.Strings
import TIO, TIO::WriteF, TIO::WriteLn
	from tmodc.lib.IO

begin
	var s: String = Strings("Hello tmodc.lib.Strings.\n", 13)
	var io: TIO = IO()

	io.WriteLn("With tmodc.lib.IO")
	io.WriteF("%s", s.value())

	s := String::new("Good bye.")
	io.WriteF("%s\n,", s.value)
end test_Strings

