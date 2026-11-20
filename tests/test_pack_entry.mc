program fixtures.packentry()

export function answer(): integer
begin
	return 4
end

begin
	assert answer() == 4
end
