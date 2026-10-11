module codegen()
(**
 * Mod-c
 * By M. Scott Reynolds
 * Date 18 April 2026
 * 
 * Main codegen dispacthcer and
 * Initial Context definition.
 *
 * Initial context passed into codegen_generate to setup environment
 * and other options. Target is defined in codegen_common
 *  .out = out                          // REQUIRED: Predefined output buffer. 
 *  .ast = ast                          // REQUIRED: Top of the Abstract Syntax Tree
 *  .debug_enabled = true               // REQUIRED: Set to true/false for debug statement generation.
 *  .target = TARGET_C/TARGET_HEADER    // REQUIRED: Output code target. 
 *                                      // Currently only TARGET_C and TARGET_HEADER supported.
 *)


import DynBuf 
    from dynbuf
import codegen_mh 
    from codegen_mh
import size_t 
    from "stddef.h"
import stderr, fprintf 
    from "stdio.h"
import exit 
    from "stdlib.h"
import Node 
    from "node.h"
import CodegenTarget, CodegenContext, TARGET_C, TARGET_HEADER, 
    TARGET_MH, TARGET_VM, TARGET_WASM, TARGET_JSON,
    from codegen_common
import codegen_c,
    from codegen_c
// import codegen_c 
//     from "codegen_c.h"
import codegen_header 
    from codegen_header


// type CodegenTarget = enum TARGET_C, TARGET_HEADER, TARGET_VM, TARGET_WASM, TARGET_JSO end


export type InitialContext = struct
    out: ^DynBuf
    ast: const ^Node
    debug_enabled: bool
    assert_off: bool
    dbc_off: bool
    target: CodegenTarget
end


(**
 * Codegen main dispatcher from the given AST using the selected target.
 * The output is written into the provided DynBuf (which must be initialized).
 * Exits program on fatal error. 
 *)
export procedure codegen_generate(initial: InitialContext)
begin
    var ctx: CodegenContext

    if initial.ast == nil or initial.out == nil then
        fprintf(stderr, "FATAL ERROR: codegen_generate: NULL initial.ast or NULL initial.out\n")
        exit(1)
    end

    // Setup the main initial from initial context.
    ctx.out := initial.out
    ctx.ast := initial.ast
    ctx.target := initial.target
    ctx.debug_enabled := initial.debug_enabled
    ctx.assert_off := initial.assert_off
    ctx.dbc_off := initial.dbc_off
    ctx.parent_ctx := nil
    ctx.parent_node := nil
    ctx.enclosing_func := nil
    ctx.enclosing_loop := nil
    ctx.indent := 0

    if ctx.debug_enabled then
        fprintf(stderr, "DEBUG: flag has been set\n")
    end
    if ctx.assert_off then
        fprintf(stderr, "ASSERT_OFF: flag has been set\n")
    end
    if ctx.dbc_off then
        fprintf(stderr, "DBC_OFF: flag has been set\n")
    end

    switch initial.target of
        case TARGET_C:
            codegen_c(ctx)

        case TARGET_HEADER:
            codegen_header(ctx)

        case TARGET_MH:
            codegen_mh(ctx)

        case TARGET_VM, TARGET_WASM, TARGET_JSON:
            fprintf(stderr, "ERROR: codegen_generate: target %d not yet implemented\n", initial.target)
            exit(1)
        else:
            fprintf(stderr, "ERROR: codegen_generate: unknown target specified: %d\n", initial.target)
            exit(1)
    end
end codegen_generate

begin
end codegen
