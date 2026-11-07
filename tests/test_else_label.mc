program test_else_label()

import exit from "stdlib.h"

type Color = enum
	Red,
	Green,
	Blue,
	Yellow
end

function bucket(c: Color): integer
begin
	switch c of
		case Red:
			return 1
		else Green, Blue, default:
			return 2
	end
end bucket

function klass(n: integer): integer
begin
	switch n of 
		case 1: 
			return 1
		else 2, 3, default:
			return 9
	end
end klass

function letter(ch: char): integer
begin
	switch ch of
		case 'a':
			return 1
		else 'b', 'c', default:
			return 9
	end
end letter

function only_default(n: integer): integer
begin
	switch n of 
		case 1:
			return 1
		else default:
			return 7
	end
end only_default

begin
	if bucket(Red) <> 1 then exit(1); end
	if bucket(Green) <> 2 then exit(1); end
	if bucket(Blue) <> 2 then exit(1); end
	if bucket(Yellow) <> 2 then exit(1); end
	if klass(1) <> 1 then exit(1); end
	if klass(2) <> 9 then exit(1); end
	if klass(3) <> 9 then exit(1); end
	if klass(4) <> 9 then exit(1); end
	if letter('a') <> 1 then exit(1); end
	if letter('b') <> 9 then exit(1); end
	if letter('c') <> 9 then exit(1); end
	if letter('d') <> 9 then exit(1); end
	if only_default(1) <> 1 then exit(1); end
	if only_default(5) <> 7 then exit(1); end
end test_else_label

