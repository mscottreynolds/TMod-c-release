program test_type_ctor()

type Number = integer

function Number::Number(n: integer): integer
begin
	return n
end Number::Number

type Box = union
	i: integer
end

function Box::Box(n: integer): Box
begin
	var b: Box
	b.i := n
	return b
end Box::Box

type Color = enum
	Red,
	Blue
end

function Color::Color(n:integer): Color
begin
	if n == 0 then
		return Red
	end
	return Blue
end Color::Color

type Handle = opaque

function Handle::Handle(): Handle
begin
	var h: Handle = nil
	return h
end Handle::Handle

begin
	var n: integer = Number(1)
	var b: Box = Box(7)
	var c: Color = Color(0)
	var h: Handle = Handle()

	assert n == 1
	assert b.i == 7
	assert c == Red
	assert h == nil
	assert Number::Number(2) == 2
	assert Box::Box(8).i == 8
	assert Color::Color(1) == Blue
end test_type_ctor
