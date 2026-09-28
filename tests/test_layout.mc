program test_layout()

import printf from "stdio.h"

(* Layout / EOS smoke test - parser should accept all of the following splits.
   Tier-1: compiles, runs, prints section markers. *)

function pick(a: integer,
	 b: integer): integer
begin
	(* RETURN value on next line -- needs skip_layout_breaks in parse_return_stmt;
		omit this call from main until that fix is in *)
	return (a + 
		b)
end

begin
	var a: integer
	var b: integer
	var i: integer
	var x: integer

	a := 1
	b := 2

	printf("=== import/var (see test_import_layout.mc for full decl test) ===\n")

	(* --- expressions: parse_unary / trailing continuators --- *)

	x := a +
		b
	printf("expr-add split: x=%d\n", x)

	x := a == 1 and
		 b == 2 ? 10 : 20
	printf("expr-and/ternary split: x=%d\n", x)

	x := (a + 
			b) * 2
	printf("expr-parens split: x=%d\n", x)

	(* --- IF: expr continuators + consume(THEN/END) --- *)

	if a == 1 or
		b == 2 
	then
		printf("if-or split: yes\n")
	end

	if a == 1 and
	   b == 2 then
	   	printf("if-and split: yes\n")
	end

	if a <> b
	then
		printf("if-the split: yes\n")
	else
		printf("if-then split: else\n")
	end

	if a == 0 then
		printf("elsif: no\n")
	elsif a == 1 or
	      b == 2
	then
		printf("elsif-or split: yes\n")
	end

	(* --- WHILE / FOR / REPEAT / LOOP: consume(DO/UNTIL/END) --- *)

	i := 0
	while i < 2
	do
		printf("while-do split: i=%d\n", i)
		i := i + 1
	end

	for i := 1
	to 2
	do
		printf("for-to-do split: i=%d\n", i)
	end

	for i := 3
	downto 2
	do
		printf("for-downto-do split: i=%d\n", i)
	end

	for i := 0
	to 4
	by 2
	do
		printf("for-by-do split: i=%d\n", i)
	end

	i := 0
	repeat
		printf("repeat-until split: i=%d\n", i)
		i := i + 1
	until i >= 2

	loop
		printf("loo-end split: once\n")
		i := 99
		break
	end

	(* --- SWITCH: consume(OF) --- *)
	switch a + b
	of
		case 3:
			printf("switch-of split: 3\n")
		else:
			printf("switch-of split: else\n")
	end

	(* Uncomment when parse_return_stmt skips layout before checkEOS: *)
	x := pick(a, b)
	printf("return split: x=%d\n", x)


	printf("=== layout test done ===\n")
end test_layout

