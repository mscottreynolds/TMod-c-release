MODULE test_RepeatUntil()

IMPORT printf FROM "stdio.h"

EXPORT FUNCTION main(): int
BEGIN
    VAR i: int = 0;

    REPEAT
        printf("i = %d\n", i);
        i := i + 1;
    UNTIL (i >= 5 OR i == 999);

    // With AND inside condition
    REPEAT
        printf("i = %d\n", i);
        i := i - 1;
    UNTIL (i <= 0 AND NOT (i == -1));

    return 0;
END main

BEGIN
END test_RepeatUntil
