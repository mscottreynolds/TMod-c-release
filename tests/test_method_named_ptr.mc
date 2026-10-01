program test_method_named_ptr()

(* Named pointer alias is the owner: Handle = ^integer is instance;
 * ^Handle peels. Handle::from is static (first formal <> Handle). *)

type Handle = ^integer

procedure Handle::set(s: Handle, n: integer)
begin
	if s <> nil then
		s^ := n
	end
end Handle::set


function Handle::get(s: Handle): integer
begin
	if s == nil then
		return 0
	end
	return s^
end Handle::get

function Handle::new(p: ^integer): Handle
begin
	return p
end Handle::new


begin
	var cell: integer = 0
	var h: Handle
	var p: ^Handle

	h := Handle::new(@cell)
	h.set(7)
	assert h.get() == 7
	assert Handle::get(h) == 7
	assert cell == 7

	p := @h
	p.set(9)
	assert p.get() == 9
	assert Handle::get(p) == 9
	assert cell == 9

	// ^Handle[i] is Handle; Handle[i] is integer
	assert p[0].get() == 9
	p[0].set(11)
	assert h.get() == 11
	assert p[0].get() == 11
	assert h[0] == 11
end

