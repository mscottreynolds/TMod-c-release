program test3_const_param_member()

type Point = struct
	x: integer
end

procedure Bad(const p: Point)
begin
	p.x := 1
end

begin
	var q: Point = {}
	Bad(q)
end
