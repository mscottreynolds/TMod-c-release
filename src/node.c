/**
 * Mod-c
 * By M. Scott Reynolds
 * Date 28 March 2026
 *
 * node.c - AST node creation helper
 * 			Updated for grammar 0.6.2
 */
#include "tmodc.h"
#include "node.h"
#include "arena.h"
#include "symbol.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <iso646.h>

// silence another warning about not being used.
void node_indent(size_t indent);

/**
 * Emit indentation dots safely.
 * Avoids -Wstrict-overflow on signed loop counters.
 */
static void node_indent_dots(int indent) 
{
	int i = 0;
	while (i < indent) {
		printf(". ");
		i++;
	}
}



/**
 * Emit indentation spaces.
 * Avoids -Wstrict-overflow on signed loop counters.
 */
void node_indent(size_t indent) 
{
	size_t i = 0;
	while (i < indent) {
		printf("  ");
		i++;
	}
}


/**
 * Create a new AST node in the given arena.
 * Zero-initializes all fields, sets kind and token, then returns pointer.
 * Never returns NULL - arena_alloc exits on allocation failure.
 *
 * @param arena 	Arena to allocate from (must be initialized)
 * @param kind 		NodeKind to assign
 * @param tok 		TToken to associate (copied by value)
 * @return 			Newly allocated and initialized Node*
 */
Node *node_create(Arena *arena, NodeKind kind, TToken tok) {
	// Defensive check - arena must be valid (helps catch caller bugs early)
	if (arena == NULL) {
		fprintf(stderr, "ERROR: node.node_create: Invalid or uninitialized arena\n");
		exit(1);
	}

	Node *n = arena_alloc(arena, sizeof(Node));

	// Zero all fields (union safety, prevents garbage in pointers/counts/etc.)
	// memset(n, 0, sizeof(Node));

	n->kind = kind;
	n->token = tok;			// struct copy - safe and efficient

	return n;
}

static void print_kind_line_column(const Node *n, const char *kind_name)
{
	// printf("%s %d:%d ", kind_name, n->token.line, n->token.column);
	if (n != NULL) {
		// Actually silence compiler warning that 'n' isn't used.
		printf("%s ", kind_name);
	}
}


static void print_line_column(const Node *n)
{
	printf("%04d:%04d ", n->token.line, n->token.column);			
}


// static void print_type(TType *t)
// {
// 	if (t != NULL) {
// 		if (t->is_array and t->element_type != NULL) {
// 			print_type(t->element_type);
// 			printf("[");
// 			if (t->array_size > 0) {
// 				printf("%zu", t->array_size);
// 			}
// 			printf("]");
// 		} else if (t->is_pointer) {
// 			printf("^");
// 			if (t->name != NULL and t->name_len > 0) {
// 				printf("'%.*s'", (int)t->name_len, t->name);
// 			}
// 		} else if (t->name != NULL and t->name_len > 0) {
// 			printf("'%.*s'", (int)t->name_len, t->name);
// 		} else {
// 			printf("(unknown type)");
// 		}
// 	} else {
// 		printf("(inferred)");
// 	}
// }


/**
 * Print the AST node tree recursively with indentation.
 * Shows node kind, source location, token snippet, and recurses into children.
 * Updated 09 April 2026 to support new VariableItem structure (VAR/CONST/LET).
 *
 * @param n 		Node to print (NULL is handled gracefully)
 * @param indent 	Current indentation level (0 = root)
 */
void node_print(const Node *n, int indent) 
{
	if (n == NULL) {
		if (indent >= 0) {
			node_indent_dots(indent);
		}
		printf("(null)\n");
		return;
	}

	if (indent >= 0) {
		print_line_column(n);
		node_indent_dots(indent);
	}

	const char *kind_name = "UNKNOWN";
	switch (n->kind) {
		case NODE_PROGRAM:
			kind_name = TokenKind__string(n->program_decl.unit_kind);
			print_kind_line_column(n, kind_name);
			if (n->program_decl.name and n->program_decl.name_len > 0) {
				printf("'%.*s'", (int)n->program_decl.name_len, n->program_decl.name);
			} else {
				printf("(unnamed)");
			}

			if (n->program_decl.return_type) {
				printf(" : ");
				// print_type(n->program_decl.return_type);
				type_print(n->program_decl.return_type);
			}
			printf("\n");

			// Params
			for (size_t i = 0; i < n->program_decl.param_count; i++) {
				node_print(n->program_decl.params[i], indent + 1);
			}

			// Decls
			for (size_t i = 0; i < n->program_decl.count; i++) {
				node_print(n->program_decl.decls[i], indent + 1);
			}

			// Block
			if (n->program_decl.block) {
				node_print(n->program_decl.block, indent + 1);
			}
			break;

		case NODE_DOC_COMMENT:
			kind_name = "DOC_COMMENT";
			print_kind_line_column(n, kind_name);
			printf("'%.*s'\n", (int)n->doc_comment.text_len, n->doc_comment.text);
			break;

		case NODE_PREPROCESSOR:
			kind_name = "PREPROCESSOR";
			print_kind_line_column(n, kind_name);
			printf("'%.*s'", (int)n->preprocessor.length, n->preprocessor.text);
			printf("\n");
			break;

		case NODE_DEFINE:
			kind_name = "DEFINE";
			print_kind_line_column(n, kind_name);
			if (n->define_stmt.is_exported) {
				printf("EXPORT ");
			}
			printf("'%.*s'\n", (int)n->define_stmt.length, n->define_stmt.text);
			break;

		case NODE_VAR_DECL: 	
		case NODE_CONST_DECL:
		case NODE_LET_DECL:
			if (n->kind == NODE_VAR_DECL) {
				kind_name = "VAR_DECL";
			} else if (n->kind == NODE_CONST_DECL) {
				kind_name = "CONST_DECL";
			} else {
				kind_name = "LET_DECL";
			}
			print_kind_line_column(n, kind_name);
			if (n->var_decl.is_exported) {
				printf(" EXPORT");
			}
			if (n->var_decl.is_extern) {
				printf(" EXTERN");
			}
			if (n->var_decl.is_static) {
				printf(" STATIC");
			}
			printf("\n");

			// Print each VariableItem
			for (size_t i = 0; i < n->var_decl.count; i++) {
				const Node *item = n->var_decl.items[i];
				node_print(item, indent + 1);
			}
			break;

		case NODE_VAR_ITEM:
		case NODE_CONST_ITEM:
		case NODE_LET_ITEM:
			if (n->kind == NODE_VAR_ITEM) {
				kind_name = "VAR_ITEM";
			} else if (n->kind == NODE_CONST_ITEM) {
				kind_name = "CONST_ITEM";
			} else if (n->kind == NODE_LET_ITEM) {
				kind_name = "LET_ITEM";
			} else {
				kind_name = "(unknown) ITEM";
			}
			print_kind_line_column(n, kind_name);

			// const type?
			if (n->var_item.item_type and n->var_item.item_type->is_const) {
				printf("const ");
			}

			printf("'%.*s : ", (int)n->var_item.name_len, n->var_item.name);
			// print_type(n->var_item.item_type);
			type_print(n->var_item.item_type);

			if (n->var_item.initializer) {
				printf(" =\n");
				node_print(n->var_item.initializer, indent + 1);
			} else {
				printf(" (zero-initialized)");
				printf("\n");
			}
			break;

		case NODE_TYPE_DECL:
			kind_name = "TYPE_DECL";
			print_kind_line_column(n, kind_name);
			if (n->type_decl.is_exported) {
				printf("(EXPORT)" );
			}
			if (n->type_decl.is_extern) {
				printf("(EXTERN) ");
			}
			if (n->type_decl.is_forward) {
				printf("(FORWARD) ");
			}

			if (n->type_decl.defined_type != NULL and n->type_decl.defined_type->is_const) {
				printf(" const ");
			}

			// Show the type name being defined
			if (n->type_decl.name != NULL and n->type_decl.name_len > 0) {
				printf("'%.*s' ", (int)n->type_decl.name_len, n->type_decl.name);
			} else {
				printf("(unnamed)");
			}

			// Show the defined type
			printf("= ");

			if (n->type_decl.struct_body != NULL) {
				Node *struct_body = n->type_decl.struct_body;
				if (struct_body->struct_decl.is_packed) {
					printf("PACKED ");
				}
				if (struct_body->struct_decl.is_union) {
					printf("UNION ");
				} else {
					printf("STRUCT ");
				}
				if (struct_body->struct_decl.extends_type) {
					printf("EXTENDS '%.*s'", 
						(int)struct_body->struct_decl.extends_type->name_len,
						struct_body->struct_decl.extends_type->name);
				}
				printf("\n");
				for (size_t i = 0; i < struct_body->struct_decl.field_count; i++) {
					node_print(struct_body->struct_decl.fields[i], indent + 1);
				}
			} else if (n->type_decl.method_type != NULL) {
				Node *m = n->type_decl.method_type;
				if (m->method_type.is_function) {
					printf("FUNCTION ");
					if (m->method_type.return_type) {
						printf(": ");
						type_print(m->method_type.return_type);
						printf("\n");
					} else {
						printf(": (none)\n");
					}

				} else {
					printf("PROCEDURE \n");
				}

				if (m->method_type.params) {
					// printf("\n");
					node_print(m->method_type.params, indent + 1);
				} else {
					printf("(no params)\n");
				}
			} else if (n->type_decl.enum_type != NULL) {
				Node *en = n->type_decl.enum_type;
				printf("ENUM\n");
				for (size_t i = 0; i < en->enum_type.count; i++) {
					node_print(en->enum_type.elements[i], indent + 1);
				}
			} else if (n->type_decl.defined_type != NULL) {
				type_print(n->type_decl.defined_type);
				printf("\n");
			} else if (n->type_decl.is_extern_struct) {
				printf("STRUCT");
				if (n->type_decl.c_tag_name != NULL and n->type_decl.c_tag_name_len > 0) {
					printf(" '%.*s'", (int)n->type_decl.c_tag_name_len, 
						n->type_decl.c_tag_name);
				}
				printf("\n");
			} else if (n->type_decl.is_forward) {
				printf("FORWARD\n");
			} else {
				printf("(opaque)\n");
			}

			break;

		case NODE_ENUM_TYPE:
			kind_name = "ENUM_TYPE";
			print_kind_line_column(n, kind_name);
			printf("\n");
			for (size_t i = 0; i < n->enum_type.count; i++) {
				node_print(n->enum_type.elements[i], indent + 1);
			}
			break;

		case NODE_ENUM_ITEM:
			kind_name = "ENUM_ITEM";
			print_kind_line_column(n, kind_name);
			printf("'%.*s'", (int)n->enum_item.name_len, n->enum_item.name);
			if (n->enum_item.value != NULL) {
				printf(" =\n");
				node_print(n->enum_item.value, indent + 1);
			} else {
				printf("\n");
			}
			// printf("\n");
			break;

		case NODE_STRUCT_DECL:
			if (n->struct_decl.is_union) {
				kind_name = "UNION_DECL";
			} else {
				kind_name = "STRUCT_DECL ";
			}
			print_kind_line_column(n, kind_name);
			printf("'%.*s'", (int)n->struct_decl.name_len, n->struct_decl.name);
			if (n->struct_decl.is_packed) {
				printf("PACKED ");
			}
			if (n->struct_decl.extends_type) {
				printf("EXTENDS '%.*s'", 
					(int)n->struct_decl.extends_type->name_len,
					n->struct_decl.extends_type->name);
			}
			if (n->struct_decl.is_union) {
				printf("UNION ");
			}
			printf("\n");
			for (size_t i = 0; i < n->struct_decl.field_count; i++) {
				node_print(n->struct_decl.fields[i], indent + 1);
			}
			break;

		case NODE_ARRAY_TYPE:
			kind_name = "ARRAY_TYPE";
			print_kind_line_column(n, kind_name);
			if (n->array_type.element_type) {
				node_print(n->array_type.element_type, indent + 1);
			}
			printf("[");
			if (n->array_type.size_expr) {
				node_print(n->array_type.size_expr, 0);
			} else {
				printf("?");
			}
			printf("]\n");
			break;

		case NODE_ARRAY_LITERAL:
			kind_name = "ARRAY_LITERAL";
			print_kind_line_column(n, kind_name);
			printf("[%zu]\n", n->array_literal.count);
			for (size_t i = 0; i < n->array_literal.count; i++) {
				node_print(n->array_literal.elements[i], indent + 1);
			}
			break;

		case NODE_ARRAY_INDEX:
			kind_name = "ARRAY_INDEX";
			print_kind_line_column(n, kind_name);
			printf("\n");
			node_print(n->array_index.array_, indent + 1);
			// for (int i = 0; i < indent + 1; i++) {
			// 	printf(".."); 
			// }
			// printf("[ ");
			node_print(n->array_index.index, indent + 1);
//			printf(" ]\n");
			break;


		case NODE_FIELD_DECL:
			kind_name = "FIELD_DECL";
			print_kind_line_column(n, kind_name);
			printf("'%.*s'", (int)n->field_decl.name_len, n->field_decl.name);
			if (n->field_decl.field_type) {
				printf(" : ");
				// print_type(n->field_decl.field_type);
				type_print(n->field_decl.field_type);
				// printf(" : '%.*s'", (int) n->field_decl.field_type->name_len,
				// 	n->field_decl.field_type->name);
			}
			if (n->field_decl.initializer) {
				printf(" = ");
				node_print(n->field_decl.initializer, indent + 1);
			} else {
				printf("\n");
			}
			break;

		case NODE_FIELD_ACCESS:
			kind_name = "FIELD_ACCESS";
			print_kind_line_column(n, kind_name);
			printf("\n");
			node_print(n->field_access.record_, indent + 1);
			kind_name = "FIELD";
			print_line_column(n);
			node_indent_dots(indent + 1);
			print_kind_line_column(n, kind_name);
			printf("'%.*s'\n", (int)n->field_access.field_len,
									n->field_access.field_name);
			break;

		case NODE_PROC_DECL:
		case NODE_FUNC_DECL:
			kind_name = (n->kind == NODE_PROC_DECL) ? "PROC_DECL" : "FUNC_DECL";
			print_kind_line_column(n, kind_name);

			if (n->proc_decl.is_extern) {
				printf("EXTERN ");
			}

			if (n->proc_decl.is_forward) {
				printf("FORWARD ");
			}

			if (n->proc_decl.is_exported) {
				printf("EXPORT ");
			}

			if (n->proc_decl.is_recursive) {
				printf("RECURSIVE ");
			}

			if (n->proc_decl.is_function) {
				printf("FUNCTION ");
				if (n->proc_decl.method_owner and n->proc_decl.method_owner_len > 0) {
					printf("'%.*s::%.*s': ",
						(int)n->proc_decl.method_owner_len, n->proc_decl.method_owner,
						(int)n->proc_decl.name_len, n->proc_decl.name);
				} else if (n->proc_decl.name and n->proc_decl.name_len > 0) {
					printf("'%.*s': ", (int)n->proc_decl.name_len, n->proc_decl.name);
				}

				if (n->proc_decl.return_type) {
					type_print(n->proc_decl.return_type);
					// printf(": '%.*s' ", (int)n->proc_decl.return_type->name_len,
					// 	n->proc_decl.return_type->name);
				}
			} else {
				printf("PROCEDURE ");
				if (n->proc_decl.method_owner and n->proc_decl.method_owner_len > 0) {
					printf("'%.*s::%.*s'", 
						(int)n->proc_decl.method_owner_len, n->proc_decl.method_owner,
						(int)n->proc_decl.name_len, n->proc_decl.name);
				} else if (n->proc_decl.name and n->proc_decl.name_len > 0) {
					printf("'%.*s'", (int)n->proc_decl.name_len, n->proc_decl.name);
				}
			}

			printf("\n");

			if (n->proc_decl.receiver) {
				print_line_column(n);
				node_indent_dots(indent + 1);
				printf("RECEIVER\n");
				node_print(n->proc_decl.receiver, indent + 2);
			}

			// Parameters
			if (n->proc_decl.params) {
				node_print(n->proc_decl.params, indent + 1);
			}

			// Body
			if (n->proc_decl.body) {
				node_print(n->proc_decl.body, indent + 1);
			}
			break;

		case NODE_BLOCK:		
			kind_name = "BLOCK"; 
			print_kind_line_column(n, kind_name);
			if (n->block.count == 0) {
				printf(" (empty)"); 
			} else {
				// printf(" (%zu statements)", n->block.count);
			}
			printf("\n");

			// DbC requires
			for (size_t i = 0; i < n->block.require_count; i++) {
				print_line_column(n);
				node_indent_dots(indent + 1);
				printf("REQUIRE\n");
				node_print(n->block.requires[i], indent + 2);
			}

			for (size_t i = 0; i < n->block.count; i++) {
				node_print(n->block.stmts[i], indent + 1);
			}

			// DbC ensures
			for (size_t i = 0; i < n->block.ensure_count; i++) {
				print_line_column(n);
				node_indent_dots(indent + 1);
				printf("ENSURE\n");
				node_print(n->block.ensures[i], indent + 2);
			}

			break;

		case NODE_IF:
			kind_name = "IF";
			print_kind_line_column(n, kind_name);
			printf("\n");
			node_print(n->if_stmt.cond, indent + 1);
			node_print(n->if_stmt.then_, indent + 1);
			if (n->if_stmt.elsif_ != NULL) { 
				node_print(n->if_stmt.elsif_, indent + 1); 
			}
			if (n->if_stmt.else_ != NULL) { 
				node_print(n->if_stmt.else_, indent + 1); 
			}
			break;

		case NODE_ELSIF:
			kind_name = "ELSIF";
			print_kind_line_column(n, kind_name);
			printf("\n");
			node_print(n->if_stmt.cond, indent + 1);
			node_print(n->if_stmt.then_, indent + 1);
			if (n->if_stmt.elsif_ != NULL) {
				node_print(n->if_stmt.elsif_, indent + 1);
			}
			if (n->if_stmt.else_ != NULL) {
				node_print(n->if_stmt.else_, indent + 1);
			}
			break;

		case NODE_ELSE:
			kind_name = "ELSE";
			print_kind_line_column(n, kind_name);
			printf("\n");
			if (n->if_stmt.else_ != NULL) {
				node_print(n->if_stmt.else_, indent + 1);
			}
			break;

		case NODE_WHILE:
			kind_name = "WHILE";
			print_kind_line_column(n, kind_name);
			printf("\n");

			node_print(n->while_stmt.cond, indent + 1);

			// DbC INVARIANTS
			for (size_t i = 0; i < n->while_stmt.invariant_count; i++) {
				print_line_column(n);
				node_indent_dots(indent + 1);
				printf("INVARIANT\n");
				node_print(n->while_stmt.invariants[i], indent + 2);
			}

			if (n->while_stmt.body != NULL) {
				node_print(n->while_stmt.body, indent + 1);
			}
			break;

		case NODE_FOR:
			kind_name = "FOR";
			print_kind_line_column(n, kind_name);
			printf("%.*s :=  ... %s ... BY %d DO\n", (int)n->for_stmt.var_len, n->for_stmt.var_name,
								n->for_stmt.step >= 0 ? "TO" : "DOWNTO",
								n->for_stmt.step);
			node_print(n->for_stmt.start_, indent + 1);
			node_print(n->for_stmt.end_, indent + 1);

			// TODO: Handle 'BY' keyword. Step is currently a placeholder.

			// DbC INVARIANTS
			for (size_t i = 0; i < n->for_stmt.invariant_count; i++) {
				print_line_column(n);
				node_indent_dots(indent + 1);
				printf("INVARIANT\n");
				node_print(n->for_stmt.invariants[i], indent + 2);
			}

			if (n->for_stmt.body != NULL) {
				node_print(n->for_stmt.body, indent + 1);
			}
			break;

		case NODE_REPEAT_UNTIL:
			kind_name = "REPEAT_UNTIL";
			print_kind_line_column(n, kind_name);
			printf("\n");

			// DbC INVARIANTS
			for (size_t i = 0; i < n->repeat_until.invariant_count; i++) {
				print_line_column(n);
				node_indent_dots(indent + 1);
				printf("INVARIANT\n");
				node_print(n->repeat_until.invariants[i], indent + 2);
			}

			if (n->repeat_until.body != NULL) {
				node_print(n->repeat_until.body, indent + 1);
			}
			if (n->repeat_until.cond != NULL) {
				node_print(n->repeat_until.cond, indent + 1);
			}
			break;

		case NODE_LOOP:
			kind_name = "LOOP";
			print_kind_line_column(n, kind_name);
			printf("\n");

			// DbC INVARIANTS
			for (size_t i = 0; i < n->loop_stmt.invariant_count; i++) {
				print_line_column(n);
				node_indent_dots(indent + 1);
				printf("INVARIANT\n");
				node_print(n->loop_stmt.invariants[i], indent + 2);
			}

			if (n->loop_stmt.body != NULL) {
				node_print(n->loop_stmt.body, indent + 1);
			}
			break;

		case NODE_RETURN:
			kind_name = "RETURN";
			print_kind_line_column(n, kind_name);
			printf("\n");
			if (n->ret.expr != NULL) {
				node_print(n->ret.expr, indent + 1);	// print expression on next line, easier to read
			}
			break;

		case NODE_CONTINUE:
			kind_name = "CONTINUE";
			print_kind_line_column(n, kind_name);
			printf("\n");
			break;

		case NODE_BREAK:
			kind_name = "BREAK";
			print_kind_line_column(n, kind_name);
			printf("\n");
			break;

		case NODE_ASSIGN:
			kind_name = "ASSIGN";
			print_kind_line_column(n, kind_name);
			printf(" %s \n", TokenKind__string(n->binary.op));
			node_print(n->binary.left, indent + 1);
			node_print(n->binary.right, indent + 1);
			break;

		case NODE_BINARY:
			kind_name = "BINARY";
			print_kind_line_column(n, kind_name);
			// Show the operator nicely
			printf("%s\n", TokenKind__string(n->binary.op));
			node_print(n->binary.left, indent + 1);
			node_print(n->binary.right, indent + 1);
			break;

		case NODE_CALL:
			kind_name = "CALL";
			print_kind_line_column(n, kind_name);
			// if (n->call.name and n->call.name_len > 0) {
			// 	printf("'%.*s' ( ", (int)n->call.name_len, n->call.name);
			if (n->call.receiver_expr != NULL) {
				printf("<recv>:");
			}
			if (n->call.method_owner and n->call.method_owner_len > 0) {
				printf("'%.*s::%.*s', ( ",
					(int)n->call.method_owner_len, n->call.method_owner,
					(int)n->call.name_len, n->call.name);
			} else if (n->call.name and n->call.name_len > 0) {
				printf("'%.*s' ( ", (int)n->call.name_len, n->call.name);

			} else {
				printf("?? ( ");
			}

			// Print arguments
			for (size_t i = 0; i < n->call.argc; i++) {
				if (i > 0) {
					printf(", ");
				}
				// For simple literals/idents, show a short preview
				if (n->call.args[i]->kind == NODE_LITERAL) {
					size_t len = n->call.args[i]->token.length > 30 ? 30 : n->call.args[i]->token.length;
					printf("'%.*s'", (int)len, n->call.args[i]->token.start);
				} else if (n->call.args[i]->kind == NODE_IDENT) {
					printf("%.*s", (int)n->call.args[i]->token.length,
						n->call.args[i]->token.start);
				} else {
					printf("<expr>");
				}
			}
			printf(" )");
			if (n->resolved_sym != NULL) {
				printf(" -> %s", symbol_kind_name(n->resolved_sym->kind));
			}
			printf("\n");
			break;

		case NODE_ASSERT:
			kind_name = "ASSERT";
			print_kind_line_column(n, kind_name);
			printf("\n");
			node_print(n->assert_stmt.condition, indent + 1);
			if (n->assert_stmt.const_expr != NULL) {
				node_print(n->assert_stmt.const_expr, indent + 1);
			} 
			break;

		case NODE_SIZEOF:
			kind_name = "SIZEOF";
			print_kind_line_column(n, kind_name);
			if (n->sizeof_expr.is_type) {
				printf("(type) ");
				if (n->sizeof_expr.target.sizeof_type != NULL) {
					printf("'%.*s'", (int)n->sizeof_expr.target.sizeof_type->name_len,
						n->sizeof_expr.target.sizeof_type->name);
				}
			} else {
				printf("(designator)\n");
				node_print(n->sizeof_expr.target.designator, indent + 1);
			}
			printf("\n");
			break;

		case NODE_LEN:
			kind_name = "LEN";
			print_kind_line_column(n, kind_name);
			printf("(designator)\n");
			node_print(n->sizeof_expr.target.designator, indent + 1);
			break;

		case NODE_IMPORT:
			kind_name = "IMPORT";
			print_kind_line_column(n, kind_name);
			if (n->import_stmt.from_path and n->import_stmt.path_len > 0) {
				printf(" FROM '%.*s'", (int)n->import_stmt.path_len, n->import_stmt.from_path);
			}
			printf("\n");
			for (size_t i = 0; i < n->import_stmt.count; i++) {
				node_print(n->import_stmt.items[i], indent+1);
			}
			break;

		case NODE_IMPORT_ITEM:
			kind_name = "IMPORT_ITEM";
			print_kind_line_column(n, kind_name);
			// printf("'%.*s'", (int)n->import_item.qualident_len, n->import_item.qualident);
			if (n->import_item.method_owner != NULL and n->import_item.method_owner_len > 0) {
				printf("'%.*s::%.*s'",
					(int)n->import_item.method_owner_len, n->import_item.method_owner,
					(int)n->import_item.qualident_len, n->import_item.qualident);
			} else {
				printf("'%.*s'", (int)n->import_item.qualident_len, n->import_item.qualident);
			}
			if (n->import_item.import_alias and n->import_item.import_alias_len > 0) {
				printf(" AS '%.*s'", (int)n->import_item.import_alias_len, n->import_item.import_alias);
			}
			printf("\n");
			break;

		case NODE_PARAM:
			kind_name = "PARAM";
			print_kind_line_column(n, kind_name);
			if (n->param.is_const) {
				printf("const ");
			}

			// It is a grammar error to have both VAR and REF. But show them both in AST
			// just in case...
			if (n->param.is_var) {
				printf("VAR ");
			}
			if (n->param.is_ref) {
				printf("REF ");
			}
			printf("'%.*s' : ", (int)n->param.name_len, n->param.name);
			// print_type(n->param.param_type);
			type_print(n->param.param_type);
			printf("\n");

			break;

		case NODE_EXPR_STMT:	
			kind_name = "EXPR_STMT"; 
			print_kind_line_column(n, kind_name);
			printf("\n");
			node_print(n->expr_stmt.expr, indent + 1);
			break;

		case NODE_CAST:
			kind_name = "CAST";
			print_kind_line_column(n, kind_name);
			printf("AS ");
			// print_type(n->cast_expr.target_type);
			type_print(n->cast_expr.target_type);
			printf("\n");
			// if (n->cast_expr.target_type and n->cast_expr.target_type->name) {
			// 	printf("'%.*s'\n", (int) n->cast_expr.target_type->name_len,
			// 		n->cast_expr.target_type->name);
			// } else {
			// 	printf("(unknown type)\n");
			// }
			node_print(n->cast_expr.expr, indent + 1);
			break;

		case NODE_UNARY:
			kind_name = "UNARY";
			print_kind_line_column(n, kind_name);
			printf("%s\n", TokenKind__string(n->unary.op));
			node_print(n->unary.operand, indent + 1);
			break;

		case NODE_TERNARY:
			kind_name = "TERNARY";
			print_kind_line_column(n, kind_name);
			printf("\n");
			node_print(n->ternary.cond, indent + 1);
			node_print(n->ternary.then_expr, indent + 1);
			node_print(n->ternary.else_expr, indent + 1);
			break;			

		case NODE_IDENT:
			kind_name = "IDENT";
			print_kind_line_column(n, kind_name);
			if (n->token.length > 0) {
				printf("'%.*s'", (int)n->token.length, n->token.start);
			}
			if (n->resolved_sym != NULL) {
				printf(" -> %s", symbol_kind_name(n->resolved_sym->kind));
			}
			printf("\n");
			break;

		case NODE_LITERAL:
			kind_name = "LITERAL";
			print_kind_line_column(n, kind_name);
			if (n->token.length > 0 and n->token.start != NULL) {
				size_t len = n->token.length > 60 ? 60 : n->token.length;
				printf("'%.*s'", (int)len, n->token.start);
			}
			printf("\n");
			break;

		case NODE_PARAM_LIST:
			kind_name = "PARAM_LIST";
			print_kind_line_column(n, kind_name);
			if (n->param_list.has_ellipsis) {
				printf(" ...");
			}
			printf("\n");
			for (size_t i = 0; i < n->param_list.count; i++) {
				node_print(n->param_list.params[i], indent + 1);
			}

			break;

		case NODE_INC:
		case NODE_DEC:
			kind_name = (n->kind == NODE_INC) ? "INC" : "DEC";
			print_kind_line_column(n, kind_name);
			printf("\n");
			node_print(n->binary.left, indent + 1);
			if (n->binary.right != NULL) {
				node_print(n->binary.right, indent + 1);
			}
			break;

		case NODE_DEFER:
			kind_name = "DEFER";
			print_kind_line_column(n, kind_name);
			printf("\n");
			node_print(n->defer_stmt.action, indent + 1);
			break;

		case NODE_DEBUG:
			kind_name = "DEBUG";
			print_kind_line_column(n, kind_name);
			printf("\n");
			node_print(n->defer_stmt.action, indent + 1);
			break;

		case NODE_SWITCH:
			kind_name = "SWITCH";
			print_kind_line_column(n, kind_name);
			printf("\n");

			// The controlling expression
			node_print(n->switch_stmt.expr, indent + 1);

			// Each CASE arm
			for (size_t i = 0; i < n->switch_stmt.case_count; i++) {
				SwitchCase *c = n->switch_stmt.cases[i];

				print_line_column(n);
				node_indent_dots(indent + 1);
				printf("CASE\n");

				// Print labels for this arm
				for (size_t j = 0; j < c->label_count; j++) {
					node_print(c->labels[j], indent + 2);
				}

				// Body of teh arm
				node_print(c->body, indent + 2);
			}

			// The required ELSE
			print_line_column(n);
			node_indent_dots(indent + 1);
			printf("ELSE\n");
			node_print(n->switch_stmt.else_body, indent + 1);
			break;

		case NODE_PAREN:
			kind_name = "PAREN";
			print_kind_line_column(n, kind_name);
			printf("\n");
			node_print(n->paren.expr, indent + 1);
			break;
			
		case NODE_METHOD_TYPE:
		default:	// Get token name instead.
			// kind_name = TokenKind__string(n->token.kind);
			kind_name = "UNKNOWN_NODE";
			print_kind_line_column(n, kind_name);
			printf("(%s)", TokenKind__string(n->token.kind));
			if (n->token.length > 0 and n->token.start != NULL) {
				size_t len = n->token.length > 32 ? 32 : n->token.length;
				printf("'%.*s'\n", (int)len, n->token.start);
			}
			printf("\n");
			break;
	}
}


