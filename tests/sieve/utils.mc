module utils()

(**
 * Mod-c
 * By M. Scott Reynolds
 * Date 20 February 2026
 *
 * utils.c - Portable helper functions and safe arithmetic utilities.
 *)

// Some cross platform alternates

// import utils
import limits
import string
import ctype

export type long_long = long long
export type uint = unsigned int
export type uchar = unsigned char
export type pchar = ^char


(**
 * Portable replacement for strnlen (not in C89/C95, but very useful).
 * Returns the length of the string or maxlen if no null terminator found.
 *)
export function utils_strnlen(const s: ^char, maxlen: size_t): size_t
begin
    var results: size_t = 0

    if s <> nil then
    	let z: ^char = memchr(s, '\0', maxlen)
        if z != nil then
            results := (z - s) as size_t
        else
            results := maxlen
        end
    end
    return results
end


(**
 * Portable replacement for strndup.
 * Allocates and returns a new null-terminated copy of the first n chars of s.
 * Returns NULL on allocation failure (caller must check).
 *)
export function utils_strndup(const s: ^char, n: size_t): pchar
begin
    var new_str: pchar = nil

    if s <> nil then
        let len: size_t = utils_strnlen(s, n)
        new_str := malloc(len + 1)
    	if new_str != nil then
            memcpy(new_str, s, len)
        	new_str[len] := '\0'
        end
    end
    return new_str
end


(**
 * Integer power using exponentiation by squaring (positive exponents only) 
 * Checks for overflow before each multiplication.
 * Exits program on detected overflow.
 *
 * @param base  Base value (may be negative)
 * @param exp   Non-negative exponent
 * @return      base^exp if representable in long long
 *)
export function utils_power(base: long_long, exp: uint): long_long
begin
    var result: long_long = 1
    var b: long_long = base

    while exp > 0 do
        if exp & 1 as uint then                      // if exponent is odd
            if b <> 0 and result > LLONG_MAX / b then
                fprintf(stderr, "ERROR: utils_power: multiplication overflow\n")
                exit(1)
            end
            result *= b
        end

        if exp > 1 as uint then
            if b <> 0 and b > LLONG_MAX / b then
                fprintf(stderr, "ERROR: utils_power: squaring overflow\n")
                exit(1)
            end

            b *= b                         // square the base
        end

        exp >>= 1                          // exp /= 2
    end
    return result
end utils_power


(**
 * @brief   Safely multiplies two signed long long integers.
 * @details Checks for overflow before performing the multiplication.
 *          Uses the standard method of testing against LLONG_MAX / LLONG_MIN
 *          to detect cases where the result would exceed the representable range.
 *
 * @param   a        First operand
 * @param   b        Second operand
 * @return  The product a * b if it can be represented in long long.
 *          Exits the program with an error message on overflow.
 *
 * @note    Assumes two's complement (guaranteed in C11 for signed integers).
 *          Corectly handles the edge case LLONG_MIN * -1.
 *)
export function utils_safe_multiply(a: long_long, b: long_long): long_long
begin
    // Early exit for obvious zero cases (optimization + clarity)
    if a == 0 or b == 0 then
        return 0
    end

    // Special case: LLONG_MIN * -1 overflows signed long long.
    if a == LLONG_MIN and b == -1 as long_long then
        fprintf(stderr, "ERROR: utils_safe_multiply: overflow - LLONG_MIN * -1 is not representable\n")
        exit(1)
    end

    // Check if the multiplication would overflow positive direction
    if b > 0 then
        // If a is positive, check against LLONG_MAX / b
        if a > 0 then
            if a > LLONG_MAX / b then
                fprintf(stderr, "ERROR: utils_safe_multiply: overflow (positive * positive)\n")
                exit(1)
            end
        else
            // netative * positive
            if a < LLONG_MIN / b then
                fprintf(stderr, "ERROR: utils_safe_multiply: overflow (negative * positive)\n")
                exit(1)
            end
        end
    else // b < 0
        // If a is positive, check against LLONG_MIN / b
        if a > 0 then
            // positive * negative
            if a > LLONG_MIN / b then // note: LLONG_MIN / b is negative or zero
                fprintf(stderr, "ERROR: utils_safe_multiply: overflow (positive * negative)\n")
                exit(1)
            end
        else
            // negative * negative
            if a < LLONG_MAX / b then
                fprintf(stderr, "ERROR: utils_safe_multiply: overflow (negative * negative)\n")
                exit(1)
            end
        end
    end

    // Multiplication is safe
    return a * b
end utils_safe_multiply


(**
 * Parse integer literal that may contain:
 *  - _ digit separators (ignored)
 *  - 0x / 0X   hexadecimal
 *  - 0o / 0O   octal
 *  - 0b / 0B   binary
 * Exits on overflow or invalid characters.
 *)
export function utils_parse_integer_literal(const s: ^char, len: size_t): long_long
begin
    var base: int = 10
    var i: size_t = 0
    var result: long_long = 0

    if s == NULL or len == 0 then
        return 0
    end

    // printf("debug: {s=%.*s}\n", (int)len, s);

    // Skip leading whitespace (defensive)
    while len > 0 and isspace(s^ as uchar) do
        inc(s); inc(len)
    end

    // Detect base prefix
    if len >= 2 and s[0] == '0' then
        let p: char = s[1]
        if p == 'x' or p == 'X' then
            base := 16; i := 2
        elsif p == 'o' or p == 'O' then
            base := 8; i := 2
        elsif p == 'b' or p == 'B' then
            base := 2; i := 2
        end
    end

    while i < len do
        var digit: int

        let c: char = s[i]
        if c <> '_' then        // skip separator
            if isdigit(c as uchar) then
                digit := c - '0'
            elsif base == 16 and c >= 'a' and c <= 'f' then
                digit := 10 + (c - 'a')
            elsif base == 16 and c >= 'A' and c <= 'F' then
                digit := 10 + (c - 'A')
            else
                fprintf(stderr, "ERROR: utils_parse_integer_literal: invalid digit '%c' in bases %d\n", c, base)
                exit(1)
            end

            if digit >= base then
                fprintf(stderr, "ERROR: utils_parse_integer_literal: digit '%c' out of range for base %d\n", c, base)
                exit(1)
            end

            // Safe multiplication + add
            if result > (LLONG_MAX - digit) / base then
                fprintf(stderr, "ERROR: utils_parse_integer_literal: integer overflow\n")
                exit(1)
            end
            result := result * base + digit;
        end
        inc(i)
    end
    return result
end utils_parse_integer_literal

begin
end Utils
