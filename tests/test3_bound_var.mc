program test3_bound_var()

begin
	var n: integer = 3

	while n > 0 do
		bound n
		n := n - 1
	end
end

