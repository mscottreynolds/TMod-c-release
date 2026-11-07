program test3_else_label_dup()

type Color = enum
	Red,
	Green
end

begin
	var c: Color = Red
	switch c of 
		case Red:
		else Red, default:
	end
end test3_else_label_dup

