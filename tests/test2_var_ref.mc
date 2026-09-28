program test2_var_ref()

import printf from "stdio.h"

(**
 * Test VAR (mutable alias), REF (immutable pointer), and default immutable parameters.
 *)


type array_of_integer = integer[]



procedure Swap(VAR a: integer, VAR b: integer)
begin
	var temp: integer = a
  	a := b
  	b := temp
end Swap

procedure PrintArray(REF arr: array_of_integer, arr_len: integer)
begin
	var i: integer = 0
	while i < arr_len do
		printf("%d", arr[i])
		i := i + 1
	end
	printf("\n")
end PrintArray

procedure IncrementAll(VAR arr: array_of_integer, arr_len: integer)
begin
	var i: integer = 0
	while i < arr_len do
		arr[i] := arr[i] + 1
		i := i + 1
	end
end IncrementAll

begin
	var x: integer = 10
	var y: integer = 20
	var data: integer[5] = {1, 2, 3, 4, 5}
	// var data: array[5] of integer := {1, 2, 3, 4, 5}

	printf("Before swap: x=%d, y=%d\n", x, y)
	Swap(@x, @y)
	printf("After swap: x=%d, y=%d\n", x, y)

	printf("Original array: ")
	PrintArray(@data, 5)

	IncrementAll(@data, 5)

	printf("After increment: ")
	PrintArray(@data, 5)

	printf("VAR/REF test passed.\n")
end test_var_ref

