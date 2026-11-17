module tmodc.lib.Cardinal(n: cardinal): TCardinal

(**
 * Basic wrapper around cardinals.
 * example: var n: TCardinal = Cardinal(123)
 *)


import fprintf, snprintf, FILE from "stdio.h"


(**
 * Basic TCardinal type.
 *)
export type TCardinal = struct
    value: cardinal
    str: array[32] of char
end    


export function TCardinal::TCardinal(n: cardinal): TCardinal
begin
    var u: TCardinal
    u.value := n
    snprintf(u.str, sizeof(u.str), "%u", n)
    return u
end


export function TCardinal::value(ref self: TCardinal): cardinal
begin
    return self.value
end


export function TCardinal::to_string(ref self: TCardinal): string
begin
    return @self.str[0] as string
end


export function TCardinal::write(ref self: TCardinal, out: ^FILE): integer
begin
    return fprintf(out, "%s", @self.str[0])
end


begin
    var c: TCardinal = TCardinal(n)

    return c
end Cardinal
