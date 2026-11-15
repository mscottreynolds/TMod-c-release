Program tmodc.tests.test_all()

Import TIO, TIO::print, TIO::fprint, TIO::error,
	from tmodc.lib.IO
Import TString, TString::TString, TString::length, TString::value, TString::len
	from tmodc.lib.String
Import TCardinal, TCardinal::toString
	from tmodc.lib.Cardinal
Import TReal, TReal::toString
	from tmodc.lib.Real
Import TInteger, TInteger::toString
	from tmodc.lib.Integer

Begin
	Var io: TIO = IO()
	Var s: TString = String("Hello tmodc.lib.String.\n")

	io.fprint(io.stdout, "io.fprint(io.stdout): %s", s.value)

	io.print("io.print: %s", s.value())

	s := TString("Good bye.", TString::len("Good bye."))

	io.error("io.error: %s\n", s.value)

	Let i: TInteger = Integer(-42)
	io.print("TInteger: %s\n", i.toString())

	Let u: TCardinal = Cardinal(3)
	io.print("TCardinal: %s\n", u.toString())

	Let r: TReal = Real(3.14)
	io.print("TReal: %s\n", r.toString())

End test_all
