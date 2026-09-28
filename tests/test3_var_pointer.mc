program test2_var_ref()

import printf from "stdio.h"


(* Good *)
procedure Swap(VAR a: ^integer, VAR b: ^integer)
begin
	var temp: ^integer = a
  	a := b
  	b := temp
end Swap



(* Bad *)
procedure Swap4(VAR a: ^integer, b: ^integer)
begin
	var temp: ^integer = a
  	a := b
  	b := temp
end Swap


begin
	var x: integer = 10
	var y: integer = 20
	var p: ^integer = @x
	var q: ^integer = @y

	printf("Before swap: x=%d, y=%d\n", x, y)
	printf("Before swap: p^=%d, q^=%d\n", p^, q^)
	assert x == 10 and y == 20
	assert p^ == 10 and q^ == 20
	Swap(p, q)
	printf("After swap: x=%d, y=%d\n", x, y)
	printf("Before swap: p^=%d, q^=%d\n", p^, q^)
	assert x == 10 and y == 20
	assert p^ == 20 and q^ == 10
end test_var_ref

