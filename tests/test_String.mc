program test_String()

import size_t from "stddef.h"
import printf from "stdio.h"
import strlen from "string.h"

type TString forward

type FCString = function(s: TString): const ^char
type FLength = function(s: TString): size_t


type TString = struct
    length: size_t
    capacity: size_t
    value: const ^char
end    


function TString::length(s: TString): size_t
begin
	return s.length
end


function TString::string(s: TString): string
begin
	return s.value
end


function TString::capacity(s: TString): size_t
begin
	return s.capacity
end


function TString::pchar(s: TString): const ^char
begin
	return s.value
end


function TString::new(p: const ^char): TString
begin
	var s: TString = {0, 0, p}
	s.length := strlen(p)
	return s
end


procedure string::print(s: string)
begin
	printf("%s", s)
end


function string::length(s: string): size_t
begin
	return strlen(s)
end


function string::get(s: string, n: integer): char
begin
	let l: integer = strlen(s) as integer
	if n >= 0 and n < l then
		return s[n]
	else
		return '\0'
	end
end


function char::size(c: char): integer
begin
	if c <> '\0' then
		return 42
	else
		return 0
	end
end


begin
	var s: TString = TString::new("Hello")
	var t: string = "Hello world."
	var c: char = '\0'

	printf("s.length=%zu\n", s.length())
	printf("s.capacity=%zu\n", s.capacity())
	printf("s.string=%s\n", s.string())
	printf("s.pchar=%s\n", s.pchar())
	t.print()
	printf("\n")
	printf("t.length=%zu\n", t.length())
	printf("c=%c, c.size()=%d\n", c, c.size())
	c := 'a'
	printf("c=%c, c.size()=%d\n", c, c.size())

	begin
		var i = 0
		for i := 0 to 20 do
			printf("%d:%c\n", i, t.get(i))
		end
	end
end
