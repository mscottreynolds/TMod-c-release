module tmodc.lib.String(str: string): TString

(**
 * Basic wrapper around string.
 * example: var s: TString = String("...")
 *)


(**
 * Basic TString type.
 *)
export type TString = struct
    value: string
    length: integer
end

export function TString::TString(s: string, l: integer): TString
begin
    var t: TString

    t.value := s
    t.length := l
    return t
end


export function TString::value(ref self: TString): string
begin
    return self.value
end TString::value

// helper function
export function TString::len(str: string): integer
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

    return TString(str, TString::len(str))
end String
