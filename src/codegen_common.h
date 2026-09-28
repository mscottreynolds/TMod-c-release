 /**
  * codegen_common.h
  *
  * 5 June 2026
  * 
  * Shared code generation helpers used by both the full C emitter (codegen_c.c)
  * and the header emitter (codegen_header.c).
  *
  * This file should contain only low-level emission primatives and context
  * management that are independent of "full program" vs "header only" logic.
  */

#ifndef MODC_CODEGEN_COMMON_H
#define MODC_CODEGEN_COMMON_H

#include "node.h"
#include "dynbuf.h"
#include "ttype.h"		// for TType*
#include "symkind.h"


/* ===================================
 * Codegen Context
 * =================================== */


/**
 * Target backend selection
 */
typedef enum {
  TARGET_C,         // Current c backend (default)
  TARGET_HEADER,    // Header .h backend conaining exports.
  TARGET_MH,        // modc-mh/1 export table backend.
  TARGET_VM,        // Future bytecode VM
  TARGET_WASM,      // Future WebAssembly (optional)
  TARGET_JSON       // JSON representation of the AST.
} CodegenTarget;


/**
 * Context passed through all recursive codegen functions.
 * Contains the output buffer, current indentation, and parent/scope intormation.
 * This eliminates long parameter lists and makes future extensions (symbol table,
 * defer lists, etc.) trivial. This is setup by the main codegen_generate function.
 */
typedef struct CodegenContext CodegenContext;
typedef struct CodegenContext {
    DynBuf     *out;                    // REQUIRED: Output buffer - never NULL after init
    const Node *ast;                    // REQUIRED: Top of the AST.
    int indent;                         // REQUIRED: Current indentation level
    bool debug_enabled;                 // REQUIRED: Indicate if debug mode is on or not.
    bool assert_off;                    // REQUIRED: Turn off assert statemetns if true
    bool dbc_off;                       // REQUIRED: Turn off DbC statements if true
    CodegenTarget target;               // REQUIRED: Code generation target.
    const CodegenContext *parent_ctx;   // NULL: parent ctx. May be NULL.
    const Node *parent_node;            // NULL: immediate parent node (may be NULL)
    const Node *enclosing_func;         // NULL: nearest function/procedure for RETURN/DEFER
    const Node *enclosing_loop;         // NULL: nearest loop (for BREAK/CONTINUE)
    size_t stmt_index;                  // When parent_node is a BLOCK: index in
                                        // block.stmts of the statement being
                                        // emitted (or block.count at fall-through
                                        // END). Cutoff for DEFER: only stmts[i] 
                                        // with i < stmt_index have been executed.
} CodegenContext;


/* ===============================================
 * Conext Helpers
 * =============================================== */

/**
 * Creae a child context for a nested node.
 */
CodegenContext ctx_push(const CodegenContext *ctx, const Node *new_parent);


/* ===============================================
 * Low-level Emission Helpers
 * =============================================== */

void emit_indent(DynBuf *out, int indent);

bool codegen_unit_binds_portable(const Node *prog, const char *name, size_t name_len);

void codegen_emit_c_prelude(DynBuf *out, const Node *prog);

void emit_return_type(DynBuf *out, const TType *t);

void emit_array_type(DynBuf *out, const TType *t, const char *name, size_t name_len);

void emit_type_specifier(DynBuf *out, const TType *t, const char *name, size_t len,
							bool is_param, bool is_var, bool is_ref, bool is_const);

void emit_param_list(DynBuf *out, Node **params, size_t count, bool is_parameter,
        bool has_ellipsis);

void emit_var_decl(DynBuf *out, const char *name, size_t name_len, const TType *t);

void emit_doc_comment_as_c(DynBuf *out, const Node *n);


/**
 * Emit a LET binding name: name_l{line}_c{col}
 * binding_decl is the NODE_LET_ITEM (sym-decl or let item node).
 */
void emit_let_binding_name(DynBuf *out, const char *name, size_t name_len,
                        const Node *binding_decl);

/**
 * Emit an identifier expression (mangles LET uses via resolved_sym).
 */
void emit_let_ident(DynBuf *out, const Node *n);


/* ============================================
 * Reusable Declaration Emitters
 * ============================================ */

void codegen_common_type_decl(const Node *n, CodegenContext ctx);

void codegen_common_proc_or_func(const Node *n, CodegenContext ctx);

void codegen_common_struct_decl(const Node *n, CodegenContext ctx);

void codegen_common_union_decl(const Node *n, CodegenContext ctx);

void codegen_common_enum_type(const Node *en, const char *type_name, size_t type_name_len, CodegenContext ctx);

void codegen_common_method_type(const Node *method, const Node *type_decl, CodegenContext ctx);

void codegen_common_expr(const Node *n, CodegenContext ctx);

void codegen_common_emit_literal(const Node *n, CodegenContext ctx);

void codegen_common_array_literal(const Node *n, CodegenContext ctx);

void codegen_common_preprocessor(const Node *n, CodegenContext ctx);

void codegen_common_define(const Node *n, CodegenContext ctx);

void codegen_common_field_access(const Node *n, CodegenContext ctx);

void codegen_common_sizeof_expr(const Node *n, CodegenContext ctx);

void codegen_common_len_expr(const Node *n, CodegenContext ctx);

void codegen_common_inc_dec(const Node *n, CodegenContext ctx, bool as_statement);

void codegen_common_module_prototype(const Node *n, CodegenContext ctx);

void codegen_common_import(const Node *n, CodegenContext ctx);

#endif	/* MODC_CODEGEN_COMMON_H */
