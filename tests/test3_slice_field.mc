program test3_slice_field()

type TShow = function(s: char[]): integer

type Box = struct
	h: TShow
end

function show(s: char[]): integer
begin
	return countof(s)
end

begin
	var box: Box
	var p: ^char

	box.h := show
	(box.h(p))
end
