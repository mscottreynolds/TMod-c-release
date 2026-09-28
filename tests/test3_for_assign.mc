program test3_for_assign(x: z)

(** Expect semantic error when run with -a or -c *)

var i: integer

begin
	for i := 1 to 10 do
		i := 5
	end
end

