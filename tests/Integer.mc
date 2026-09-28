module Integer(n: integer): TInteger

(**
 * Basic wrapper around integers.
 * example: var n: TInteger = Integer(n)
 *)


(**
 * Basic TInteger type.
 *)
export type TInteger = struct
    _value: integer
end    


export function TInteger::value(ref self: TInteger): integer
begin
    return self._value
end


begin
    var i: TInteger = { n }

    return i
end Integer
