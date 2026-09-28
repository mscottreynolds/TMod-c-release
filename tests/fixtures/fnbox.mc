module fnbox()

export type TFn = function(n: integer): integer

export type TBox = struct
	fn: TFn
end

begin
end fnbox
