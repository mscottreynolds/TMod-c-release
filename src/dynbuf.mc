module dynbuf()

(**
 * Mod-c
 * By M. Scott Reynolds
 * Date 20 February 2026
 *
 * dynbuf.c - Dynamic null-terminated string buffer with exponential growth.
 *)


import size_t from "stddef.h"
import stderr, fprintf from "stdio.h"
import malloc, realloc, free, exit from "stdlib.h"
import memcpy, strlen from "string.h"


(**
 * Dynamic string buffer with exponential growth and null-termination.
 * All functions maintain null-termination (data[used] == '\0').
 * The bufffer owns its data pointer - caller must call dynbuf_free().
 *)
export type DynBuf = struct
    data: ^char
    size: size_t
    used: size_t
end
export type pDynBuf = pointer to DynBuf


const INITIAL_BUFFER_SIZE: cardinal = 8192u


(**
 * Initialize a dynamic buffer with initial capacity.
 * Exits program on allocation failure.
 *)
export procedure dynbuf_init(b: ^DynBuf) 
begin
    if b == nil then
        fprintf(stderr, "ERROR: dynbuf_init: NULL buffer pointer\n")
        exit(1)
    end

    b^.size := INITIAL_BUFFER_SIZE;
    b^.used := 0;
    b^.data := malloc(b^.size);

    if not b^.data then
        fprintf(stderr, "ERROR: dynbuf_init: malloc(%zu) failed\n", b^.size)
        exit(1)
    end

    b^.data[0] := '\0'      // always null-terminated
end


(**
 * Append a null-terminated string to the buffer.
 * Automatically grows if needed.
 * Exits on reallocation failure.
 *)
export procedure dynbuf_appendn(b: ^DynBuf, str: const ^char, str_len: size_t)
begin
    if b == nil or b^.data == nil or str == nil then
        fprintf(stderr, "ERROR: dynbuf_appendn: invalid argument (NULL pointer)\n")
        exit(1)
    end

    let needed: size_t = b^.used + str_len + 1      // +1 for null terminator

    while needed > b^.size do
        var new_size: size_t
        var new_data: ^char

        if b^.size > 0 then
            new_size := b^.size * 2
        else
            new_size := INITIAL_BUFFER_SIZE
        end

        // Prevent overflow in size calculation
        if new_size / 2 <> b^.size or new_size < b^.size then
            fprintf(stderr, "ERROR: dynbuf_appendn: capacity overflow (current %zu)\n", b^.size)
            exit(1)
        end

        new_data := realloc(b^.data, new_size)
        if not new_data then
            fprintf(stderr, "ERROR: dynbuf_appendn: realloc(%zu) failed\n", new_size)
            exit(1)
        end

        b^.size := new_size
        b^.data := new_data
    end

    memcpy(b^.data + b^.used, str, str_len)
    b^.used += str_len
    b^.data[b^.used] := '\0'

end dynbuf_append


(**
 * Append n chars of a string to the buffer.
 *)
export procedure dynbuf_append(b: ^DynBuf, str: const ^char)
begin
    if b == nil or b^.data == nil or str == nil then
        fprintf(stderr, "ERROR: dynbuf_append: invalid argument (NULL pointer)\n")
        exit(1)
    end

    let str_len: size_t = strlen(str)
    dynbuf_appendn(b, str, str_len)

end dynbuf_append


(**
 * Append a single character to the buffer.
 * Automatically grows if needed.
 * Exits on reallocation failure.
 *)
export procedure dynbuf_append_char(b: ^DynBuf, c: char) 
begin
    if b == nil or b^.data == nil then
        fprintf(stderr, "ERROR: dynbuf_append_char: invalid buffer\n")
        exit(1)
    end

    let needed: size_t = b^.used + 2        // current + char + null

    if needed > b^.size then
        var new_size: size_t
        var new_data: ^char

        if b^.size > 0 then
            new_size := b^.size * 2
        else
            new_size := INITIAL_BUFFER_SIZE
        end

        if new_size / 2 <> b^.size or new_size < b^.size then
            fprintf(stderr, "ERROR: dynbuf_append_char: capacity overflow (current %zu)\n", b^.size)
            exit(1)
        end

        new_data := realloc(b^.data, new_size)
        if  not new_data then
            fprintf(stderr, "ERROR: dynbuf_append_char: realloc(%zu) failed\n", new_size)
            exit(1)
        end

        b^.data := new_data;
        b^.size := new_size;
    end

    b^.data[b^.used] := c
    inc(b^.used)
    b^.data[b^.used] := '\0'

end dynbuf_append_char


(**
 * Free the buffer's memory and reset all fields.
 * Safe to call multiple times or on uninitialized buffer.
 *)
export procedure dynbuf_free(b: ^DynBuf) 
begin
    if b == nil then
        return
    end

    if b^.data then
        free(b^.data)
    end
    b^.data := nil
    b^.size := 0
    b^.used := 0

end dynbuf_free


begin
end dynbuf

