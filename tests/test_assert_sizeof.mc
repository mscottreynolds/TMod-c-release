program test_assert_sizeof(argc: int, argv: ^char[])

import printf from "stdio.h"

begin
	let x = sizeof(integer)
	let y = sizeof(argv[0])

	assert sizeof(int) > 0, "sanity"

	printf("x = %d\n", x);
	printf("y = %d\n", y);
end
