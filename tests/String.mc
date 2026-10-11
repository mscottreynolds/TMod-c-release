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
    value: const ^char
    length: size_t
end    


export function TString::new(s: string): TString
begin
    var ts: TString
    ts.value := s
    ts.length := strlen(s)
    return ts
end


export function TString::cstring(ref self: TString): const ^char
begin
    return self.value
end


export function TString::length(ref self: TString): size_t
begin
    return self.length
end


begin
    var s: TString = { str, strlen(str) }

    return s
end String
