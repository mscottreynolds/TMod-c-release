program test_opaque_ptr()

import printf from "stdio.h"

type Slot = struct
	p: ^opaque
	c: const ^opaque
end

procedure take(p: ^opaque)
begin
	assert p == nil
end

procedure take_row(row: array[] of ^opaque)
begin
	assert row[0] == nil
end

function id(p: ^opaque): ^opaque
begin
	return p
end

function id_ptr(p: POINTER TO opaque): ^opaque
begin
	return p
end


begin
	var p: ^opaque = nil
	var q: POINTER TO opaque = nil
	var c: const ^opaque = nil
	var a: array[2] of ^opaque
	var s: Slot

	p := nil as ^opaque
	a[0] := nil
	a[1] := p
	s.p := id(p)
	s.c := c
	q := id_ptr(q)
	take(p)
	take_row(a)
	assert p == nil
	assert q == nil
	assert c == nil
	assert s.p == nil
	assert a[0] == nil
	assert sizeof(^opaque) == sizeof(p)
	printf("opaque ptr ok\n")
end test_opaque_ptr

