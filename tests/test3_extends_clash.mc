program test3_extends_clash()

type Parent = struct
	name: integer
end

type Bad = struct extends Parent
	name: integer
end

begin
end

