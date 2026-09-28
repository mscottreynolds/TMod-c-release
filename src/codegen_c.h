/**
 * Mod-c
 * By M. Scott Reynolds
 * Date 18 April 2026
 * 
 * codegen_c.h - 	Generate C code from AST
 */

#ifndef MODC_CODEGEN_C_H
#define MODC_CODEGEN_C_H

#include "codegen_common.h"


/**
 * Generate C source code from the given AST in the CodegenContext.
 * The output is written into the provided DynBuf (which must be initialized),
 * also set in the CodegenContext.
 * Exits program on fatal error.
 */
void codegen_c(CodegenContext ctx);

#endif	/* MODC_CODEGEN_C_H */
