module Integer(n: integer): TInteger

(**
 * Basic wrapper around integers.
 * example: var n: TInteger = Integer(n)
 *)


(**
 * Basic TInteger type.
 *)
export type TInteger = struct
    value: integer
end    


export function TInteger::value(ref self: TInteger): integer
begin
    return self.value
end


begin
    var i: TInteger = { n }

    return i
end Integer
