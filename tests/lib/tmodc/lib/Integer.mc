module tmodc.lib.Integer(n: integer): TInteger

(**
 * Basic wrapper around integers.
 * example: var n: TInteger = Integer(n)
 *)

import snprintf from "stdio.h"


(**
 * Basic TInteger type.
 *)
export type TInteger = struct
    value: integer
    str: array[32] of char
end    


export function TInteger::TInteger(i: integer): TInteger
begin
    var n: TInteger
    n.value := i
    snprintf(n.str, sizeof(n.str), "%d", i)

    return n
end


export function TInteger::value(ref self: TInteger): integer
begin
    return self.value
end


export function TInteger::toString(ref self: TInteger): string
begin
    return @self.str[0] as string
end


begin
    var i: TInteger = TInteger(n)

    return i
end Integer
