program test_string()

import printf from "stdio.h"

import TString, TString::cstring, TString::length 
    from "../include/String.mh"
    // from String
import TStringBuffer, pStringBuffer, TStringBuffer::getData, TStringBuffer::getCapacity, 
    TStringBuffer::getLength, TStringBuffer::append, TStringBuffer::appendn, TStringBuffer::append_char,
    TStringBuffer::free, TStringBuffer::init,
    from "../include/StringBuffer.mh"
import TInteger, TInteger::value from "../include/Integer.mh"
import TReal, TReal::value from "../include/Real.mh"
import TCardinal, TCardinal::value from "../include/Cardinal.mh"

begin
    var s: TString = String("Hello world")
    var sb: TStringBuffer = StringBuffer("")
    var i: TInteger
    var u: TCardinal
    var f: TReal

    // var p: pStringBuffer = @sb

    // printf("%s:%zu\n", str.value, str.length)
    // printf("%s:%zu\n", TString::cstring(s), TString::length(s))
    // printf("sb.capacity=%zu\n", sb.capacity)

    assert s.cstring() <> nil
    assert s.length() > 0
    printf("=== TString ===\n")
    printf("s.cstring()=%s\n", s.cstring())
    printf("s.length()=%zu\n", s.length())

    printf("=== TStringBuffer ===\n")
    sb.append(s.cstring())
    sb.append("\n")
    sb.append("Hello again!\n")
    // TStringBuffer::append(sb, s.cstring())
    printf("sb.getLength()=%zu\n", sb.getLength())
    printf("sb.getCapacity()=%zu\n", sb.getCapacity())
    printf("sb.getData()=%s\n", sb.getData())
    // printf("p.getData()=%s\n", p.getData())          // TODO: Make this work (instance method on pointers)
    // assert sb.data <> nil
    // assert sb.free <> nil
    sb.free()
    printf("after free, sb.getCapacity()=%zu\n", sb.getCapacity())
    TStringBuffer::free(sb)
    printf("after free x2, sb.getCapacity()=%zu\n", sb.getCapacity())
    sb.init()
    printf("after init: sb.getCapacity()=%zu\n", sb.getCapacity())
    sb.free()
    printf("after free, sb.getCapacity()=%zu\n", sb.getCapacity())

    printf("=== TIngteger ===\n")
    i := Integer(3)
    printf("i = %d\n", i.value())

    printf("=== TReal ===\n")
    f := Real(3.14)
    printf("f = %f\n", f.value())

    printf("=== TCardinal ===\n")
    u := Cardinal(42)
    printf("u = %u\n", u.value())
end
