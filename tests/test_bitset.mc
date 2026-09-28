program test_bitset()

import printf from "stdio.h"

type Colors = enum
	Red,
	Green,
	Blue,
end

begin
	printf("Red=%d Green=%d Blue=%d\n", Red, Green, Blue)
	printf("Bitset: %d %d %d\n", (1ULL << Red), (1ULL << Green), (1ULL << Blue))
end
