program test_FactorialDemo()

(**
 * Demonstrates recursion with Factorial + iterative version for safety 
 *)


import printf from "stdio.h"


recursive function FactorialRecursive(n: int): int
begin
    if n <= 1 then
        return 1
    else
        return n * FactorialRecursive(n - 1)
    end
end

function FactorialIterative(n: int): int
begin
    var                         \
        result: int = 1,        \
        i: int = 2

    while i <= n do
        result := result * i
        i := i + 1
    end
    return result
end

begin
    let n = 10

    printf("Recursive Factorial(%d%s%d\n", n, ") = ", FactorialRecursive(n))
    printf("Iterative Factorial(%d%s%d\n", n, ") = ", FactorialIterative(n))
    printf("\n");

    assert FactorialRecursive(n) == FactorialIterative(n),      \
           "Recursive and iterative factorial must match"
end
