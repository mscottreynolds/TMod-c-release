program test_type_order()

import printf from "stdio.h"

export type pNode = ^TNode
export type ppNode = ^pNode
export type pWord = ^TWord

export type TNode = struct
	next: pNode
	other: ^TOther
	value: integer
end

export type TOther = struct
	node: ppNode
end

export type TWord = union
	i: integer
	b: byte
end

export type pColor = ^Color
export type Color = enum
	Red,
	Blue
end

type pHidden = ^Hidden
type Hidden = struct
	next: pHidden
end

begin
	var n: TNode
	var p: pNode = @n
	var pp: ppNode = @p
	var other: TOther
	var w: TWord
	var pw: pWord = @w
	var h: Hidden
	var ph: pHidden = @h
	var color: Color = Red
	var c: pColor = @color

	n.value := 1
	n.next := nil
	n.other := @other
	other.node := 00
	w.i := 1
	h.next := ph
	if p^.value == 1 and pw^.i == 1 and c <> nil and ph^.next == @h then
		printf("test_type_order ok\n")
	end
end test_type_order


