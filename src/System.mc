header System

import void from "stddef.h"
import from "stdio.h"
import va_list from "stdarg.h"

export type pchar = ^char
export type pvoid = ^void
export type ppvoid = ^pvoid

(** Types *)
export extern type size_t
export extern type FILE
export extern type va_list

(** stdlib functions *)
export extern procedure exit(status: int)
export extern function malloc(size: size_t): ^opaque
export extern procedure free(ptr: ^opaque)
export extern function realloc(ptr: ^opaque, size: size_t): ^opaque
export extern function calloc(nmemb: size_t, size: size_t): ^opaque
export extern function strtol(nptr: const ^char, endptr: ^pchar, base: int): long
export extern function atoi(nptr: const ^char): int

(** ctype functions *)
export extern function isdigit(c: int): int
export extern function isspace(c: int): int
export extern function isalnum(c: int): int
export extern function isalpha(c: int): int
export extern function isxdigit(c: int): int
export extern function toupper(c: int): int

(** string functions *)
export extern function memcpy(dest: ^opaque, src: const ^opaque, n: size_t): ^opaque
export extern function memcmp(s1: const ^opaque, s2: const ^opaque, n: size_t): int
export extern function strlen(s: const ^char): size_t
export extern function memset(s: ^opaque, c: int, n: size_t): ^opaque
export extern function memchr(s: const ^opaque, c: int, n: size_t): ^opaque
export extern function strchr(s: const ^char, c: int): ^char
export extern function strrchr(s: const ^char, c: int): ^char
export extern function strcmp(s1: const ^char, s2: const ^char): int
export extern function strncmp(s1: const ^char, s2: const ^char, n: size_t): int

(** stdio functions *)
export extern function fprintf(stream: ^FILE, format: const ^char, ...): int
export extern function printf(format: const ^char, ...): int
export extern function snprintf(dest: ^char, size: size_t, format: const ^char, ...): int
export extern function vsnprintf(dest: ^char, size: size_t, format: const ^char, ap: va_list): int
export extern function fopen(pathname: const ^char, mode: const ^char): ^FILE
export extern function fclose(stream: ^FILE): int
export extern function fread(ptr: ^opaque, size: size_t, nmemb: size_t, stream: ^FILE): size_t
export extern function fseek(stream: ^FILE, offset: long, whence: int): int
export extern function ftell(stream: ^FILE): long
export extern function fputs(s: const ^char, stream: ^FILE): int
export extern procedure perror(s: const ^char)


end System
