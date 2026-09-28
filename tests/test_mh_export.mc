module test_mh_export()

import printf from "stdio.h"

export function mh_add(a: integer, b: integer): integer
begin
	return a + b
end

export type MHPoint = struct
	x: integer
	y: integer
end

export function main(): int
begin
	printf("Hello from test_mh_export\n")
	return 0
end


begin
end test_mh_export