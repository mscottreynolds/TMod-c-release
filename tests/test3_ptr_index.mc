program test3_ptr_index()


type Cell = struct
	n: integer
end


begin
	var cells: array[1] of Cell
	var p: ^Cell

	p := @cells[0]
	p[0].no_such_field := 1
end test3_ptr_index


(* gk/msr *)
