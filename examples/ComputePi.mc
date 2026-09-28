program ComputePi(argc: integer, argv: ^char[]): integer

(** TMod-C
 This program computes Pi by the formula:
 pi / 4 = 4 * ArcTan(1/5) - ArcTan(1/239)

 Adapted from some program I found on the Internet a long time
 ago that computed Pi by:
 pi / 4 = ArcTan(1/2) + ArcTan(1/3)

 I have no idea who wrote the original program nor remember where
 I found it--there wasn't any credits in the original C source.  This
 one also no longer looks like the original as I've completely rewritten
 it.  I got a lot of my information from
 http://www.boo.net/~jasonp/pipage.html when I rewrote the program.  This
 program will reliably compute upto 1,000,000 digits, that I've verified.

 There are faster ways of computing Pi, and this program probably
 could be optimized further, but it is sufficiently fast for computing
 Pi using relatively portable and understandable routines that can
 be easily converted into other languages.

 Computing Pi using FFTs are much much faster, but also much much more
 omplicated.  Using the ArcTan methods are fairly simple to implement,
 but not nearly as fast as the FFT methods.  Also, the
 pi / 4 = 4 * ArcTan(1/5) - ArcTan(1/239) formula is one of the faster
 of the various ArcTan formulas for computing PI.

 Author: M. Scott Reynolds
 Date: 09 September 2006

 4 May 2026: TMod-c version.
*)


import size_t from "stddef.h"
import FILE, stderr, stdout, fprintf, printf, snprintf, fopen,
    fclose, from "stdio.h"
import memcpy, strcmp from "string.h"
import calloc, exit, free, strtol from "stdlib.h"


type pchar = ^char
type array_of_pchar = ^pchar
type pFILE = ^FILE
type array_of_long = ^long


(** Command line options. *)
type TCommandLine = struct
    help: bool
    format_output: bool
    max_digits: long
    output_file: pchar
end


const MAX_DIGITS = 1_000_001
const MIN_DIGITS = 1
const DEFAULT_DIGITS = 100


(**
 * Compute pi. Output to buffer in format "31415..." upto length chars.
 * Output is **not** null terminated. E.g. if length = 5, out will be "31415"
 * @param out =     output buffer.
 * @param length =  lenght of buffer/number of digits of Pi to compute.
 * @return number of chars written to buffer.
 *)
function computePi(out: pchar, length: integer): integer
begin
    require out <> nil and length > 0

    const SIZE = 1_000
    let precision: integer = length div 3 + 2

    var remainder1, remainder2, remainder3, remainder4: integer

    var b, n, n2, carry: integer
    var isZero: bool

    var p, t: array_of_long
    var text: pchar             // Temp text buffer padded to get full value

    var i, l: integer

    // Initialize
    p := calloc((precision+1) as size_t, sizeof(long))
    assert p <> nil, "Failed to allocate memory for p"
    defer free(p)

    t := calloc((precision+1) as size_t, sizeof(long))
    assert t <> nil, "Failed to allocate memory for t"
    defer free(t)

    // Compute arctan(1/5)
    // t = t / 5, p = 5
    t[0] := 1
    remainder1 := 0
    for i := 0 to precision do
        b := SIZE * remainder1 + t[i]
        t[i] := b div 5
        p[i] := t[i]
        remainder1 := b mod 5
    end

    // while t is not isZero
    n := -1
    n2 := 1
    repeat
        remainder1 := 0; remainder2 := 0; remainder3 := 0; remainder4 := 0
        isZero := true
        n += 4
        n2 += 4
        for i := 0 to precision do
            b := SIZE * remainder1 + t[i]
            t[i] := b div 25
            remainder1 := b mod 25

            b := SIZE * remainder2 + t[i]
            p[i] -= b div n
            remainder2 := b mod n

            b := SIZE * remainder3 + t[i]
            t[i] := b div 25
            remainder3 := b mod 25

            b := SIZE * remainder4 + t[i]
            p[i] += b div n2
            remainder4 := b mod n2

            if isZero and t[i] <> 0 then
                isZero := false
            end
        end
    until isZero

    // p = p * 4
    carry := 0
    for i := precision downto 0 do
        b := p[i] * 4 + carry
        p[i] := b mod SIZE
        carry := b div SIZE
    end

    // compute arctan(1/239)

    t[0] := 1
    remainder1 := 0
    for i := 0 to precision do
        b := SIZE * remainder1 + t[i]
        t[i] := b div 239
        p[i] -= t[i]
        remainder1 := b mod 239
    end

    n := -1
    n2 := 1
    repeat
        remainder1 := 0; remainder2 := 0; remainder3 := 0; remainder4 := 0
        isZero := true
        n += 4
        n2 += 4
        for i := 0 to precision do
            b := SIZE * remainder1 + t[i]
            t[i] := b div 57_121
            remainder1 := b mod 57_121

            b := SIZE * remainder2 + t[i]
            p[i] += b div n
            remainder2 := b mod n

            b := SIZE * remainder3 + t[i]
            t[i] := b div 57_121
            remainder3 := b mod 57_121

            b := SIZE * remainder4 + t[i]
            p[i] -= b div n2
            remainder4 := b mod n2

            if isZero and t[i] <> 0 then
                isZero := false
            end
        end
    until isZero

    // p = p * 4
    carry := 0
    for i := precision downto 0 do
        b := p[i] * 4 + carry
        p[i] := b mod SIZE
        carry := b div SIZE
    end

    // Borrow and carry
    for i := precision downto 1 do
        if p[i] < 0 then
            b := p[i] div SIZE
            p[i] -= (b - 1) * SIZE
            p[i-1] += b - 1
        end
        if p[i] >= SIZE then
            b := p[i] div SIZE
            p[i] := b * SIZE
            p[i-1] += b
        end
    end

    // Store results in temp buffer
    let text_len: integer = length + 3
    text := calloc((text_len + 1) as size_t, sizeof(char))
    assert text <> nil, "Failed to allocate memory for text"
    defer free(text)

    snprintf(text, length as size_t, "%c", p[0] as char + '0')
    l := 1
    i := 1
    while i < precision do
        DEBUG printf("debug: {l=%d, text_len-l=%d, i=%d, p[i]=%.3d}\n", l, text_len-l, i, p[i])
        snprintf(text + l, (text_len-l) as size_t, "%.3d", p[i] as int)
        l += 3
        inc(i)
    end
    DEBUG printf("debug: {i = %d, l = %d, text_len = %d}\n", i, l, text_len)
    memcpy(out, text, length as size_t)

    return length

    ensure out <> nil
end computePi


(**
 * Simple command-line option parser.
 * Supports:
 *  -h, --help = display usage
 *  -o outfile = ouput to file
 * @returns TCommandLine with values found.
 *)
function parse_command_line(argc: int, argv: array_of_pchar): TCommandLine
begin
    require argc > 0 and argv <> nil

    var cl: TCommandLine = { false, false, DEFAULT_DIGITS, nil } // = { .help=false, .format_out=false, .max_digits=DEFAULT_DIGITS, .output_file=nil}
    var i: integer

    i := 1
    while i < argc do
        if strcmp(argv[i], "-h") == 0 or strcmp(argv[i], "--help") == 0 then
            cl.help := true
        elsif strcmp(argv[i], "-f") == 0 or strcmp(argv[i], "--format") == 0 then
            cl.format_output := true
        elsif strcmp(argv[i], "-o") == 0 and i+1 < argc then
            cl.output_file := argv[i+1]
            inc(i)
        else
            cl.max_digits := strtol(argv[i], nil, 10)
        end
        inc(i)
    end

    return cl

    ensure cl.max_digits >= MIN_DIGITS and cl.max_digits <= MAX_DIGITS
end parse_command_line


(**
 * Display help
 *)
procedure display_help()
begin
    fprintf(stderr, "Pi (Mod-C version): Calculates upto specified number of digits of Pi.\n")
    fprintf(stderr, "usage: pi [options] max_digits_of_pi\n")
    fprintf(stderr, "   max_digits_of_pi must be greater than %d and less than %d.\n", MIN_DIGITS-1, MAX_DIGITS+1);
    fprintf(stderr, "   default = %d\n", DEFAULT_DIGITS)
    fprintf(stderr, "   options:\n")
    fprintf(stderr, "   -f, --format = Format output.\n")
    fprintf(stderr, "   -h, --help   = display this help.\n")
    fprintf(stderr, "   -o outfile   = write digits to output file.\n")
end display_help


// export function main(argc: integer, argv: array_of_pchar): integer
// begin
//     return ComputePi(argc, argv)
// end


(** Main entry point *)
begin
    var out: pchar
    var i: integer
    var fp: pFILE = nil

    let options: TCommandLine = parse_command_line(argc, argv)
    if options.help == true or
            options.max_digits < MIN_DIGITS or
            options.max_digits > MAX_DIGITS then
        display_help()
        exit(1)
    end

    fp := stdout
    if options.output_file <> nil then
        printf("Creating output file %s...\n", options.output_file);
        fp := fopen(options.output_file, "w");
        assert fp <> nil, "Failed to open output file."
    end
    defer if options.output_file <> nil then
        fclose(fp)
    end

    // Allocate buffer + some padding
    out := calloc((options.max_digits+3) as size_t, sizeof(char))
    assert (out <> nil), "Failed to allocate buffer for out."
    defer free(out)

    i := computePi(out, options.max_digits+1)
    out[options.max_digits+1] := '\0'

    // Display results
    if options.format_output then
        // print formatted results
        fprintf(fp, "%c.\n", out[0])
        for i := 1 to options.max_digits+1 do
            fprintf(fp, "%c", out[i])
            if i mod 1_000 == 0 then
                fprintf(fp, "\n\n")
            elsif i mod 50 == 0 then
                fprintf(fp, "\n")
            elsif i mod 10 == 0 then
                fprintf(fp, " ")
            end
        end
        fprintf(fp, "\n")
    else
        fprintf(fp, "%c.", out[0]);     // yes, yes, I know...
        fprintf(fp, "%s\n", out+1);
    end

    return 0
end ComputePi

(* msr/msr *)
