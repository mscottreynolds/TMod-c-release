program test_tmodc()

import size_t from "stddef.h"
import fprintf, stdout, from "stdio.h"
import strlen from "string.h"


(**
 * Basic string type.
 *)
type TString = struct
    value: const ^char
    length: size_t
end


function cstring(s: TString): const ^char
begin
    return s.value
end


function length(s: TString): size_t
begin
    return s.length
end

function TSTRING(s: const ^char): TString
begin
    var r: TString

    r.value := s
    r.length := strlen(s)
    return r
end


begin
    var str: TString = TSTRING("Hello world")

    fprintf(stdout, "%s:%zu\n", str.value, str.length)
    fprintf(stdout, "%s:%zu\n", cstring(str), length(str))
end
