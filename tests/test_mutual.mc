program test_mutual()

recursive function is_even(n: integer): bool
begin
	if n == 0 then
		return true
	end
	return is_odd(n - 1)
end

recursive function is_odd(n: integer): bool
begin
	if n == 0 then
		return false
	end
	return is_even(n - 1)
end

begin
	assert is_even(4), "4 is even"
	assert is_odd(3), "3 is odd"
	assert not is_even(3), "3 is not even"
end
