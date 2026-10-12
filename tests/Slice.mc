module Slice()

(**
 * A generic slice object for an array of items (objects/structs/etc.).
 *)

import printf 
    from "stdio.h"
import malloc, free, void 
    from "stdlib.h"
import strncpy, snprintf, strlen, 
    from "string.h"


(**
 * Slice structure. Contains a pointer to an array of items
 * as `const ^byte`. Create new ones with `slice::new(...)`.
 *)
export type slice = struct 
    value: const ^byte      // pointer to unknown type of object
    size: integer           // Size of a single element of the object.
    count: integer          // Number of elements in the object. 
end


(**
 * Creae a new slice from an object.
 * @param value = pointer to some array of records.
 * @param size = size of an individual record in the array.
 * @param count = count of records in the array.
 * @return Return a new slice object.
 *)
export function slice::new(value: ^opaque, size: integer, count: integer): slice
begin
    require value <> nil and size > 0 and count >= 0

    var sl: slice
    sl.value := value as ^byte
    sl.size := size
    sl.count := count
    return sl
end


(**
 * Return the slice value as a `string`
 *)
export function slice::asString(s: slice): string
begin
    require s.value <> nil

    return s.value as string
end


(**
 * Return the value of the slice, pointer to an array of records, etc.
 *)
export function slice::value(s: slice): const ^opaque
begin
    require s.value <> nil

    var v: const ^byte = s.value
    return v
end


(**
 * Return the count of records in this slice.)
 *)
export function slice::count(s: slice): integer
begin
    require s.count >= 0

    return s.count
end


(**
 * Return the size of an individual record/item.
 *)
export function slice::size(s: slice): integer
begin
    require s.size > 0
    return s.size
end


(**
 * Create and return a new slice from an array of char.
 *)
export function slice::fromChar(c: array[] of char, length: integer): slice
begin
    require length >= 0 and c <> nil

    var sl: slice
    sl.value := c as ^byte
    sl.size := sizeof(char)
    sl.count := length
    return sl
end


(**
 * Create and return a new slice from a string.
 *)
export function slice::fromString(s: const ^char, length: integer): slice
begin
    require s <> nil and length >= 0

    var sl: slice
    sl.value := s as const ^byte
    sl.size := sizeof(char)
    sl.count := length
    return sl
end


(**
 * Create and return a new slice for items starting at `start`
 * with count of items. Size of individual items remains the same.
 * Indexes are zero based. 
 *)
export function slice::slice(self: slice, start: integer, count: integer): slice
begin
    require self.value <> nil and 
        start >= 0 and start < self.count and 
        count >= 0 and count <= self.count and
        (start + count) <= self.count

    var sl: slice
    sl.size := self.size
    sl.count := count
    sl.value := (self.value + start * self.size) as const ^byte
    return sl
end


(**
 * Get and return record/item at `index`.
 * Index is zero based.
 *)
export function slice::get(self: slice, index: integer): const ^opaque
begin
    assert index < self.count and index >= 0

    let p: const ^byte = self.value
    let item: const ^byte = p + index * self.size
    return item
end


(* Helper routine. *)
procedure println(s: slice)
begin
    printf("%.*s\n", s.count(), s.asString())
end


export function main(): integer
begin
    Slice()
    return 0
end


(**
 * Test the various methods for slice.
 *)
begin
    var hello: string = "hello"
    var t: slice = slice::fromString(hello, strlen(hello) as integer)
    var s: slice = t.slice(1, 4)
    var c: array[1024] of char

    println(t)
    println(s)

    let u: slice = slice::fromString(t.asString(), 3)
    println(u)

    snprintf(c, countof(c), "An array of char turned slice.")

    let v: slice = slice::fromChar(c, countof(c))
    println(v)
    printf("v.count=%d, v.size=%d\n", v.count, v.size)
    printf("strlen(c)=%d\n", strlen(v.asString()) as integer)

    let half: slice = v.slice(0, strlen(v.asString()) as integer /2)
    printf("half=%.*s\n", half.count, half.asString())

    begin
        var more: array[20] of slice
        let m: slice = slice::new(more, sizeof(slice), countof(more))

        printf("sizeof(more)=%d\n", sizeof(more))
        printf("countof(more)=%d\n", countof(more))
        printf("sizeof(slice)=%d\n", sizeof(slice))
        printf("sizeof(m)=%d\n", sizeof(m))
        printf("m.size=%d\n", m.size)
        printf("m.count=%d\n", m.count)
    end
end Slice

