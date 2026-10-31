program test3_bound_while0()

begin
	var i: integer = 0

	while i < 1 do
		bound 0
		i := 1
	end
end

