program test_pointer_var()

import printf from "stdio.h"
import malloc, free from "stdlib.h"
import void from "stddef.h"

type pvoid = ^void

// type integer = int

type Node = struct
	value: integer
	next: ^Node
end

type pNode = ^Node

begin
	var root: ^Node = malloc(sizeof(Node))
	defer free(root)

	root^.value := 42
	root^.next := nil
	printf("root=%p, root^.value=%d\n", root as pvoid, root^.value)
	root.value := 42
	root.next := nil
	printf("root=%p, root.value=%d\n", root as pvoid, root.value)

	begin
		var p: ^Node = malloc(sizeof(Node))
		defer free(p)
		p^.value := 43
		p^.next := root
		printf("p=%p, p^.value=%d\n", p as pvoid,  p^.value)
		printf("p=%p, p.value=%d\n", p as pvoid, p.value)
		printf("p^.next=%p p.next=%p\n", p^.next as pvoid, p.next as pvoid)
		printf("p^.next^.value=%d p.next.value=%d\n", p^.next^.value, p.next.value)
	end


	printf("VAR on pointer test passed.\n")
end test_pointer_var
