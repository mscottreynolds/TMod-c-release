program test_array(argc: int, argv: ^char[]): int

import printf from "stdio.h"
import memcpy from "string.h"
import void from "stdlib.h"

type pvoid = ^void

const LIMIT = 100

type String = ^char
type StringList = String[]
type Bool = ^bool
type BoolList = array[3] of Bool

type PChar = ^char
type PCharList = PChar[]
type ArrayOfPChar = ^PChar[]

type Vector3 = array[3] of int
type Matrix = array[4] of array[4] of int
type Plain = array of char
type pInt = pointer to int

begin
    var arg: String
    var args: String[]
    var Args: ^String
    var Args5: String[5]
    let n = 3
    var i, x:long, y: int, z: pInt
    var j: long
    var l: array[LIMIT + 1] of char

    var v: Vector3 = {1, 2, 3}
    var m: Matrix       // Zero initialized 
    var pv: ^Vector3 = @v
    var pa: ^array[3] of int = @v

    printf("auto-deref test...\n")
    printf("v=%p pv=%p\n", v as pvoid, pv as pvoid)
    assert pv^[0] == v[0]
    assert pv[1] == v[1]
    assert pv[2] == v[2]
    printf("pv[0]=%d (auto-deref)\n", pv[0])

    assert pa[0] == 1

    if i <> j then
        printf("i <> j\n")
    end
    printf("args: %s\n", argv[0])
    printf("done\n")

    printf("sizeof(l) = %d, LIMIT=%d\n", sizeof(l), LIMIT)

    let w: Vector3 = {2, 3, 4}
    if sizeof(w) > sizeof(v) then
        memcpy(v, w, sizeof(v))
    else
        memcpy(v, w, sizeof(w))
    end
    printf("length of v = %zu\n", sizeof(v) / sizeof(int))
    printf("{")
    for i := 0 to (sizeof(v) / sizeof(int)) - 1 do
        printf("%d,", v[i])
    end
    printf("}\n")

    y := 4
    z := @y
    printf("z = %d\n", z^)

    printf("Vector3 test passed.\n");
    printf("Nested array syntax accepted.\n");
    return 0
end
