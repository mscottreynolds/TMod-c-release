program test_FizzBuzz()

    import printf from "stdio.h"

    (* Simple demonstration of procedures, loops, and conditionals *)

    procedure PrintFizzBuzz(n: int)
    begin
        if n mod 15 == 0 then
            printf("FizzBuzz\n")
        elsif n mod 3 == 0 then
            printf("Fizz\n")
        elsif n mod 5 == 0 then
            printf("Buzz\n")
        else
            printf("%d\n", n)
        end
    end

begin
    var i :int = 1
    while i <= 100 do
        PrintFizzBuzz(i)
        i := i + 1
    end

    (* Bonus: assert that the loop completed correctly *)
    assert i == 101, "Loop should have finished at 101"
end
