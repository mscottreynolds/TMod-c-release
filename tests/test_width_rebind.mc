program test_width_rebind()

type integer = integer 64

begin
	var x: integer = 1
	assert sizeof(x) == 8
	assert sizeof(integer) == 8
end

