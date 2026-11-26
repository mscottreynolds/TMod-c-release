program test3_slice_fp()

type TShow = function(s: char[]): integer

function show(s: char[]): integer
begin
	return countof(s)
end

begin
	var fp: TShow
	var p: ^char

	fp := show
	fp(p)
end
