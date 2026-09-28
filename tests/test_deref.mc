program test_deref()

	import printf from "stdio.h"
	
	type pInt = ^int

	var p: pInt = nil
	var q: ^int = nil
	var x: int = 42
begin
	p := @x		// Address-of
	p^ := 99	// corect dereference
	printf("%d\n", p^)		// should print 99

	q := @x
	q^ := 42
	printf("%d\n", q^)		//
	
	// ^p := 100	// should now be syntax error.
end
