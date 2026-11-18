program test_infer_brace()

type Count = integer

type Point = struct
	x: integer
	y: integer
end

const A = 10
const table = { 10, 20 }

begin
	var xs = { 1, 2, 3, }
	var grid = { { 1, 2 }, { 3, 4 } }
	var pick = 0 < 1 ? { 7, 8 } : { 9, 10 }
	var letters = { 'a', 'b' }
	var words = { "one", "two" }
	var n: Count = 4
	var both = { 1, n }
	var from_const = { A, 20 }
	let row = { 4, 5, 6 }
	let named: array[2] of integer = { 8, 9 }
	let q: Point = { 3, 4 }

	assert countof(xs) == 3
	assert xs[0] == 1
	assert xs[2] == 3
	assert countof(grid) == 2
	assert grid[1][1] == 4
	assert countof(pick) == 2
	assert pick[0] == 7
	assert pick[1] == 8
	assert countof(letters) == 2
	assert letters[0] == 'a'
	assert countof(words) == 2
	assert countof(both) == 2
	assert both[1] == 4
	assert from_const[0] == 10
	assert countof(table) == 2
	assert table[1] == 20
	assert countof(row) == 3
	assert row[2] == 6
	assert named[1] == 9
	assert q.x == 3
	assert q.y == 4
	assert words[0][1] == 'n'
	assert words[1][0] == 't'
end

