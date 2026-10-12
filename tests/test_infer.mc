program test_infer()
import printf from "stdio.h"
begin
	var n = 1
	let s = "hi"
	const c = 40
	var a = 0, b, d: integer
	var m = -2
	var bits = 4 & 5
	var sum = 1 + 2
	var pick = true ? 1 : 2
	var nested = false ? 1 : true ? 2 : 3

	n := n + c + a + b + d + m
	printf("s = %s\n", s)
	printf("n = %d\n", n)
	printf("sum = %d\n", sum)
	printf("bits = %d\n", bits)
	printf("pick = %d\n", pick)
	printf("nested = %d\n", nested)
end

