program FibonacciDemo()

(** Demonstrates both iterative and recursive Fibonacci *)


import printf from "stdio.h"


function FibIterative(n: cardinal): cardinal
begin
    var a: cardinal = 0, b: cardinal = 1, i: cardinal = 0
    
    if n <= 1 then
        return n
    end

    for i := 2 to n do
        let temp: cardinal = a + b
        a := b
        b := temp
    end
    return b
end FibIterative


recursive function FibRecursive(n: cardinal): cardinal
begin
    if n > 1 then
        return FibRecursive(n-1) + FibRecursive(n-2)
    end
    return n
end FibRecursive


begin
    var n: cardinal = 10

    printf("Iterative Fib(%u%s%u\n", n, ") = ", FibIterative(n))
    printf("Recursive Fib(%u%s%u\n", n, ") = ", FibRecursive(n))

    assert FibIterative(n) == FibRecursive(n), "Both methods should match"
end FibonacciDemo

(* gk/msr *)
