program test3_for_assign(x: z)

(** Expect semantic error when run with -a or -c *)

begin
	for i = 0 to 1 do
		i := 2
	end
end

