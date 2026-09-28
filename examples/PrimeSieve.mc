program PrimeSieve()
(**
 * Sieve of Eratosthenes - demonstrates arrays, loops, and procedures 
 *)

import printf from "stdio.h"


const LIMIT = 1_000_000


procedure PrintPrimes()
begin
    var is_prime: bool[LIMIT + 1]
    var i: integer,
        p: integer

    // Initialize array
    for i := 0 to LIMIT do 
        is_prime[i] := true
    end

    is_prime[0] := false
    is_prime[1] := false

    // Mark multiples of each prime
    p := 2
    while p * p <= LIMIT do
        if is_prime[p] then
            i := p * p
            while i <= LIMIT do
                is_prime[i] := false
                i := i + p
            end
        end
        inc(p)
    end

    // Print primes
    for i := 2 to LIMIT do
        if is_prime[i] then
            printf("%d\n", i)
        end
    end
end

begin
    PrintPrimes()
end PrimeSieve

(* gk/msr *)
