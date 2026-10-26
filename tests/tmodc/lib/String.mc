module tmodc.lib.String(str: string): TString

(**
 * Basic wrapper around strings.
 * example: var s: TString = String("...")
 *)



(**
 * Basic TString type.
 *)
export type TString = struct
    value: string
    length: integer
end

export function TString::value(ref self: TString): string
begin
    return self.value
end TString::value


function len(str: string): integer
begin
    require str <> nil

    var l: integer = 0

    while str[l] <> '\0' do
        inc(l)
    end
    return l
end len


export function TString::length(ref self: TString): integer
begin
    return self.length
end TString::length


begin
    require str <> nil

    var s: TString = { str, len(str) }

    return s
end String
