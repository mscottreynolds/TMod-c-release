program test_packed()

import printf from "stdio.h"
import int8_t, int16_t from "stdint.h"

import from "tmodc.h"


type Point = packed struct
	x: int16_t
	y: int16_t
	z: int8_t
end

type uPoint = struct 
	a: int16_t
	b: int16_t
	c: int8_t
end

begin
	var p: Point = {1, 2, 3}
	var up: uPoint = {4, 5, 6}

	printf("sizeof(Point) = %ld\n", sizeof(p))		// should be 5
	printf("sizeof(uPoint) = %ld\n", sizeof(up))

	// NOTE: tcc doesn't "pack"
	// assert sizeof(p) == 5, "should be 5"
end

