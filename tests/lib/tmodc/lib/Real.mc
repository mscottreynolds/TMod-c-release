module tmodc.lib.Real(r: real): TReal

(**
 * Basic wrapper around real values.
 * example: var r: TReal = Real(1.0)
 * r.value()
 *)


import snprintf from "stdio.h"

(**
 * Basic TReal type
 *)
export type TReal = struct
    value: real
    str: array[64] of char
end    


export function TReal::TReal(r: real): TReal
begin
    var v: TReal

    v.value := r
    snprintf(v.str, sizeof(v.str), "%g", r)

    return v
end


export function TReal::value(ref self: TReal): real
begin
    return self.value
end


export function TReal::toString(ref self: TReal): string
begin
    return @self.str[0] as string
end


begin
    var v: TReal = TReal(r)

    return v
end
