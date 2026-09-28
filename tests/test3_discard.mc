program test3_discard()

(* 13b Policy A: bare call of a function with known result must fail *)

function has_result(): integer
begin
	return 1
end

begin
	has_result()
end
