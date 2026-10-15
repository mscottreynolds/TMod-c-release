program test_union_ctor()

type Box = union
	i: integer
end

function Box::Box(n: integer): Box
begin
	var b: Box
	b.i := n
	return b
end Box::Box

begin
	var b: Box = Box(1)
end test_union_ctor

