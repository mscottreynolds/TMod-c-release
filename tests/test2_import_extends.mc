program test2_import_extends()

(*
 * Reads tests/test2_export_extends.mh
 * (tmodc tests/test2_export_extends.mc -M)
 *)

import TParent, TChild from test2_export_extends

var c: TChild

begin
	c.x := 1
	c.y := 2
end
