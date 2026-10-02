# TMod-c — Complete Syntax (EBNF)

**Status:** Living formal grammar (single source of truth for syntax productions).  
**Last updated:** 30 September 2026
**Companion:** Language definition prose is in [`language-report.md`](language-report.md).  
**Not here:** Implementation status, changelogs, design essays — see `CURRENT.md` and `language-report.md`.

Notation is EBNF as used in the productions below. Keywords are case-insensitive; identifiers are case-sensitive (see productions and the Language Report). An identifier is at most 255 characters (Language Report §2.2).

```ebnf
(*
 * TMod-c — complete formal EBNF (single source of truth for productions)
 *
 * Builtin types (lowercase reserved type-identifiers):
 *  	 	bool, byte, char, integer, cardinal, real, string
 *)

tmodc-unit = program-unit | module-unit ;

(**** Top-level units **********************************************)

program-unit = "PROGRAM" module-name formal-parameters EOS
    { import-stmt }
    declaration-sequence 
    block ;

module-unit = "MODULE" module-name formal-parameters EOS
    { import-stmt }
    declaration-sequence 
    block ;

module-name = identifier ;

(**** Imports ******************************************************)

import-stmt   = "IMPORT" [ import-item { "," import-item } ] "FROM" import-source EOS ;
import-source = string-literal | qualident ;

import-item = [ type-identifier "::" ] identifier ;

(**** Top Level Declarations *************************************************)

declaration-sequence = {  type-decl 
                        | const-decl 
                        | let-decl 
                        | var-decl 
                        | define-decl
                        | method-decl
                        | extern-type-decl
                        | extern-var-decl
                        | extern-proc-decl
                        | extern-func-decl } ;

type-decl   = [ "EXPORT" ] type-def ;
const-decl  = [ "EXPORT" ] const-def ;
let-decl    = [ "EXPORT" ] let-def ;
define-decl = [ "EXPORT" ] "DEFINE" identifier rest-of-line ;
var-decl    = [ "EXPORT" ] [ "EXTERN" ] var-def     (* top level. *)
            | [ "STATIC" ] var-def ;                (* block level *)

(* rest-of-line: C text from the identifier through the terminating newline,
   including '\' continuations. Not TMod-c tokens. DEFINE is top-level only. *)

(* Multi-item definitions *)

type-def    = "TYPE" type-item { "," type-item } EOS ;
const-def   = "CONST" const-item { "," const-item } EOS ;
let-def     = "LET" let-item { "," let-item } EOS ;         (* may be used anywhere *)
var-def     = "VAR" var-item { "," var-item } EOS ;

type-item   = identifier "=" type-expression 
			| identifier "FORWARD" ;
const-item  = identifier [ ":" type-specifier ] "=" const-expression ;
let-item    = identifier [ ":" type-specifier ] "=" ( initializer | expression ) ;
var-item    = identifier [ ":" type-specifier ] [ "=" ( initializer | expression ) ] ;

initializer = "{" [ expression { "," expression } ] "}" ;

(**** Types ********************************************************)

(* Full type expressions used on right-hand side of TYPE declarations *)
type-expression = type-specifier
    | type-name
    | struct-type
    | union-type
    | enum-type
    | set-type                  (* Planned: SET OF enum; see language-report §5 *)
    | method-type
    | opaque-type-expression
    | qualident "<" type-specifier { "," type-specifier } ">" ; (* future generics *)

opaque-type-expression = "OPAQUE"
                       | "^" "OPAQUE"
                       | "POINTER" "TO" "OPAQUE" ;

(* Used for VAR / LET / CONST / formals / fields — no OPAQUE here.
   At most one pointer constructor (^ or POINTER TO) per specifier.
   Further levels: name the inner type, or ^T[]  — not ^^T.
   ARRAY OF may nest; the element type may itself include one ^.
   Language Report §5.3. *)
type-specifier = [ "CONST" ] type-name [ array-suffix ]
			   | [ "CONST" ] ( "^" | "POINTER" "TO" ) type-name [ array-suffix ]
			   | [ "CONST" ] ( "^" | "POINTER" "TO" ) "ARRAY" [ array-suffix ] "OF" type-specifier
			   | [ "CONST" ] "ARRAY" [ array-suffix ] "OF" type-specifier
			   | [ "CONST" ] set-type ;   (* Planned: SET OF enum; no array of sets in v1 *)

array-suffix = "[" [ const-expression ] "]"     (* fixed size *)
             | "[" "]" ;                        (* open array T[] *)

type-name = type-identifier { type-identifier }   (* "int", "long long", etc. *)
          | width-type ;

width-type = ( "integer" | "cardinal" | "real" ) decimal-integer ;
    (* Exact width. Closed N: integer/cardinal 8|16|32|64; real 32|64.
       Decimal digits only (no 0x, no '_', no leading zeros).
       Not a rebindable name; typical use is TYPE RHS or a type-specifier.
       Same production in .mh type-spec (fields, formals, results); mutually
       exclusive with extra C words ("long long"). *)

type-identifier = identifier ;
    (* lowercase builtins: bool, byte, char, integer, cardinal, real, string. *)

(* Planned? `type Foo = struct Bar`. `type Foo = struct of`... *)

struct-type = [ "PACKED" ] "STRUCT" [ type-identifier ] [ "EXTENDS" type-identifier ] [ "OF" ] [ EOS ] 
			{ field-decl EOS } 
			"END" ;

union-type = "UNION" [ "OF" ] [ EOS ] 
           { field-decl EOS } 
           "END" ;

enum-type = "ENUM" [ "OF" ] [ EOS ] 
          enum-decl { "," enum-decl } [ "," ] [ EOS ] 
          "END" ;

enum-decl  = identifier [ "=" const-expression ] ;

(* Planned (not parsed yet). E is an enum type; members in 0 .. 63. *)
set-type = "SET" "OF" type-identifier ;

method-type = ( "PROCEDURE" | "FUNCTION" ) formal-parameters ;

(* Field of STRUCT or UNION. type-specifier only (named types for nesting). *)
field-decl  = identifier ":" type-specifier [ "=" const-expression ] ;

return-type = [ "CONST" ] [ "^" | "POINTER" "TO" ] type-identifier ;

(* Placeholder for full template/generic definition support *)
template-decl = "TEMPLATE" "<" template-parameter { "," template-parameter } ">"
                ( type-decl | struct-decl | method-prototype ) ;

template-parameter = type-identifier [ ":" type-specifier ] ;   (* T: Type or just T *)

(**** Methods ******************************************************)

method-decl = [ "EXPORT" ] [ "EXTERN" ] method-prototype ;

(* Foreign symbols — see "Modules, imports, exports, and foreign symbols" *)
extern-type-decl = "EXTERN" "TYPE" identifier [ "=" extern-type-rhs ] EOS ;
extern-type-rhs  = type-expression
                 | "STRUCT" [ type-identifier ] ;   (* C tag alias; no fields, no END *)
extern-var-decl  = "EXTERN" "VAR" var-item { "," var-item } EOS ;
extern-proc-decl = "EXTERN" [ "EXPORT" ] "PROCEDURE" identifier formal-parameters EOS ;
extern-func-decl = "EXTERN" [ "EXPORT" ] "FUNCTION" identifier formal-parameters EOS ;

method-prototype = [ "RECURSIVE" ] ( "PROCEDURE" | "FUNCTION" )
    qualified-method-name formal-parameters [ "FORWARD" ] EOS ;

qualified-method-name = [ type-identifier "::" ] identifier ;

method-def = method-prototype
    block;

formal-parameters = "(" [ parameter-def { "," parameter-def } [ "," "..." ] ] ")" [ ":" return-type ] ;
    (* C varargs pass-through (0.26.7). At least one named formal; "..." last.
       Emit ", ..." in C. No TMod-c va_list. Not on PROGRAM/MODULE. *)

parameter-def = [ "VAR" | "REF" | "CONST" ] identifier ":" type-specifier ;

(**** Blocks & Statements ******************************************)

block = 
    "BEGIN"
        { require-clause }
        statement-sequence
        [ return-statement ]
        { ensure-clause }
    "END" [ end-tag ] ;

end-tag = identifier [ "::" identifier ] ;

(* Design by Contract clauses *)
require-clause      = "REQUIRE" expression EOS ;
ensure-clause       = "ENSURE" expression EOS ;
invariant-clause    = "INVARIANT" expression EOS ; (* allowed only in loop bodies *)

statement-sequence = definition-sequence { statement EOS } [ return-statement ] ;

definition-sequence = { const-def | let-def | var-def } ;

(****** Statements ****************************************************)

statement = 
    block
    | if-then-statement
    | switch-statement
    | while-statement
    | repeat-statement
    | for-statement
    | loop-statement
    | assignment-stmt
    | call-stmt
    | break-statement
    | continue-statement
    | expr-statement
    | defer-stmt
    | debug-stmt
    | assert-stmt
    | let-stmt
    | inc-dec-stmt ;

let-stmt = let-def ;

if-then-statement =
    "IF" expression "THEN" statement-sequence
    { "ELSIF" expression "THEN" statement-sequence }
    [ "ELSE" statement-sequence ]
    "END" ;

switch-statement =
    "SWITCH" expression "OF"
        { "CASE" case-labels ":" statement-sequence }
        "ELSE" ":" statement-sequence
    "END" ;

case-labels = const-expression { "," const-expression } ;

while-statement =
    "WHILE" expression "DO" 
        [ "BOUND" const-expression ]
        { invariant-clause } 
        statement-sequence 
    "END" ;

repeat-statement =
    "REPEAT"
        [ "BOUND" const-expression ]
        { invariant-clause }
        statement-sequence 
    "UNTIL" expression ;

for-statement =
    "FOR" identifier ":=" expression ( "TO" | "DOWNTO" ) expression [ "BY" const-expression ] "DO" 
        { invariant-clause }
        statement-sequence 
    "END" ; 

loop-statement =
    "LOOP" 
        [ "BOUND" const-expression ]
        { invariant-clause } 
        statement-sequence 
    "END" ;

assignment-stmt = designator ( ":=" | compound-assignment ) expression ;

compound-assignment
    = "*=" | "/=" | "%=" | "+=" | "-=" | "<<=" | ">>=" | "&=" | "|=" ;

call-stmt = ( qualified-method-name | designator ) "(" [ argument-list ] ")" 
		  { "." identifier "(" [ argument-list ] ")" } ;
expr-statement = "(" expression ")" ;        		(* explicit discard of results *)
return-statement = "RETURN" [ expression ] ;    	(* expression required in FUNCTION *)
break-statement    = "BREAK" ;
continue-statement = "CONTINUE" ;
inc-dec-stmt = "INC" "(" designator [ "," expression ] ")" 
             | "DEC" "(" designator [ "," expression ] ")" ;
defer-stmt = "DEFER" statement ;
debug-stmt = "DEBUG" statement ;
assert-stmt = "ASSERT" expression [ "," assert-msg ]
assert-msg = const-expression ;

(************** Designators ****************************)

designator = qualident { selector } ;

selector = "." identifier       (* field access; call => instance method sugar *)
    | "[" expression "]"        (* array element; pointer-to-array peel (0.26.5.178);
                                 * also C-index of ^T when T is not an array (0.26.7.191);
                                 * written ^Named first: ^sds[i] is sds (0.26.8.196) *)
    | "^" ;                     (* Pascal-style dereference *)
    (* C-index p[i] on ^T has type T (same strip as p^); C is p[i], not (*p)[i].
     * Written ^ is stripped before alias chase (^sds[i] is sds, not char).
     * Pointer-to-array p[i] peels: C (*(p))[i]. argv: ^char[] is not a peel. *)

(*** INC / DEC - both statement and expression forms ***)
inc-dec-expr = "INC" "(" designator [ "," expression ] ")"
             | "DEC" "(" designator [ "," expression ] ")" ;

qualident = identifier { "." identifier } ;
identifier = (letter | "_") , { letter | digit | "_" } ;
    (* Length: at most 255 characters (Language Report §2.2). Not encoded in the production. *)

(************** Expressions ****************************)

(* Expression precedence chain - right-associative where appropriate *)

expression = conditional-expression;

conditional-expression = logical-or-expression
    | logical-or-expression "?" expression ":" conditional-expression ;

logical-or-expression = logical-and-expression { "OR" logical-and-expression } ;

logical-and-expression = equality-expression { "AND" equality-expression } ;

equality-expression = relational-expression { equality-op relational-expression } ;
equality-op = "==" | "!=" | "<>" ;          (* "<>" is the same as "!=" *)

relational-expression = shift-expression { relational-op shift-expression } ;
relational-op = "<" | ">" | "<=" | ">=" | "IN" ;  (* IN: Planned SET OF membership; not a type guard *)

shift-expression = additive-expression { shift-op additive-expression } ;
shift-op = "<<" | ">>" ;

additive-expression = multiplicative-expression { additive-op multiplicative-expression } ;
additive-op = "+" | "-" | "|"  | "XOR";

multiplicative-expression = power-expression { mult-op power-expression } ;
mult-op = "*" | "/" | "%" | "&" | "DIV" | "MOD" ;

power-expression = unary-expression 
    | unary-expression "**" power-expression; (* right-associative *)

unary-expression = inc-dec-expr
    | cast-expression
    | prefix-op unary-expression ;

cast-expression = "CAST" "(" type-specifier "," expression ")"
    | postfix-expression "AS" type-specifier  (* postfix cast *)
    | postfix-expression ;

prefix-op = "NOT" | "!" | "~" | "+" | "-" | "^" | "@" ;

postfix-expression = primary-expression
    { "[" expression "]"
    | "(" [ argument-list ] ")"		(* free call, or field+call => instance method *)
    | "." identifier                (* field; next "(" may form instance call *)
    | "^"
    } ;

instance-method-call = "." identifier "(" [ argument-list ] ")" ;

type-qualified-call = type-identifier "::" identifier "(" [ argument-list ] ")" ;

argument-list = expression { "," expression } ;

primary-expression = identifier
    | literal
    | "(" expression ")"
    | array-literal         (* { expr {, expr} } *)
    | designator 
    | range-expression
    | countof-expression
    | type-qualified-call ;

range-expression = additive-expression ".." additive-expression ; (* inclusive *)

array-literal = "{" [ expression { "," expression } ] [","] "}" ;
    (* Also the Planned set constructor (SET OF enum). Semantic: set vs array by type. *)

literal = integer-literal | real-literal | char-literal | string-literal
    | "TRUE" | "FALSE" | "NIL" ;

integer-literal = decimal-integer | hexadecimal-integer | octal-integer | binary-integer ;
decimal-integer     = digit { [ seperator ] digit } ;*)
hexadecimal-integer = "0x" hex-digit { [ seperator ] hex-digit } ;
octal-integer       = "0o" octal-digit { [ seperator ] octal-digit } ;
binary-integer      = "0b" binary-digit { [ seperator ] binary-digit } ;

hex-digit    = digit | "A".."F" | "a".."f" ;
octal-digit  = "0".."7" ;
binary-digit = "0" | "1" ;
seperator    = "_" ;        (* optional thousands/grouping seperator *)

real-literal = decimal-part [ "." decimal-part ] [ exponent-part ] ;
decimal-part = digit { [ seperator ] digit } ;
exponent-part = ("E" | "e") [ "+" | "-" ] digit { [ seperator ] digit } ;

char-literal   = "'" ( character | escape-sequence ) "'" ;
(* string-literal type is builtin string; see "Builtin type: string" *)
string-literal = '"' { character except '"' | escape-sequence } '"' ;

letter = "a".."z" | "A".."Z" ;
digit  = "0".."9" ;

escape-sequence = "\\" | "\'" | "\"" | "\?" | "\a" | "\b" | "\f" | "\n" 
	| "\r" | "\t" | "\v" | "\x" hex-digit hex-digit
    | "\" octal-digit [ octal-digit [ octal-digit ] ] ;

character = (* any printable char except " or \ or control chars *) ;

const-expression = expression ; (* Expressions that can be computed at compile time. *)

sizeof-expession = "SIZEOF" "(" ( type-specifier | designator ) ")" ;

countof-expression = "COUNTOF" "(" type-specifier | designator ")" ;
    (* Outermost element count of a complete fixed array. Type integer. *)

(******* Keywords *******************************************************************)

(* Keywords are case-insensitive: "IF", "if", "If", "iF" are recognized as the same *)
(* Identifiers are case-sensitive: "MyVar", "myvar", "MYVAR" are distinct. *)

keyword = "ALIAS" | "AND" | "ARRAY" | "AS" | "ASSERT" | "BEGIN" | "BOUND" | "BREAK" |
        "BY" | "CASE" | "CAST" | "CONST" | "CONTINUE" | "COUNTOF" | "DEBUG" | "DEC" | 
        "DEFAULT" | "DEFINE" | "DEFER" | "DIV" | "DO" | "DOWNTO" | "ELSE" | "ELSIF" |
        "END" | "ENSURE" | "ENUM" | "EXPORT" | "EXTENDS" | "EXTERN"| "FALSE" | "FOR" |
        "FORWARD" | "FROM" | "FUNCTION" | "HEADER" | "IF" | "IMPORT" | "IN" | "INC" |
        "INLINE" | INVARIANT" | "LET" | "LOOP" | "MOD" | "MODULE" | "NIL" | "NOT" |
        "OF" | "OPAQUE" | "OR" | "PACKED" | "POINTER" | "PROCEDURE" | "PROGRAM" |
        "RECORD" | "RECURSIVE" | "REF" | "REPEAT" | "REQUIRE" | "RETURN" | "SET" |
        "SIZEOF" | "STATIC" | "STRUCT" | "SWITCH" | "THEN" | "TO" | "TRUE" | "TYPE" |
        "UNION" | "UNTIL" | "VAR" | "WHILE" | "XOR" | "TEMPLATE" ;

(**** End-of-Statement ****************************)

(* Layout convention (for authors):
   - Prefer one statement per line.
   - Multiple statements on one line require ';'.
   - Indentation is NOT significant.
*)

EOS = ";" | newline-when-eos ;

newline-when-eos = NEWLINE (* unless any of:

  (1) Explicit continuation: '\' is the last non-whitespace before NEWLINE
      (lexer suppresses the line break).

  (2) Bracketed expression: inside (), [], {} delimiter pairs in expressions.

  (3) Trailing continuator: the last non-comment token on the line cannot
      complete the current phrase. Includes:
        :=  ,  .  ::  +  -  *  /  ^  @  (  [  {
        and  or  xor  =  <>  <=  >=  <  >
        keywords that grammatically require a following phrase
        (if, elsif, while, repeat, for, return, require, ensure, then, else, …).

  (4) Anchor-not-yet-closed: statement forms with a fixed closing marker
      before EOS — notably import-stmt before FROM import-source.
      Comma-separated declaration lists (VAR, CONST, LET, TYPE) also continue
      on the next line when the previous line ended with ','.

';' always ends a statement (except inside strings and comments).

import-stmt EOS placement: IMPORT … FROM import-source EOS
  (EOS is after the import-source operand, not after each import-item). *)


(******* Comments *****************************************************)

comment = { single-line-comment | c-style-comment | pascal-style-comment } ;

single-line-comment = "//" ... newline
c-style-comment = "/*" ... "*/"
pascal-style-comment = "(*" ... { pascal-style-comment } ... "*)"    


(***************************************************************************)
```

---

*End of formal syntax. For informal rules and semantics, see the [TMod-c Language Report](language-report.md).*
