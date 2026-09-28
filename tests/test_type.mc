program test_type()

import FILE, printf from "stdio.h"

// type integer = int
type pchar = ^char
// type INTEGER = integer
type pFILE = ^FILE
// type MyInt = INTEGER
type StringPtr = ^pchar
type long_long = long long
type unsigned_int = unsigned int
type array5_of_int = int[5]
type array_of_int = int[]

var f: pFILE = nil

begin
    // Test array of literal
    var a: array5_of_int = {3, 1, 4, 1, 5, }
    var b: array_of_int = { 3, 1, 4, 1, 5, 9, 2, 6, }
    var x: long_long = 1234577890
    var y: unsigned_int = 4234

    printf("%d\n", a[0])
    
	printf("Types parsed.\n")
end
