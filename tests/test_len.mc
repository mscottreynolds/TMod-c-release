program test_len()

begin
	var a: array[4] of integer
	var v: array[3] of integer = {1, 2, 3}

	assert len(a) == 4
	assert len(v) == 3
	assert sizeof(a) == len(a) * sizeof(a[0])
end
