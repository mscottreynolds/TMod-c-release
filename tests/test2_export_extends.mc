program test2_export_extends()

export type TParent = struct
	x: integer
end

export type TChild = struct extends TParent
	y: integer
end

begin
end

