module test_module_ref(ref box: TBox, delta: integer)

import printf from "stdio.h"

(**
 * Module-entry REF must lower like a procedure formal: T* in C,
 * pointee load in the body, auto-& when calling another REF formal.
 * 7a binds the module name in this unit, so the call site needs no @.
 *)

export type TBox = struct
 	n: integer
 end

 procedure TBox::bump(ref self: TBox, d: integer)
 begin
 	self.n := self.n + d
 end TBox::bump

 export function main(): int
 begin
 	var b: TBox

 	b.n := 40
 	// test_module_ref(@b, 1)
    test_module_ref(b, 1)
 	assert b.n == 42, "module REF formal must mutate the caller"
 	printf("test_module_ref passed (%d).\n", b.n)
 	return 0
 end main

 begin
 	TBox::bump(box, delta)
 	box.n := box.n + 1
 end test_module_ref
