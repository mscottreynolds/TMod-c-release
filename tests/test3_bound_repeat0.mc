program test3_bound_repeat0()

begin
	var n: integer = 0

	repeat
		bound 0
		n := 1
	until n >= 1
end

