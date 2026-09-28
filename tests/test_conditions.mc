PROGRAM test_conditions()

import printf from "stdio.h"

BEGIN
    VAR a: int = 5
    VAR b: int = 10
    VAR c: int = 15

    IF (a < b AND b < c) THEN
        printf("a < b < c is true\n");
    ELSIF (a == b) THEN
        printf("a equals b\n");
    ELSE
        printf("None of the above\n");
    END

    // Nested IF
    IF (a > 0) THEN
        IF (b > 0) THEN
            printf("Both positive\n");
        END
    END

END
