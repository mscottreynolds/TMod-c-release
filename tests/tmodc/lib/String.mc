module tmodc.lib.String(str: string, length: integer): TString


(**
 * Basic wrapper around const strings.
 * example: var s: TString = String("...", len)
 * s.value()
 * s.length()
 *
 * Alternate version without a TString::TString constructor,
 * but using the module name instead.
 *)


import strlen from "string.h"


(**
 * Basic TString type.
 *)
export type TString = struct
    value: const ^char
    length: integer
end    


export function TString::new(s: string): TString
begin
    var ts: TString
    ts.value := s
    ts.length := strlen(s) as integer
    return ts
end


export function TString::value(ref self: TString): string
begin
    return self.value
end


export function TString::length(ref self: TString): integer
begin
    return self.length
end


begin
    var s: TString = { str, length }

    return s
end tmodc.lib.String
