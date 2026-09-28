module test_Math(): TMath

import printf from "stdio.h"
// import from test_Math


export type TFunction1 = function(n: integer): integer
export type TFunction2 = function(a: integer, b: integer): integer

export type TMath = struct
	_pi: double
	say: TFunction1
	add: TFunction2
	sub: TFunction2
end


function say(n: integer): integer
begin
	return n
end

function add(a: integer, b: integer): integer
begin
	return a + b
end

function sub(a: integer, b: integer): integer
begin
	return a - b
end


export function TMath::create(): TMath
begin
	var math: TMath

	math.say := say
	math.add := add
	math.sub := sub
	math._pi := 3.14159265358979323846264338327950

	return math
end


export function TMath::pi(self: TMath): real
begin
	return self._pi as real
end


export function main(): integer
begin
	let n: TMath = test_Math()
	let m = TMath::create()

	printf("say %d\n", m.say(42))
	printf("add %d\n", m.add(1, 2))
	printf("sub %d\n", m.sub(3, 4))
	printf("pi %f\n", n.pi())
	printf("pi %3.15f\n", m._pi)

	return 0
end


begin
	return TMath::create()
end
