program test3_import_union_field()

(*
 * Reads tests/test2_export_union.mh
 * (tmodc tests/test2_export_union.mc -M)
 *)

import TValue from test2_export_union

var v: TValue

begin
	v.no_such_field := 1
end
