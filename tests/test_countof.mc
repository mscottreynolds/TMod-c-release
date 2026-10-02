program test_countof()

type Buf = array[4] of integer

begin
	var len: integer
	var a: array[4] of integer
	var v: array[3] of integer = {1, 2, 3}
	var m: array[7] of array[3] of integer
	var b: array[countof(a)] of integer
	var buf: Buf

	len := countof(a)
	assert len == 4
	assert countof(v) == 3
	assert countof(m) == 7
	assert countof(b) == 4
	assert countof(buf) == 4
	assert countof(array[4] of integer) == 4
	assert sizeof(a) == countof(a) * sizeof(a[0])
end
