program test2_import_fn_type()

(*
 * tmodc tests/test2_export_fn_type.mc -M
 *)

import TFn, TBox from test2_export_fn_type

var b: TBox

begin
	(b.fn(1))
end
