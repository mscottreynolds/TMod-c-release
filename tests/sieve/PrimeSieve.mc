program PrimeSieve()

(* Sieve of Eratosthenes - demonstrates arrays, loops, and procedures *)

import utils_power from "utils.h"

procedure PrintPrimes(LIMIT: integer)
begin
    var is_prime: ^bool = malloc(LIMIT+1 * sizeof(bool))
    var i, p, q: integer

    defer if true then free(is_prime); printf("done\n"); end

    (* Initialize array *)
    for i := 0 to LIMIT do 
        is_prime[i] := true
    end

    is_prime[0] := false
    is_prime[1] := false

    (* Mark multiples of each prime *)
    p := 2
    q := utils_power(p, 2)
    while q <= LIMIT do
        if is_prime[p] then
            i := q
            while i <= LIMIT do
                is_prime[i] := false
                i := i + p
            end
        end
        p := p + 1
        q := utils_power(p, 2)
    end

    (* Find the last 10 primtes *)
    q := 0; i := LIMIT
    while i > 0 and q < 10 do
        if is_prime[i] then
            inc(q)
        end
        dec(i)
    end
    debug printf("debug: q = %d, i = %d\n", q, i)

    (* Now print those primes *)
    while i <= LIMIT do
        if is_prime[i] then
            printf("%zu\n", i)
        end
        inc(i)
    end
end

begin
    const LIMIT: size_t = 1_000_000_000

    PrintPrimes(LIMIT)
end
