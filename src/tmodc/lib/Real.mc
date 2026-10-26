module tmodc.lib.Real(n: real): TReal

(**
 * Basic wrapper around real values.
 * example: var r: TReal = Real(1.0)
 *)


(**
 * Basic TReal type
 *)
export type TReal = struct
    value: real
end    


export function TReal::value(ref self: TReal): real
begin
    return self.value
end TReal::value


begin
    var r: TReal = { n }

    return r
end Real
