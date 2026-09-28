program test2_var_ref()

import printf from "stdio.h"


(* Good *)
procedure Swap(VAR a: integer, VAR b: integer)
begin
	var temp: integer = a
  	a := b
  	b := temp
end Swap


(* Bad *)
procedure Swap3(a: integer, REF b: integer)
begin
	var temp: integer = a
  	a := b
  	b := temp
end Swap


begin
	var x: integer = 10
	var y: integer = 20

	printf("Before swap: x=%d, y=%d\n", x, y)
	Swap(x, y)
	printf("After swap: x=%d, y=%d\n", x, y)
end test_var_ref

