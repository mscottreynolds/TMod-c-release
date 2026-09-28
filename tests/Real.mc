module Real(r: real): TReal

(**
 * Basic wrapper around real values.
 * example: var r: TReal = Real(1.0)
 * r.value()
 *)


(**
 * Basic TReal type
 *)
export type TReal = struct
    _value: real
end    


export function TReal::value(ref self: TReal): real
begin
    return self._value
end


begin
    var v: TReal = { r }

    return v
end
