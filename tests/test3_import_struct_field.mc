program test3_import_struct_field()

(**
 * Alphabetically should run after test2_export_struct.
 * Will read test2_export_struct.mh, 
 * which needs to be created manually `tmodc tests/test2_export_struct.mc -M`
 *)

import TName from test2_export_struct

var n: TName

begin
    n.no_such_field := 1
end

