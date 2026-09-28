program test3_let_addr_var()


begin
	let n: integer = 0
	var pc: ^integer = @n 			// mutable pointer on @ LET, not legal.

end

