program test2_export_fn_type()

export type TFn = function(n: integer): integer

export type TBox = struct
	fn: TFn
end

begin
end
