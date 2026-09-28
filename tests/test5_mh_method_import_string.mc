program test5_mh_method_import_string()

import printf from "stdio.h"

import TString, TString::cstring, TString::length 
//    from "../include/String.mh"
    from String
import TStringBuffer, TStringBuffer::getLength, TStringBuffer::getData, TStringBuffer::free 
    from StringBuffer
    // from "../include/StringBuffer.mh"


begin
    var s: TString = String("Hello world")
    var sb: TStringBuffer = StringBuffer("")

    // printf("%s:%zu\n", str.value, str.length)
    printf("%s:%zu\n", TString::cstring(s), TString::length(s))

    assert s.cstring() <> nil
    assert s.length() > 0
    printf("s.cstring()=%s s.length()=%zu\n", s.cstring(), s.length())

    // printf("sb.capacity=%zu\n", sb.capacity)
    // assert sb.data <> nil
    // assert sb.free <> nil
    sb.free()
    // TStringBuffer::free(sb)
    // assert sb.data == nil

end
