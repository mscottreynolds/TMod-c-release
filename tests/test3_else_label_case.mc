program test3_else_label_case()

type Color = enum
	Red,
	Green
end

begin
	var c: Color = Red
	switch c of
		case Red:
		else case Green, default:
	end
end test3_else_label_case

