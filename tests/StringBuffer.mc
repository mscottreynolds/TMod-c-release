module StringBuffer(s: string): TStringBuffer

(**
 * StringBuffer
 * By M. Scott Reynolds
 * Date 20 February 2026
 *
 * TStringBuffer - Dynamic null-terminated string buffer with exponential growth.
 *)


import size_t from "stddef.h"
import stderr, fprintf from "stdio.h"
import malloc, realloc, exit, free from "stdlib.h"
import memcpy, strlen from "string.h"

(**
 * Dynamic string buffer with exponential growth and null-termination.
 * All functions maintain null-termination (_data[_length] == '\0').
 * The bufffer owns its _data pointer - caller must call TStringBuffer::free().
 *)
export type TStringBuffer = struct
    _data: ^char
    _capacity: size_t
    _length: size_t
end
export type pStringBuffer = ^TStringBuffer


const INITIAL_BUFFER_SIZE = 1024u


(**
 * Get pointer to _data
 *)
export function TStringBuffer::getData(ref b: TStringBuffer): ^char
begin
    return b._data
end TStringBuffer::getData


export function pStringBuffer::getData(p: pStringBuffer): ^char
begin
    require p <> nil
    return p^._data
end pStringBuffer::getData


(**
 * Get the current capacity
 *)
export function TStringBuffer::getCapacity(ref b: TStringBuffer): size_t
begin
    return b._capacity
end TStringBuffer::getCapacity


(**
 * Get the current length
 *)
export function TStringBuffer::getLength(ref b: TStringBuffer): size_t
begin
    return b._length
end TStringBuffer::getLength


(**
 * Initialize a dynamic string buffer with initial default capacity.
 * Exits program on allocation failure.
 *)
export procedure TStringBuffer::init(ref b: TStringBuffer)
begin
    b._capacity := INITIAL_BUFFER_SIZE;
    b._length := 0;
    b._data := malloc(b._capacity);

    if not b._data then
        fprintf(stderr, "ERROR: TStringBuffer::init: malloc(%zu) failed\n", b._capacity)
        exit(1)
    end

    b._data[0] := '\0'      // always null-terminated
end TStringBuffer::init


(**
 * Append a null-terminated string to the buffer.
 * Automatically grows if needed.
 * Exits on reallocation failure.
 *)
export procedure TStringBuffer::appendn(ref b: TStringBuffer, str: const ^char, str_len: size_t)
begin
    if str == nil or str_len == 0 or b._data == nil then
        return
    end

    let needed: size_t = b._length + str_len + 1      // +1 for null terminator

    while needed > b._capacity do
        var new_capacity: size_t
        var new_data: ^char

        if b._capacity > 0 then
            new_capacity := b._capacity * 2
        else
            new_capacity := INITIAL_BUFFER_SIZE
        end

        // Prevent overflow in capacity calculation
        if new_capacity / 2 <> b._capacity or new_capacity < b._capacity then
            fprintf(stderr, "ERROR: TStringBuffer::appendn: _capacity overflow (current %zu)\n", b._capacity)
            exit(1)
        end

        new_data := realloc(b._data, new_capacity)
        if not new_data then
            fprintf(stderr, "ERROR: TStringBuffer::appendn: realloc(%zu) failed\n", new_capacity)
            exit(1)
        end

        b._capacity := new_capacity
        b._data := new_data
    end

    memcpy(b._data + b._length, str, str_len)
    b._length += str_len
    b._data[b._length] := '\0'

end TStringBuffer::appendn


(**
 * Append n chars of a string to the buffer.
 *)
export procedure TStringBuffer::append(ref b: TStringBuffer, str: const ^char)
begin
    if str == nil then
        return
    end

    let str_len: size_t = strlen(str)
    TStringBuffer::appendn(b, str, str_len)

end TStringBuffer::append


(**
 * Append a single character to the buffer.
 * Automatically grows if needed.
 * Exits on reallocation failure.
 *)
export procedure TStringBuffer::append_char(ref b: TStringBuffer, c: char) 
begin
    let needed: size_t = b._length + 2        // current + char + null

    if needed > b._capacity then
        var new_capacity: size_t
        var new_data: ^char

        if b._capacity > 0 then
            new_capacity := b._capacity * 2
        else
            new_capacity := INITIAL_BUFFER_SIZE
        end

        if new_capacity / 2 <> b._capacity or new_capacity < b._capacity then
            fprintf(stderr, "ERROR: TStringBuffer::append_char: _capacity overflow (current %zu)\n", b._capacity)
            exit(1)
        end

        new_data := realloc(b._data, new_capacity)
        if  not new_data then
            fprintf(stderr, "ERROR: TStringBuffer::append_char: realloc(%zu) failed\n", new_capacity)
            exit(1)
        end

        b._data := new_data;
        b._capacity := new_capacity;
    end

    b._data[b._length] := c
    inc(b._length)
    b._data[b._length] := '\0'

end TStringBuffer::append_char


(**
 * Free the buffer's memory and reset all fields.
 * Safe to call multiple times or on uninitialized buffer.
 *)
export procedure TStringBuffer::free(ref b: TStringBuffer) 
begin
    if b._data then
        free(b._data)
    end
    b._data := nil
    b._capacity := 0
    b._length := 0

end TStringBuffer::free


(* Setup and return an initialized string buffer. Caller is responsible for free. *)
begin
    var sb: TStringBuffer

    sb.init()
    if strlen(s) > 0 then
        sb.append(s)
    end

    return sb

end StringBuffer
