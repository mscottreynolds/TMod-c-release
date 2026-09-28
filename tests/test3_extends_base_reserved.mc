program test3_extends_base_reserved()

type Parent = struct
	x: integer
end

type Bad = struct extends Parent
	base: integer
end

begin
end
