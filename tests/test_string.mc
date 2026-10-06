program test_string(argc: int, argv: ^char[])

import size_t from "stddef.h"
import printf from "stdio.h"
import strlen from "string.h"

export type pchar = ^char

export type string = struct
	value: const ^char
	length: size_t
end

function string::new(s: const ^char): string
begin
	var t: string = {s, strlen(s)}
	return t
end

function string::value(ref s: string): const ^char
begin
	printf("foo ")
	return s.value
end

function string::length(ref s: string): size_t
begin
	printf("bar ")
	return s.length
end


begin
	var s: string = {"Hello", 5}
	var h: const ^char = "Hello world."
	var t: string = string::new(h)
	var u: string = t

	printf("s.value=%s\n", s.value())
	printf("s.length=%zu\n", s.length())
	printf("t.value=%s\n", t.value())
	printf("t.length=%zu\n", t.length())
	printf("u.value=%s\n", u.value)
	printf("u.length=%zu\n", u.length())
	printf("u.length=%zu\n", u.length)
end
