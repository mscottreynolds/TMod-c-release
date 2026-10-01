module Tsds()
(* TSDSLib 2.0 -- A C dynamic strings library
 *
 * Copyright (c) 2006-2015, Salvatore Sanfilippo <antirez at gmail dot com>
 * Copyright (c) 2015, Oran Agra
 * Copyright (c) 2015, Redis Labs, Inc
 * Copyright (c) 2026, M. Scott Reynolds
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
 *)

(**
 * TSDSLib 2.0 (port of SDS 2.0 https://github.com/antirez/sds)
 * 22 Sept 2026: 
 * Port to TMod-c by M. Scott Reynolds
 * 30 Sept 2026:
 * Added type bound methods.
 * Added a few more tests to sdsTest() so all API methods are tested.
 * Included as an example in TMod-c release distribution at 
 * https://github.com/mscottreynolds/TMod-c-release
 *)


(* ==== Imports ==== *)


import printf from "stdio.h"
import from "stdlib.h"
import memset, memcpy, strlen, strchr, memmove, memcmp, from "string.h"
import tolower, toupper, isprint, isspace, from "ctype.h"
import LLONG_MIN, LLONG_MAX, UINT_MAX, ULLONG_MAX, from "limits.h"
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
 * Type bound for sdslen. Note that len is spelled out to length as
 * `len` is a reserved keyword.
 *)
export function sds::length(ref s: sds): size_t
begin
    return sdslen(s)
end sds::length


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
 * Type bound wrapper for sdsavail.
 *)
export function sds::avail(ref s: sds): size_t
begin
    return sdsavail(s)
end sds::avail


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
 * Type bound wrapper for sdssetlen
 *)
export procedure sds::setLen(ref s: sds, newlen: size_t)
begin
    sdssetlen(s, newlen)
end sds::setLen


(**
 * Increase length by inc. Used by sdscatfmt.
 *)
procedure sdsinclen(s: sds, inc_: size_t)
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
 * return sdsalloc() = sdsavail() + sdslen()
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
 * Type bound wrapper for sdsalloc
 *)
export function sds::alloc(ref s:sds): size_t
begin
    return sdsalloc(s)
end sds::alloc


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


(**
 * Type bound wrapper for sdssetalloc.
 *)
export procedure sds::setAlloc(ref s: sds, newlen: size_t)
begin
    sdssetalloc(s, newlen)
end sds::setAlloc


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
 * Type bound method for sdsnewlen()
 *)
export function sds::newLen(init_to: const ^VOID, initlen: size_t): sds
begin
    return sdsnewlen(init_to, initlen)
end sds::newLen


(**
 * Create an empty (zero length) sds string. Even in this case the string
 * always has an implicit nil term.
 *)
export function sdsempty(): sds
begin
    return sdsnewlen("", 0)
end sdsempty


(**
 * Type bound wrapper for sdsempty.
 *)
export function sds::empty(): sds
begin
    return sdsempty()
end sds::empty


(**
 * Create a new sds string starting from a null terminaed C string.
 *)
export function sdsnew(init: const ^char): sds
begin
    var initlen: size_t = (init == nil) ? 0 : strlen(init)
    return sdsnewlen(init, initlen)
end sdsnew


(**
 * Type bound wrapper for sdsnew()
 *)
export function sds::new(init: const ^char): sds
begin
    return sdsnew(init)
end sds::new


(**
 * Duplicate an sds string. 
 *)
export function sdsdup(s: const sds): sds
begin
    return sdsnewlen(s, sdslen(s));
end sdsdup


(**
 * Type bound wrapper for sdsdup.
 *)
export function sds::dup(ref s: const sds): sds
begin
    return sdsdup(s)
end sds::dup


(**
 * Free an sds string. No operation is performed if 's' is NIL.
 *)
export procedure sdsfree(s: sds)
begin
    if s <> nil then
        s_free((s-sdsHdrSize(s[-1])) as ^char)
    end
end sdsfree


(**
 * Type bound wrapper for sdsfree()
 * Note this sets s := nil.
 *)
export procedure sds::free(var s: sds)
begin
    sdsfree(s)
    s := nil
end sds::free


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
 * Type bound wrapper for sdsupdatelen.
 *)
export procedure sds::updateLen(ref s: sds)
begin
    sdsupdatelen(s)
end sds::updateLen


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
 * Type bound wrapper for sdsclear.
 *)
export procedure sds::clear(ref s: sds)
begin
    sdsclear(s)
end sds::clear


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
 * Type bound wrapper for sdsMakeRoomFor. Note that this will update s
 * in place if memory location changes and doesn't have a return value.
 *)
export procedure sds::makeRoomFor(var s: sds, addlen: size_t)
begin
    s := sdsMakeRoomFor(s, addlen)
end sds::makeRoomFor


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
 * Type bound wrapper for sdsRemoveFreeSpace.
 * Note that s is updated in place.
 *)
export procedure sds::removeFreeSpace(var s: sds)
begin
    s := sdsRemoveFreeSpace(s)
end sds::removeFreeSpace


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
    return sdsHdrSize(s[-1]) + alloc + 1
end sdsAllocSize


(**
 * Type bound wrapper for sdsAllocSize.
 *)
export function sds::allocSize(ref s: sds): size_t
begin
    return sdsAllocSize(s)
end sds::allocSize


(**
 * Return the pointer of the actual SDS allocation (normally SDS strings
 * are referenced by the start of the string buffer).
 *)
export function sdsAllocPtr(s: sds): ^VOID
begin
    return (s-sdsHdrSize(s[-1])) as ^VOID
end sdsAllocPtr


(**
 * Type bound wrapper for sdsAllocPtr.
 *)
export function sds::allocPtr(ref s: sds): ^VOID
begin
    return sdsAllocPtr(s)
end sds::allocPtr


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
 * Type bound wrapper for sdsIncrLen.
 *)
export procedure sds::incrLen(ref s: sds, incr: ssize_t)
begin
    sdsIncrLen(s, incr)
end sds::incrLen


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
 * Type bound wrapper for sdsgrowzero.
 * Note that this updates s in place.
 *)
export procedure sds::growZero(var s: sds, length: size_t)
begin
    s := sdsgrowzero(s, length)
end sds::growZero


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
 * Type bound wrapper for sdscatlen.
 * Note that this updates s in place.
 *)
export procedure sds::catLen(var s: sds, t: const ^VOID, length: size_t)
begin
    s := sdscatlen(s, t, length)
end sds::catLen


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
 * Type bound wrapper for sdscat.
 * Note this will update s in place and doesn't have a return value.
 *)
export procedure sds::cat(var s: sds, t: const ^char)
begin
    s := sdscat(s, t)
end sds::cat


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
 * Type bound wrapper for sdscatsds.
 * Note that this updates s in place.
 *)
export procedure sds::catsds(var s: sds, t: const sds)
begin
    s := sdscatsds(s, t)
end sds::catsds


(**
 * Destructively modify the sds string 's' to hold the specified binary
 * safe string pointed by 't' of the length 'length' bytes.
 *)
export function sdscpylen(s: sds, t: const ^char, length: size_t): sds
begin
    var new_s: sds = s

    if sdsalloc(new_s) < length then
        new_s := sdsMakeRoomFor(new_s, length - sdslen(new_s))
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
 * Type bound wrapper for sdscpylen.
 * Note that this updates s in place.
 *)
export procedure sds::cpyLen(var s: sds, t: const ^char, length: size_t)
begin
    s := sdscpylen(s, t, length)
end sds::cpyLen


(**
 * Like sdscpylen() but 't' must be a null terminaed string so that the length
 * of the string is obtained with strlen().
 *)
export function sdscpy(s: sds, t: const ^char): sds
begin
    return sdscpylen(s, t, strlen(t))
end sdscpy


(**
 * Type bound wrapper for sdscpy.
 * Note this will update the value of s.
 *)
export procedure sds::cpy(var s: sds, t: const ^char)
begin
    s := sdscpy(s, t)
end sds::cpy


(**
 * Helper for sdscatlonglong() doing the actual number -> string
 * conversion. 's' must point to a string with room for at least
 * SDS_LLSTR_SIZE bytes.
 *
 * The function returns the length of the null-terminaed string
 * representation stored at 's'. 
 *)

type HUSH_GCC = enum
    SDS_LLSTR_SIZE = 21
end

// #define SDS_LLSTR_SIZE 21

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
        p^ := '0' + (v mod 10)
        inc(p)
        v /= 10
    until v == 0
    if value < 0 then
        p^ := '-'
        inc(p)
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
        p^ := '0' + (v mod 10)
        inc(p)
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
    var buf: array[SDS_LLSTR_SIZE] of char
    var length: int = sdsll2str(buf, value)

    return sdsnewlen(buf, length)
end sdsfromlonglong


(**
 * Wrapper for sdsfromlonglong.
 *)
export function sds::fromLongLong(value: llong): sds
begin
    return sdsfromlonglong(value)
end sds::fromLongLong


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
 * Type bound wrapper for sdscatvprintf.
 * Note this updates s in place.
 *)
export procedure sds::catvPrintf(var s: sds, fmt: const ^char, ap: va_list)
begin
    s := sdscatvprintf(s, fmt, ap)
end sds::catvPrintf


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
 * Type bound version of sdscatprintf.
 * Note this updates s in place.
 *)
export procedure sds::catPrintf(var s: sds, fmt: const ^char, ...)
begin
    var ap: va_list
    var t: ^char

    va_start(ap, fmt)
    t := sdscatvprintf(s, fmt, ap)
    va_end(ap)
    s := t as sds
end sds::catPrintf


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
export function sdscatvfmt(s: sds, fmt: const ^char, ap: va_list): sds
begin
    var initlen: size_t = sdslen(s)
    var f: const ^char = fmt
    var i: long
    var new_s: sds = s

    // To avoid continuous reallocations, let's start with a buffer that
    // can hold at least two times the format string itself. It's not the 
    // best heuristic but seems to work in practice.
    new_s := sdsMakeRoomFor(new_s, initlen + strlen(fmt) * 2)
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
            if next <> '\0' then
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

                else:
                    // Handle %% and generally %<unknown>.
                    new_s[i] := next
                    inc(i)
                    sdsinclen(new_s, 1)

                end
            end

        else:
            new_s[i] := f^
            inc(i)
            sdsinclen(new_s, 1)
        end
        inc(f)
    end

    // Add null-term
    new_s[i] := '\0'
    return new_s
end sdscatvfmt


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
    var ap: va_list
    var new_s: sds = s

    va_start(ap, fmt)
    new_s := sdscatvfmt(s, fmt, ap)
    va_end(ap)
    return new_s
end sdscatfmt


(**
 * Type bound version of sdscatfmt.
 * Note this updates s in place.
 *)
export procedure sds::catFmt(var s: sds, fmt: const ^char, ...)
begin
    var ap: va_list

    va_start(ap, fmt)
    s := sdscatvfmt(s, fmt, ap)
    va_end(ap)
end sds::catFmt


(**
 * Remove the part of the string from left and from right composed just of
 * contiguous characters found in 'cset', that are a null terminated C string.
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
 * Type bound wrapper for sdstrim.
 *)
export procedure sds::trim(ref s: sds, cset: const ^char)
begin
    (sdstrim(s, cset))
end sds::trim


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
    var newlen: size_t
    var length: size_t = sdslen(s)
    var new_start: ssize_t = start
    var new_end: size_t = end_

    if length == 0 then
        return
    end
    if new_start < 0 then
        new_start := length + new_start
        if new_start < 0 then
            new_start := 0
        end
    end
    if new_end < 0 then
        new_end := length + new_end
        if new_end < 0 then
            new_end := 0
        end
    end
    newlen := (new_start > new_end) ? 0 : (new_end - new_start) + 1
    if newlen <> 0 then
        if new_start >= length as ssize_t then
            newlen := 0
        elsif new_end >= length as ssize_t then
            new_end := length - 1
            newlen := (new_end - new_start) + 1
        end
    end
    if new_start and newlen then
        memmove(s, s + new_start, newlen)
    end
    s[newlen] := 0
    sdssetlen(s, newlen)
end sdsrange


(**
 * Type bound wrapper for sdsrange.
 *)
export procedure sds::range(ref s: sds, start: ssize_t, end_: ssize_t)
begin
    sdsrange(s, start, end_)
end sds::range


(**
 * Apply tolower() to every character of the sds string 's'.
 *)
export procedure sdstolower(s: sds)
begin
    var length: size_t = sdslen(s)
    var j: size_t

    for j := 0 to length-1 do
        s[j] := tolower(s[j])
    end
end sdstolower


(**
 * Type bound wrapper for sdstolower.
 *)
export procedure sds::toLower(ref s: sds)
begin
    sdstolower(s)
end sds::toLower


(**
 * Apply toupper() to every character of the sds string 's'.
 *)
export procedure sdstoupper(s: sds)
begin
    var length: size_t = sdslen(s)
    var j: size_t

    for j := 0 to length-1 do
        s[j] := toupper(s[j])
    end
end sdstoupper


(**
 * Type bound wrapper for sdstoupper.
 *)
export procedure sds::toUpper(ref s: sds)
begin
    sdstoupper(s)
end sds::toUpper


(**
 * Compare to sds strings s1 and s2 with memcmp().
 *
 * Return value:
 *
 *      positive if s1 > s2.
 *      negative if s1 < s2.
 *      0 if s1 and s2 are exactly the same binary string.
 *
 * If two strings share exactly the same prefix, but one of the two has
 * additional characters, the longer string is considered to be greater than 
 * the smaller one.
 *)
export function sdscmp(const s1: sds, const s2: sds): int
begin
    var l1, l2, minlen: size_t
    var cmp: int

    l1 := sdslen(s1)
    l2 := sdslen(s2)
    minlen := (l1 < l2) ? l1 : l2
    cmp := memcmp(s1, s2, minlen)
    if cmp == 0 then
        return l1 > l2 ? 1 : (l1 < l2 ? -1 : 0)
    end
    return cmp
end sdscmp


(**
 * Type bound wrapper for sdscmp.
 *)
export function sds::cmp(ref s1: sds, ref s2: sds): int
begin
    return sdscmp(s1, s2)
end sds::cmp


(**
 * Split 's' with separator in 'sep'. An array
 * of sds strings is returned. *count will be set
 * by reference to the number of tokens returned.
 *
 * On out of memory, zero length string, zero length
 * separator, NIL is returned.
 *
 * Note that 'sep' is able to split a string using
 * a multi-character separator. For example
 * sdssplit("foo_-_bar", "_-_") will return two 
 * elements "foo" and "bar".
 *
 * This version of the function is binary-safe but
 * requires length arguments. sdssplit() is just the
 * same function but for zero-terminated strings.
 *)
export function sdssplitlen(s: const ^char, length: ssize_t, sep: const ^char, seplen: int, count: ^int): ^sds
begin
    var elements: int = 0
    var slots: int = 5
    var start: long = 0
    var j: long = 0
    var tokens: ^sds
    var cleanup: bool = false

    if seplen < 1 or length <= 0 then
        count^ := 0
        return nil
    end

    tokens := s_malloc(sizeof(sds) * slots)
    if tokens == nil then
        return nil
    end

    // This replaces the "goto cleanup" in the original sds.c source.
    defer if cleanup then
        sdsfreesplitres(tokens, elements)
        count^ := 0
    end

    j := 0
    while j < (length - (seplen-1)) do
        // Make sure there is room for the next element and the final one.
        if slots < elements + 2 then
            var newtokens: ^sds

            slots *= 2
            newtokens := s_realloc(tokens, sizeof(sds) * slots)
            if newtokens == nil then
                cleanup := true
                return nil
            end
            tokens := newtokens
        end

        // search the separator
        if ((seplen == 1 and (s+j)^ == sep[0]) or (memcmp(s+j, sep, seplen) == 0)) then
            tokens[elements] := sdsnewlen(s + start, j - start)
            if tokens[elements] == nil then
                cleanup := true
                return nil
            end
            inc(elements)
            start := j + seplen
            j := j + seplen - 1         // skip the separator
        end
        inc(j)
    end

    // Add the final element. We are sure there is room in the tokens array.
    tokens[elements] := sdsnewlen(s + start, length - start)
    if tokens[elements] == nil then
        cleanup := true
        return nil
    end
    inc(elements)
    count^ := elements

    return tokens
end sdssplitlen


(**
 * Wrapper for sdssplitlen.
 *)
export function sds::splitLen(s: const ^char, length: ssize_t, sep: const ^char, seplen: int, count: ^int): ^sds
begin
    return sdssplitlen(s, length, sep, seplen, count)
end sds::splitLen


(**
 * Free the result returned by sdssplitlen(), or do nothing if 'tokens' is NIL. 
 *)
export procedure sdsfreesplitres(tokens: ^sds, count: int)
begin
    var n: int = count
    if tokens then
        while n > 0 do
            dec(n)
            sdsfree(tokens[n])
        end
        s_free(tokens)
    end
end sdsfreesplitres


(**
 * Wrapper for sdsfreesplitres.
 *)
export procedure sds::freeSplitRes(tokens: sds[], count: int)
begin
    sdsfreesplitres(tokens, count)
end sds::freeSplitRes


(**
 * Append to the sds strings "s" an escaped string representation where
 * all the non-printable characters (tested with isprint()) are turned into
 * escapes in the for "\n\r\a...." or "\x<hex-number>".
 *
 * After the call, the modified sds string is no longer valid and all the
 * references must be substituted with the new pointer returned by the call.
 *)
export function sdscatrepr(s: sds, p: const ^char, length: size_t): sds
begin
    var t: sds = sdscatlen(s, "\"", 1)
    var l: size_t = length
    var q: const ^char = p

    while l > 0 do
        dec(l)
        switch q^ of
            case '\\', '"':
                t := sdscatprintf(t, "\\%c", q^)

            case '\n': t := sdscatlen(t, "\\n", 2)
            case '\r': t := sdscatlen(t, "\\r", 2)
            case '\t': t := sdscatlen(t, "\\t", 2)
            case '\a': t := sdscatlen(t, "\\a", 2)
            case '\b': t := sdscatlen(t, "\\b", 2)
            else:
                if isprint(q^) then
                    t := sdscatprintf(t, "%c", q^)
                else
                    t := sdscatprintf(t, "\\x%02x", q^ as uchar)
                end
        end
        inc(q)
    end
    return sdscatlen(t, "\"", 1)
end sdscatrepr


(**
 * Type bound wrapper for sdscatrepr.
 * Note this will update the value of s.
 *)
export procedure sds::catRepr(var s: sds, p: const ^char, length: size_t)
begin
    s := sdscatrepr(s, p, length)
end sds::catRepr


(*
 * Helper function for sdssplitargs() that reutrns non zero if 'c'
 * is a valid hex digit.
 *)
function is_hex_digit(c: char): int
begin
    return (c >= '0' and c <= '9') or (c >= 'a' and c <= 'f') or
            (c >= 'A' and c <= 'F')
end is_hex_digit


(*
 * Helper function for sdssplitargs() that converts a hex digit into an
 * integer from 0 to 15
 *)
function hex_digit_to_int(c: char): int
begin
    switch c of
        case '0': return 0
        case '1': return 1
        case '2': return 2
        case '3': return 3
        case '4': return 4
        case '5': return 5
        case '6': return 6
        case '7': return 7
        case '8': return 8
        case '9': return 9
        case 'a', 'A': return 10
        case 'b', 'B': return 11
        case 'c', 'C': return 12
        case 'd', 'D': return 13
        case 'e', 'E': return 14
        case 'f', 'F': return 15
        else: return 0
    end
end hex_digit_to_int


(**
 * Split a line into arguments, where every argument can be in the
 * following programming-language REPL-alike form:
 *
 * foo bar "newline are supported\h" and "\xff\x00otherstuff"
 *
 * The number of arguments is stored into *argc, and an array 
 * of sds is returned.
 *
 * The caller should free the resulting array of sds strings with
 * sdsfreesplitres().
 *
 * Note that sdscatrepr() is able to convert back a string into
 * a quoted string in the same format sdssplitargs() is able to parse.
 *
 * The function returns the allocated tokens on success, even when the
 * input string is empty, or NIL if the input contains unbalanced
 * quotes or closed quotes followed by non space characters
 * as in: "foo"bar or "foo'
 *)
export function sdssplitargs(line: const ^char, argc: ^int): ^sds
begin
    var p: const ^char = line
    var current: ^char = nil
    var vector: ^pchar = nil
    var err: bool = false

    // Cleanup if there was an error
    defer if err then
        while argc^ >= 0 do
            sdsfree(vector[argc^])
            dec(argc^)
        end
        s_free(vector)
        if current then
            sdsfree(current)
        end
        argc^ := 0
    end

    argc^ := 0
    loop
        // skip blanks
        while p^ and isspace(p^) do
            inc(p)
        end
        if p^ then
            // get a token
            var inq: bool = false       // set to true if we are in "quotes"
            var insq: bool = false      // set to true if we are in single quotes
            var done: bool = false

            if current == nil then
                current := sdsempty()
            end
            while not done do
                if inq then
                    if p^ == '\\' and (p+1)^ == 'x' and
                            is_hex_digit((p+2)^) and
                            is_hex_digit((p+3)^) then
                        var b: uchar

                        b := (hex_digit_to_int((p+2)^) * 16) +
                            hex_digit_to_int((p+3)^)
                        current := sdscatlen(current, (@b) as ^char, 1)
                        p += 3
                    elsif p^ == '\\' and (p+1)^ then
                        var c: char

                        inc(p)
                        switch p^ of
                            case 'n': c := '\n'
                            case 'r': c := '\r'
                            case 't': c := '\t'
                            case 'b': c := '\b'
                            case 'a': c := '\a'
                            else: c := p^
                        end
                        current := sdscatlen(current, @c, 1)
                    elsif p^ == '"' then
                        // closing quote must be followed by a space or
                        // nothing at all
                        if (p+1)^ and not isspace((p+1)^) then
                            err := true
                            return nil
                        end
                        done := true
                    elsif not p^ then
                        // unterminated quotes
                        err := true
                        return nil
                    else
                        current := sdscatlen(current, p, 1)
                    end
                elsif insq then
                    if p^ == '\\' and (p+1)^ == '\'' then
                        inc(p)
                        current := sdscatlen(current, "'", 1)
                    elsif p^ == '\'' then
                        // Closing quote must be followed by a space or
                        // nothing at all.
                        if (p+1)^ and not isspace((p+1)^) then
                            err := true
                            return nil
                        end
                        done := true
                    elsif not p^ then
                        // unterminated quotes
                        err := true
                        return nil
                    else
                        current := sdscatlen(current, p, 1)
                    end
                else
                    switch p^ of
                        case ' ', '\n', '\r', '\t', '\0': done := true
                        case '"': inq := true
                        case '\'': insq := true
                        else: 
                            current := sdscatlen(current, p, 1)
                    end
                end
                if p^ then
                    inc(p)
                end
            end
            // Add the token to the vector
            vector := s_realloc(vector, ((argc^) + 1) * sizeof(pchar))
            vector[argc^] := current
            inc(argc^)
            current := nil
        else
            /// Even on empty input string return something not nil.
            if vector == nil then
                vector := s_malloc(sizeof(^VOID))
            end
            return vector
        end
    end
end sdssplitargs


(**
 * Wrapper for sdssplitargs.
 *)
export function sds::splitArgs(line: const ^char, argc: ^int): ^sds
begin
    return sdssplitargs(line, argc)
end sds::splitArgs


(**
 * Modify the string substituting all the occurrences of the set of
 * characters specified in the 'from' string to the corresponding character
 * in the 'to' array.
 *
 * For instance: sdsmapchars(mystring, "ho", "01", 2)
 * will have the effect of turning the string "hello" into "0ell1".
 *
 * The function returnrs the sds string pointer, that is always the same
 * as the input pointer since no resize is needed.
 *)
export function sdsmapchars(s: sds, from_: const ^char, to_: const ^char, setlen: size_t): sds
begin
    var j, i, l: size_t

    l := sdslen(s)
    for j := 0 to l-1 do
        for i := 0 to setlen-1 do
            if s[j] == from_[i] then
                s[j] := to_[i]
                break
            end
        end
    end
    return s
end sdsmapchars


(**
 * Type bound wrapper for sdsmapchars.
 *)
export procedure sds::mapChars(ref s: sds, from_: const ^char, to_: const ^char, setlen: size_t)
begin
    (sdsmapchars(s, from_, to_, setlen))
end sds::mapChars


(**
 * Join an array of C strings using the specified separator (also a C string).
 * Returns the result as an sds string. 
 *)
export function sdsjoin(argv: ^char[], argc: int, sep: ^char): sds
begin
    var join: sds = sdsempty()
    var j: int

    for j := 0 to argc-1 do
        join := sdscat(join, argv[j])
        if j <> argc-1 then
            join := sdscat(join, sep)
        end
    end
    return join
end sdsjoin


(**
 * Wrapper for sdsjoin
 *)
export function sds::join(argv: ^char[], argc: int, sep: ^char): sds
begin
    return sdsjoin(argv, argc, sep)
end sds::join


(**
 * Like sdsjoin, but joins an array of SDS strings.
 *)
export function sdsjoinsds(argv: ^sds, argc: int, sep: const ^char, seplen: size_t): sds
begin
    var join: sds = sdsempty()
    var j: int

    for j := 0 to argc-1 do
        join := sdscatsds(join, argv[j])
        if j <> argc-1 then
            join := sdscatlen(join, sep, seplen)
        end
    end

    return join
end sdsjoinsds


(**
 * Wrapper for sdsjoinsds
 *)
export function sds::joinsds(argv: sds[], argc: int, sep: const ^char, seplen: size_t): sds
begin
    return sdsjoinsds(argv, argc, sep, seplen)
end sds::joinsds


(**
 * Wrappers to the allocators used by SDS. Note that SDS will actually
 * just use the macros defined into sdsalloc.h in order to avoid to pay
 * the overhead of function calls. Here we define these wrappers only for
 * the programs SDS is linked to, if they want to touch the SDS internals
 * even if they use a different allocator.
 *)
export function sds_malloc(size: size_t): ^VOID
begin
    return s_malloc(size)
end sds_malloc


export function sds_realloc(ptr: ^VOID, size: size_t): ^VOID
begin
    return s_realloc(ptr, size)
end sds_realloc


export procedure sds_free(ptr: ^VOID)
begin
    s_free(ptr)
end sds_free


#if defined(SDS_TEST_MAIN)
import test_cond, test_report, from "testhelp.h"

define UNUSED(x) (void)(x)

function sdsTest(): int
begin
    begin
        var x, y: sds
        x := sds::new("foo")

        test_cond("Create a string and obtain the length",
            x.length() == 3 and memcmp(x, "foo\0", 4) == 0)

        x.free()
        x := sds::newLen("foo", 2)
        test_cond("Create a string with specified length",
            x.length() == 2 and memcmp(x, "fo\0", 3) == 0)

        x.cat("bar")
        test_cond("Strings concatenation", 
            x.length() == 5 and memcmp(x, "fobar\0", 6) == 0)

        x.cpy("a")
        test_cond("sds::cpy() against an originally longer string",
            x.length() == 1 and memcmp(x, "a\0", 2) == 0)

        x.cpy("xyzxxxxxxxxxxyyyyyyyyyykkkkkkkkkk")
        test_cond("sds::cpy() against an originally shorter string",
            x.length() == 33 and
            memcmp(x, "xyzxxxxxxxxxxyyyyyyyyyykkkkkkkkkk\0", 33) == 0)

        x.free()
        x := sds::empty()
        x.catPrintf("%d", 123)
        test_cond("sds::catPrintf() seems working in the base case",
            x.length() == 3 and memcmp(x, "123\0", 4) == 0)

        x.free()
        x := sds::empty()
        x.catPrintf("a%cb", 0)
        test_cond("sds::catPrintf() seems working with \\0 inside of result",
            x.length() == 3 and memcmp(x, "a\0b\0", 4) == 0)

        begin
            var etalon: array[1024 * 1024] of char
            var i: size_t

            x.free()
            for i := 0 to sizeof(etalon)-1 do
                etalon[i] := '0'
            end
            x := sds::empty()
            x.catPrintf("%0*d", sizeof(etalon), 0)

            test_cond("sds::catPrintf() can print 1MB",
                x.length() == sizeof(etalon) and memcmp(x, etalon, sizeof(etalon)) == 0)
        end

        x.free()
        x := sds::new("--")
        x.catFmt("Hello %s World %I,%I--", "Hi!", LLONG_MIN, LLONG_MAX)
        test_cond("sds::catFmt() seems working in the base case",
            x.length() == 60 and
            memcmp(x, "--Hello Hi! World -9223372036854775808,9223372036854775807--", 60) == 0)
        printf("[%s]\n", x)

        x.free()
        x := sds::new("--")
        x.catFmt("%u,%U--", UINT_MAX, ULLONG_MAX);
        test_cond("sds::catFmt() seems working with unsigned numbers",
            x.length() == 35 and
            memcmp(x, "--4294967295,18446744073709551615--", 35) == 0)

        x.free()
        x := sds::new(" x ")
        x.trim(" x")
        test_cond("sds::strim() works when all chars match", 
            x.length() == 0)

        x.free()
        x := sds::new(" x ")
        x.trim(" ")
        test_cond("sds::trim() works when a single char remains",
            x.length() == 1 and x[0] == 'x')

        x.free()
        x := sds::new("xxciaoyyy")
        x.trim("xy")
        test_cond("sds::trim() correctly trims characters",
            x.length() == 4 and memcmp(x, "ciao\0", 5) == 0)

        y := x.dup()
        y.range(1, 1)
        test_cond("sds::range(..., 1, 1)",
            y.length() == 1 and memcmp(y, "i\0", 2) == 0)

        y.free()
        y := x.dup()
        y.range(1, -1)
        test_cond("sds::range(..., 1, -1",
            y.length() == 3 and memcmp(y, "iao\0", 4) == 0)

        y.free()
        y := x.dup()
        y.range(-2, -1)
        test_cond("sds::range(..., -2, -1)",
            y.length() == 2 and memcmp(y, "ao\0", 3) == 0)

        y.free()
        y := x.dup()
        y.range(2, 1)
        test_cond("sds::range(..., 2, 1)",
            y.length() == 0 and memcmp(y, "\0", 1) == 0)

        y.free()
        y := x.dup()
        y.range(1, 100)
        test_cond("sds::range(..., 1, 100)",
            y.length() == 3 and memcmp(y, "iao\0", 4) == 0)

        y.free()
        y := x.dup()
        y.range(100, 100)
        test_cond("sds::range(..., 100, 100)",
            y.length() == 0 and memcmp(y, "\0", 1) == 0)

        y.free()
        x.free()
        x := sds::new("foo")
        y := sds::new("foa")
        test_cond("sds::cmp(foo, foa)",
                x.cmp(y) > 0)

        y.free()
        x.free()
        x := sds::new("bar")
        y := sds::new("bar")
        test_cond("sds::cmp(bar, bar)", x.cmp(y) == 0)

        y.free()
        x.free()
        x := sds::new("aar")
        y := sds::new("bar")
        test_cond("sds::cmp(aar, bar)", x.cmp(y) < 0)

        y.free()
        x.free()
        x := sds::newLen("\a\n\0foo\r", 7)
        y := sds::empty()
        y.catRepr(x, x.length())
        test_cond("sds::catRepr(...data...)",
            memcmp(y, "\"\\a\\n\\x00foo\\r\"", 15) == 0)

        begin
            var p: ^char
            var step: int = 10
            var j, i: int

            x.free()
            y.free()
            x := sds::new("0")
            test_cond("sds::new() free/len buffers", x.length() == 1 and x.avail() == 0)

            // Run the test a few times in order to hit the first two
            // SDS header types.
            for i := 0 to 10-1 do
                var oldlen: int = x.length()

                x.makeRoomFor(step)
                let type_: int = x[-1] & SDS_TYPE_MASK

                test_cond("sds::makeRoomFor() len", x.length() == oldlen)
                if type_ <> SDS_TYPE_5 then
                    test_cond("sds::makeRoomFor() free", x.avail() >= step)
                end
                p := x + oldlen
                for j := 0 to step-1 do
                    p[j] := 'A' + j
                end
                x.incrLen(step)
            end
            test_cond("sds::makeRoomFor() content",
                memcmp("0ABCDEFGHIJABCDEFGHIJABCDEFGHIJABCDEFGHIJABCDEFGHIJABCDEFGHIJABCDEFGHIJABCDEFGHIJABCDEFGHIJABCDEFGHIJ", x, 101) == 0)
            test_cond("sds::makeRoomFor() final length", x.length() == 101)

            x.free()
        end

        begin
            var tokens: ^sds
            var n: int = 0
            var argv: array[2] of ^char

            tokens := sds::splitLen("foo_-_bar", 9, "_-_", 3, @n)
            test_cond("sds::splitLen()",
                n == 2 and tokens <> nil and
                tokens[0].length() == 3 and memcmp(tokens[0], "foo\0", 4) == 0 and
                tokens[1].length() == 3 and memcmp(tokens[1], "bar\0", 4) == 0)
            sds::freeSplitRes(tokens, n)

            n := 0
            tokens := sds::splitArgs("one \"two words\" three", @n)
            test_cond("sds::splitArgs()",
                n == 3 and tokens <> nil and
                tokens[0].length() == 3 and memcmp(tokens[0], "one\0", 4) == 0 and
                tokens[1].length() == 9 and memcmp(tokens[1], "two words\0", 10) == 0 and
                tokens[2].length() == 5 and memcmp(tokens[2], "three\0", 6) == 0)
            sds::freeSplitRes(tokens, n)

            x := sds::new("hello")
            x.mapChars("ho", "01", 2)
            test_cond("sds::mapChars()", 
                x.length() == 5 and memcmp(x, "0ell1\0", 6) == 0)
            x.free()

            argv[0] := "foo"
            argv[1] := "bar"
            x := sds::join(argv, 2, "-")
            test_cond("sds::join()",
                x.length() == 7 and memcmp(x, "foo-bar\0", 8) == 0)
            x.free()
        end
    end
    test_report()

    return 0
end sdsTest
#endif


#ifdef SDS_TEST_MAIN
export function main(): int
begin
    return sdsTest()
end main
#endif


begin
end Tsds
