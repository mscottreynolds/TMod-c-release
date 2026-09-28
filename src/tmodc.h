/** HAND MODIFIED */

#ifndef MODC_MODULE_tmodc_H
#define MODC_MODULE_tmodc_H

/**
 * some additional type definitions.
 */

/* === IMPORT === */
#include "stddef.h"

/* === IMPORT === */
#include "stdint.h"

/* === IMPORT === */
#include "stdbool.h"

/* === IMPORT === */
#include "limits.h"

/* === IMPORT === */
#include "float.h"

/* === IMPORT === */
#include "assert.h"

/* === IMPORT === */
#include "stdlib.h"

/* === IMPORT === */
#include "string.h"

/* === IMPORT === */
#include "stdio.h"

/* === IMPORT === */
#include "math.h"

/* === TYPE EXPORT === */
typedef int8_t int8;

/* === TYPE EXPORT === */
typedef int16_t int16;

/* === TYPE EXPORT === */
typedef int32_t int32;

/* === TYPE EXPORT === */
typedef int64_t int64;

/* === TYPE EXPORT === */
typedef uint8_t uint8;

/* === TYPE EXPORT === */
typedef uint16_t uint16;

/* === TYPE EXPORT === */
typedef uint32_t uint32;

/* === TYPE EXPORT === */
typedef uint64_t uint64;

typedef int integer;

/**
 * Basic string CONSTANT type.
 * Example: s: String = { "Hello world", 11}
 */
typedef struct String String;
typedef struct String {
    const char* value;          // only initialize to existing strings.
    size_t length;              // Initialize with strlen("...")
} String;


#endif /* MODC_MODULE_tmodc_H */
