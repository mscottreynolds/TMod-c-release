program test3_bound_define()

define LIM = 4

begin
	var i: integer = 0

	while i < 3 do
		bound LIM
		i := i + 1
	end
end test3_bound_define

