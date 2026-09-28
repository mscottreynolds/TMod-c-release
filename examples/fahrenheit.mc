program fahrenheit()

(**
 * Print Fahrenheit-Celsius table for
 * fahr = 2,  20, ... 300; floating-point version
 *)


import printf from "stdio.h"


begin
    var 
        fahr,
        celsius: real
    var 
        lower, 
        upper, 
        step: integer

    lower := 0              // lower limit of temperature table
    upper := 300            // upper limit
    step := 20              // step size

    printf("%3s %6s\n", "F", "C")
    printf("--- ------\n")
    fahr := lower
    while fahr <= upper do
	   	celsius := (5.0/9.0) * (fahr-32.0)
	   	printf("%3.0f %6.1f\n", fahr, celsius)
	   	fahr := fahr + step
	end
end fahrenheit

(* msr/msr *)
