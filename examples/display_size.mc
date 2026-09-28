program display_size()


import printf from "stdio.h"
import intmax_t, uintmax_t, INTPTR_MAX, UINTPTR_MAX from "stdint.h"
import INT_MAX, UINT_MAX, LONG_MAX, LLONG_MAX, ULLONG_MAX from "limits.h"
import SIZE_MAX, size_t from "stddef.h"

type integer = long
type cardinal = unsigned long
type real = double
type uint = unsigned int
type ulong = unsigned long
type long_int = long int
type long_long = long long
type llint = long long int
type ullint = unsigned long long int
type long_double = long double
type TypeData = struct
	name: string
	size: integer
end
type ArrayOfTypes = array[] of TypeData


var type_data: ArrayOfTypes = {
		{ "bool", sizeof(bool) },
		{ "byte", sizeof(byte) }, 
		{ "char", sizeof(char) },
		{ "short", sizeof(short) },
		{ "int", sizeof(int) },
		{ "integer", sizeof(integer) },
		{ "cardinal", sizeof(cardinal) },
		{ "uint", sizeof(uint) },
		{ "long_int", sizeof(long_int) },
		{ "llint", sizeof(llint) },
		{ "long", sizeof(long) },
		{ "long_long", sizeof(long_long) },
		{ "ulong", sizeof(ulong) },
		{ "ullint", sizeof(ullint) },
		{ "real", sizeof(real) },
		{ "float", sizeof(float) },
		{ "double", sizeof(double) },
		{ "long_double", sizeof(long_double) },
		{ "intmax_t", sizeof(intmax_t) },
		{ "uintmax_t", sizeof(uintmax_t) },
		{ "size_t", sizeof(size_t) },
}


begin
	var i : integer = 0
	var n: integer = sizeof(type_data) / sizeof(type_data[0])

	printf("INT_MAX = %ld\n", INT_MAX)
	printf("UINT_MAX = %lu\n", UINT_MAX)
	printf("LONG_MAX = %ld\n", LONG_MAX)
	printf("LLONG_MAX = %lld\n", LLONG_MAX)
	printf("ULLONG_MAX = %llu\n", ULLONG_MAX)
	printf("SIZE_MAX = %zu\n", SIZE_MAX)
	printf("INTPTR_MAX = %lld\n", INTPTR_MAX)
	printf("UINTPTR_MAX = %llu\n", UINTPTR_MAX)
	printf("SIZE_MAX as int = %lld\n", SIZE_MAX as int)
	printf("SIZE_MAX as long = %lld\n", SIZE_MAX as long)
	printf("SIZE_MAX as integer = %lld\n", SIZE_MAX as integer)

	printf("%12s %12s\n", "type", "size (bits)")
	printf("-------------------------\n")
	for i := 1 to n do
		var t: TypeData = type_data[i-1]
		printf("%12s %12zu\n", t.name, t.size * 8 )
	end

	printf("\n")
end display_size

(* msr/msr *)
