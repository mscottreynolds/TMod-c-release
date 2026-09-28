program test3_infer()
begin
	// 1 + 2 has no type_of_expr yet => cannot infer
	var x = 1 + 2
	var y = true ? 1 : 2
end

