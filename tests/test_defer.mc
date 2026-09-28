program test_defer()

import printf from "stdio.h"


(**
 * Test DEFER with early exits (return, break, continue)
 * Expected behavior: every defer runs exactly once, in LIFO order,
 * even when the function exits early.
 *)

 procedure test_return()
 begin
 	var x: int = 42
 	defer printf("DEFER 1: cleanup from return, x = %d\n", x)
 	defer printf("DEFER 2: another cleanup (LIFO order)\n")

 	printf("test_return: before return\n")
 	return
 	// printf("UNREACHABLE after return\n")
 end

 procedure test_break()
 begin
 	var i: int

 	for i := 1 to 5 do
 		defer printf("DEFER break: cleanup at i=%d\n", i)

 		if i == 3 then
 			printf("test_break: breaking at i=3\n")
 			break
 		end

 		printf("test_break: continuing i=%d\n", i)
 	end
 end

 procedure test_continue()
 begin
 	var i: int

 	for i := 1 to 5 do
 		defer printf("DEFER continue: cleanup at i=%d\n", i)

 		if i mod 2 == 0 then
 			defer printf("DEFER after continue i=%d\n", i)
 			printf("test_continue: continuing at i=%d\n", i)
 			continue
 		end

 		printf("test_continue: i = %d\n", i)
 	end
 end

procedure test_nested_return()
begin
	var i: int
	defer printf("DEFER nested_return i = %d\n", i)

	for i := 1 to 4 do
		defer printf("DEFER nested return %d\n", i)
		if i == 3 then
            printf("Returning %d\n", i)
			return
		end
	end
end


procedure test_return_before_defer(var ran: integer)
begin
    // kilo editorSave: early return in the same BEGIN/END as a later DEFER
    if true then
        return
    end
    defer ran := 1
end


procedure test_return_after_defer(var ran: integer)
begin
    defer ran := 1
    if true then
        return
    end
end


procedure test_skip_second_defer(var first: integer, var second: integer)
begin
    defer first := 1
    if true then
        return
    end
    defer second := 2
end


procedure test_continue_before_defer(var hits: integer)
begin
    var i: integer

    hits := 0
    for i := 1 to 2 do
        if i == 1 then
            continue
        end
        defer inc(hits)
    end
end


procedure test_while()
begin
    var n: integer = 0

    while n < 20 do; defer n += 1; printf("[%d]", n); end
end test_while


procedure test_loop()
begin
    var n: integer = 0

    loop
        invariant n < 50
        defer inc(n)

        printf("n = %d\n", n)
        if n > 25 then
            break
        end
    end
end


begin
 	printf("=== Testing DEFER with early exits ===\n\n")
	defer printf("DEFER from main BEGIN/END\n");

 	test_return()
 	printf("\n")

 	test_break()
 	printf("\n")

 	test_continue()
 	printf("\n")

 	test_nested_return()
 	printf("\n")

    begin
        var ran: integer = 0
        var first: integer = 0
        var second: integer = 0
        var hits: integer = 0

        test_return_before_defer(ran)
        assert ran == 0

        test_return_after_defer(ran)
        assert ran == 1

        test_skip_second_defer(first, second)
        assert first == 1
        assert second == 0

        test_continue_before_defer(hits)
        assert hits == 1
    end

    test_while()
    printf("\n")

    test_loop()
    printf("\n")

 	printf("=== All DEFER tests completed successfully ===\n")
 end
