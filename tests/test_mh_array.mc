module test_mh_array()

export type pchar = ^char

import printf from "stdio.h"

export type Node = struct
	n: integer
end

export procedure take_open(p: ^Node[])
begin
	printf("take_open: p == nil: %d\n", (p == nil))
end

export procedure take_fixed(row: integer[4])
begin
	printf("take_fixed: %d\n", row[0])
end

export procedure take_ptr_array(p: ^array[] of Node)
begin
	printf("take_ptr_array: p == nil: %d\n", (p == nil))
end

export type Buf = char[]

export type Row = struct
	cells: integer[4]
end

export function main(argc: int, argv: ^pchar): int
begin
	printf("test_mh_array: argc=%d, argv <> nil=%d\n", argc, (argv <> nil))
	return 0
end

begin
end test_mh_array

