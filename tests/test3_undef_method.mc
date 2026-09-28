program test3_undef_method()

(* 0.26: free call with no matching method must fail *)

type T = struct
	x: integer
end


begin
	T::no_such(1)
end
