program test2_mh_enum_import()

import Color, Red, Green, Blue from "fixtures/colors.mh"

function name_of(c: Color): const ^char
begin
	switch c of
		case Red: 	return "red"
		case Green: return "green"
		case Blue:	return "blue"
		else:		return "?"
	end
end name_of

begin
end

