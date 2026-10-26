module tmodc.lib.Strings(str: string, length: integer): String


(**
 * Basic wrapper around const strings.
 * example: var s: String = String("...", len)
 * s.value()
 * s.length()
 *)


(**
 * Basic String type.
 *)
export type String = struct
    value: const ^char
    length: integer
end    


export function String::String(str: string, length: integer): String
begin
    var s: String = { str, length }

    return s
end String::String


function len(str: string): integer
begin
    require str <> nil

    var l: integer = 0

    while str[l] <> '\0' do
        inc(l)
    end
    return l
end len


export function String::new(s: string): String
begin
    var ts: String
    ts.value := s
    ts.length := len(s) as integer
    return ts
end String::new


export function String::value(ref self: String): string
begin
    return self.value
end String::value


export function String::length(ref self: String): integer
begin
    return self.length
end String::length


begin
    var s: String = String::String(str, length)

    return s
end tmodc.lib.Strings
