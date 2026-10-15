program test_alias_ctor()

type Number = integer

function Number::Number(n: integer): integer
begin
	return n
end Number::Number

begin
	var n: integer = Number(1)
end test_alias_ctor

