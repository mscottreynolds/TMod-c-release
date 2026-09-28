program test_width()

type i32t = integer 32

begin
	var i8: integer 8 = 1
	var i16: integer 16 = 2
	var i32: integer 32 = 3
	var i64: integer 64 = 4
	var u8: cardinal 8 = 5
	var u32: cardinal 32 = 6
	var r32: real 32 = 1.5
	var r64: real 64 = 2.5

	var a: i32t = 9

	assert sizeof(i8) == 1
	assert sizeof(i16) == 2
	assert sizeof(i32) == 4
	assert sizeof(i64) == 8
	assert sizeof(u8) == 1
	assert sizeof(u32) == 4
	assert sizeof(r32) == 4
	assert sizeof(r64) == 8
	assert sizeof(a) == 4
	assert sizeof(integer 32) == 4
end

