program test_slice(args: ^char[])

(* Open-array formals carry a hidden integer length. countof reads it. *)

import printf from "stdio.h"

import strlen from "string.h"

type OpenChar = char[]

function show(s: char[]): integer
begin
	return countof(s)
end

function show_kw(s: array[] of char): integer
begin
	return countof(s)
end

function show_alias(s:OpenChar): integer
begin
	return countof(s)
end

function pass(s: char[]): integer
begin
	return show(s)
end

function span(a: char[], n: integer, b: integer[]): integer
begin
	return countof(a) + n + countof(b)
end

function take4(a: array[4] of integer): integer
begin
	return countof(a)
end

type slice = struct
	value: ^char
	count: integer
end

function slice::new(value: ^char): slice
begin
	var s: slice = { value, strlen(value) }
	return s
end


begin
	var buf: array[32] of char
	var raw: char[8]
	var letters: array[3] of char
	var nums: array[5] of integer
	var four: array[4] of integer

	assert show(buf) == 32
	assert show(raw) == 8
	assert show_kw(buf) == 32
	assert show_alias(buf) == 32
	assert pass(buf) == 32
	assert span(letters, 10, nums) == 18
	assert take4(four) == 4

	let argc = countof(args)

	if argc > 0 then
		var s: slice = slice::new(args[0])
		printf("args[0] = %s\n", s.value)
	end
end

