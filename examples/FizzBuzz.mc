program FizzBuzz()

(** Simple demonstration of procedures, loops, and conditionals *)

import printf from "stdio.h"

procedure PrintFizzBuzz(n: integer)
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
    var i = 1
    
    while i <= 100 do
        PrintFizzBuzz(i)
        inc(i)
    end
end FizzBuzz

(* gk/msr *)
