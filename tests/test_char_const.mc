program test_char_const()

(* A character CONST folds to the host int and emits no C object. *)

const C = 'a'
const NL = '\n'
const HEX = '\x41'
const OCT = '\101'
const FF = '\xff'
const BELL = '\a'
const QUOTE = '\''
const Q = '\q'
const WIDE = '\400'
const PLUS: integer = 'a' + 1
const NEG = -'a'

function hit(ch: char): integer
begin
	switch ch of 
		case C:
			return 1
		else:
			return 0
	end
end

begin
	var buf: array[PLUS] of char

	assert C == 'a'
	assert C == 97
	assert NL == 10
	assert HEX == '\x41'
	assert HEX == 65
	assert OCT == 65
	assert FF == '\xff'
	assert BELL == 7
	assert QUOTE == 39
	assert Q == 'q'
	assert WIDE == 0
	assert PLUS == 98
	assert countof(buf) == 98
	assert NEG == -97
	assert hit('a') == 1
	assert hit('b') == 0
end
