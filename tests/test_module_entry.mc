program test_module_entry()

import printf from "stdio.h"

(* Import only the type. 7a must still bind the unit-entry name bumpint. *)
import TBump from "fixtures/bumpint.mh"

begin
    var n: integer = 41

    bumpint(n)
    assert n == 42, "imported module entry REF must mutate the caller"
    printf("test_module_entry passed.\n")
end test_module_entry
