program test3_infer_brace_width()

(* integer and integer 32 stay distinct, so this must not infer. *)

begin
	var w: integer 32 = 1
	var xs = { 1, w }
end
