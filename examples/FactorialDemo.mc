program FactorialDemo()
(**
 * Demonstrates recursion with Factorial + iterative version for safety 
 *)


import printf from "stdio.h"


recursive function FactorialRecursive(n: integer): integer
begin
    if n <= 1 then
        return 1
    else
        return n * FactorialRecursive(n - 1)
    end
end FactorialRecursive


function FactorialIterative(n: int): int
begin
    var
        result = 1,
        i = 2

    while i <= n do
        result := result * i
        i := i + 1
    end
    return result
end FactorialIterative


begin
    let n = 10

    let f1 = FactorialRecursive(n)
    let f2 = FactorialIterative(n)

    printf("Recursive Factorial(%d%s%d\n", n, ") = ", f1)
    printf("Iterative Factorial(%d%s%d\n", n, ") = ", f2)
    printf("\n");

    assert f1 == f2, "Recursive and iterative factorial must match"
end FactorialDemo

(* gk/msr *)
