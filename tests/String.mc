module String(str: const ^char): TString

(**
 * Basic wrapper around const strings.
 * example: var s: TString = String("...")
 * s.cstring()
 * s.length()
 *)


import size_t from "stddef.h"
import strlen from "string.h"


(**
 * Basic TString type.
 *)
export type TString = struct
    _value: const ^char
    _length: size_t
end    


export function TString::cstring(ref self: TString): const ^char
begin
    return self._value
end


export function TString::length(ref self: TString): size_t
begin
    return self._length
end


begin
    var s: TString = { str, strlen(str) }

    return s
end String
