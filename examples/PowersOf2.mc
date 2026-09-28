program PowersOf2()

(**
 * TMod-c port of PowersOf2 example comes from
 * "Programming in Modula-2", by Niklaus Wirth
 * Third, corrected edition, pg. 41-42
 *)

import printf from "stdio.h"

const m = 11, n = 32 	// M ~ N * log(2)

begin
	var i, j, k, exp: cardinal
	var c, r, t: cardinal
	var d: array[m] of cardinal
	var f: array[n] of cardinal

	d[0] := 1
	k := 1
	for exp := 1 to n do
		// compute d = 2 ^ exp by d := 2 * d
		c := 0 		// carry
		for i := 0 to k-1 do
			t := 2 * d[i] + c
			if t >= 10 then
				d[i] := t - 10
				c := 1
			else
				d[i] := t
				c := 0
			end
		end
		if c > 0 then
			d[k] := 1
			k := k + 1
		end

		// output d[k-1] ... d[0]
		i := m
		repeat 
			i := i - 1
			printf(" ")
		until i == k
		repeat
			i := i - 1
			printf("%c", (d[i] + '0'))
		until i == 0
		printf("%4u", exp)

		// compute and output f = 2 ^ (-exp) by f := f div 2
		printf("  0.")
		r := 0 				//remainder
		for j := 1 to exp-1 do
			r := 10 * r + f[j]
			f[j] := r div 2
			r := r mod 2
			printf("%c", (f[j] + '0'))
		end
		f[exp] := 5
		printf("5")
		printf("\n")
	end
end PowersOf2

(* nw/msr *)
