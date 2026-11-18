program Pi800()

(**
 * pi800.mc
 * Dik T. Winter's spigot algorithm for the first 800 digits of Pi.
 *)

import printf from "stdio.h"

const digitsPerGroup = 4
const base = 10000 			// 10^digitsPerGroup
const terms = 2800 			// 14 * 200 => 800 digits
const arraySize = terms + 1

var remainders: array[arraySize] of integer
var index, termCount, denominator, accumulator, carry: integer

begin
	// Initialize remainder array to 2000 (base/5)
	for index := 0 to terms-1 do
		remainders[index] := base div 5
	end
	remainders[terms] := 0

	carry := 0
	termCount := terms

	while termCount > 0 do
		accumulator := 0
		index := termCount

		// Inner spigot loop: extract next digits
		while index > 0 do
			accumulator := accumulator + remainders[index] * base
			denominator := 2 * index - 1
			remainders[index] := accumulator mod denominator
			accumulator := accumulator div denominator
			index := index - 1
			if index > 0 then
				accumulator := accumulator * index
			end
		end

		// Output next group of 4 digits
		printf("%.*d", digitsPerGroup, carry + accumulator div base)
		carry := accumulator mod base

		termCount := termCount - 14
	end

	printf("\n")
end

(* gk/msr *)
