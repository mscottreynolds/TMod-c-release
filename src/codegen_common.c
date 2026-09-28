/**
 * Mod-c
 * By M. Scott Reynolds
 * Date 18 April 2026
 *
 * codegen_common.c - Common codegen routines used by different targets.
 */


#include "tmodc.h"
#include "codegen_common.h"
#include "symkind.h"
#include "symbol.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <iso646.h>
#include "version.h"
#include "utils.h"
#include "mh_reader.h"
#include "Lexer.h"


static void emit_type_leaf_name(DynBuf *out, const TType *t)
{
    const char *s = NULL;
    size_t n = 0;

    if (t == NULL) {
        dynbuf_append(out, "int");
        return;
    }
    if (type_c_spelling(t, &s, &n) and s != NULL and n > 0) {
        dynbuf_appendn(out, s, n);
        return;
    }
    if (t->name != NULL and t->name_len > 0) {
        dynbuf_appendn(out, t->name, t->name_len);
        return;
    }
    dynbuf_append(out, "int");
}


/* ====================================
 * Code generation context
 * ==================================== */


/**
 * Create a child context for a nested node.
 * Struct copy is cheap and safe.
 * Exits on fatal error (should never happen in normal use.).
 */
CodegenContext ctx_push(const CodegenContext *ctx, const Node *new_parent)
{
    if (ctx == NULL or ctx->out == NULL) {
        fprintf(stderr, "ERROR: ctx_push: NULL context or output buffer\n");
        exit(1);
    }

    CodegenContext child = *ctx;        // struct copy
    child.parent_node = new_parent;
    child.parent_ctx = ctx;

    // Update enclosing scopes when appropriate
    if (new_parent != NULL) {
        if (new_parent->kind == NODE_PROC_DECL or
            new_parent->kind == NODE_FUNC_DECL) {
            child.enclosing_func = new_parent;
        }

        if (new_parent->kind == NODE_FOR or
            new_parent->kind == NODE_WHILE or
            new_parent->kind == NODE_REPEAT_UNTIL or
            new_parent->kind == NODE_LOOP) {
            child.enclosing_loop = new_parent;
        }
    }
    return child;
}


/* ================================================================
 * Emit routines
 * ================================================================ */


/**
 * Emit indentation (4 spaces per level)
 * Safe, clear, and silences -Wstrict-overflow without complexity.
 */
void emit_indent(DynBuf *out, int indent)
{
    int i = 0;
    while (i < indent) {
        dynbuf_append(out, "    ");
        i = i + 1;      
    }
}


/**
 * Emit Doc Comment, both Pascal and C style, as C style comments.
 */
void emit_doc_comment_as_c(DynBuf *out, const Node *n) {
    if (n == NULL or n->kind != NODE_DOC_COMMENT) {
        return;
    }

    size_t text_len = n->doc_comment.text_len;
    const char *text = n->doc_comment.text;

    // Doc comments should at least be 6 chars long: "(** *)""
    if (text_len > 5) {
        // If C style comments, full text can be output.
        if (strncmp(text, "/**", 3) == 0 and text[text_len-1] == '/') {
            // output as is.
            dynbuf_appendn(out, text, text_len);

        // Pascal style comments need to be converted.
        } else if (strncmp(text, "(**", 3) == 0 and text[text_len-1] == ')') {
            // Pascal style. Switch to C style.
            dynbuf_append_char(out, '/');
            dynbuf_appendn(out, text+1, text_len-2);
            dynbuf_append_char(out, '/');
        }
        dynbuf_append_char(out, '\n');
    }
}


/**
 * True if this unit has type Name = ... for a portable rebindable name.
 */
bool codegen_unit_binds_portable(const Node *prog, const char *name, size_t name_len)
{
    size_t i;
    const Node *d;
    size_t j;
    const Node *item;
    const char *bind = NULL;
    size_t bind_len = 0;

    if (prog == NULL or prog->kind != NODE_PROGRAM or name == NULL or name_len == 0) {
        return false;
    }
    for (i = 0; i < prog->program_decl.count; i++) {
        d = prog->program_decl.decls[i];
        // if (d == NULL or d->kind != NODE_TYPE_DECL) {
        if (d == NULL) {
            continue;
        }
        if (d->kind == NODE_TYPE_DECL) {
            if (d->type_decl.is_forward or d->type_decl.is_extern) {
                continue;
            }
            if (d->type_decl.name == NULL or d->type_decl.name_len != name_len) {
                continue;
            }
            if (memcmp(d->type_decl.name, name, name_len) == 0) {
                return true;
            }
            continue;
        }
        if (d->kind != NODE_IMPORT) {
            continue;
        }
        if (d->import_stmt.from_path == NULL or
                not mh_path_is_mh(d->import_stmt.from_path, d->import_stmt.path_len)) {
            continue;
        }
        for (j = 0; j < d->import_stmt.count; j++) {
            item = d->import_stmt.items[j];
            if (item == NULL or item->kind != NODE_IMPORT_ITEM) {
                continue;
            }
            bind = item->import_item.qualident;
            bind_len = item->import_item.qualident_len;
            if (item->import_item.import_alias != NULL and
                    item->import_item.import_alias_len > 0) {
                bind = item->import_item.import_alias;
                bind_len = item->import_item.import_alias_len;
            }
            if (bind != NULL and bind_len == name_len and
                    memcmp(bind, name, name_len) == 0) {
                return true;
            }
        }
    }
    return false;
}


/**
 * C ABI prelude for a generated .h (includes, nil, byte, portable four).
 * Unit TYPE binds replace the default typedef for that name.
 */
void codegen_emit_c_prelude(DynBuf *out, const Node *prog)
{
    if (out == NULL) {
        return;
    }

    dynbuf_append(out, "#include <stdint.h>\n");
    dynbuf_append(out, "#include <stdbool.h>\n");
    dynbuf_append(out, "#include <assert.h>\n");
    dynbuf_append_char(out, '\n');

    dynbuf_append(out, "#define nil ((void *)0)\n");
    dynbuf_append(out, "#define NIL nil\n");
    dynbuf_append(out, "typedef uint8_t byte;\n");

    // Portable four: unit TYPE rebind replaces the default (Language Report 5.5/ 10.1)
    if (!codegen_unit_binds_portable(prog, "string", 6)) {
        dynbuf_append(out, "typedef const char* string;\n");
    }
    if (!codegen_unit_binds_portable(prog, "integer", 7)) {
        dynbuf_append(out, "typedef int integer;\n");
    }
    if (!codegen_unit_binds_portable(prog, "cardinal", 8)) {
        dynbuf_append(out, "typedef unsigned int cardinal;\n");
    }
    if (!codegen_unit_binds_portable(prog, "real", 4)) {
        dynbuf_append(out, "typedef float real;\n");
    }
    dynbuf_append_char(out, '\n');
}


/**
 * Emit return type. Same as type-specifier except [] not allowed.
 * TODO: fill out code for handling array type returns, i.e. they must collaps into just *
 */
void emit_return_type(DynBuf *out, const TType *t)
{
    if (t == NULL) {
        dynbuf_append(out, "int");
        return;
    }

    if (t->is_const) {
        dynbuf_append(out, "const ");
    }

    if (t->is_pointer) {
        emit_type_leaf_name(out, t);
        dynbuf_append_char(out, '*');
    } else if (t->is_array and t->element_type != NULL) {
        emit_type_leaf_name(out, t->element_type);
        if (t->element_type->is_pointer) {
            dynbuf_append_char(out, '*');
        }
        dynbuf_append_char(out, '*');
    } else {
        emit_type_leaf_name(out, t);
    }
}


/**
 * Emit C array type syntax for typedefs and declarations.
 * Recursively handles nested arrays and the ARRAY[N] of syntax.
 * Produces correct C syntax, for example: int Matrix[4][4] or int Vector3[3]
 *
 * Called with name = NULL when emitting only the base type (inner recursion).
 */
void emit_array_type(DynBuf *out, const TType *t, const char *name, size_t name_len)
{
    if (t == NULL) {
        dynbuf_append(out, "int");
        if (name != NULL and name_len > 0) {
            dynbuf_append_char(out, ' ');
            dynbuf_appendn(out, name, name_len);
        }
        return;
    }

    if (t->is_array and t->element_type != NULL) {
        // Recurse to emit base type + name (name only at outermost level)
        emit_array_type(out, t->element_type, name, name_len);

        // Emit this level's dimension (outermost first)
        dynbuf_append_char(out, '[');
        if (t->array_size > 0) {
            char buf[32] = {0};
            // Simple portable number -> string (no new utils needed)
            snprintf(buf, sizeof(buf), "%zu", t->array_size);
            dynbuf_append(out, buf);
        } else {
            // open array [] (rare in typedefs but supported)
            // dynbuf_append_char(out, ']');    // just []
            // return;  // no extra chars needed
            // int n[] = {3, 1, 4, };   // is supported.
        }
        dynbuf_append_char(out, ']');
        return;
    }

    // Leaf / base type (int, ^char, String, etc.)
    if (t->is_const) {
        dynbuf_append(out, "const ");
    }
    if (t->is_pointer) {
        if (t->name != NULL and t->name_len > 0) {
            emit_type_leaf_name(out, t);
        } else {
            dynbuf_append(out, "void");
        }
        dynbuf_append_char(out, '*');
    } else {
        emit_type_leaf_name(out, t);
    }

    if (name != NULL and name_len > 0) {
        dynbuf_append_char(out, ' ');
        dynbuf_appendn(out, name, name_len);
    }
}


/**
 * Emit type specifier (for typedef, function returns, parameters, etc.)
 * Supports: normal types, open arrays T[], fixed arrays T[N]. If type is an array
 * it needs the name of of identifier associated with the type as array information 
 * will be declared after the identifier name. If name = NULL or len = 0, then array 
 * information will collaps into just a '*' after the type name.
 * New Parameter Passing Model:
 *  - VAR   -> T*
 *  - REF   -> T*
 *  - CONST -> const T* (or const T for small types)
 *  - default -> T (or const T* for aggregates)
 *
 * @param out = output buffer
 * @param t = TType to generate code for
 * @param name = name of the identifier associated with type. Needed for arrays
 * @param len = lenght of the name.
 */
void emit_type_specifier(DynBuf *out, const TType *t, 
                                    const char* name, size_t len,
                                    bool is_param, bool is_var, bool is_ref, bool is_const)
{
    if (t == NULL) {
        dynbuf_append(out, "int ");
        if (name != NULL and len > 0) {
            dynbuf_appendn(out, name, len);
        }
        return;
    }

    // Parameter qualifiers take precedence
    bool emit_const = is_const or t->is_const;
    // bool emit_pointer = false;

    if (is_param) {
        if (is_var or is_ref) {
            // emit_pointer = true;     // mutable alias or pointer
        } else if (emit_const) {
            dynbuf_append(out, "const ");
            // For small types we could pass by value, but pointer is safer for consistency
            // emit_pointer = true;
        } else {
            // Default immutable parameter: pass by pointer for aggregates, by value for small
            // For phase 1 we uniformly use pointer + const for safety/readability
            // emit_pointer = true;
        }
    } else {
        // Non-parameter (var/let/const decl)
        if (emit_const) {
            dynbuf_append(out, "const ");
        }
    }

    // Base type. Full support for nested arrays (ARRAY[N] OF ... and [N])
    // Pointer-to-array (^array[N] of T): both flags on one TType.
    // Must not take array decay (params) or emit_array_type (T name[N]).
    // C: T (*name)[N]. Open N => T (*name)[]. Named ^Vector3 is not this
    // arm (is_pointer only on the use type -> Vector3 *p below).
    // v1: element is a leaf (integer, struct name), not a nested array.
    if (t->is_array and t->element_type != NULL and t->is_pointer) {
        char buf[32] = {0};

        emit_type_leaf_name(out, t->element_type);
        dynbuf_append(out, " (*");
        if (name != NULL and len > 0) {
            dynbuf_appendn(out, name, len);
        }
        dynbuf_append(out, ")");
        dynbuf_append_char(out, '[');
        if (t->array_size > 0) {
            snprintf(buf, sizeof(buf), "%zu", t->array_size);
            dynbuf_append(out, buf);
        }
        dynbuf_append_char(out, ']');
        return;
    }

    if (t->is_array and t->element_type != NULL) {
        if (is_param) {
            // Parameters: array decay to pointer (C standard)
            emit_type_specifier(out, t->element_type, NULL, 0, true, false, false, is_const);
            dynbuf_append_char(out, '*');       // ensure pointer

            if (name != NULL and len > 0) {
                dynbuf_append_char(out, ' ');
                dynbuf_appendn(out, name, len);
            }
        } else {
            // Typedefs / variable declarations: emit full C array syntax
            emit_array_type(out, t, name, len);
            return;     // recursion already emitted everything.
        }
        return;
    }

    // Normal non-array type (pointer, named type, etc.)
    if (t->is_pointer) {
        if (t->name != NULL and t->name_len > 0) {
            emit_type_leaf_name(out, t);
        } else {
            dynbuf_append(out, "void");
        }
        dynbuf_append_char(out, '*');
    } else {
        emit_type_leaf_name(out, t);
    }

    // // VAR / REF formals lower to T* (Oberon-style alias / reference).
    // if (is_param and (is_var or is_ref)) {
    // VAR/REF on a non-pointer T => T* (alias / reference to value).
    // REF on ^T => leave as T* (pointer by value; no rebind of caller's pointer).
    // VAR on ^T => T** so p := nil can rebind the caller's pointer variable.
    if (is_param and (is_var or is_ref) and not t->is_pointer) {
        dynbuf_append_char(out, '*');
    } else if (is_param and is_var and t->is_pointer) {
        dynbuf_append_char(out, '*');       // T** for VAR p: ^T
    }

    if (name != NULL and len > 0) {
        dynbuf_append_char(out, ' ');
        dynbuf_appendn(out, name, len);
    }
}


/**
 * Emit parameter list
 */
void emit_param_list(DynBuf *out,  Node **params, size_t count, bool is_parameter,
        bool has_ellipsis)
{
    // Parameter list
    dynbuf_append(out, "(");

    if (params != NULL and count > 0) {
        for (size_t i = 0; i < count; i++) {
            const Node *param = params[i];
            if (i > 0) {
                dynbuf_append(out, ", ");
            }

            emit_type_specifier(out, 
                param->param.param_type, 
                param->param.name, 
                param->param.name_len,
                is_parameter,
                param->param.is_var,
                param->param.is_ref,
                param->param.is_const);
        }
        if (has_ellipsis) {
            dynbuf_append(out, ", ...");
        }
    } else {
        dynbuf_append(out, "void");     // no parameters
    }

    dynbuf_append(out, ")");    
}


/**
 * Emit a full variable declaration (name + array brackets in correct position)
 * Example bool is_prime[101] = {0}
 */
void emit_var_decl(DynBuf *out, const char *name, size_t name_len, const TType *t)
{
    if (t == NULL) {
        dynbuf_append(out, "int ");
        dynbuf_appendn(out, name, name_len);
        return;
    }

    emit_type_specifier(out, t, name, name_len, false, false, false, false);
}


/**
 * Emit a LET binding name: name_l{line}_c{col}
 * binding_decl is the NODE_LET_ITEM (sym-decl or let item node).
 */
void emit_let_binding_name(DynBuf *out, const char *name, size_t name_len,
                        const Node *binding_decl)
{
    char buf[32];

    if (out == NULL or name == NULL or name_len == 0 or binding_decl == NULL) {
        return;
    }

    dynbuf_appendn(out, name, name_len);
    dynbuf_append(out, "_l");
    snprintf(buf, sizeof(buf), "%d", binding_decl->token.line);
    dynbuf_append(out, buf);
    dynbuf_append(out, "_c");
    snprintf(buf, sizeof(buf), "%d", binding_decl->token.column);
    dynbuf_append(out, buf);
}


/**
 * codegen_param_is_by_ref
 */
static bool codegen_param_is_by_ref(const Node *param_decl)
{
    if (param_decl == NULL or param_decl->kind != NODE_PARAM) {
        return false;
    }
    return param_decl->param.is_var or param_decl->param.is_ref;
}


/**
 * True when C formal is T* alias of value T (not when formal type is already ^U).
 */
static bool codegen_param_needs_pointee_load(const Node *param_decl)
{
    const TType *ty;
    if (!codegen_param_is_by_ref(param_decl)) {
        return false;
    }
    ty = param_decl->param.param_type;
    if (ty == NULL) {
        return false;
    }
    // Open arrray already decays to pointer; use name as pointer
    if (ty->is_array) {
        return false;
    }
    // REF/VAR on non-pointer T => (*p). REF on ^T => p. VAR on ^T => (*p) is T*.
    if (ty->is_pointer) {
        return param_decl->param.is_var;        // only VAR ^T uses (*p) as T*
    }
    return true;        // VAR/REF T
}


/**
 * Formal for call arg index (0-based). Instance sugar: reciver is formal 0,
 * so args[i] maps to formals[i + 1].
 */
static const Node *codegen_call_formal_for_arg(const Node *call, size_t arg_index)
{
    const Node *decl;
    const Node *pl;
    size_t fi;

    if (call == NULL or call->resolved_sym == NULL or call->resolved_sym->decl == NULL) {
        return NULL;
    }
    decl = call->resolved_sym->decl;
    if (decl->kind != NODE_PROC_DECL and decl->kind != NODE_FUNC_DECL) {
        return NULL;
    }
    pl = decl->proc_decl.params;
    if (pl == NULL or pl->kind != NODE_PARAM_LIST or pl->param_list.params == NULL) {
        return NULL;
    }
    fi = arg_index;
    if (call->call.receiver_expr != NULL) {
        fi = arg_index + 1;
    }
    if (fi >= pl->param_list.count) {
        return NULL;
    }
    return pl->param_list.params[fi];
}


/**
 * codegen_call_formal_receiver
 */
static const Node *codegen_call_formal_receiver(const Node *call)
{
    const Node *decl;
    const Node *pl;

    if (call == NULL or call->call.receiver_expr == NULL) {
        return NULL;
    }
    if (call->resolved_sym == NULL or call->resolved_sym->decl == NULL) {
        return NULL;
    }
    decl = call->resolved_sym->decl;
    if (decl->kind != NODE_PROC_DECL and decl->kind != NODE_FUNC_DECL) {
        return NULL;
    }
    pl = decl->proc_decl.params;
    if (pl == NULL or pl->kind != NODE_PARAM_LIST or pl->param_list.count == 0) {
        return NULL;
    }
    return pl->param_list.params[0];
}


/**
 * True when this actual should be emitted with a leading '&' for a VAR/REF formal
 */
static bool codegen_args_needs_address(const Node *formal, const Node *arg)
{
    const TType *ty;

    if (formal == NULL or arg == NULL or formal->kind != NODE_PARAM) {
        return false;
    }
    // Already address-of (@x => &x).
    if (arg->kind == NODE_UNARY and arg->unary.op == TOK_AT) {
        return false;
    }
    if (!codegen_param_is_by_ref(formal)) {
        return false;
    }
    ty = formal->param.param_type;
    if (ty == NULL) {
        return false;
    }
    if (ty->is_array) {
        return false;
    }
    if (ty->is_pointer) {
        // VAR p: ^T => T**; need &ptr_var. REF p: ^T => T*; pass pointer as-is.
        return formal->param.is_var;
    }
    // VAR/REF p: T => T*; need &value.
    return true;
}


/**
 * codegen_emit_call_arg_deref
 */
static void codegen_emit_call_arg_deref(const Node *formal, const Node *arg, 
        bool auto_deref, size_t base_depth, CodegenContext ctx)
{
    bool need_addr;
    bool wrap;
    size_t i;

    need_addr =codegen_args_needs_address(formal, arg);
    wrap = need_addr and (auto_deref or base_depth > 0);

    if (need_addr) {
        dynbuf_append_char(ctx.out, '&');
    }
    if (wrap) {
        dynbuf_append_char(ctx.out, '(');
    }
    if (auto_deref) {
        dynbuf_append(ctx.out, "(*");
    }
    codegen_common_expr(arg, ctx);
    if (auto_deref) {
        dynbuf_append_char(ctx.out, ')');
    }
    for (i = 0; i < base_depth; i++) {
        dynbuf_append(ctx.out, ".base");
    }
    if (wrap) {
        dynbuf_append_char(ctx.out, ')');
    }
}


/**
 * codegen_emit_call_arg
 */
// static void codegen_emit_call_arg(const Node *formal, const Node *arg, CodegenContext ctx)
// {
//     codegen_emit_call_arg_deref(formal, arg, false, ctx);
// }


/**
 * Emit an identifier expression (mangles LET uses via resolved_sym).
 */
void emit_let_ident(DynBuf *out, const Node *n)
{
    if (n == NULL or out == NULL) {
        return;
    }

    if (n->resolved_sym != NULL and n->resolved_sym->kind == SYM_KIND_LET and
            n->resolved_sym->decl != NULL) {
        emit_let_binding_name(out, n->resolved_sym->name,
                                        n->resolved_sym->name_len,
                                        n->resolved_sym->decl);
    } else if (n->resolved_sym != NULL and n->resolved_sym->kind == SYM_KIND_PARAM and
            codegen_param_needs_pointee_load(n->resolved_sym->decl)) {
        // VAR/REF formal is T* in C; surface name is the pointee.
        dynbuf_append(out, "(*");
        dynbuf_appendn(out, n->token.start, n->token.length);
        dynbuf_append_char(out, ')');
    } else if (n->token.length > 0 and n->token.start != NULL) {
        dynbuf_appendn(out, n->token.start, n->token.length);
    }
}


/**
 * Emit a TYPE declaration.
 * Simple types for now.
 */
void codegen_common_type_decl(const Node *n, CodegenContext ctx)
{
    if (n == NULL) {
        return;
    }

    emit_indent(ctx.out, ctx.indent);

    // type Name FORWARD -- incomplete tag+typedef so the name exists for ^Name
    // and for a later complete struct. Method types that take Name by value
    // must still be emitted after the complete defintion (see codegen_c).
    if (n->type_decl.is_forward) {
        if (n->type_decl.name == NULL or n->type_decl.name_len == 0) {
            dynbuf_append(ctx.out, "/* type FORWARD (unnamed) */ \n");
            return;
        }
        dynbuf_append(ctx.out, "typedef struct ");
        dynbuf_appendn(ctx.out, n->type_decl.name, n->type_decl.name_len);
        dynbuf_append_char(ctx.out, ' ');
        dynbuf_appendn(ctx.out, n->type_decl.name, n->type_decl.name_len);
        dynbuf_append(ctx.out, ";\n");
        return;
    }

    // extern type Name = struct [tag] -- alias forthe C tag; layout from #include
    if (n->type_decl.is_extern and n->type_decl.is_extern_struct) {
        const char *tag;
        size_t tag_len;

        if (n->type_decl.name == NULL or n->type_decl.name_len == 0) {
            dynbuf_append(ctx.out, "/* extern type struct (unnamed) */\n");
            return;
        }
        if (n->type_decl.c_tag_name != NULL and n->type_decl.c_tag_name_len > 0) {
            tag = n->type_decl.c_tag_name;
            tag_len = n->type_decl.c_tag_name_len;
        } else {
            tag = n->type_decl.name;
            tag_len = n->type_decl.name_len;
        }
        dynbuf_append(ctx.out, "typedef struct ");
        dynbuf_appendn(ctx.out, tag, tag_len);
        dynbuf_append_char(ctx.out, ' ');
        dynbuf_appendn(ctx.out, n->type_decl.name, n->type_decl.name_len);
        dynbuf_append(ctx.out, ";\n");
        return;
    }

    // Opaque EXTERN TYPE: C definition comes from #include, not typedef here.
    if (n->type_decl.is_extern and n->type_decl.defined_type == NULL) {
        dynbuf_append(ctx.out, "/* extern type ");
        dynbuf_appendn(ctx.out, n->type_decl.name, n->type_decl.name_len);
        dynbuf_append(ctx.out, " (foreign) */\n");
        return;
    }

    if (n->type_decl.name == NULL or n->type_decl.name_len == 0) {
        dynbuf_append(ctx.out, "/* TODO: codegen_common_type_decl: Invalid TYPE node */\n");
        return;
    }

    dynbuf_append(ctx.out, "typedef ");

    // Check if this TYPE is defining a STRUCT or UNION
    if (n->type_decl.struct_body != NULL) {
        // Emit the struct inline
        if (n->type_decl.struct_body->struct_decl.is_union) {
            codegen_common_union_decl(n->type_decl.struct_body, ctx);
        } else {
            codegen_common_struct_decl(n->type_decl.struct_body, ctx);
        }
    }

    // ENUM types
    else if (n->type_decl.enum_type != NULL) {
        codegen_common_enum_type(n->type_decl.enum_type,
            n->type_decl.name, n->type_decl.name_len, ctx);
    }

    // Method types
    else if (n->type_decl.method_type != NULL) {
        codegen_common_method_type(n->type_decl.method_type, n, ctx);
    }

    // Regular type (alias, pointer, array, etc.)
    else if (n->type_decl.defined_type != NULL) {
        const TType *dt = n->type_decl.defined_type;

        if (dt->is_opaque) {
            // v1: both opaque and ^opaque => void * alias
            dynbuf_append(ctx.out, "void *");
            dynbuf_appendn(ctx.out, n->type_decl.name, n->type_decl.name_len);
            // dynbuf_append(ctx.out, ";\n");
            // return
        } else if (n->type_decl.defined_type->is_array and n->type_decl.defined_type->element_type != NULL) {
            emit_type_specifier(ctx.out, 
                n->type_decl.defined_type, 
                n->type_decl.name, 
                n->type_decl.name_len,
                false, false, false, false);
        } else {
            //Normal type or pointer
            emit_type_specifier(ctx.out, n->type_decl.defined_type, n->type_decl.name, n->type_decl.name_len,
                false, false, false, false);
        }
        // dynbuf_append_char(ctx.out, ' ');

    } else {
        emit_type_specifier(ctx.out, n->type_decl.defined_type, n->type_decl.name, n->type_decl.name_len,
            false, false, false, false);
    }

    dynbuf_append(ctx.out, ";\n");

    return;
}


/**
 * Emit Declaration portion of PROCEDURE or FUNCTION.
 * To be called by codegen_c or codegen_header.
 */
void codegen_common_proc_or_func(const Node *n, CodegenContext ctx)
{
    if (n == NULL) {
        return;
    }

    if (n->kind != NODE_PROC_DECL and n->kind != NODE_FUNC_DECL) {
        dynbuf_append(ctx.out, "/* TODO: codegen_common_proc_or_func: unexpected node */\n");
        return;
    }

    emit_indent(ctx.out, ctx.indent);

    if (n->proc_decl.is_extern) {
        dynbuf_append(ctx.out, "extern ");
    } else if (not n->proc_decl.is_exported) {
        dynbuf_append(ctx.out, "static ");
    }

    // Return type
    if (n->kind == NODE_FUNC_DECL and n->proc_decl.return_type != NULL) {
        emit_return_type(ctx.out, n->proc_decl.return_type);
        dynbuf_append_char(ctx.out, ' ');
    } else {
        dynbuf_append(ctx.out, "void ");
    }

    // Function name
    if (n->proc_decl.method_owner != NULL and n->proc_decl.method_owner_len > 0) {
        dynbuf_appendn(ctx.out, n->proc_decl.method_owner, n->proc_decl.method_owner_len);
        dynbuf_append(ctx.out, "__");
        dynbuf_appendn(ctx.out, n->proc_decl.name, n->proc_decl.name_len);
    } else {
        dynbuf_appendn(ctx.out, n->proc_decl.name, n->proc_decl.name_len);
    }

    // Parameter list
    if (n->proc_decl.params != NULL) {
        emit_param_list(ctx.out, n->proc_decl.params->param_list.params, n->proc_decl.params->param_list.count, true, 
            n->proc_decl.params->param_list.has_ellipsis);
    } else {
        emit_param_list(ctx.out, NULL, 0, false, false);
    }


}


/**
 * Emit STRUCT declaration.
 * Maps to a C typedef struct with named fields.
 */
void codegen_common_struct_decl(const Node *n, CodegenContext ctx)
{
    if (n == NULL or n->kind != NODE_STRUCT_DECL or n->struct_decl.is_union) {
        dynbuf_append(ctx.out, "/* TODO: codegen_common_struct_decl: invalid STRUCT node */\n");
        return;
    }

    // First forward declare the struct so self-referential poitners will work.
    dynbuf_append(ctx.out, "struct ");
    if (n->struct_decl.is_packed) {
        dynbuf_append(ctx.out, "__attribute__((packed)) ");
    }

    dynbuf_appendn(ctx.out, n->struct_decl.name, n->struct_decl.name_len);
    dynbuf_append_char(ctx.out, ' ');
    dynbuf_appendn(ctx.out, n->struct_decl.name, n->struct_decl.name_len);
    dynbuf_append(ctx.out, ";\n");

    // Now emit the regular definition. 
    emit_indent(ctx.out, ctx.indent);
    dynbuf_append(ctx.out, "typedef struct ");
    if (n->struct_decl.is_packed) {
        dynbuf_append(ctx.out, "__attribute__((packed)) ");
    }
    dynbuf_appendn(ctx.out, n->struct_decl.name, n->struct_decl.name_len);
    dynbuf_append(ctx.out, " {\n");

    // EXTENDS support for STRUCT: embed base struct as first member (C composition)
    if (n->struct_decl.extends_type != NULL) {
        emit_indent(ctx.out, ctx.indent + 1);
        dynbuf_append(ctx.out, "struct ");
        if (n->struct_decl.extends_type->name != NULL and
            n->struct_decl.extends_type->name_len > 0) {
            dynbuf_appendn(ctx.out, n->struct_decl.extends_type->name,
                            n->struct_decl.extends_type->name_len);
        } else {
            dynbuf_append(ctx.out, "Base");         // fallback
        }
        dynbuf_append(ctx.out, " base;\n");
    }

    // Emit fields
    for (size_t i = 0; i < n->struct_decl.field_count; i++) {
        const Node *f = n->struct_decl.fields[i];
        if (f == NULL) {
            continue;
        }

        emit_indent(ctx.out, ctx.indent + 1);

        // Field type
        if (f->field_decl.field_type != NULL) {
            emit_type_specifier(ctx.out, f->field_decl.field_type, f->field_decl.name, f->field_decl.name_len,
                false, false, false, false);
        } else {
            dynbuf_append(ctx.out, "int "); // safe fallback
        }

        // dynbuf_append_char(out, ' ');

        // Field name
        // dynbuf_appendn(out, f->field_decl.name, f->field_decl.name_len);

        // Optional initializer (rare in struct fields)
        if (f->field_decl.initializer != NULL) {
            dynbuf_append(ctx.out, " = ");
            codegen_common_expr(f->field_decl.initializer, ctx);
        }

        dynbuf_append(ctx.out, ";\n");
    }

    emit_indent(ctx.out, ctx.indent);
    dynbuf_append(ctx.out, "} ");
    dynbuf_appendn(ctx.out, n->struct_decl.name, n->struct_decl.name_len);
}


/**
 * Emit UNION declaration. (Uses NODE_STRUCT_DECL)
 * Maps to a C typedef union with named fields.
 */
void codegen_common_union_decl(const Node *n, CodegenContext ctx)
{
    if (n == NULL or n->kind != NODE_STRUCT_DECL or not n->struct_decl.is_union) {
        dynbuf_append(ctx.out, "/* TODO: codegen_common_union_decl: invalid UNION node */\n");
        return;
    }

    // First forward declare the union so self-referential poitners will work.
    dynbuf_append(ctx.out, "union ");
    dynbuf_appendn(ctx.out, n->struct_decl.name, n->struct_decl.name_len);
    dynbuf_append_char(ctx.out, ' ');
    dynbuf_appendn(ctx.out, n->struct_decl.name, n->struct_decl.name_len);
    dynbuf_append(ctx.out, ";\n");

    // Now emit the regular definition. 
    emit_indent(ctx.out, ctx.indent);
    dynbuf_append(ctx.out, "typedef union ");
    dynbuf_appendn(ctx.out, n->struct_decl.name, n->struct_decl.name_len);
    dynbuf_append(ctx.out, " {\n");

    // Emit fields
    for (size_t i = 0; i < n->struct_decl.field_count; i++) {
        const Node *f = n->struct_decl.fields[i];
        if (f == NULL) {
            continue;
        }

        emit_indent(ctx.out, ctx.indent + 1);

        // Field type
        if (f->field_decl.field_type != NULL) {
            emit_type_specifier(ctx.out, f->field_decl.field_type, f->field_decl.name, f->field_decl.name_len,
                false, false, false, false);
        } else {
            dynbuf_append(ctx.out, "int "); // safe fallback
        }

        // dynbuf_append_char(out, ' ');

        // Field name
        // dynbuf_appendn(out, f->field_decl.name, f->field_decl.name_len);

        // Optional initializer (rare in struct fields)
        if (f->field_decl.initializer != NULL) {
            dynbuf_append(ctx.out, " = ");
            codegen_common_expr(f->field_decl.initializer, ctx);
        }

        dynbuf_append(ctx.out, ";\n");
    }

    emit_indent(ctx.out, ctx.indent);
    dynbuf_append(ctx.out, "} ");
    dynbuf_appendn(ctx.out, n->struct_decl.name, n->struct_decl.name_len);
}


/**
 * Emit ENUM type body for TYPE T = ENUM ... END.
 * Emits: enum { M = n, ... } TypeName
 * (Caller adds 'typedef' and trailing ';')
 */
void codegen_common_enum_type(const Node *en, const char *type_name, size_t type_name_len, CodegenContext ctx)
{
    size_t i;

    if (en == NULL or en->kind != NODE_ENUM_TYPE or type_name == NULL or type_name_len == 0) {
        dynbuf_append(ctx.out, "/* TODO: codegen_common_enum_type: invalid ENUM node */\n");
    }

    emit_indent(ctx.out, ctx.indent);
    dynbuf_append(ctx.out, "enum {\n");

    for (i = 0; i < en->enum_type.count; i++) {
        const Node *item = en->enum_type.elements[i];
        if (item == NULL or item->kind != NODE_ENUM_ITEM) {
            continue;
        }

        emit_indent(ctx.out, ctx.indent + 1);
        dynbuf_appendn(ctx.out, item->enum_item.name, item->enum_item.name_len);
        if (item->enum_item.value_known) {
            dynbuf_append(ctx.out, " = ");
            // small int - snprintf avoids int-string helper
            {
                char num[32];
                (void) snprintf(num, sizeof num, "%d", item->enum_item.int_value);
                dynbuf_append(ctx.out, num);
            }
        }
        if (i + 1 < en->enum_type.count) {
            dynbuf_append(ctx.out, ",");
        }
        dynbuf_append_char(ctx.out, '\n');
    }

    emit_indent(ctx.out, ctx.indent);
    dynbuf_append(ctx.out, "} ");
    dynbuf_appendn(ctx.out, type_name, type_name_len);
}


/**
 * Generate method type.
 */
void codegen_common_method_type(const Node *method, const Node *type_decl, CodegenContext ctx)
{
    if (method == NULL or method->kind != NODE_METHOD_TYPE) {
        dynbuf_append(ctx.out, "/* TODO: codegen_common_method_type: invalid METHOD_TYPE node */\n");
        return;
    }

    // Emit return type
    if (method->method_type.return_type != NULL) {
        emit_return_type(ctx.out, method->method_type.return_type);
    } else {
        dynbuf_append(ctx.out, "void");
    }

    // Emit " (*Name)"
    dynbuf_append(ctx.out, " (*");
    dynbuf_appendn(ctx.out, type_decl->type_decl.name, type_decl->type_decl.name_len);
    dynbuf_append(ctx.out, ")");

    // Emit parameter list using the existing helper (includes names)
    if (method->method_type.params != NULL and
        method->method_type.params->kind == NODE_PARAM_LIST) {
        Node *plist = method->method_type.params;
        emit_param_list(ctx.out,
                        plist->param_list.params,
                        plist->param_list.count,
                        true,
                        plist->param_list.has_ellipsis);
    } else {
        dynbuf_append(ctx.out, "(void)");
    }
}


/**
 * Emit expression
 */
void codegen_common_expr(const Node *n, CodegenContext ctx)
{
    size_t up = 0;
    size_t ui = 0;
    size_t i = 0;

    if (n == NULL) {
        dynbuf_append(ctx.out, "NULL");
        return;
    }

    up = n->upcast_depth;
    if (up > 0) {
        if (n->upcast_ptr) {
            dynbuf_append(ctx.out, "&((*(");
        } else {
            dynbuf_append(ctx.out, "((");
        }
    }

    switch (n->kind) {
        case NODE_IDENT:
            // dynbuf_appendn(ctx.out, n->token.start, n->token.length);
            emit_let_ident(ctx.out, n);
            break;

        case NODE_LITERAL:
            codegen_common_emit_literal(n, ctx);
            break;

        case NODE_ARRAY_INDEX:
            if (n->array_index.auto_deref) {
                dynbuf_append(ctx.out, "(*");
            }
            codegen_common_expr(n->array_index.array_, ctx);
            if (n->array_index.auto_deref) {
                dynbuf_append_char(ctx.out, ')');
            }
            dynbuf_append_char(ctx.out, '[');
            codegen_common_expr(n->array_index.index, ctx);
            dynbuf_append_char(ctx.out, ']');
            break;
            
        case NODE_FIELD_ACCESS:
            codegen_common_field_access(n, ctx);
            break;

        case NODE_CALL:
            // Field / value call-through: emit designator, then (args). No receiver prepend
            if (n->call.callee_expr != NULL) {
                dynbuf_append_char(ctx.out, '(');
                codegen_common_expr(n->call.callee_expr, ctx);
                dynbuf_append_char(ctx.out, ')');
            } else if (n->resolved_sym != NULL) {
                dynbuf_appendn(ctx.out, n->resolved_sym->name, n->resolved_sym->name_len);
            } else if (n->call.method_owner != NULL and n->call.method_owner_len > 0) {
                dynbuf_appendn(ctx.out, n->call.method_owner, n->call.method_owner_len);
                dynbuf_append(ctx.out, "__");
                dynbuf_appendn(ctx.out, n->call.name, n->call.name_len);
            } else {
                dynbuf_appendn(ctx.out, n->call.name, n->call.name_len);
            }
            dynbuf_append(ctx.out, "(");
            // Insance sugar only when not a field call-through
            if (n->call.callee_expr == NULL and n->call.receiver_expr != NULL) {
                codegen_emit_call_arg_deref(codegen_call_formal_receiver(n),
                    n->call.receiver_expr, n->call.auto_deref,
                    n->call.base_depth, ctx);
            }
            for (i = 0; i < n->call.argc; i++) {
                // if (i > 0 or n->call.receiver_expr != NULL) {
                if (i > 0 or (n->call.callee_expr == NULL and n->call.receiver_expr != NULL)) {
                    dynbuf_append(ctx.out, ", ");
                }
                // codegen_emit_call_arg(codegen_call_formal_for_arg(n, i),
                //     n->call.args[i], ctx);
                codegen_emit_call_arg_deref(codegen_call_formal_for_arg(n, i),
                    n->call.args[i],
                    (i == 0 and n->call.receiver_expr == NULL and
                        n->call.callee_expr == NULL and n->call.auto_deref),
                    (i == 0 and n->call.receiver_expr == NULL and
                        n->call.callee_expr == NULL) ? n->call.base_depth : 0,
                    ctx);
            }

            dynbuf_append(ctx.out, ")");
            break;

        case NODE_ASSIGN:
            codegen_common_expr(n->binary.left, ctx);
            dynbuf_append_char(ctx.out, ' ');

            // Support comound assignment (updated 23 Apr)
            const char *op_str = "=";
            TokenKind op = n->binary.op;
            if (op == TOK_COLON_EQ) {
                op_str = "=";
            } else if (op == TOK_ADD_EQ) {
                op_str = "+=";
            } else if (op == TOK_SUB_EQ) {
                op_str = "-=";
            } else if (op == TOK_MUL_EQ) {
                op_str = "*=";
            } else if (op == TOK_DIV_EQ) {
                op_str = "/=";
            } else if (op == TOK_MOD_EQ) {
                op_str = "%=";
            } else if (op == TOK_AND_EQ) {
                op_str = "&=";
            } else if (op == TOK_OR_EQ) {
                op_str = "|=";
            } else if (op == TOK_BITWISE_NOT_EQ) {
                op_str = "^=";      // ~ becomes ^ in C for bitwise not.
            } else if (op == TOK_LSHIFT_EQ) {
                op_str = "<<=";
            } else if (op == TOK_RSHIFT_EQ) {
                op_str = ">>=";
            }
            dynbuf_append(ctx.out, op_str);
            dynbuf_append_char(ctx.out, ' ');
            codegen_common_expr(n->binary.right, ctx);
            break;

        case NODE_BINARY:
            if (n->binary.op == TOK_KEYWORD_DIV) {
                // Special handling for DIV: cast both sides to long (integer division)
                dynbuf_append(ctx.out, "(long)(");
                codegen_common_expr(n->binary.left, ctx);
                dynbuf_append(ctx.out, ") / (long)(");
                codegen_common_expr(n->binary.right, ctx);
                dynbuf_append(ctx.out, ")");
            } else if (n->binary.op == TOK_POWER) {
                dynbuf_append(ctx.out, "pow((");
                codegen_common_expr(n->binary.left, ctx);
                dynbuf_append(ctx.out, "),(");
                codegen_common_expr(n->binary.right, ctx);
                dynbuf_append(ctx.out, "))");
            } else {
                codegen_common_expr(n->binary.left, ctx);
                dynbuf_append_char(ctx.out, ' ');
                if (n->binary.op == TOK_KEYWORD_AND) {
                    dynbuf_append(ctx.out, "&&");
                } else if (n->binary.op == TOK_KEYWORD_OR) {
                    dynbuf_append(ctx.out, "||");
                } else if (n->binary.op == TOK_KEYWORD_MOD) {
                    dynbuf_append(ctx.out, "%");
                } else if (n->binary.op == TOK_KEYWORD_XOR) {
                    dynbuf_append(ctx.out, "^");
                } else {
                    dynbuf_append(ctx.out, TokenKind__string(n->binary.op));
                }
                dynbuf_append_char(ctx.out, ' ');
                codegen_common_expr(n->binary.right, ctx);
            }
            break;

        case NODE_TERNARY:
            dynbuf_append_char(ctx.out, '(');
            codegen_common_expr(n->ternary.cond, ctx);
            dynbuf_append(ctx.out, " ? ");
            codegen_common_expr(n->ternary.then_expr, ctx);
            dynbuf_append(ctx.out, " : ");
            codegen_common_expr(n->ternary.else_expr, ctx);
            dynbuf_append_char(ctx.out, ')');
            break;

        case NODE_CAST:
            if (n->upcast_depth > 0) {
                // EXTENDS: g as Parent => (g).base, not (Parent)g
                codegen_common_expr(n->cast_expr.expr, ctx);
            } else {
                dynbuf_append_char(ctx.out, '(');
                emit_type_specifier(ctx.out, n->cast_expr.target_type, NULL, 0, false, false, false, false);
                dynbuf_append(ctx.out, ")");
                codegen_common_expr(n->cast_expr.expr, ctx);
            }
            break;

        case NODE_UNARY:
            if (n->unary.op == TOK_AT) {
                dynbuf_append_char(ctx.out, '&');
            } else if (n->unary.op == TOK_CARET) {
                // Parenthesize so p^[i] is (*p)[i], not *p[i] ([] binds tighter).
                dynbuf_append(ctx.out, "(*");
                codegen_common_expr(n->unary.operand, ctx);
                dynbuf_append_char(ctx.out, ')');
                break;
            } else if (n->unary.op == TOK_KEYWORD_NOT) {
                dynbuf_append(ctx.out, "!");
            } else {
                dynbuf_append(ctx.out, TokenKind__string(n->unary.op));
            }
            codegen_common_expr(n->unary.operand, ctx);
            break;

        case NODE_PAREN:
            dynbuf_append_char(ctx.out, '(');
            codegen_common_expr(n->paren.expr, ctx);
            dynbuf_append_char(ctx.out, ')');
            break;

        case NODE_ARRAY_LITERAL:
            codegen_common_array_literal(n, ctx);
            break;

        case NODE_SIZEOF:
            codegen_common_sizeof_expr(n, ctx);
            break;

        case NODE_LEN:
            codegen_common_len_expr(n, ctx);
            break;

        case NODE_INC:
        case NODE_DEC:
            codegen_common_inc_dec(n, ctx, false);     // expression context
            break;

        case NODE_PREPROCESSOR:
            codegen_common_preprocessor(n, ctx);
            break;

        case NODE_DOC_COMMENT:
            // i DON'T THINK THEY SHOULD BE APPERING IN THE MIDDLE OF EXPRESSIONS???
            break;

        // Supress unhandled case warnings.
        case NODE_SWITCH:
        case NODE_DEBUG:
        case NODE_PROGRAM:
        case NODE_PROC_DECL:
        case NODE_FUNC_DECL:
        case NODE_VAR_DECL:
        case NODE_CONST_DECL:
        case NODE_LET_DECL:
        case NODE_VAR_ITEM:
        case NODE_CONST_ITEM:
        case NODE_LET_ITEM:
        case NODE_TYPE_DECL:
        case NODE_PARAM:
        case NODE_PARAM_LIST:
        case NODE_IMPORT:
        case NODE_IMPORT_ITEM:
        case NODE_STRUCT_DECL:
        case NODE_FIELD_DECL:
        case NODE_METHOD_TYPE:
        case NODE_ARRAY_TYPE:
        case NODE_BLOCK:
        case NODE_IF:
        case NODE_ELSIF:
        case NODE_ELSE:
        case NODE_FOR:
        case NODE_WHILE:
        case NODE_REPEAT_UNTIL:
        case NODE_LOOP:
        case NODE_BREAK:
        case NODE_CONTINUE:
        case NODE_RETURN:
        case NODE_EXPR_STMT:
        case NODE_ASSERT:
        case NODE_DEFER:
        case NODE_DEFINE:
        default:
            // TODO: expand as we add more expression kinds
            dynbuf_append(ctx.out, "/* TODO: codegen_common_expr: expr kind ");
            dynbuf_append(ctx.out, TokenKind__string((TokenKind)n->token.kind));
            dynbuf_append(ctx.out, " */");
            break;
    }

    if (up > 0) {
        if (n->upcast_ptr) {
            dynbuf_append(ctx.out, "))");
        } else {
            dynbuf_append_char(ctx.out, ')');
        }
        for (ui = 0; ui < up; ui++) {
            dynbuf_append(ctx.out, ".base");
        }
        dynbuf_append_char(ctx.out, ')');
    }
}


/**
 * Emit a literal value as C11-compatible source text.
 * - Decimal, hex (0x), octal (converted from 0o to 0), binary
 *   converted from 0b to octal or decimal)
 * - Strips all '_' separators.
 * - Preserves original token text for strings and chars.
 */
void codegen_common_emit_literal(const Node *n, CodegenContext ctx)
{
    if (n == NULL) {
        dynbuf_append(ctx.out, "0");
        return;
    }

    if (n->token.kind != TOK_NUMBER) {
        // String, char, etc. - emit as-is
        dynbuf_appendn(ctx.out, n->token.start, n->token.length);
        return;
    }

    // === Handleinteger literal with possible base prefix and _ separators ===
    const char *s = n->token.start;
    size_t len = n->token.length;

    if (len >= 2 and s[0] == '0') {
        char prefix = s[1];

        if (prefix == 'x' or prefix == 'X') {
            // Hex is already C11 compatible
            for (size_t i = 0; i < len; i++) {
                if (s[i] != '_') {
                    dynbuf_append_char(ctx.out, s[i]);
                }
            }
            return;
        } else if (prefix == 'o' or prefix == 'O') {
            // Convert 0o77 -> 077 (C11 octal)
            dynbuf_append_char(ctx.out, '0');
            for (size_t i = 2; i < len; i++) {
                if (s[i] != '_') {
                    dynbuf_append_char(ctx.out, s[i]);
                }
            }
            return;
        } else if (prefix == 'b' or prefix == 'B') {
            // Convert 0b1010 -> decimal (safest for C11)
            long long value = utils_parse_integer_literal(s, len);
            char buf[32];
            snprintf(buf, sizeof(buf), "%lld", value);
            dynbuf_append(ctx.out, buf);
            return;
        }
    }

    // Default: decimal with possible _ separators
    for (size_t i = 0; i < len; i++) {
        if (s[i] != '_') {
            dynbuf_append_char(ctx.out, s[i]);
        }
    }
}


/**
 * Emit array literal: { expr, expr, ... }
 * Special fast path for the extremly common {0} zero-initializer.
 */
void codegen_common_array_literal(const Node *n, CodegenContext ctx)
{
    if (n == NULL or n->kind != NODE_ARRAY_LITERAL) {
        dynbuf_append(ctx.out, "{0}");
        return;
    }

    if (n->array_literal.count == 1) {
        const Node *elem = n->array_literal.elements[0];
        if (elem != NULL and elem->kind == NODE_LITERAL and
            elem->token.length == 1 and elem->token.start[0] == '0') {
            dynbuf_append(ctx.out, "{0}");
            return;
        }
    }

    dynbuf_append(ctx.out, "{");
    for (size_t i = 0; i < n->array_literal.count; i++) {
        if (i > 0) {
            dynbuf_append(ctx.out, ", ");
        }
        codegen_common_expr(n->array_literal.elements[i], ctx);
    }
    dynbuf_append(ctx.out, "}");
}


/**
 * Preprocessor directives.
 */
void codegen_common_preprocessor(const Node *n, CodegenContext ctx)
{
    if (n == NULL or n->kind != NODE_PREPROCESSOR) {
        return;
    }

    dynbuf_appendn(ctx.out, n->preprocessor.text, n->preprocessor.length);
    dynbuf_append_char(ctx.out, '\n');
}


/**
 * Emit define
 */
void codegen_common_define(const Node *n, CodegenContext ctx)
{
    if (n == NULL or n->kind != NODE_DEFINE) {
        return;
    }

    dynbuf_append(ctx.out, "#define ");
    dynbuf_appendn(ctx.out, n->define_stmt.text, n->define_stmt.length);
    dynbuf_append_char(ctx.out, '\n');
}


/**
 * Emit field access: record.field
 */
void codegen_common_field_access(const Node *n, CodegenContext ctx)
{
    if (n == NULL) {
        return;
    }
    if (n->field_access.auto_deref) {
        dynbuf_append(ctx.out, "(*");
    }
    dynbuf_append_char(ctx.out, '(');
    codegen_common_expr(n->field_access.record_, ctx);
    dynbuf_append_char(ctx.out, ')');
    if (n->field_access.auto_deref) {
        dynbuf_append_char(ctx.out, ')');
    }
    {
        size_t d = n->field_access.base_depth;
        size_t i;
        for (i = 0; i < d; i++) {
            dynbuf_append(ctx.out, ".base");
        }
        // If record_ lowered as (*p), we need (*p).field not (*p)->field.
        // emit_let_ident already wraps (*p), so '.' is correct.
        // Only use '->' if we emit bare p without (*). Prefere (*p).x always.
        dynbuf_append_char(ctx.out, '.');
        dynbuf_appendn(ctx.out, n->field_access.field_name, n->field_access.field_len);
    }
}


/**
 * Emit LEN(designator) as C array-length idiom (itermin).
 * ((integer)(sizeof(n) / sizeof((n)[0])))
 */
void codegen_common_len_expr(const Node *n, CodegenContext ctx)
{
    const Node *d;

    if (n == NULL or n->kind != NODE_LEN or n->sizeof_expr.is_type or
            n->sizeof_expr.target.designator == NULL) {
        dynbuf_append(ctx.out, "((integer)0)");
        return;
    }
    d = n->sizeof_expr.target.designator;
    dynbuf_append(ctx.out, "((integer)(sizeof(");
    codegen_common_expr(d, ctx);
    dynbuf_append(ctx.out, ") / sizeof((");
    codegen_common_expr(d, ctx);
    dynbuf_append(ctx.out, ")[0])))");
}

/**
 * Emit SIZEOF (type or designator)
 */
void codegen_common_sizeof_expr(const Node *n, CodegenContext ctx)
{
    if (n == NULL or n->kind != NODE_SIZEOF) {
        dynbuf_append(ctx.out, "((integer)sizeof(0))");    // safe fallback
        return;
    }

    dynbuf_append(ctx.out, "((integer)sizeof(");

    if (n->sizeof_expr.is_type and n->sizeof_expr.target.sizeof_type != NULL) {
        emit_type_specifier(ctx.out, n->sizeof_expr.target.sizeof_type, NULL, 0, false, false, false, false);
    } else if (not n->sizeof_expr.is_type and n->sizeof_expr.target.designator != NULL) {
        codegen_common_expr(n->sizeof_expr.target.designator, ctx);
    } else {
        dynbuf_append(ctx.out, "0");    // fallback
    }

    dynbuf_append(ctx.out, "))");
}


/**
 * Emit INC / DEC statement (works for both statements and expressions)
 * 
 * Statement context:   INC(x);     → x++;
 *                      INC(x, 5);  → x += 5;
 * 
 * Expression context:  INC(x)      → x++
 *                      INC(x, 5)   → (x += 5)     <<-- parentheses added here
 */
void codegen_common_inc_dec(const Node *n, CodegenContext ctx, bool as_statement)
{
    if (n == NULL) {
        return;
    }

    bool is_compound = (n->binary.right != NULL);

    if (is_compound and not as_statement) {
        dynbuf_append_char(ctx.out, '(');       // protect precedence
    }

    codegen_common_expr(n->binary.left, ctx);          // designator

    if (is_compound) {
        // compound for with step
        if (n->kind == NODE_INC) {
            dynbuf_append(ctx.out, " += ");
        } else {
            dynbuf_append(ctx.out, " -= ");
        }
        codegen_common_expr(n->binary.right, ctx);
    } else {
        // simple form
        if (n->kind == NODE_INC) {
            dynbuf_append(ctx.out, "++");
        } else {
            dynbuf_append(ctx.out, "--");
        }
    }

    if (is_compound and not as_statement) {
        dynbuf_append_char(ctx.out, ')');       // close protective parentheses
    }

    if (as_statement) {
        dynbuf_append(ctx.out, ";\n");
    }
}


/**
 * Write out module prototype.
 */
void codegen_common_module_prototype(const Node *n, CodegenContext ctx)
{
    // Return type
    if (n->program_decl.return_type != NULL) {
        emit_return_type(ctx.out, n->program_decl.return_type);
        dynbuf_append_char(ctx.out, ' ');
    } else {
        dynbuf_append(ctx.out, "void ");
    }

    // module name
    dynbuf_appendn(ctx.out, n->program_decl.name, n->program_decl.name_len);

    // Parameter list
    emit_param_list(ctx.out, n->program_decl.params, n->program_decl.param_count, true, false);
    dynbuf_append(ctx.out, ";\n\n");
}


/**
 * Emit a C #include from IMPORT ... FROM "path"
 * The string-literal token includes quotes.
 * .mh paths: emit the associated .h (same stem/path); modc reads .mh at compile time only.
 */
void codegen_common_import(const Node *n, CodegenContext ctx)
{
    const char *from_path;
    size_t path_len;
    char include_path[4096];

    if (n == NULL or n->kind != NODE_IMPORT) {
        return;
    }

    // if (n->import_stmt.from_path == NULL or n->import_stmt.path_len == 0) {
    //     return; 
    // }
    from_path = n->import_stmt.from_path;
    path_len = n->import_stmt.path_len;
    if (from_path == NULL or path_len == 0) {
        return;
    }

    dynbuf_append(ctx.out, "#include ");
    if (mh_path_is_mh(from_path, path_len)) {
        // pcchar inner = NULL;
        // size_t inner_len = 0;

        // (void) mh_strip_string_literal(from_path, path_len, &inner, &inner_len);
        // if (path_len >= 2 and from_path[0] == '"') {
        //     dynbuf_append_char(ctx.out, '"');
        //     dynbuf_appendn(ctx.out, inner, inner_len - 3);
        //     dynbuf_append(ctx.out, ".h\"");
        // } else {
        //     dynbuf_appendn(ctx.out, inner, inner_len - 3);
        //     dynbuf_append(ctx.out, ".h");
        if (not mh_format_h_include(from_path, path_len, include_path, sizeof include_path)) {
            return;
        }
        dynbuf_append_char(ctx.out, '"');
        dynbuf_append(ctx.out, include_path);
        dynbuf_append_char(ctx.out, '"');
    } else {
        dynbuf_appendn(ctx.out, from_path, path_len);
    }
    dynbuf_append_char(ctx.out, '\n');
}
