program test_for()

import size_t from "stddef.h"
import stderr, printf, fprintf from "stdio.h"
import exit from "stdlib.h"

type Color = enum
	Red,
	Green, 
	Blue
end

var calls: integer = 0

function limit(): integer
begin
	printf("limit() called\n")
	calls := calls + 1
	return 5
end

var i, j: integer

begin
	var nested: integer = 0
	var shadow: integer = 40
	var acc: integer = 0
	var typed: integer = 0

	for i := 1 to limit() do
		printf("i = %d\n", i)
	end

	if calls <> 1 then
		fprintf(stderr, "FAIL: limit() called %d times, expected 1\n", calls)
		exit(1)
	end
	printf("FOR end-once test passed.\n")

	for i := 1 to 2 do for j := 1 to 3 do nested := nested + 1; end end
	printf("nested=%d\n", nested)
	if nested <> 6 then
		fprintf(stderr, "FAIL: nexted one-line FOR count %d, expected 6\n", nested)
		exit(1)
	end
	printf("FOR nested test passed.\n")

	for shadow = 1 to 3 do
		acc := acc + shadow
	end
	if shadow <> 40 then
		fprintf(stderr, "FAIL: for i = wrote the outer variable\n")
		exit(1)
	end
	if acc <> 6 then
		fprintf(stderr, "FAIL: for i = sum %d, expected 6\n", acc)
		exit(1)
	end

	for k = 1 to 4 do
		acc := acc + k
	end
	if acc <> 16 then
		fprintf(stderr, "FAIL: for k = sum %d, expected 16\n", acc)
		exit(1)
	end

	for k: integer = 1 to 2 do
		typed := typed + 1
	end
	if typed <> 2 then
		fprintf(stderr, "FAIL: for k: integer = count %d, expected 2\n", typed)
		exit(1)
	end

	begin
		var letters: integer = 0
		var cards: integer = 0
		var bytes: integer = 0
		var sz: integer = 0
		var sz2: integer = 0
		var ptrs: integer = 0
		var colors: integer = 0
		var n: size_t = 4
		var buf: array[3] of char

		for c = 'A' to 'C' do
			letters := letters + 1
		end
		if letters <> 3 then
			fprintf(stderr, "FAIL: char FOR count %d, exptected 3\n", letters)
			exit(1)
		end

		for cu: cardinal = 1 to 3 do
			cards += 1
		end
		if cards <> 3 then
			fprintf(stderr, "FAIL: cardinal FOR count %d, expected 3\n", cards)
			exit(1)
		end

		for b: byte = 1 to 2 do
			inc(bytes)
		end
		if bytes <> 2 then
			fprintf(stderr, "FAIL: byte FOR count %d, exptected 2\n", bytes)
			exit(1)
		end

		for s: size_t = 1 to n do
			sz := sz + 1
		end
		if sz <> 4 then
			fprintf(stderr, "FAIL: size_t FOR count %d, expected 4\n", sz)
			exit(1)
		end

		for s2 = n to n do
			sz2 += 1
		end
		if sz2 <> 1 then
			fprintf(stderr, "FAIL: size_t start FOR count %d, expected 1\n", sz2)
			exit(1)
		end

		for p: ^char = @buf[0] to @buf[2] do
			ptrs := ptrs + 1
		end
		if ptrs <> 3 then
			fprintf(stderr, "FAIL: pointer FOR count %d, expected 3\n", ptrs)
			exit(1)
		end

		for e: Color = Red to Blue do
			colors := colors + 1
		end
		if colors <> 3 then
			fprintf(stderr, "FAIL: enum FOR count %d, expected 3\n", colors)
			exit(1)
		end
	end

	printf("FOR local index test passed.\n")
end
