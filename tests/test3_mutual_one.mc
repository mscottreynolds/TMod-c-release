program test3_mutual_one()

recursive function is_even(n: integer): bool
begin
	if n == 0 then
		return true
	end
	return is_odd(n - 1)
end

function is_odd(n: integer): bool
begin
	if n == 0 then
		return false
	end
	return is_even(n - 1)
end

begin
	assert is_odd(1), "odd"
end
