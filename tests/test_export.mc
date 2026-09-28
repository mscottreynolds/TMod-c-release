MODULE test_export()

IMPORT printf FROM "stdio.h"

EXPORT TYPE TIntInt = struct
    x: int
    y: int
END


EXPORT PROCEDURE greet()
BEGIN
    printf("Hello from exported proc!\n");
END


PROCEDURE private_helper()
BEGIN
    printf("Private helper called\n");
END


EXPORT FUNCTION add(a: int, b: int): int
BEGIN
    return a + b;
END


FUNCTION subtract(x: int, y: int): int
BEGIN
    return x - y;
END


EXPORT FUNCTION main(): int
BEGIN
    greet();
    private_helper();
    printf("Add: %d\n", add(5, 3));
    printf("Sub: %d\n", subtract(10, 4));
    return 0;
END main


BEGIN
END Test_Exports
