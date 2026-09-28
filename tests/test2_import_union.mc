program test2_import_union()

(*
 * Reads tests/test2_export_union.mh
 * (tmodc tests/test2_export_union.mc -M)
 *)

import TValue from test2_export_union

var v: TValue

begin
	v.i := 42
	v.f := 1.5
end
