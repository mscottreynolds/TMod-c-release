program test3_import_extends_parent()

(*
 * Reads tests/test2_export_extends.mh
 * (tmodc tests/test2_export_extends.mc M)
 *)

import TChild from test2_export_extends

var c: TChild

begin
	c.x := 1
end
