program test3_callable_field_ambig()

type THandler = procedure (n: integer)

type S = struct
	m: THandler
end

procedure S::m(self: S, n: integer)
begin
end

begin
	var s: S
	s.m(1) 			// Both field and instance method
end
