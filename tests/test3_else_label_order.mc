program test3_else_label_order()

type Color = enum
	Red,
	Green
end

begin
	var c: Color = Red
	switch c of
		case Red:
		else default, Green:
	end
end test3_else_label_order

