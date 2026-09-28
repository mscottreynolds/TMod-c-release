program test_enum()

import printf from "stdio.h"

type Color = enum
	Red,
	Green,
	Blue
end

function color_name(c: Color): const ^char
begin
	switch c of
		case Red:	return "red"
		case Green:	return "green"
		case Blue:	return "blue"
		else:		return "?"
	end
end color_name

begin
	var c = Green
	printf("%s\n", color_name(c))
end test_enum
