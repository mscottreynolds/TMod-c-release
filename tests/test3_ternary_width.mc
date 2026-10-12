program test3_ternary_width()
(*
 *integer 32 and plain integer literal are different static types, 
 * so this must fail semantic analysis.
 *)


begin
	var n: integer 32
	var m = true ? n : 1
end

