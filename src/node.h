/**
 * Mod-c
 * By M. Scott Reynolds
 * Date 28 March 2026
 *
 * node.h - Abstract Syntax Tree (AST) node definitions
 *			Updated for grammar 0.7.2
 */

#ifndef MODC_NODE_H
#define MODC_NODE_H

#include "Lexer.h"			// for TToken, TokenKind
#include "arena.h"			// Arena
#include "ttype.h"			// TType
#include <stddef.h>			// size_t
#include <stdbool.h>		// bool


/**
 * Kinds of AST nodes.
 * Grouped roughly by syntactic category.
 * Updated 28 March 2026 for grammar version 0.6.2.
 */
typedef enum {
	NODE_PROGRAM,

	// Declarations
	NODE_DOC_COMMENT,
	NODE_PREPROCESSOR, 		// #include, #define, #if, etc...
	NODE_DEFINE,			// [EXPORT] DEFINE identifer RestOfLine
	NODE_PROC_DECL,
	NODE_FUNC_DECL,
	NODE_VAR_DECL,
	NODE_CONST_DECL,
	NODE_LET_DECL,
	NODE_VAR_ITEM,			// VAR
	NODE_CONST_ITEM,
	NODE_LET_ITEM,
	NODE_TYPE_DECL,
	NODE_PARAM,				// single parameter (used in param lists)
	NODE_PARAM_LIST,		// (param { , param } )
	NODE_IMPORT,			// IMPORT ... FROM ...
	NODE_IMPORT_ITEM,		// one qualident [AS ident] in the list
	NODE_STRUCT_DECL,		// STRUCT identifier [EXTENDS type] { ... }
	NODE_FIELD_DECL,
	NODE_METHOD_TYPE,		// PROCEDURE / FUNCTION ty pe (for use in TYPE declarations, params, etc.)
	NODE_ARRAY_TYPE,		// array type: array[Size] of ElementType or array_of_T[N]
	NODE_ARRAY_LITERAL,		// { expr, expr, ... }
	NODE_ARRAY_INDEX,		// designator [ index-expr ]
	NODE_FIELD_ACCESS,		// designator . identifier
	NODE_ENUM_TYPE,
	NODE_ENUM_ITEM,			// One member in NODE_ENUM_TYPE.elements[]

	// Statements
	NODE_BLOCK,
	NODE_IF,
	NODE_ELSIF,
	NODE_ELSE,
	NODE_FOR,
	NODE_WHILE,				// WHILE expression DO ... END
	NODE_REPEAT_UNTIL, 
	NODE_LOOP,
	NODE_BREAK,
	NODE_CONTINUE,
	NODE_RETURN,
	NODE_EXPR_STMT,
	NODE_ASSIGN,			// :=
	NODE_ASSERT,			// ASSERT (expression [, const-expression])
	NODE_SIZEOF,			// SIZEOF (type-identifier | designator )
	NODE_LEN,				// LEN (designagtor) -- interim sizeof(n) / sizeof(n[0])
	NODE_INC,				// INC(designator [, step])
	NODE_DEC,				// DEC(designator [, step])
	NODE_DEFER,
	NODE_DEBUG,
	NODE_SWITCH,


	// Expressions
	NODE_PAREN,
	NODE_BINARY,
	NODE_UNARY,
	NODE_CAST, 				// postfix "AS" cast
	NODE_LITERAL,
	NODE_IDENT,
	NODE_CALL,
	NODE_TERNARY,			// cond ? then : else

	// Future expansion placeholders (add here as needed)
} NodeKind;


/**
 * Forward declaration of AST node.
 * All nodes are allocated in an Arena and owned by it.
 */
typedef struct Node Node;

/** Forward declaration -- full definition in symbol.h */
struct TSymbol;

/** ===================================================================
 * Variable / Constant / Let item (shared across VAR, CONST, LET)
 * Grammar:
 *   var-item   = identifier [ ":" type-identifier ] [ "=" ( initializer | expression ) ]
 *   const-item = identifier [ ":" type-identifier ] "=" const-expression
 *   let-item   = identifier [ ":" type-identifier ] "=" ( initializer | expression )
 */
// typedef struct {
// 	const char *name;			// Identifier
// 	size_t		name_len;
// 	TType 		*type;	
// 	Node 		*initializer;
// } VariableItem;


/** Switch statement case */
typedef struct SwitchCase {
	Node **labels;			// array of const-expression nodes
	size_t label_count;
	size_t label_capacity;
	Node *body;				// statement-seqeunce for this arm
} SwitchCase;


/**
 * Core AST node structure.
 * Every node carries its kind and origination lexer token (for error reporting / source location).
 * Fields are unionized to save space - only one variant is active at a time.
 */
struct Node {
	NodeKind kind;
	TToken token;					// originating token (location + text snippet)
	struct TSymbol *resolved_sym;	// semantic pass: bound symbol for IDENT/CALL (NULL if foreign/unresolved)
	// EXTENDS auto-upcast (semantic): append ".base" this many times when emitting
	// this expression as a value (assign RHS, return, call arg, init). 0 = none.
	// Arena-zeroed; only set when child => ancestor by value.
	size_t upcast_depth;
	bool upcast_ptr;				// true => &((*(expr)).base x N); value => ((expr).base x N)

	union {
		// Program (top-level root)
		struct {
			TokenKind 	unit_kind;	// TOK_KEYWORD_PROGRAM or TOK_KEYWORD_MODULE

			const char 	*name;		// id of the program/module
			size_t		name_len;	// length of the id, no null assumption.

			// Optional parameters.
			Node **params;			// array of param nodes (or simple ident+type)
			size_t param_count;
			size_t param_capacity;

			TType *return_type;		// optional return type.

			Node **decls; 			// array of declaration nodes
			size_t count;
			size_t capacity;		// for dynamic growth

			Node *block;			// BEGIN ... BODY (optional for module)
		} program_decl;

		// Top-level documentation comment (passthrough + future -D support)
		struct {
			const char 	*text;		// null-terminated, original delimiters stripped or kept?
			size_t 		text_len;
			// We keep the original token for line/column in AST and future doc generator.
		} doc_comment;

		// Preprocessor directives.
		struct {
			const char *text;
			size_t		length;
		} preprocessor;

		// [EXPORT] DEFINE identifier RestOfLine (body is C, not TMod-c)
		struct {
			const char *name;		// identifier only
			size_t 		name_len;
			const char *text;		// identifer + reset of the line (source span)
			size_t 		length;
			bool 		is_exported;
		} define_stmt;

		// Import statement (top-level)
		struct {
			Node 		**items;	// array of NODE_IMPORT_ITEM
			size_t		count;
			size_t		capacity;
			const char *from_path;	// string-literal or qualident after FROM (pointer to source)
			size_t		path_len;
		} import_stmt;

		// Single import item: name | Type::name [AS ident]
		struct {
			const char *qualident;			// method short name, or plain/dotted import name
			size_t		qualident_len;
			const char *method_owner;		// Type in Type::name; NULL if plain
			size_t 		method_owner_len;
			const char *import_alias;		// optional AS identifier
			size_t		import_alias_len;
		} import_item;

		// Struct declaration 
		struct {
			const char	*name;
			size_t		name_len;
			TType 		*extends_type;	// optional EXTENDS qualident
			Node 		**fields; 		// array of field nodes (field-decl)
			size_t 		field_count;
			size_t 		field_capacity;
			bool 		is_exported;
			bool		is_packed;
			bool 		is_union; 		// True = C union, false = C struct.
		} struct_decl;

		// Struct field
		struct {
			const char 	*name;
			size_t		name_len;
			TType 		*field_type;				// may be NULL if omitted
			Node 		*initializer;		// optional = const-expression
		} field_decl;

		// Method / Procedure type (e.g. TYPE Compare = PROCEDURE(a: T): integer)
		struct {
			Node	*params;		// NODE_PARAM_LIST or NULL
			TType	*return_type;	// NULL for PROCEDURE, present fOR function
			bool	is_function;	// true = FUNCTION, false = PROCEDURE
		} method_type;

		// Procecure / Function declaration
		struct {
			const char *name;
			size_t 		name_len;
			const char 	*method_owner; 		// type-identifier for Type::name (NULL if free proc)
			size_t		method_owner_len;
			Node 		*params;			// NODE_PARAM_LIST or NULL
			TType 		*return_type;		// optional
			Node *body;						// Block node
			bool is_exported;
			bool is_recursive;
			bool is_extern;
			bool is_forward;				// postfix FORWARD - body later in unit
			bool is_function;				// True for FUNCTION, false for PROCEDURE.
			Node *receiver;					// legacy Oberon receiver (unused: remove later)
		} proc_decl, func_decl;

		// Var declaration
		struct {
			Node 			**items;		// Array of variable items (arena allocated)
			size_t			count;			// size of the arrays/VAR entries.
			size_t			capacity;
			bool 			is_exported;
			bool			is_extern;
			bool 			is_static;
		} var_decl, const_decl, let_decl;

		// Variable item (VAR/CONST/LET)
		struct {
			const char *name;			// Identifier
			size_t		name_len;
			TType 		*item_type;	
			Node 		*initializer;
		} var_item, const_item, let_item;

		// TType declaration
		struct {
			const char 	*name;
			size_t		name_len;
			TType 		*defined_type;
			Node 		*struct_body;		// When non-NULL points to struct TYPE ident = STRUCT ...
			Node		*method_type;		// When non-NULL points to NODE_METHOD_TYPE
			Node 		*enum_type;			// When non-NULL points to a NODE_ENUM_TYPE
			Node 		*initializer;
			bool 		is_exported;
			bool		is_extern;			// EXTERN TYPE (opaque foreign / alias)
			bool 		is_forward;			// type Name FORWARD - completed later in unit
			bool 		is_extern_struct;	// extern type Name = struct [tag]
			const char 	*c_tag_name;		// nil => tag is Name
			size_t 		c_tag_name_len;
		} type_decl;

		// Enum Type
		struct {
			const char 	*name;
			size_t  	name_len;
			Node **elements;
			size_t count;
			size_t capacity;
		} enum_type;

		// Enum Item
		struct {
			const char 	*name;
			size_t 		name_len;
			Node 		*value;			// Opitonal const-expression; nil = auto-increment
			bool		value_known;	// set by semantic
			int 		int_value;		// evaluated member value
		} enum_item;

		// Array type
		struct {
			Node *element_type;		// type node or identifier
			Node *size_expr;		// size (const expression or NULL for open array)
			bool is_open;			// true for dynamic/open arrays later
		} array_type;

		// Array literal { expr, expr, ... }
		struct {
			Node **elements;		// array of expression nodes
			size_t count;
			size_t capacity;
		} array_literal;

		// Parameter declaration
		struct {
			const char *name;
			size_t		name_len;
			bool 		is_var;
			bool 		is_ref;
			bool		is_const;
			TType 		*param_type;
		} param;

		// Parameter list
		struct {
			Node 		**params;
			size_t 		count;
			size_t		capacity;
			bool		has_ellipsis;		// last formal was ... (C varargs)
		} param_list;

		// Block (BEGIN ... END)
		struct {
			Node 		**stmts;		// array of statement nodes
			size_t 		count;
			size_t 		capacity;

			Node **defers;				// DEFER support - collected during parsing.
			size_t defer_count;			// Emitted LIFO at block exit.
			size_t defer_capacity;

			// DbC contract clauses (expressions). Stored directly as the inner expr nodes.
			Node **requires;			// REQUIRE (expr) clauses at start of block
			size_t require_count;
			size_t require_capacity;

			Node **ensures;				// ENSURE (expr) clauses at end of block (before RETURN/END)
			size_t ensure_count;
			size_t ensure_capacity;
		} block;

		// If / Elsif / Else chain
		struct {
			Node *cond;
			Node *then_;
			Node *elsif_;		// next ELSIF (or NULL)
			Node *else_;		// ELSE branch (or NULL)
		} if_stmt;

		// While loop
		struct {
			Node *cond;				// condittion expression
			Node *body;				// statement sequence (usually a BLOCK)

			Node **invariants;		// INVARIANT (expr)clauses (after DO, before body)
			size_t invariant_count;
			size_t invariant_capacity;
		} while_stmt;

		// For
		struct {
			const char 	*var_name;			// loop variable name
			size_t 		var_len;
			Node 		*start_;
			Node 		*end_;
			int 		step;			// Default 1 (positive or negative)
			Node 		*body;

			Node **invariants;			// INVARIANT (expr) clauses
			size_t invariant_count;
			size_t invariant_capacity;

		} for_stmt;

		// Repeat ... Until
		struct {
			Node *body;
			Node *cond;					// evaluated after body

			Node **invariants;			// INVARIANT (expr) clauses
			size_t invariant_count;
			size_t invariant_capacity;

		} repeat_until;

		// Infinite LOOP
		struct {
			Node *body;

			Node **invariants;			// INVARIANT (expr) clauses
			size_t invariant_count;
			size_t invariant_capacity;			
		} loop_stmt;

		// Switch statement
		struct {
			Node *expr;				// the controlling expression
			SwitchCase **cases;		// array of switch_cases
			size_t case_count;		
			size_t case_capacity;
			Node *else_body;		// the required ELSE statement-sequence
		} switch_stmt;

		// Return statement
		struct { 
			Node *expr; 		// optional return value
		} ret;

		// Binary / Unary
		struct {
			Node *left;
			Node *right;
			TokenKind op;
		} binary;

		// Ternary conditional (a ? b : c)
		struct {
			Node *cond;
			Node *then_expr;
			Node *else_expr;
		} ternary;

		// Unary operator expression
		struct {
			Node *operand;
			TokenKind op;
		} unary;

		// Unary operator expression
		struct {
			Node *expr;
		} paren;

		// Cast expression (postfix "AS")
		struct {
			Node *expr;			// expression being cast
			TType *target_type;	// Target type after "AS"
		} cast_expr;

		// Literal (number, string, char) or Identifier
		struct { 
			const char *value;			// text as in source (not null-terminated if len used)
			size_t length;				// byte length from original token (preferred over strlen)
		} literal, ident;

		// Function/procedure call
		struct {
			const char 	*name;
			size_t		name_len;
			const char 	*method_owner;	// for Type::name calls (NULL for obj:name sugar)
			size_t		method_owner_len;
			Node 		*receiver_expr;	// instance sugar: prepend as first arg in codegen
			Node 		*callee_expr;	// call-through value (field / later designator); no prepend
			Node 		**args;			// array of argument expression nodes
			size_t 		argc;
			size_t		arg_capacity;	// for dynamic growth
			bool 		auto_deref;		// Oberon p.method: receiver is ^T; emit (*(p))
			size_t 		base_depth;		// EXTENDS: ".base" hops after peel (0 = owner type)
		} call;

		// Array indexing
		struct {
			Node *array_;		// left side (ident, field, etc.)
			Node *index;		// index expression
			bool auto_deref;	// Oberon p[i]: left is ^array; emit (*(p))[i]

		} array_index;

		// Field access
		struct {
			Node 		*record_;		// left side (struct or object)
			const char	*field_name;
			size_t 		field_len;
			size_t 		base_depth;		// EXTENDS: number of ".base" before field (0 = own/synthetic)
			bool		auto_deref;		// Oberon p.x: left is ^T; emit (*(p)).field
		} field_access;

		// Expression statement
		struct {
			Node *expr;				// Expression
		} expr_stmt;

		// Build-in statements (new for 0.6.2)
		struct {
			Node *condition;		// required expression for ASSERT
			Node *const_expr;		// optional second argument (const-expression)
		} assert_stmt;

		// Defer statement/Debug same action.
		struct {
			Node *action;			// the deferred statement/expression
		} defer_stmt, debug_stmt;

		// Debug statement
		// struct {
		// 	Node *action;
		// } debug_stmt;

		struct {
			bool is_type;				// true if SIZEOF(type-identifier), false if designator
			union {
				TType *sizeof_type;		// when is_type == true
				Node *designator;		// when is_type == false
			} target;
		} sizeof_expr;
	};
};


/**
 * Create a new node in the given arena.
 * Zero-initializes all fields (union safety).
 * Never returns NULL - arena_alloc exits on failure.
 *
 * @param arena 		Must be valid and initialized
 * @param kind 			Node type to create
 * @param tok 			Originating lexer token (copied)
 * @return 				Newly allocated Node*
 */
Node *node_create(Arena *arena, NodeKind kind, TToken tok);


/**
 * Print the AST node tree recursively with indentation.
 * Shows node kind, source location, token snippet, and recurses into children.
 * Updated 09 April 2026 to support new VariableItem structure (VAR/CONST/LET).
 *
 * @param n 		Node to print (NULL is handled gracefully)
 * @param indent 	Current indentation level (0 = root)
 */
void node_print(const Node *n, int indent);


#endif		/* MODC_NODE_H */
