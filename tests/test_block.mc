program test_block()

import printf from "stdio.h"

begin
    var x: int = 3
    var z: int = -1
    printf("Outer block. x=%d, z=%d\n", x, z)

    begin
        var y: int = x + 4
        var x: int = y          // TODO: Emit warning on shadowed variable?

        printf("Inner block, x=%d, y=%d, z=%d\n", x, y, z)
        let z: int = 2

        begin
            let x :int = 5
            let z : int = z - 1
            printf("Inner inner block, x=%d, y=%d, z=%d\n", x, y, z)
        end

        let Day :const ^char =  "20260326"
        let Time :const ^char = "15:54"
        printf("%s-%s\n", Day, Time)
    end
    printf("Outer block. x=%d, z=%d\n", x, z)

    printf("%d.%d\n", 3, 1415926 )
end

