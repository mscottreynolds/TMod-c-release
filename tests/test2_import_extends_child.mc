program test2_import_extends_child()

(*
 * Import Child only. Own field y is on the export line.
 * Parent field x is the next test (test3)
 * Reads tests/test2_export_extends.mh
 *)

import TChild from test2_export_extends

var c: TChild

begin
	c.y := 2
end
