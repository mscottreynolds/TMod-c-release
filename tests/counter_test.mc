program counter_test()

import printf from "stdio.h"

define ID = __COUNTER__

begin
    printf("%d\n", ID)  // 0
    printf("%d\n", ID)  // 1
    printf("%d\n", ID)  // 2

    for n: integer = 1 to 10 do
        printf("n=%d\n", ID)
    end
    // return 0
end
