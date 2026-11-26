program test_slice_fp()

(* A call through a method type inserts the hidden slice length. *)

type OpenChar = char[]
type TShow = function(s: char[]): integer
type TAlias = function(s: OpenChar): integer
type TSpan = function(a: char[], n: integer, b: integer[]): integer

type Box = struct
	h: TShow
end

function show(s: char[]): integer
begin
	return countof(s)
end

function show_alias(s: OpenChar): integer
begin
	return countof(s)
end

function span(a: char[], n: integer, b: integer[]): integer
begin
	return countof(a) + n + countof(b)
end

function pass(fp: TShow, s: char[]): integer
begin
	return fp(s)
end

begin
	var buf: array[32] of char
	var letters: array[3] of char
	var nums: array[5] of integer
	var fp: TShow
	var ap: TAlias
	var sp: TSpan
	var box: Box

	fp := show
	assert fp(buf) == 32
	assert pass(fp, buf) == 32
	box.h := show
	assert box.h(buf) == 32

	ap := show_alias
	assert ap(buf) == 32

	sp := span
	assert sp(letters, 10, nums) == 18
end

