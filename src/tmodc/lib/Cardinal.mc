module tmodc.lib.Cardinal(n: cardinal): TCardinal

(**
 * Basic wrapper around cardinals.
 * example: var n: TCardinal = Cardinal(123)
 *)


(**
 * Basic TCardinal type.
 *)
export type TCardinal = struct
    value: cardinal
end    


export function TCardinal::value(ref self: TCardinal): cardinal
begin
    return self.value
end TCardinal::value


begin
    var c: TCardinal = { n }

    return c
end Cardinal
