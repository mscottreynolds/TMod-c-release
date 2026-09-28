module Tsds()
(* SDSLib 2.0 -- A C dynamic strings library
 * (https://github.com/antirez/sds)
 *
 * Copyright (c) 2006-2015, Salvatore Sanfilippo <antirez at gmail dot com>
 * Copyright (c) 2015, Oran Agra
 * Copyright (c) 2015, Redis Labs, Inc
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *   * Redistributions of source code must retain the above copyright notice,
 *     this list of conditions and the following disclaimer.
 *   * Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *   * Neither the name of Redis nor the names of its contributors may be used
 *     to endorse or promote products derived from this software without
 *     specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *
 * 22 Sept 2026: 
 * Port to TMod-c by M. Scott Reynolds
 *)


(* ==== Imports ==== *)


import from "stdio.h"
import from "stdlib.h"
import memset, memcpy, strlen, strchr, memmove, from "string.h"
import from "ctype.h"
import LLONG_MIN, LLONG_MAX from "limits.h"
import void, size_t from "stddef.h"
import ssize_t from "sys/types.h"
import va_list, va_copy, vsnprintf, va_end, va_start, va_arg from "stdarg.h"
import uint8_t, uint16_t, uint32_t, uint64_t from "stdint.h"


(* ==== Definitions ==== *)


(* ==== from sdsalloc.h ==== *)
(* SDS allocator selection.
 *
 * This file is used in order to change the SDS allocator at compile time.
 * Just define the following defines to what you want to use. Also add
 * the include of your alternate allocator if needed (not needed in order
 * to use the default libc allocator). *)

define s_malloc malloc
define s_realloc realloc
define s_free free
(* ==== end sdaalloc.h ==== *)

export define SDS_MAX_PREALLOC (1024*1024)

(* FIXME: 

In sds.h:
    extern const char *SDS_NOINIT;
and in sds.c:
    const char *SDS_NOINIT = "SDS_NOINIT";

If Tsds.mc:
    extern export var SDS_NOINIT: const ^char = "SDS_NOINIT"
or
    export extern var SDS_NOINIT: const ^char = "SDS_NOINIT"
then Tsds.c:
    extern const char* SDS_NOINIT;
and Tsds.h:
    extern const char* SDS_NOINIT;

If Tsds.mc:
    extern var SDS_NOINIT: const ^char = "SDS_NOINIT"
then Tsds.c:
    extern const char* SDS_NOINIT;
and Tsds.h:
    !! nothing !!

If Tsds.mc:
    export var SDS_NOINIT: const ^char = "SDS_NOINIT"
then Tsds.c:
    static const char* SDS_NOINIT = "SDS_NOINIT";
and Tsds.h:
    const char* SDS_NOINIT = "SDS_NOINIT";
and CC:
    error: redefinition of ‘SDS_NOINIT

*)

var SDS_NOINIT: const ^char = "SDS_NOINIT"

export type pchar = ^char
export type VOID = void
export type llong = long long
export type ullong = unsigned long long
export type uchar = unsigned char
export type uint = unsigned int
export type sds = ^char

(* Note: sdshdr5 is never used, we just access the flags byte directly.
 * However is here to document the layout of type 5 SDS strings. *)

export type sdshdr5 = packed struct
    flags: uchar            // 3 lsb of type, and 5 msb of string length
    buf: array[] of char
end

export type sdshdr8 = packed struct
    length: uint8_t         // used
    alloc: uint8_t          // excluding the header and null terminator
    flags: uchar            // 3 lsb of type, 5 unused bits
    buf: array[] of char
end

export type sdshdr16 = packed struct
    length: uint16_t        // used
    alloc: uint16_t         // excluding the header and null terminator
    flags: uchar            // 3 lsb of type, 5 unused bits
    buf: array[] of char
end

export type sdshdr32 = packed struct
    length: uint32_t        // used
    alloc: uint32_t         // excluding the header and null terminator
    flags: uchar            // 3 lsb of type, 5 unused bits
    buf: array[] of char
end

export type sdshdr64 = packed struct
    length: uint64_t        // used
    alloc: uint64_t         // excluding the header and null terminator
    flags: uchar            // 3 lsb of type, 5 unused bits
    buf: array[] of char
end

export define SDS_TYPE_5  0
export define SDS_TYPE_8  1
export define SDS_TYPE_16 2
export define SDS_TYPE_32 3
export define SDS_TYPE_64 4
export define SDS_TYPE_MASK 7
export define SDS_TYPE_BITS 3
export define SDS_HDR_VAR(T, s) struct sdshdr##T *sh = (void*)((s)-(sizeof(struct sdshdr##T)));
export define SDS_HDR(T, s) ((struct sdshdr##T *)((s)-(sizeof(struct sdshdr##T))))
export define SDS_TYPE_5_LEN(f) ((f)>>SDS_TYPE_BITS)

export define SDS_HDR_SH(T, s) (void*)((s)-(sizeof(struct sdshdr##T)))


(* ==== Previously inlined C functions that were in sds.h ==== *)


(* TODO: Implement INLINE keyword for TMod-c as a passthrough hint for generated C code. *)

(**
 * Return length of s
 *)
export function sdslen(s: sds): size_t
begin
    var flags: uchar = s[-1]
    switch (flags & SDS_TYPE_MASK) of
        case SDS_TYPE_5:
            return SDS_TYPE_5_LEN(flags)
        case SDS_TYPE_8:
            let sh: ^sdshdr8 = (s-sizeof(sdshdr8)) as ^sdshdr8      // SDS_HDR_VAR
            return sh.length
        case SDS_TYPE_16:
            let sh: ^sdshdr16 = (s-sizeof(sdshdr16)) as ^sdshdr16   // SDS_HDR_VAR
            return sh.length
        case SDS_TYPE_32:
            let sh: ^sdshdr32 = (s-sizeof(sdshdr32)) as ^sdshdr32   // SDS_HDR_VAR
            return sh.length
        case SDS_TYPE_64:
            let sh: ^sdshdr64 = (s-sizeof(sdshdr64)) as ^sdshdr64   // SDS_HDR_VAR
            return sh.length
        else:
            return 0
    end
end sdslen


(**
 * Return available space
 *)
export function sdsavail(s: sds): size_t
begin
    var flags: uchar = s[-1]
    switch (flags & SDS_TYPE_MASK) of
        case SDS_TYPE_5:
            return 0
        case SDS_TYPE_8:
            let sh: ^sdshdr8 = (s-sizeof(sdshdr8)) as ^sdshdr8      // SDS_HDR_VAR
            return sh.alloc - sh.length
        case SDS_TYPE_16:
            let sh: ^sdshdr16 = (s-sizeof(sdshdr16)) as ^sdshdr16   // SDS_HDR_VAR
            return sh.alloc - sh.length
        case SDS_TYPE_32:
            let sh: ^sdshdr32 = (s-sizeof(sdshdr32)) as ^sdshdr32   // SDS_HDR_VAR
            return sh.alloc - sh.length
        case SDS_TYPE_64:
            let sh: ^sdshdr64 = (s-sizeof(sdshdr64)) as ^sdshdr64   // SDS_HDR_VAR
            return sh.alloc - sh.length
        else:
            return 0
    end
end sdsavail


(**
 * Set length of s to newlen
 *)
export procedure sdssetlen(s: sds, newlen: size_t)
begin
    var flags: uchar = s[-1]
    switch (flags & SDS_TYPE_MASK) of
        case SDS_TYPE_5:
            var fp: ^uchar = (s as ^uchar)-1
            fp^ := SDS_TYPE_5 | (newlen << SDS_TYPE_BITS)

        case SDS_TYPE_8:
            SDS_HDR(8, s)^.length := newlen

        case SDS_TYPE_16:
            SDS_HDR(16, s)^.length := newlen

        case SDS_TYPE_32:
            SDS_HDR(32, s)^.length := newlen

        case SDS_TYPE_64:
            SDS_HDR(64, s)^.length := newlen

        else:
            ;
    end
end sdssetlen


(**
 * Increase length by inc
 *)
export procedure sdsinclen(s: sds, inc_: size_t)
begin
    var flags: uchar = s[-1]
    switch (flags & SDS_TYPE_MASK) of
        case SDS_TYPE_5:
            var fp: ^uchar = (s as ^uchar)-1
            var newlen: uchar = SDS_TYPE_5_LEN(flags) + inc_
            fp^ := SDS_TYPE_5 | (newlen << SDS_TYPE_BITS)

        case SDS_TYPE_8:
            SDS_HDR(8, s)^.length += inc_

        case SDS_TYPE_16:
            SDS_HDR(16, s)^.length += inc_

        case SDS_TYPE_32:
            SDS_HDR(32, s)^.length += inc_

        case SDS_TYPE_64:
            SDS_HDR(64, s)^.length += inc_

        else:
            ;
    end
end sdsinclen


(**
 * sdsalloc() = sdsavail() + sdslen()
 *)
export function sdsalloc(const s:sds): size_t
begin
    var flags: uchar = s[-1]
    switch (flags & SDS_TYPE_MASK) of
        case SDS_TYPE_5:
            return SDS_TYPE_5_LEN(flags)
        case SDS_TYPE_8:
            return SDS_HDR(8, s)^.alloc
        case SDS_TYPE_16:
            return SDS_HDR(16, s)^.alloc
        case SDS_TYPE_32:
            return SDS_HDR(32, s)^.alloc
        case SDS_TYPE_64:
            return SDS_HDR(64, s)^.alloc
        else:
            return 0
    end
end sdsalloc


(**
 * Set alloc to newlen
 *)
export procedure sdssetalloc(s: sds, newlen: size_t)
begin
    var flags: uchar
    if s <> nil then
        flags := s[-1]
        switch (flags & SDS_TYPE_MASK) of
            case SDS_TYPE_5:
                ;   // Nothing to do. This type has no total allocation info.

            case SDS_TYPE_8:
                SDS_HDR(8,s)^.alloc := newlen

            case SDS_TYPE_16:
                SDS_HDR(16,s)^.alloc := newlen

            case SDS_TYPE_32:
                SDS_HDR(32,s)^.alloc := newlen

            case SDS_TYPE_64:
                SDS_HDR(64,s)^.alloc := newlen

            else:
                ;
        end
    end
end sdssetalloc


(* ==== Forwards ==== *)



export function sdsnewlen(init: const ^VOID, initlen: size_t): sds forward
export function sdsnew(init: const ^char): sds forward
export function sdsempty(): sds forward
export function sdsdup(const s: sds): sds forward
export procedure sdsfree(s: sds) forward
export function sdsgrowzero(s: sds, length: size_t): sds forward
export function sdscatlen(s: sds, t: const ^VOID, length: size_t): sds forward
export function sdscat(s: sds, t: const ^char): sds forward
export function sdscatsds(s: sds, t: const sds): sds forward
export function sdscpylen(s: sds, t: const ^char, length: size_t): sds forward
export function sdscpy(s: sds, t: const ^char): sds forward

export function sdscatvprintf(s: sds, fmt: const ^char, ap: va_list): sds forward

(* __GNUC__ had this defined: __attribute__((format(printf, 2, 3))); *)
export function sdscatprintf(s: sds, fmt: const ^char, ...): sds forward

export function sdscatfmt(s: sds, fmt: const ^char, ...): sds forward
export function sdstrim(s: sds, cset: const ^char): sds forward
export procedure sdsrange(s: sds, start: ssize_t, end_: ssize_t) forward
export procedure sdsupdatelen(s: sds) forward
export procedure sdsclear(s: sds) forward
export function sdscmp(s1: const sds, s2: const sds): int forward
export function sdssplitlen(s: const ^char, length: ssize_t, sep: const ^char, seplen: int, count: ^int): ^sds forward
export procedure sdsfreesplitres(tokens: ^sds, count: int) forward
export procedure sdstolower(s: sds) forward
export procedure sdstoupper(s: sds) forward
export function sdsfromlonglong(value: llong): sds forward
export function sdscatrepr(s: sds, p: const ^char, length: size_t): sds forward
export function sdssplitargs(line: const ^char, argc: ^int): ^sds forward
export function sdsmapchars(s: sds, from_: const ^char, to_: const ^char, setlen: size_t): sds forward
export function sdsjoin(argv: ^char[], argc: int, sep: ^char): sds forward
export function sdsjoinsds(argv: ^sds, argc: int, sep: const ^char, seplen: size_t): sds forward

(* Low level functions exposed to the user API *)
export function sdsMakeRoomFor(s: sds, addlen: size_t): sds forward
export procedure sdsIncrLen(s: sds, incr: ssize_t) forward
export function sdsRemoveFreeSpace(s: sds): sds forward
export function sdsAllocSize(s: sds): size_t forward
export function sdsAllocPtr(s: sds): ^VOID forward

(* Export the allocator used by SDS to the program using SDS.
 * Sometimes the program SDS is linked to, may use a different set of
 * allocators, but may want to allocate or free things that SDS will
 * respectively free or allocate. *)
export function sds_malloc(size: size_t): ^VOID forward
export function sds_realloc(ptr: ^VOID, size: size_t): ^VOID forward
export procedure sds_free(ptr: ^VOID) forward

#ifdef REDIS_TEST
export function sdsTest(argc: int, argv: ^char[]): int forward
#endif


(* ==== static inlined sds.c functions ==== *)


(*
 * Return size of specified header.
 *)
function sdsHdrSize(hdr_type: char): int
begin
    switch hdr_type & SDS_TYPE_MASK of
        case SDS_TYPE_5:
            return sizeof(sdshdr5)
        case SDS_TYPE_8:
            return sizeof(sdshdr8)
        case SDS_TYPE_16:
            return sizeof(sdshdr16)
        case SDS_TYPE_32:
            return sizeof(sdshdr32)
        case SDS_TYPE_64:
            return sizeof(sdshdr64)
        else:
            return 0
    end
end sdsHdrSize


(*
 * Get the SDS TYPE for the corresponding string.
 *)
function sdsReqType(string_size: size_t): char
begin
    if string_size < 1<<5 then
        return SDS_TYPE_5
    elsif string_size < 1<<8 then
        return SDS_TYPE_8
    elsif string_size < 1<<16 then
        return SDS_TYPE_16
    end

#if (LONG_MAX == LLONG_MAX)
    if string_size < 1ll<<32 then
        return SDS_TYPE_32
    else
        return SDS_TYPE_64
    end
#endif

    return SDS_TYPE_32
end sdsReqType


(* ==== Functions defined in sds.c ==== *)


(**
 * Create a new sds string with the content specified by the 'init' pointer
 * and 'initlen'.
 * If NIL is used for 'ini' the string is initialized with zero bytes.
 * If SDs_NOINIT is used, the buffer is left uninitialized;
 *
 * The string is always null-terminated (all the sds strings are, always) so
 * even if you create an sds string with:
 *
 * mystring := sdsnewlne("abc", 3)
 *
 * You can print the string with printf() as there is an implicit \0 at the
 * end of the string. However the string is binary safe and can contain
 * \0 characters in the middle, as the length is stored in the sds header.
 *)
export function sdsnewlen(init_to: const ^VOID, initlen: size_t): sds
begin
    var sh: ^VOID
    var s: sds
    var sds_type: char = sdsReqType(initlen)
    var hdrlen: int = 0
    var fp: ^uchar
    var init: const ^VOID = init_to

    // Empty strings are usually created in order to append. Use type 8
    // since type 5 is not good at this.
    if sds_type == SDS_TYPE_5 and initlen == 0 then
        sds_type := SDS_TYPE_8
    end
    hdrlen := sdsHdrSize(sds_type)

    sh := s_malloc(hdrlen + initlen + 1)
    if sh == nil then
        return nil
    end
    if init == SDS_NOINIT as const ^VOID then
        init := nil
    elsif not init then
        memset(sh, 0, hdrlen + initlen + 1)
    end
    s := (sh as ^char) + hdrlen
    fp := (s-1) as ^uchar
    switch sds_type of
        case SDS_TYPE_5:
            fp^ := sds_type | (initlen << SDS_TYPE_BITS)

        case SDS_TYPE_8:
            let sh: ^sdshdr8 = (s-sizeof(sdshdr8)) as ^sdshdr8      // SDS_HDR_VAR
            sh.length := initlen
            sh.alloc := initlen
            fp^ := sds_type

        case SDS_TYPE_16:
            let sh: ^sdshdr16 = (s-sizeof(sdshdr16)) as ^sdshdr16   // SDS_HDR_VAR
            sh.length := initlen
            sh.alloc := initlen
            fp^ := sds_type

        case SDS_TYPE_32:
            let sh: ^sdshdr32 = (s-sizeof(sdshdr32)) as ^sdshdr32   // SDS_HDR_VAR
            sh.length := initlen
            sh.alloc := initlen
            fp^ := sds_type

        case SDS_TYPE_64:
            let sh: ^sdshdr64 = (s-sizeof(sdshdr64)) as ^sdshdr64   // SDS_HDR_VAR
            sh.length := initlen
            sh.alloc := initlen
            fp^ := sds_type

        else:
            ;
    end
    if initlen and init then
        memcpy(s, init, initlen)
    end
    s[initlen] := '\0'
    return s
end sdsnewlen


(**
 * Create an empty (zero length) sds string. Even in this case the string
 * always has an implicit nil term.
 *)
export function sdsempty(): sds
begin
    return sdsnewlen("", 0)
end sdsempty


(**
 * Create a new sds string starting from a null terminaed C string.
 *)
export function sdsnew(init: const ^char): sds
begin
    var initlen: size_t = (init == nil) ? 0 : strlen(init)
    return sdsnewlen(init, initlen)
end sdsnew


(**
 * Duplicate an sds string. 
 *)
export function sdsdup(s: const sds): sds
begin
    return sdsnewlen(s, sdslen(s));
end sdsdup


(**
 * Free an sds string. No operation is performed if 's' is NIL.
 *)
export procedure sdsfree(s: sds)
begin
    if s != nil then
        s_free((s-sdsHdrSize(s[-1])) as ^char)
    end
end sdsfree


(**
 * Set the sds string length to the length as obtained with strlen(), so
 * considering as content only up to the first null term character.
 *
 * This function is useful when the sds string is hacked manually in some
 * way, like in the following example:
 *
 *  s := sdsnew("foobar")
 *  s[2] := '\0'
 *  sdsupdatelen(s)
 *  printf("%d\n", sdslen(s))
 *
 * The output will be "2", but if we comment out the call to sdsupdatelen()
 * the output will be "6" as the string was modified but the logical length
 * remains 6 bytes.
 *)
export procedure sdsupdatelen(s: sds)
begin
    var reallen: size_t = strlen(s)
    sdssetlen(s, reallen)
end


(**
 * Modify an ses string in-place to make it empty (zero length).
 * However all the existing buffer is not discarded but set as free space
 * so that next append operations will not require allocations up to the
 * number of bytes previously available.
 *)
export procedure sdsclear(s: sds)
begin
    sdssetlen(s, 0)
    s[0] := '\0'
end


(**
 * Enlarge the free space at the end of the sds string so that the caller
 * is sure that after calling this function can overwrite up to addlen
 * bytes after the end of the string, plus one more byte for null term.
 *
 * Note: this does not change the *length* of the sds string as returned
 * by sdslen(), but only the free buffer space we have.
 *)
export function sdsMakeRoomFor(s: sds, addlen: size_t): sds
begin
    var sh, newsh: ^VOID
    var avail: size_t = sdsavail(s)
    var length, newlen, reqlen: size_t
    var sds_type, oldtype: char
    var hdrlen: int
    var new_s: sds = nil

    oldtype := s[-1] & SDS_TYPE_MASK

    // Return if there is enough space left.
    if avail >= addlen then
        return s
    end

    length := sdslen(s)
    sh := (s-sdsHdrSize(oldtype)) as ^char
    newlen := length + addlen
    reqlen := newlen
    if newlen < SDS_MAX_PREALLOC then
        newlen *= 2
    else
        newlen += SDS_MAX_PREALLOC
    end

    sds_type := sdsReqType(newlen)

    // Don't use type 5: the user is appending to the string and type 5 is
    // not able to remember empty space, so sdsMakeRoomFor must be called
    // at every appending operation.
    if sds_type == SDS_TYPE_5 then
        sds_type := SDS_TYPE_8
    end
    hdrlen := sdsHdrSize(sds_type)
    assert (hdrlen + newlen + 1 > reqlen), "Catch size_t overflow"
    if oldtype == sds_type then
        newsh := s_realloc(sh, hdrlen + newlen + 1)
        if newsh == nil then
            return nil
        end
        new_s := cast(^char, newsh) + hdrlen
    else
        // Since the header size changes, need to move the string forward,
        // and can't use realloc
        newsh := s_malloc(hdrlen + newlen + 1)
        if newsh == nil then
            return nil
        end
        memcpy(newsh as ^char + hdrlen, s, length + 1)
        s_free(sh)
        new_s := cast(^char, newsh) + hdrlen
        new_s[-1] := sds_type
        sdssetlen(new_s, length)
    end
    sdssetalloc(new_s, newlen)
    return new_s
end sdsMakeRoomFor


(**
 * Reallocate the sds string so that it has no free space at the end. The
 * contained string remains not altered, but next concatenation operations
 * will require a reallocation.
 *
 * After the call, the passed sds string is no longer valid and all the
 * references must be substituted with the new pointer returned by the call.
 *)

export function sdsRemoveFreeSpace(s: sds): sds
begin
    var sh, newsh: ^VOID
    var sds_type, oldtype: char
    var hdrlen, oldhdrlen: int
    var length: size_t = sdslen(s)
    var avail: size_t = sdsavail(s)
    var new_s: sds = nil

    oldtype := s[-1] & SDS_TYPE_MASK
    oldhdrlen := sdsHdrSize(oldtype)
    sh := (s-oldhdrlen) as ^char

    // Return if there is no space left
    if avail == 0 then
        return s
    end

    // Check what would be the minimum SDS header that is just good enough to
    // this this string.
    sds_type := sdsReqType(length)
    hdrlen := sdsHdrSize(sds_type)

    // If the type is the same, or at least a large enough type is still
    // required, we just realloc(), letting the allocator to do the copy
    // only if really needed. Otherwise if the change is huge, we manually
    // reallocate the string to use the different header type.
    if oldtype == sds_type or sds_type > SDS_TYPE_8 then
        newsh := s_realloc(sh, oldhdrlen + length + 1)
        if newsh == nil then
            return nil
        end
        new_s := cast(^char, newsh) + oldhdrlen
    else
        newsh := s_malloc(hdrlen + length + 1)
        if newsh == nil then
            return nil
        end
        memcpy(newsh as ^char+ hdrlen, s, length + 1)
        s_free(sh)
        new_s := cast(^char, newsh) + hdrlen
        new_s[-1] := sds_type
        sdssetlen(new_s, length)
    end
    sdssetalloc(new_s, length)
    return new_s
end sdsRemoveFreeSpace


(**
 * Return the total size of the allocation of the specified sds string,
 * including:
 *  1) The sds header before the pointer.
 *  2) The string.
 *  3) The free buffer at the end if any.
 *  4) The implicit null term.
 *)
export function sdsAllocSize(s: sds): size_t
begin
    var alloc: size_t = sdsalloc(s)
    return sdsHdrSize(s[-1] + alloc + 1)
end sdsAllocSize


(**
 * Return the pointer of the actual SDS allocation (normally SDS strings
 * are referenced by the start of the string buffer).
 *)
export function sdsAllocPtr(s: sds): ^VOID
begin
    return (s-sdsHdrSize(s[-1])) as ^VOID
end sdsAllocPtr


(**
 * Increment the sds length and decrements the left free space at the 
 * end of the string according to 'incr'. Also set the null term
 * in the new end of the string.
 *
 * This function is used in order to fix the string length after the
 * user calls sdsMakeRoomFor(), writes something after the end of
 * the current string, and finally needs to set the new length.
 *
 * Note: it is possible to use a negative increment in order to 
 * right-trim the string.
 *
 * Usage example:
 *
 * Using sdsIncrLen() and sdsMakeRoomFor() it is possible to mount the
 * following schema, to cat bytes coming from the kernel to the end of an
 * sds string without copying into an intermediate buffer:
 *
 * oldlen := sdslen(s)
 * s := sdsMakeRoomFor(s, BUFFER_SIZE)
 * nread := read(fd, s+oldlen, BUFFER_SIZE)
 * ... check for nread <= 0 and handle it...
 * sdsIncrLen(s, nread)
 *)
export procedure sdsIncrLen(s: sds, incr: ssize_t)
begin
    var flags: uchar = s[-1]
    var length: size_t

    switch flags & SDS_TYPE_MASK of
        case SDS_TYPE_5:
            var fp: ^uchar = cast(^uchar, s) - 1
            var oldlen: uchar = SDS_TYPE_5_LEN(flags)

            assert((incr > 0 and oldlen+incr < 32) or (incr < 0 and oldlen >= cast(uint, -incr)))

            fp^ := SDS_TYPE_5 | ((oldlen+incr) << SDS_TYPE_BITS)
            length := oldlen + incr

        case SDS_TYPE_8:
            let sh: ^sdshdr8 = (s-sizeof(sdshdr8)) as ^sdshdr8      // SDS_HDR_VAR

            assert ((incr >= 0 and sh.alloc-sh.length >= incr) or (incr < 0 and sh.length >= cast(uint, -incr)))
            sh.length += incr
            length := sh.length

        case SDS_TYPE_16:
            let sh: ^sdshdr16 = (s-sizeof(sdshdr16)) as ^sdshdr16      // SDS_HDR_VAR

            assert ((incr >= 0 and sh.alloc-sh.length >= incr) or (incr < 0 and sh.length >= cast(uint, -incr)))
            sh.length += incr
            length := sh.length

        case SDS_TYPE_32:
            let sh: ^sdshdr32 = (s-sizeof(sdshdr32)) as ^sdshdr32      // SDS_HDR_VAR

            assert ((incr >= 0 and sh.alloc-sh.length >= cast(uint, incr)) or (incr < 0 and sh.length >= cast(uint, -incr)))
            sh.length += incr
            length := sh.length

        case SDS_TYPE_64:
            let sh: ^sdshdr64 = (s-sizeof(sdshdr64)) as ^sdshdr64      // SDS_HDR_VAR

            assert ((incr >= 0 and sh.alloc-sh.length >= cast(uint64_t, incr)) or (incr <= 0 and sh.length >= cast(uint64_t, -incr)))
            sh.length += incr
            length := sh.length

        else:
            length := 0     // Just to avoid compilation warnings.
    end
    s[length] := '\0'
end sdsIncrLen


(**
 * Grow the sds to have the specified length. Bytes that were not part of 
 * the original length of the sds will be set to zero.
 *
 * If the specified length is smaller than the current length, no operation
 * is performed. 
 *)
export function sdsgrowzero(s: sds, length: size_t): sds
begin
    var curlen: size_t = sdslen(s)
    var new_s: sds = s

    if length > curlen then
        new_s := sdsMakeRoomFor(new_s, length-curlen)
        if new_s <> nil then
            // Make sure added region doesn't conain garbage
            memset(new_s+curlen, 0, (length-curlen+1))      // Also set trailing \0 byte
            sdssetlen(new_s, length)
        end
    end
    return new_s
end sdsgrowzero


(**
 * Append the specified binary-safe string pointed by 't' of 'length' bytes to the
 * end of the specified sds string 's'.
 *
 * After the call, the passed sds string is no longer valid and all the
 * references must be substituted with the new pointer returned by the call.
 *)
export function sdscatlen(s: sds, t: const ^VOID, length: size_t): sds
begin
    var curlen: size_t = sdslen(s)
    var new_s: sds = s

    new_s := sdsMakeRoomFor(new_s, length)
    if new_s <> nil then
        memcpy(new_s+curlen, t, length)
        sdssetlen(new_s, curlen+length)
        new_s[curlen+length] := '\0'
    end

    return new_s
end sdscatlen


(**
 * Append the specified null terminated C string to the sds string 's'.
 *
 * After the call, the passed sds string is no longer valid and all the
 * references must be substituted with the new pointer returned by the call.
 *)
export function sdscat(s: sds, t: const ^char): sds
begin
    return sdscatlen(s, t, strlen(t))
end sdscat


(**
 * Append the specified sds 't' to the existing sds 's'.
 *
 * After the call, the modified sds string is no longer valid and all the
 * references must be substituted with the new pointer returned by the call.
 *)
export function sdscatsds(s: sds, t: const sds): sds
begin
    return sdscatlen(s, t, sdslen(t))
end sdscatsds


(**
 * Destructively modify the sds string 's' to hold the specified binary
 * safe string pointed by 't' of the length 'length' bytes.
 *)
export function sdscpylen(s: sds, t: const ^char, length: size_t): sds
begin
    var new_s: sds = s

    if sdsalloc(new_s) < length then
        new_s := sdsMakeRoomFor(new_s, sdslen(new_s))
        if new_s == nil then
            return nil
        end
    end

    memcpy(new_s, t, length)
    new_s[length] := '\0'
    sdssetlen(new_s, length)
    return new_s
end sdscpylen


(**
 * Like sdscpylen() but 't' must be a null erminaed string so that the length
 * of the string is obtained with strlen().
 *)
export function sdscpy(s: sds, t: const ^char): sds
begin
    return sdscpylen(s, t, strlen(t))
end


(**
 * Helper for sdscatlonglong() doing the actual number -> string
 * conversion. 's' must point to a string with room for at least
 * SDS_LLSTR_SIZE bytes.
 *
 * The function returns the length of the null-terminaed string
 * representation stored at 's'. 
 *)
const SDS_LLSTR_SIZE = 21
#define SDS_LLSTR_SIZE 21

function sdsll2str(s: ^char, value: llong): int
begin
    var p, q: ^char
    var aux: char
    var v: ullong
    var l: size_t

    // Generate the string representation. This method produces
    // a reversed string.
    if value < 0 then
        // Since v is unsigned, if value==LLONG_MIN then
        // -LLONG_MIN will overflow
        if value <> LLONG_MIN then
            v := -value
        else
            v := cast(ullong, LLONG_MAX) + 1
        end
    else
        v := value
    end

    p := s
    repeat
        inc(p)
        p^ := '0' + (v mod 10)
        v /= 10
    until v == 0
    if value < 0 then
        inc(p)
        p^ := '-'
    end

    // Compute length and add null term
    l := p - s
    p^ := '\0'

    // Reverse the string
    dec(p)
    q := s
    while q < p do
        aux := q^
        q^ := p^
        p^ := aux
        inc(q)
        dec(p)
    end

    return l
end sdsll2str


(**
 * Identical sdsll2str(), but for unsigned long long type (ullong).
 *)
function sdsull2str(s: ^char, value: ullong): int
begin
    var aux: char
    var p, q: ^char
    var l: size_t
    var v: ullong = value

    // Generate the string representation. This method produces
    // a reversed string.
    p := s
    repeat
        inc(p)
        p^ := '0' + (v mod 10)
        v /= 10
    until v == 0

    // Compute length and add null term.
    l := p - s
    p^ := '\0'

    // Reverse the string
    dec(p)
    q := s
    while q < p do
        aux := q^
        q^ := p^
        p^ := aux
        inc(q)
        dec(p)
    end

    return l

end sdsull2str


(**
 * Create an sds string from a long long value. It is much faster than:
 *
 * sdscatprintf(sdsempty(), "%lld\n", value)
 *)
export function sdsfromlonglong(value: llong): sds
begin
    var buf: array[SDS_LLSTR_SIZE + 0] of char
    var length: int = sdsll2str(buf, value)

    return sdsnewlen(buf, length)
end sdsfromlonglong


(**
 * Like sdscatprintf() but gets va_list instead of being variadic.
 *)
export function sdscatvprintf(s: sds, fmt: const ^char, ap: va_list): sds
begin
    var cpy: va_list
    var staticbuf: array[1024] of char
    var buf: ^char = staticbuf
    var t: ^char
    var buflen: size_t = strlen(fmt) * 2
    var bufstrlen: int

    // We try to start using a static buffer for speed.
    // If not possible we revert to heap allocation
    if buflen > sizeof(staticbuf) then
        buf := s_malloc(buflen)
        if buf == nil then
            return nil
        end
    else
        buflen := sizeof(staticbuf)
    end

    // Alloc enough space for buffer and \0 after failing to
    // fit the string in the current buffer size
    loop
        va_copy(cpy, ap)
        bufstrlen := vsnprintf(buf, buflen, fmt, cpy)
        va_end(cpy)
        if bufstrlen < 0 then
            if buf <> staticbuf then
                s_free(buf)
                return nil
            end
        end
        if bufstrlen as size_t >= buflen then
            if buf <> staticbuf then
                s_free(buf)
            end
            buflen := cast(size_t, bufstrlen) + 1
            buf := s_malloc(buflen)
            if buf == nil then
                return nil
            end
            continue
        end
        break
    end

    // Finally concat the obtained string to the SDS string and return it.
    t := sdscatlen(s, buf, bufstrlen)
    if buf <> staticbuf then
        s_free(buf)
    end
    return t
end sdscatvprintf


(**
 * Append to the sds string 's' a string obtained using printf-alike format
 * specifier.
 *
 * After the call, the modified sds string is no longer valid and all the
 * references must be substituted with the new pointer returned by the call.
 *
 * Example:
 *
 *  s := sdsnew("Sum is: ")
 *  s := sdscatprintf(s, "%d+%d = %d", a, b, a+b).
 *
 * Often you need to create a string from scratch with the printf-alike
 * format. When this is the need, just use sdsempty() as the target string:
 *
 * s := sdscatprintf(sdsempty(), "... your format ...", args)
 *)
export function sdscatprintf(s: sds, fmt: const ^char, ...): sds
begin
    var ap: va_list
    var t: ^char

    va_start(ap, fmt)
    t := sdscatvprintf(s, fmt, ap)
    va_end(ap)
    return t
end sdscatprintf


(**
 * This function is similar to sdscatprintf, but much faster as it does
 * not rely on sprintf() family functions implemented by the libc that
 * are often very slow. Moreover directly handling the sds string as
 * new data is concatenated provides a performanc improvement.
 *
 * However this function only handles an incompatible subset of printf-alike
 * format specifiers:
 *
 * %s - C String
 * %S - SDS string
 * %i - signed int
 * %I - 64 bit signed integer (long long, int64_t)
 * %u - unsigned int
 * %U - 64 bit unsigned integer (unsigned long long, uint64_t)
 * %% - Verbatim "%" character.
 *)
export function sdscatfmt(s: sds, fmt: const ^char, ...): sds
begin
    var initlen: size_t = sdslen(s)
    var f: const ^char = fmt
    var i: long
    var ap: va_list
    var new_s: sds = s

    // To avoid continuous reallocations, let's start with a buffer that
    // can hold at least two times the format string itself. It's not the 
    // best heuristic but seems to work in practice.
    new_s := sdsMakeRoomFor(new_s, initlen + strlen(fmt) * 2)
    va_start(ap, fmt)
    f := fmt        // Next format specifier byte to process
    i := initlen    // Position of the next byte to write to dest str
    while f^ do
        var next: char
        var str: ^char
        var l: size_t
        var num: llong
        var unum: ullong

        // Make sure there is always space for at least 1 char
        if sdsavail(new_s) == 0 then
            new_s := sdsMakeRoomFor(new_s, 1)
        end

        switch f^ of
            case '%':
                next := (f+1)^
                if next == '\0' then
                    break
                end
                inc(f)
                switch next of
                    case 's', 'S':
                        str := va_arg(ap, pchar)
                        l := (next == 's') ? strlen(str) : sdslen(str)
                        if sdsavail(new_s) < l then
                            new_s := sdsMakeRoomFor(new_s, l)
                        end
                        memcpy(new_s+i, str, l)
                        sdsinclen(new_s, l)
                        i += l
                        break
                    case 'i', 'I':
                        if next == 'i' then
                            num := va_arg(ap, int)
                        else
                            num := va_arg(ap, llong)
                        end

                        begin
                            var buf: array[SDS_LLSTR_SIZE] of char

                            l := sdsll2str(buf, num)
                            if sdsavail(new_s) < l then
                                new_s := sdsMakeRoomFor(new_s, l)
                            end
                            memcpy(new_s+i, buf, l)
                            sdsinclen(new_s, l)
                            i += l
                        end
                        break
                    case 'u', 'U':
                        if next == 'u' then
                            unum := va_arg(ap, uint)
                        else
                            unum := va_arg(ap, ullong)
                        end

                        begin
                            var buf: array[SDS_LLSTR_SIZE] of char

                            l := sdsull2str(buf, unum)
                            if sdsavail(new_s) < l then
                                new_s := sdsMakeRoomFor(new_s, l)
                            end
                            memcpy(new_s+i, buf, l)
                            sdsinclen(new_s, l)
                            i += l
                        end
                        break
                    else:
                        // Handle %% and generally %<unknown>.
                        new_s[i] := next
                        inc(i)
                        sdsinclen(new_s, 1)
                        break
                end
                break
            else:
                new_s[i] := f^
                inc(i)
                sdsinclen(new_s, 1)
                break
        end
        inc(f)
    end
    va_end(ap)

    // Add null-term
    new_s[i] := '\0'
    return new_s
end sdscatfmt


(**
 * Remove the part of the string from left and from right composed just of
 * contiguous characters found in 'cset', that are a null terminated C string.
 *
 * After the call, the modified sds string is no longer valid and all the 
 * references must be substituted with the new pointer returned by the call.
 *
 * Example:
 *
 *  s := sdsnew("AA...AA.a.aa.aHelloWorld     :::")
 *  s := sdstrim(s, "Aa. :")
 *  printf("%s\n", s)
 *
 * Output will be just "HelloWorld".
 *)
export function sdstrim(s: sds, cset: const ^char): sds
begin
    var end_, sp, ep: ^char
    var length: size_t

    sp := s
    end_ := s+sdslen(s)-1
    ep := end_
    while sp <= end_ and strchr(cset, sp^) do
        inc(sp)
    end
    while ep > sp and strchr(cset, ep^) do
        dec(ep)
    end
    length := (ep-sp) + 1
    if s <> sp then
        memmove(s, sp, length)
    end
    s[length] := '\0'
    sdssetlen(s, length)
    return s
end sdstrim


(**
 * Turn the string into a smaller (or equal) string containing only the
 * substring specified by the 'start' and 'end' endexes.
 *
 * start and end can be negative, where -1 means the last character of the
 * string, -2 the penultimate character, and so forth.
 *
 * The interval is inclusive, so the start and end characters will be part
 * of the resulting string.
 *
 * The string is modified in-place
 *
 * Example:
 *
 * s := sdsnew("Hello World")
 * sdsrange(s, 1, -1)  =>  "ello World"
 *)
export procedure sdsrange(s: sds, start: ssize_t, end_: ssize_t)
begin
end sdsrange


begin
end Tsds
