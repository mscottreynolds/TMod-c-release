program test3_method_named_ptr()

(* Handle::from is static; instance syntax must fail. *)

type Handle = ^integer


function Handle::new(p: ^integer): Handle
begin
	return p
end Handle::new


begin
	var cell: integer = 0
	var h: Handle

	h := Handle::new(@cell)
	h.new(@cell)
end

