# TMod-c Language Report (Draft)

**Status:** Living draft — Wirth-style language report.  
**Version alignment:** Compiler **0.26.x** (see `CURRENT.md` for implementation status).  
**Last updated:** 30 September 2026  

**Author:** M. Scott Reynolds  

**Purpose:** Define the **TMod-c** programming language: informal rules and semantics, bottom-up.  
**Formal syntax:** Complete EBNF is **only** in [`syntax-ebnf.md`](syntax-ebnf.md).  
**Not this document:** Build numbers, test status, session diaries — see `CURRENT.md`, `changelog.md`, `docs/grok_report-*.md`, `docs/project_bible.md`.

> **Draft policy:** Rules marked *Implemented* are intended to match the current compiler. Rules marked *Planned* are language intent; the compiler may not enforce them yet. When prose and EBNF disagree, fix both; prefer explicit update over silent drift.

**Public name:** **TMod-c** (TYPE compiler). **Mod-c** / `modc` are legacy names during transition. Target binary: **`tmodc`**; system ABI module: **`tmodc.mc`** / **`tmodc.h`**.

This report is **not** a programmer’s tutorial. It is a concise reference for programmers, implementors, and manual writers — the same role as Wirth’s Oberon report. What remains unsaid is mostly left so intentionally. Examples show the **look** of the language; they are not complete programs unless labelled as such. The expected reader already programs in **C** (and may know Pascal or Oberon). Comments marked `(* C: … *)` are a lowering hint, not TMod-c syntax.

---

## Table of contents

1. [Introduction and model](#1-introduction-and-model)  
2. [Notation and vocabulary](#2-notation-and-vocabulary)  
3. [Compilation units and modules](#3-compilation-units-and-modules)  
4. [Declarations](#4-declarations)  
5. [Types](#5-types)  
6. [Expressions and designators](#6-expressions-and-designators)  
7. [Statements](#7-statements) ([§7.5 Design by contract](#75-design-by-contract-dbc-implemented-core))  
8. [Procedures, functions, and parameters](#8-procedures-functions-and-parameters)  
9. [Storage, ownership, and memory](#9-storage-ownership-and-memory)  
10. [Builtins and standard facilities](#10-builtins-and-standard-facilities)  
11. [C lowering and interop](#11-c-lowering-and-interop)  
12. [Complete syntax](#12-complete-syntax)  
13. [Document map](#13-document-map)  

---

## 1. Introduction and model

TMod-c is a **statically typed** language in the Pascal / Modula-2 / Oberon family, with selected modern conveniences, that **compiles to C11**. It is aimed at readable, reviewable systems and compiler construction code — not at replacing C’s entire ecosystem.

A compilation unit is a finite sequence of **lexical symbols** (identifiers, numbers, strings, operators, keywords, comments). The compiler emits ordinary C; the linker sees a `.c` / `.h` pair, never `.mh`.

**Example** (complete program):

```mod-c
program Hello()

import printf from "stdio.h"

begin
	printf("Hello, TMod-c\n")
end
```

`(* C: #include "Hello.h"; int main-shaped unit Hello(void) that calls printf. *)`

### 1.1 Design principles

| Principle | Meaning |
|-----------|---------|
| **Clarity over cleverness** | Assignments are statements only; control flow is explicit (`begin`…`end`, required `ELSE` in `SWITCH`, …). |
| **Simple but not too simple** | Small surface language; hard problems (ownership, modules) get short explicit rules rather than hidden runtime magic. |
| **No mandatory GC** | Default model is explicit allocation, `defer`, and arenas — not a tracing collector. |
| **No hidden allocations (policy)** | Standard library and builtins that allocate must make **who owns / who frees** obvious. |
| **Plan mutability** | Mutable locals (`VAR`) are declared at the **beginning of a block**; immutable bindings (`LET`) may bind when the value is known. |
| **Contracts, not comments** | `REQUIRE` / `ENSURE` / loop `INVARIANT` are executable Design by Contract (§7.5). They lower to C `assert`. |
| **Lower to ordinary C** | Generated code links as normal C; no required heavy runtime for the core language. |

### 1.2 What TMod-c is not

- Not a beginner tutorial.  
- Not classic Oberon System (no mandatory GC heap).  
- Not “C with different braces” — modules, `EXPORT` / `.mh`, and declaration style are first-class.

### 1.3 Source and product files

| Kind | Extension | Role |
|------|-----------|------|
| Author source | `.mc` | Only files programmers edit for TMod-c code |
| Generated C | `.c`, `.h` | Input to the host C compiler |
| Export table | `.mh` | Machine-readable exports for **modc** / **tmodc** (not hand-authored) |

The `PROGRAM` or `MODULE` name must match the output stem (`Hello.mc` → `Hello.c` / `Hello.h`, unit `Hello`).

---

## 2. Notation and vocabulary

### 2.1 Syntax notation

Productions use **Wirth EBNF** as in [`syntax-ebnf.md`](syntax-ebnf.md):

- `"X"` — terminal  
- `name` — nonterminal  
- `[ X ]` — optional  
- `{ X }` — zero or more  
- `X | Y` — alternative  
- `( X )` — grouping  

Illustrative fragments in this report are **non-normative** if they disagree with the syntax document.

### 2.2 Keywords and identifiers

- **Keywords** are **case-insensitive** (`IF`, `if`, `If`).  
- **Identifiers** are **case-sensitive** (`MyVar` ≠ `myvar`).  
- **Length *Implemented (0.26.3.170)*** — an identifier is at most **255** characters. Longer is a compile-time error (lexer / `.mh` reader). Mangled export / C names `Owner__name` may be 512; they are not source identifiers.  
- Full keyword list: EBNF production `keyword`.

**Examples:**

```
x    scan    TModc    getSymbol    firstLetter
IF    if    If          (* same keyword *)
Point    point          (* distinct identifiers *)
```

### 2.3 Numbers, strings, and comments

Integers are decimal digit sequences. Reals contain a decimal point. Strings use `"…"`. Character literals use `'x'`. Escapes follow C (`'\n'`, `'\x1b'` = two hex digits, octal `'\033'`). *Char `\x` implemented 0.26.5.186.*

**Examples:**

```
1987
12.3
4.567E8
"TMod-c"
"Don't worry"
'A'
'\x1b'
"\x1b[2J"
```

Comments: `//` to end of line, or `(* … *)` / `(** … *)`. They may appear between symbols. They do not affect meaning.

```mod-c
var n: integer = 1    // working set
(* block comment *)
```

### 2.4 Layout and end-of-statement *Implemented (core)*

- Prefer **one statement per line**.  
- **`;`** separates multiple statements on one line.  
- **Indentation is not significant.**  
- Newlines end statements except for continuations (trailing operators, open brackets, trailing commas in declaration lists, `IMPORT … FROM`, explicit `\`, etc.).

**Examples:**

```mod-c
x := 1
y := 2; z := 3
s := a +
     b            (* continuation after trailing operator *)
```

---

## 3. Compilation units and modules

### 3.1 Programs and modules

A compilation unit is a **`PROGRAM`** or a **`MODULE`**. Both have a declaration sequence and a body. Exact productions: `program-unit`, `module-unit` in the syntax document.

A **program** is the application entry. A **module** is a compilable collection of declarations (and an optional body) meant to be imported.

**Examples:**

```mod-c
program Demo(argc: integer, argv: ^char[])
begin
	(* … *)
end Demo

module Counters()
	export type TCounter = struct
		n: integer
	end
	export procedure bump(ref c: TCounter)
	begin
		c.n := c.n + 1
	end bump
begin
end Counters
```

`(* C: void Demo(int argc, char **argv);  void Counters(void); *)`

Optional `end` tag may repeat the unit or procedure name (`end Demo`, `end Type::name`).

### 3.2 Import and export *Partly implemented*

- **`.mh` / `.h` split:** `.mh` carries TMod-c export semantics; `.h` is the C ABI. Generated C **`#include`s `.h` only**, never `.mh`.  
- **`IMPORT … FROM`:**  
  - **Quoted string** — foreign/C path or explicit path (`"stdio.h"`, `"path.mh"`).  
  - **Qualident** — TMod-c module (`fixtures.minimod` → `.mh` + paired `.h`). *Implemented (0.24.5).*  
  - **Import items:** plain names, or **`Type::name`** for type-bound methods (*0.25.2*); lookup uses C mangling `Type__name`.  
- **Include-only:** `IMPORT FROM source` with no item list — `#include` only, no TMod-c names.  
- **Module entry (7a, 0.25.3.150):** a named import from an `.mh` also binds the `@module` unit-entry export. Include-only does not. `PROGRAM` names are not bound.  
- **`EXPORT`** — marks declarations written into the unit’s `.mh` table.  
- **`EXTERN`** — symbol implemented elsewhere (typically C); no body in this unit.  
- **`EXTERN TYPE`** — foreign type name.  
  - `extern type FILE` — C already has that typedef; compiler emits nothing.  
  - `extern type termios = struct` — `typedef struct termios termios;` (C tag with no typedef).  
  - `extern type Foo = struct bar` — `typedef struct bar Foo;`.  
  Not `type T = opaque` (`void *`). Not `type T FORWARD` (must complete in this unit). Layout and fields come from the `#include`. *Implemented (0.26.5.186).*  
- **Calls (0.26.0):** unresolved free `name(...)` / `Type::name(...)` is an error.  
- **Types (0.26.1):** unknown **single-word** type is an error. Multi-word C spellings (`long long`, `unsigned int`) remain legal without import. Bare `unsigned` is not a type. `unsigned` is not a modifier on `^T` or on a typedef name — see §5.3.  
- **C preprocessor:** `#define` / `#if` lines are copied into generated C; they do **not** bind TMod-c names. A name the unit must see (e.g. `switch` `case`) is **`DEFINE`** (§4.1.1), not a pass-through line.

**Examples:**

```mod-c
import printf, FILE from "stdio.h"
import size_t from "stddef.h"
import tcgetattr from "termios.h"
extern type FILE
extern type TTermios = struct termios
import TPoint from "fixtures/tpoint.mh"
import mini_answer from fixtures.minimod
import Point::print from geometry

import from "extra.h"          (* include-only: no names bound *)

export type TPoint = struct
	x: integer
	y: integer
end

export function mini_answer(): integer
begin
	return 42
end
```

Quoted `FROM "stdio.h"` does **not** parse the C header. The item list is the programmer’s claim that C will provide those names after the include.

**`.mh` export lines** (`modc-mh/1`, `@format 1`): one physical line per export. Signatures, field lists, method-type RHS, width tails (`integer 32`), and **alias RHS** (`export type integer complete integer 64`) are described in §3.2 of earlier revisions and in `CURRENT.md`. Parent fields on `EXTENDS` require the parent type imported. Field call-through requires importing the method type as well as the struct.

**Example** (generated `.mh` line, not source):

```
export type TPoint complete struct (x: integer, y: integer)
export type integer complete integer 64
export type I32 complete integer 32
export function mini_answer complete () : integer
export procedure Point__print complete instance Point (Point)
```

**Deferred:** project-root module search paths, `IMPORT *`. **Mutual TMod-c `IMPORT`:** later, after Makefile subdirectory compilation (item 15). Today cycles can compile because C headers include each other and `.mh` comes from a previous emit.

### 3.3 `.mh` completeness vs source `OPAQUE`

In **export tables**, `export type Name opaque` means “name only, no layout.”  
In **source**, `type Name = opaque` defines an opaque type (§5.2). Same English word; **different languages**.

---

## 4. Declarations

Every identifier that is not a prelude builtin must be introduced by a declaration. A declaration also states whether the name is a constant, a type, a variable, or a procedure. The name may be used from the point of declaration to the end of the enclosing block. No identifier may denote more than one object in the same scope.

### 4.1 Declaration classes

Typical forms: `TYPE`, `CONST`, `LET`, `VAR`, **`DEFINE`**, procedures/functions, methods (`Type::name`), `EXTERN` variants.

**Examples:**

```mod-c
type Point = struct
	x, y: integer
end

const N = 100
let title: string = "demo"
var i: integer
var p: Point
define CTRL_KEY(k) ((k) & 0x1f)
```

### 4.1.1 `DEFINE` *Implemented (0.26.5.188)*

`DEFINE` introduces a **C preprocessor macro** as a TMod-c name in this unit. The body is **C text**, not a TMod-c expression.

```
define-decl = [ "EXPORT" ] "DEFINE" identifier rest-of-line .
```

- **Top-level only.** Illegal inside `BEGIN`/`END`.
- Parse the identifier. Do not classify object-like vs function-like; do not parse the body. Rest of line (plus `\` continuations) is copied after `#define `.
- The name is bound like an untyped **`IMPORT`**: it exists; the C preprocessor owns the meaning. `case CTRL_KEY('q'):` is a legal TMod-c name (C makes it an integer constant expression after preprocess).
- No `EXPORT` → generated **`.c`** only.
- `EXPORT` → also the generated **`.h`**, and `export define Name complete` in the `.mh` table so another unit can `IMPORT` it from `"thisunit.mh"` (the importer already `#include`s the paired `.h`; no self-include of `"thisunit.h"`).
- Feature-test macros (`_GNU_SOURCE`) stay on the **Makefile** (`-D`). A `DEFINE` in the `.mc` is still too late if it lands after the unit `.h` / system headers.

A raw `#define` / `#if` line in the `.mc` remains pass-through and **does not** enter the symbol table. If the name is required, write `DEFINE`.

**Examples:**

```mod-c
define CTRL_KEY(k) ((k) & 0x1f)
define ANSWER 42
define SUM 1 + \
	2
export define PUBLIC_FLAG 1
```

`(* C: #define CTRL_KEY(k) ((k) & 0x1f) — space after #define, then the source span from the identifier. *)`

### 4.2 `CONST`, `LET`, and `VAR` *Design locked; LET rebind implemented (0.26.5.181); C `const` dropped (0.26.5.183)*

| Form | Role | Binding |
|------|------|---------|
| **`CONST`** | Compile-time named constant (Pascal/Oberon). May fold in array bounds, case labels. *Not* a C `const` object. | `=` |
| **`LET`** | Runtime binding after initialization. **Rebind lock** (rule 2): no `n :=` / `INC(n)` / `DEC(n)` on the **name**. Through-writes (`p.x`, `pc^`, `a[i]`) are allowed. Same **body** rule as `REF` / bare formals (§8.2). Not a `CONST` formal. | `=` |
| **`VAR`** | Mutable binding (rebind and through-writes). | `:=` for later assignment; optional `=` at init |

**Three states** (locals vs formals share **body** rules; ABI of `REF`/`VAR` is separate):

| State | Rebind | Through | Locals | Formals |
|-------|--------|---------|--------|---------|
| **1** | Yes | Yes | `VAR` | `VAR` |
| **2** | No | Yes | `LET` | `REF`, bare |
| **3** | No | No | declaration `CONST` (compile-time) | `CONST` |

`LET` is not `REF`: `REF` is a view of the caller’s object. A second `let x = …` in the same scope is a **new** binding (mangled C name), not `x :=`.

**Address-of:** `@e` is illegal if `e` is rooted at a `LET` or a declaration `CONST` (*0.26.5.183*). That blocks mutable aliasing (`let n; pc := @n; pc^ := …`) without freezing `let p: Point` then `p.x :=`. `@` of a `VAR` remains legal. Read-only `@n` as `const ^T` is deferred.

**Static text:** a string literal has C type `const char[]`. Unbound **`string`** is **`const ^char`** (`typedef const char* string`; §10.1). Prefer `let s: string = "ok"`. `let t: const ^char = "ok"` is the same pointee `const`. Do not write `let t: ^char = "ok"` (discards const). Do not put C `const` on every LET — that would freeze `let pc: ^T` pointees.

**Block placement (intent):** `VAR` and **`CONST`** at the **beginning of the block**. `LET` may appear when the value becomes known. `CONST` is a `const-expression` — it is **not** allowed mid-block like `LET`.

**Examples:**

```mod-c
const Limit = 256
const Mask = 2 * Limit - 1
const Name = "Oberon"

var i, j, k: integer
var x, y: real
var s: string = "ok"

let n = f()           (* type inferred from initializer *)
let msg: string = "done"
(* n := 3  — illegal: LET does not rebind *)
i := 0                (* VAR *)
```

`(* C: CONST currently lowers to static const objects. Preprocessor constants are DEFINE (0.26.5.188), not a fold of declaration-CONST (item 19 demoted). LET / VAR are ordinary locals (0.26.5.183). *)`

### 4.3 Grouped trailing types

A trailing type on a comma list applies to each name (Oberon / C grouping).

**Examples:**

```mod-c
var x, y, z: integer
var p, q: ^Point
```

### 4.4 `FORWARD` and incomplete types

- **`type T FORWARD`** — incomplete; completed later **in this unit**. *Implemented (0.24.17.135).*  
- Postfix **`FORWARD`** on procedures/functions — mutual recursion. *Implemented.*  
- Declaration blocks `forward … end` / `extern … end` — *deferred*.

**Examples:**

```mod-c
type Node forward

type Node = struct
	key: integer
	next: ^Node
end

procedure A(n: integer) forward
procedure B(n: integer)
begin
	if n > 0 then A(n - 1) end
end
procedure A(n: integer)
begin
	if n > 0 then B(n - 1) end
end
```

---

## 5. Types

A type determines the set of values a variable of that type may assume, and the operators that apply.

### 5.1 Type expressions vs type specifiers

- **Full `type-expression`:** RHS of `TYPE` (and optional `EXTERN TYPE … = …`) — structs, enums, method types, **opaque**, arrays, …  
- **`type-specifier`:** formals, fields, `VAR`/`LET` annotations — **no bare `OPAQUE`**.

**Examples:**

```mod-c
type Handle = opaque              (* type-expression *)
var h: Handle                     (* type-specifier: named *)
(* var x: opaque  — illegal *)
```

### 5.2 Opaque types *Implemented (0.24.11)*

```mod-c
type Handle  = opaque
type address = ^opaque            (* or POINTER TO opaque *)
```

- **`OPAQUE` only on TYPE RHS.**  
- Illegal: `var x: opaque`, `procedure f(p: ^opaque)` — **name the type first**.  
- Distinct named opaques are **not** freely interchangeable (`Handle` ≠ `File`).  
- No user-facing type named **`void`**. Prefer procedures with no result, and `^opaque` / user aliases for C `void *`.  
- **C lowering (v1):** named `opaque` and `^opaque` aliases both emit as **`typedef void *Name;`**.

### 5.3 Pointers and auto-dereference *Types implemented (one `^`); field / `p[i]` / instance on `^T` Implemented (0.26.5.176–178)*

A type-specifier may include **at most one** pointer constructor: `^T` or `POINTER TO T`. That matches the current parser. It is also the JPL Power of Ten **rule 9** stance on declarations: do not make `char **` / `T ***` the everyday type language.

Need another level? **Name the inner type**, or use an array of pointers (`^char[]`). Do **not** write `^^char`.

**C specifier order (common trap):** `^` is **prefix** (Pascal/Modula), not C postfix `*`. C `unsigned char *` is a pointer **to** `unsigned char`, so TMod-c writes the pointer in front of the whole C spelling.

| C | TMod-c | Notes |
|---|--------|-------|
| `unsigned char` | `unsigned char` | Multi-word C spelling (§3.2) |
| `unsigned char *` | `^unsigned char` | or `type uchar = unsigned char` then `^uchar` |
| `const char *` | `const ^char` | `CONST` is prefix too; same as unbound `string` |
| `char **` | `^char[]` or `^pchar` after `type pchar = ^char` | not `^^char` |

Do **not** write `unsigned ^char`. After `unsigned` the parser is collecting C words (`unsigned int`, `unsigned char`); `^` is not a word in `type-name`, so a `TYPE` declaration errors with “expected end-of-statement … (got ^)”. There is also no C type “unsigned pointer to char”: `unsigned` qualifies integer types only.

`unsigned` is **not** a modifier on a named alias either. Consecutive identifiers are one C spelling and are passed through (0.26.1: only unknown *single-word* names are rejected). So:

```mod-c
type pchar  = ^char
type upchar = unsigned pchar    (* TMod-c accepts; emits illegal C *)
```

lowers to `typedef unsigned pchar upchar;`. GCC/clang reject that: `unsigned` / `signed` / `short` / `long` combine only with `char` / `int` / `long` / …, never with a typedef name.

Prefer `^unsigned char` or name `unsigned char` first, then take a pointer.

| Form | Meaning |
|------|---------|
| `p := q` | Always **rebinds** the pointer variable |
| `p.field` | **Auto-deref** if `p` is a pointer (same as `p^.field`) — **Done (0.26.5.176)**, Oberon-07 §8.1 |
| `p[i]` | **Auto-deref** if `p` is a pointer-to-array (same as `p^[i]`) — **Done (0.26.5.178)**. Do **not** peel `^char[]` `argv[i]` |
| `p[i]` | If `p` is `^T` and `T` is **not** an array: C index, type `T` (`*(p + i)`) — **Done (0.26.7.191)**. **Not** a peel — C stays `p[i]`, not `(*p)[i]`. Enables `p[i].method()` |
| `p^` | Explicit **pointee** (one peel) |
| `@e` | **Address-of** (expression context only) |

**Not used:** `@p := …` as a special rebind form. Rebind is bare `p := …`. Existing `p^.field` remains valid (explicit peel; AST is postfix `^` then `.`). Auto-deref does **not** insert a caret node.

**C `char **argv`:** `argv: ^char[]` (in-tree: `modc`, `ComputePi`) or `type pchar = ^char` then `argv: ^pchar` / `array of pchar`.

**APIs that would be `T **` in C:** prefer **`VAR` / `REF` on `T`** (§8.2). The extra star is ABI, not a second pointer type in the source. That is the intended way to avoid stacked `^`.

**Explicit deref in expressions:** postfix `^` may be repeated (`p^^`) because a value of type `^pchar` is still a pointer, and C interop sometimes peels twice. That is **legal**, not the preferred style. Power of Ten rule 9 wants **at most one dereference per expression** (Holzmann allows N=2 only with justification). Prefer:

```mod-c
let q = p^
x := q^
```

over `x := p^^`. v1 does **not** make `p^^` a parse error. A later lint may warn. Field auto-deref is **one** implied peel per `.` selector, not sugar for `^^`. Linked-list `p.next.next` is multiple peels via fields (Oberon allows it; rule 9 is stricter on that shape — review, not a grammar ban). Index auto-deref is the same rule for `[]` when `p` is a pointer-to-array. `argv: ^char[]` stays one index (`s := argv[i]` is `^char`, not a peel of a pointer-to-array-of-char). Explicit `p^[i]` emits parenthesized C `(*(p))[i]` so `[]` does not bind tighter than unary `*`. If `p` is `^T` and `T` is not an array, `p[i]` is the `i`-th `T` (C `p[i]`); that is pointer arithmetic, not a peel (**0.26.7.191**).

Rule 9 also objects to **hiding** a dereference in a typedef. Named `type pchar = ^char` is still one visible `^` on that line; `^pchar` is a second pointer type with a name, not a silent `**`. Do not use typedefs to pretend `p^^` is a single star.

**Examples:**

```mod-c
type pNode = ^Node
var p, q: pNode
p := q                 (* rebind *)
p := nil
n := p^                (* pointee — one peel *)
k := p^.key            (* explicit peel *)
k := p.key             (* auto-deref; still one peel; C: (*(p)).key *)
q := @node             (* address-of *)

type pchar = ^char
var argv: ^char[]      (* C char ** — not ^^char *)
s := argv[i]           (* one index; result is ^char — not peeled *)

var pv: ^Vector3 = @v  (* Vector3 = array[3] of int *)
x := pv[i]             (* auto-deref; C: (*(pv))[i] *)
x := pv^[i]            (* explicit; same C *)
(* var bad: ^^char   — not a type-specifier *)
```

`(* C: Node *p;  p = q;  n = *p;  k = (*p).key;  q = &node;  char **argv as ^char[] *)`

### 5.4 Structured types

#### Arrays

An array has a fixed number of elements of one type. Indices are **signed** (`integer`), from 0. The bound may be a named `CONST` or integer const-expression (*0.24.8*).

**Examples:**

```mod-c
const N = 32
type Vector = array[N] of real
type Matrix = array[10] of array[20] of real
var a: array[100] of integer
var buf: array[N] of char
```

Open / suffix forms (`T[]`, `integer[8]`) follow the syntax document.

#### Slice formals *Planned (0.27)*

An open-array formal is a **slice**. `s: char[]` and `s: array[] of char` are the same formal. A type alias of an open array is too (`type Buf = char[]`, then `s: Buf`). The source parameter list has no length argument. Generated C keeps the pointer and inserts an **`integer`** element count immediately after it. `countof(s)` reads that word.

```mod-c
function show(s: char[]): integer
begin
	return countof(s)
end

var buf: array[32] of char
n := show(buf)          (* passes buf and 32 *)
```

`(* C: integer show(char *s, integer s_length);  show(buf, (integer)32); *)`

The count is the number of elements, not the result of `strlen`. Each open-array formal gets its own count, placed after that pointer and before the next source formal or `...`.

A slice `countof` is not a constant. `array[countof(s)]` is illegal when `s` is a slice. Passing a slice formal through to another slice formal passes the hidden integer along. An actual with no element count (`^char`, `string`, a scalar) is an error.

These stay one C parameter, with no hidden length:

- `array[N] of T` and `T[N]`. The bound is the type. `countof` folds, as in §10.2.
- `^T`. Use this for a C function that takes one pointer. A `char[]` formal would pass a count that definition does not take.

A field `buf: array[] of char` is a C flexible array member, not a slice. `countof` of that field has no stored length. Index syntax `a[i..j]` is not part of this plan.

Hosted `main` stays `int main(int argc, char **argv)`. A program `kilo(argc: integer, argv: ^char[])` lowers the program function to `(integer argc, char **argv, integer argv_length)`. The wrapper calls `kilo(argc, argv, argc)`. `countof(argv)` is `argc` and does not include the `NULL` at `argv[argc]`.

Same-unit calls do not need `.mh`. An exported slice round-trips only once the `.mh` type-spec can spell `[]`. Until then the export is `?` and another module cannot insert the length. Not in 0.26.x. See `CURRENT.md` (Future plan: slice formals).

#### Enumerations *Implemented (0.24.6–0.24.7)*

```mod-c
type Color = enum
	Red,
	Green,
	Blue
end

var c: Color = Green
```

`(* C: typedef enum { Red, Green, Blue } Color; *)`

Members are integer constants. Duplicate members are an error. Cross-module import uses `export enum` in `.mh`.

#### Sets of enumerations *Planned (not 0.26.x)*

A **set** is a bit vector over a small enum, not a hash table. `SET OF E` is legal only when `E` is an enumeration whose members are distinct constants in **0 .. 63**. The value is one machine word (`cardinal 64`). Julia/Python-style `Set` of arbitrary values is not this type.

```mod-c
type NodeKindSet = set of NodeKind

const LOOP_KINDS: NodeKindSet =
	{ NODE_FOR, NODE_WHILE, NODE_REPEAT_UNTIL, NODE_LOOP }

if new_parent^.kind in LOOP_KINDS then
	child.enclosing_loop := new_parent
end

s := s + { NODE_FOR }     (* include *)
s := s - { NODE_FOR }     (* exclude *)
```

`(* C: typedef uint64_t NodeKindSet;` then `(s & (1ULL << x)) != 0`, union `|`, intersection `&`, difference `& ~`. `*)`

- Constructor `{ a, b, … }` is the same braces as an array literal; the type of the context (or of the elements) decides set vs array. Empty `{}` requires a type ascription.
- `x IN s` — membership; `x` has type `E`, `s` has type `SET OF E`.
- `s + t` union, `s * t` intersection, `s - t` difference; `==` / `!=`. Do not overload `|` / `&` on sets (those remain integer operations).
- `SET OF E` and `SET OF F` are distinct types. No implicit conversion to `cardinal 64`.
- Not v1: `SET OF integer` / `char` / structs; more than 64 members; `FOR x IN s`; heap sets.

See `CURRENT.md` (Future plan: SET OF enum) for implementation order.

#### Records (`STRUCT`)

A struct is a fixed number of named fields, possibly of different types. Nested aggregates are named types first, then used as a field type.

**Examples:**

```mod-c
type Date = struct
	day, month, year: integer
end

type Person = struct
	name: array[32] of char
	age: integer
	born: Date
end

var d: Date
d.day := 28
d.month := 8
d.year := 2026
```

`PACKED` is available on structs (see syntax). Field lists may group trailing types (`x, y: integer`).

#### Method types

A `TYPE` whose RHS is `PROCEDURE` / `FUNCTION` is a first-class procedure type (C function pointer). See §8.3.

```mod-c
type TFn = function (n: integer): integer
var fp: TFn
```

### 5.4.0 Record extension (`STRUCT` … `EXTENDS`) — Oberon model *Implemented (0.24.13)*

TMod-c treats **`EXTENDS` as record / struct extension**, not as a class system. Single inheritance; base as prefix. A future **`CLASS`** is out of scope.

#### Intent (locked)

| Rule | Meaning |
|------|---------|
| **Single inheritance only** | At most one `EXTENDS` base type |
| **Base at offset 0** | Child layout begins with a full parent value |
| **Flat field namespace** | Parent and child fields form one set of names |
| **No name clashes** | A field name must be unique along the entire chain |
| **Access** | `c.x` whether `x` was declared on the child or on a base |
| **Synthetic `base`** | On **EXTENDS** types only: reserved name for the embedded parent (`c.base`). Plain structs may use a field named `base` |
| **Upcast (by value)** | Child where parent is required — **Done (0.24.16)**; C `.base` × N |
| **Upcast (pointer / `REF`)** | `^Child` where `^Parent` is required; `REF Parent` + Child actual — **Done (0.26.5.175)** |
| **`AS` ancestor** | `g as Parent` → `.base` × N, not `(Parent)g` — **Done (0.26.5.175)** |
| **`p^.field`** | Parent fields through postfix `^` — **Done (0.26.5.175)** |
| **`p.field` auto-deref** | Same as `p^.field` when `p` is `^T` — **Done (0.26.5.176)**. C `(*(p)).field` then `.base` × N |
| **No vtable / no hidden RTTI** | Compile-time layout only. No `IS` / type guards on structs |
| **Parent-chain methods** | `c.m()` binds `Parent::m` when `c` is `Child` / `^Child` — **Done (0.26.5.180)**. Static lookup; Child shadows Parent |

#### C lowering — option A (chosen)

Named embedded base member (portable C11). Not GNU anonymous structs; not flattened parent fields (option B).

```c
typedef struct Parent { /* … */ } Parent;
typedef struct Child {
    Parent base;     /* always first — offset 0 */
    /* child-only fields */
} Child;
```

| Layer | Behavior |
|-------|----------|
| **TMod-c source** | `c.x` for any unique field on the chain |
| **Generated C** | Parent fields via `.base` (`c.base.x`); multi-level `g.x` → `g.base.base.x` |
| **Upcast codegen** | Insert `.base` × N (not a blind struct cast) |

#### Example

```mod-c
type Parent = struct
	name: array[20] of char
end

type Child = struct extends Parent
	age: integer
end

var c: Child
c.name := …           (* parent field; C: c.base.name *)
c.age := …            (* child field;  C: c.age *)
use_parent(c)         (* auto-upcast by value; C: use_parent(((c).base)) *)
use_parent(c.base)    (* equivalent explicit parent value *)
p := @c               (* ^Child *)
use_parent_ptr(p)     (* ^Child where ^Parent; C: &((*(p)).base) *)
q := c as Parent      (* C: ((c).base) — not (Parent)c *)
k := p^.name          (* parent field; C: (*(p)).base.name *)
k := p.name           (* auto-deref; same peel; C: (*(p)).base.name *)
(* type Bad = struct extends Parent; name: integer end  — clash *)
(* type Bad2 = struct extends Parent; base: integer end — 'base' reserved *)
```

`p[i]` auto-deref for pointer-to-array and instance method on `^T` — **Done (0.26.5.178)** (§5.3 / §8.3). Parent-chain `c.m()` / `pc.m()` — **Done (0.26.5.180)** (§8.3). C-index `p[i]` when `p` is `^T` and `T` is not an array — **Done (0.26.7.191)** (§5.3 / §6.2 / §8.3).

### 5.4.1 Union types *Implemented (0.24.12)*

C-compatible **overlapping** members — sibling of `STRUCT`, **not** `EXTENDS`. **Not** language-level tagged unions.

```mod-c
type Value = union
	i: integer
	f: real
	p: ^char
end

var u: Value
u.i := 3
u.f := 1.5            (* overlays u.i — C-like; no active-member check in v1 *)
```

No `EXTENDS` on unions. Nested anonymous unions deferred; name an inner type first.

### 5.5 Built-in type names

Reserved lowercase prelude names: `bool`, `byte`, `char`, `integer`, `cardinal`, `real`, `string` (see §10).

Of these, only **`integer`**, **`cardinal`**, **`real`**, and **`string`** may be **bound once per compilation unit**:

- by a top-level `TYPE` alias, or  
- by importing that type name from another module (e.g. a pack such as `tmodc.lp64`).

A second binding of the same name in the same unit is an error. Binding affects **only that compilation unit**. If a name is never bound, the **compiler default** applies (§10.1).

`bool`, `byte`, and `char` are **not** rebindable. Width forms (`integer N`, …) are **not** rebindable names; they are type constructors on the RHS / in type positions. Closed *N:* 8/16/32/64 for integers; 32/64 for `real`. `integer 128` is illegal until the closed set is extended.

*Status: Phase A (0.24.18); widths (0.26.5); import-as-bind and `.mh` width tails (0.26.5.174); alias RHS and in-tree packs (0.26.8.194). Build-time defaults deferred.*

**Examples:**

```mod-c
type integer = integer 64     (* this unit: integer is int64_t *)
type i32 = integer 32         (* alias; width form is not a bindable name *)
var x: integer
var w: integer 32
(* type integer = long
   type integer = int           — second bind: error *)
import integer from "fixtures/lp64.mh"   (* import is the one bind *)
```

---

## 6. Expressions and designators

Expressions denote rules of computation. Parentheses group. Assignments are **not** expressions.

### 6.1 Assignments are not expressions *Implemented*

`:=` and compound assignments are **statements only**. This avoids C-style “assignment in condition.”

**Examples:**

```mod-c
i := 0
(* if (i := f()) then …  — not TMod-c *)
if i == 0 then … end
```

### 6.2 Designators

`designator = qualident { selector }` with selectors `.`, `[]`, `^`.  
Address-of is a **prefix expression** (`@`), not part of a designator — so **`@n := …` is not an assignment target**. `@` of a `LET` or declaration `CONST` is a semantic error (*0.26.5.183*; §4.2). `@` of a `VAR` (including `@n` then `let pc: ^T = @n`) is legal.

If `A` is an array, `A[E]` is the element at index `E` (`E` is `integer`). If `r` is a struct, `r.f` is field `f`. If `p` is a pointer, `p^` is the pointee; `p^.f` and auto-deref `p.f` are a field of the pointee, including **EXTENDS** parent fields (**`p^.f` Done 0.26.5.175; `p.f` Done 0.26.5.176**). Auto-deref `p[i]` when `p` is a pointer-to-array — **Done (0.26.5.178)** (§5.3); not `^char[]` `argv[i]`. If `p` is `^T` and `T` is not an array, `p[i]` is the `i`-th `T` (C `p[i]`); type is `T` (same strip as `p^`) — **Done (0.26.7.191)**. **Written `^` first (0.26.8.196):** `tokens: ^sds` with `type sds = ^char` yields `tokens[0]: sds` (keep the name; do not chase the alias before stripping). `x: sds` with no extra `^` still indexes the buffer (`char`). Instance `p[i].method` then follows ordinary named-owner rules (`tokens[0].length()`). Instance `p.method` when `p` is `^T` — **Done (0.26.5.178)** (§8.3). Parent-chain `c.method` when the method is on an `EXTENDS` ancestor — **Done (0.26.5.180)** (§8.3). Postfix `^` may chain (`p^^`) — legal, not preferred; see §5.3 / Power of Ten rule 9.

**Examples** (see types in §5):

```
i              (* integer *)
a[i]           (* element *)
d.day          (* field *)
p^.key         (* pointer then field — one peel *)
p.key          (* auto-deref; same as p^.key *)
pv[i]          (* auto-deref pointer-to-array; same as pv^[i] *)
row[at]        (* ^ERow C-index; type ERow; C row[at] *)
row[at].updateRow()  (* instance on indexed ^T; C ERow__updateRow(&row[at]) *)
pp.getX()      (* instance on ^Point; same peel as pp^.getX() *)
t.left^.key
t.left.key     (* auto-deref through a pointer field *)
argv[i]        (* ^char[] — one index; not a pointer-to-array peel *)
@i             (* address-of; expression, not a designator target *)
(* &i  — illegal as address-of: '&' is bitwise AND; use '@'  — 0.26.5.186 *)
```

Growable C buffer (`realloc` of `^T`), not a pointer-to-array:

```mod-c
type ERow = struct
	size: integer
end
type pERow = ^ERow
procedure ERow::updateRow(ref row: ERow)
begin
	(* … *)
end ERow::updateRow

var row: pERow
row[at].size := n
row[at].updateRow()     (* C: ERow__updateRow(&row[at]) *)
```

`row[at].updateRow()` works because the index of `pERow` has type `ERow`. The alias name is a different owner: `row.updateRow()` looks up `pERow::updateRow`. A receiver written `var q: ^ERow` calls `ERow::updateRow`, as does `row^.updateRow()`. See §8.3.

### 6.3 Operators

Precedence is C-like: conditional `? :`, then `or`, `and`, equality (`==`, `!=` / `<>`), relational, shifts, additive, multiplicative (`*`, `/`, `DIV`, `MOD`, `%`), power `**` (right-associative), unary (`not`, `~`, `+`, `-`, `^`, `@`).

Logical `and` / `or` are sequential (short-circuit), like C `&&` / `||`.

**Examples:**

```
1987                 (* integer *)
i DIV 3
not p or q
(i + j) * (i - j)
(0 <= i) and (i < 100)
t.key == 0
x < 0 ? -x : x
n as integer 64
CAST(integer, c)
```

`IN` is *Planned* as set membership (`x IN s` for `SET OF` enum; §5). It is not a type guard. `IS` is **dropped** (no RTTI / no `IS` on structs).

### 6.4 Casts

Prefer postfix **`AS`**. `CAST(type, expr)` is also accepted.

```mod-c
r := i as real
w := n as integer 32
```

---

## 7. Statements

Statements denote actions. A statement may be empty. Structured statements contain statement sequences.

### 7.1 Control structures

`IF`, `SWITCH` (no fallthrough; **required** `ELSE`), `WHILE`, `REPEAT`, `FOR`, `LOOP`, `BREAK`, `CONTINUE`, `RETURN`, `DEFER`, `ASSERT`.

**`WHILE … BY`:** not planned; use `defer` at loop head for an end-of-iteration step.

#### If

```mod-c
if ch >= "A" and ch <= "Z" then
	ReadIdentifier
elsif ch >= "0" and ch <= "9" then
	ReadNumber
else
	ReadOther
end
```

#### Switch *no fallthrough*

```mod-c
switch c of
	case Red:    name := "red"
	case Green:  name := "green"
	case Blue:   name := "blue"
	else:        name := "?"
end
```

`(* C: switch without fallthrough; ELSE is mandatory in the grammar. *)`

#### While / repeat / for / loop

```mod-c
while j > 0 do
	j := j DIV 2
	inc(i)
end

repeat
	k := k + 1
until k >= n

for i := 1 to n do
	sum := sum + a[i]
end

for i := n downto 1 by 1 do
	(* … *)
end

loop
	if done then break end
end
```

Today `FOR` assigns a predeclared `var i` (`for i := …`). Loop-local `FOR` (`for i = …`) is a later **breaking** change (JPL rule 6); see `CURRENT.md`. Bounds and `BY` are evaluated once at entry. The control variable must not be assigned in the body.

Statements after `RETURN`, `BREAK`, or `CONTINUE` in the same sequence are **unreachable**. Since **0.26.8.196** this is a **warning** (it was a fatal parse error from 0.24.3). Those statements are still omitted from the AST. A C preprocessor line may follow `return` (for example `#endif` after `sdsTest`). An early exit inside a nested `if` does not mark the rest of the enclosing sequence unreachable.

### 7.2 Calls and discarded results *Implemented (Policy A — 0.24.15)*

| Form | Intent |
|------|--------|
| `proc()` | Call with **no useful result** (procedure, or untyped foreign import) |
| `x := f()` | Use function result |
| `(f())` | Call and **intentionally discard** result |

A bare call as a statement is an error when the result type is **known**. Unknown result (procedure, untyped `printf`) may be called bare. C may lower discards as `(void) f(...)`.

**Examples:**

```mod-c
printf("n=%d\n", n)     (* unknown C result: bare OK *)
x := f()
(f())                   (* discard known result *)
(* f()  — error if f is a typed function *)
```

### 7.3 `DEFER` *Implemented (core)*

`DEFER statement` schedules work on **scope exit**, LIFO (last deferred runs first). Primary tool for pairing acquire with release.

**Runs** only if control **passed that `DEFER`** (*0.26.5.187*). Then LIFO on language-level exit of that scope: falling off the end, **`RETURN`**, **`BREAK`**, and **`CONTINUE`**. A `return` in a nested `if` **before** a later `defer` in the same `BEGIN`/`END` does not run that defer. Nested scopes run their own defers when *they* exit.

**Does not run** if the process **aborts** or calls C **`exit`** (or `_Exit`, `abort`, a failing `assert` / `REQUIRE` / `ENSURE` that aborts). Like C, TMod-c has **no exception processing** — there is no `try`/`finally`, no unwind past `exit`. Resource cleanup across a hard abort is the operating system’s job.

**Examples:**

```mod-c
procedure load(path: string)
begin
	var f: ^FILE = fopen(path, "r")
	if f == nil then return end
	defer fclose(f)
	(* … use f; RETURN still closes *)
end

for i := 1 to n do
	defer printf("iter %d done\n", i)
	if i == 3 then break end      (* defer for this iteration still runs *)
	if i == 1 then continue end
end
```

`(* C: not a destructor; compiler inserts the deferred statement before each in-scope RETURN/BREAK/CONTINUE and at the closing brace. exit(1) skips it. *)`

### 7.4 `INC` / `DEC` / `ASSERT`

```mod-c
inc(i)
inc(i, 2)
dec(n)
assert i >= 0
```

`ASSERT` lowers to C `assert`. `INC`/`DEC` on a formal require **`VAR`** (bare name), like `:=`.

`ASSERT` is a **statement** (anywhere a statement is allowed). `REQUIRE` / `ENSURE` / `INVARIANT` are **contract clauses** with fixed positions (§7.5), not general statements.

### 7.5 Design by contract (DbC) *Implemented (core)*

TMod-c supports a small **Eiffel-style** contract: executable boolean expressions that document and check what a block or loop owes its caller and itself. They are not comments. A false contract is a failed C `assert` (abort in a typical host build).

| Clause | Role | Where it may appear |
|--------|------|---------------------|
| **`REQUIRE` expression** | **Precondition** — must hold on **entry** | Immediately after `BEGIN`, before the statement sequence |
| **`ENSURE` expression** | **Postcondition** — must hold on **exit** (including `RETURN`) | After the statement sequence **and after** the block’s `RETURN` (if any); immediately before `END`. **Not** before `RETURN`. |
| **`INVARIANT` expression** | **Loop invariant** — must hold at the invariant point of each iteration | Immediately inside `WHILE` / `FOR` / `REPEAT` / `LOOP`, before the body statements |

Keywords are case-insensitive (`require`, `REQUIRE`). Parentheses around the expression are optional (`require p <> nil` or `require (p <> nil)`).

**Not** class/object invariants on `STRUCT`. **Not** a separate proof language. Side effects in a contract expression are allowed by the grammar and **discouraged** (same as Holzmann: assertions should be observational).

**`ASSERT` vs DbC:** `ASSERT` is an ad-hoc check in the middle of a body (Power of Ten rule 5: many assertions). `REQUIRE`/`ENSURE`/`INVARIANT` name **entry**, **exit**, and **loop** obligations so a reviewer can see the contract without reading the whole body.

**C lowering:** each clause becomes `assert(expr); /* precondition */` (or `postcondition` / invariant). A compiler flag (`dbc_off`) omits them. `<assert.h>` is in the generated prelude.

**Nil:** `nil` belongs to **pointer types**. `require p <> nil` is for `p: ^T`. A `REF n: integer` is the object, not a nullable pointer — do not write `require n <> nil` to mean “the caller passed a real variable” (see §8.2 and `parameter-passing.md`).

**Examples:**

```mod-c
procedure bump(ref c: TCounter, n: integer)
begin
	require n >= 0
	c.n := c.n + n
	ensure c.n >= n
end bump

recursive function Fact(n: integer): integer
begin
	require n >= 0
	if n <= 1 then
		return 1
	end
	return n * Fact(n - 1)
	ensure n >= 0
end Fact

procedure load(path: string)
begin
	require path <> nil
	var f: ^FILE = fopen(path, "r")
	if f == nil then return end
	defer fclose(f)
	(* … *)
	ensure true                       (* or omit ENSURE *)
end
```

`ENSURE` is evaluated on the way out of the **block** (codegen re-emits postconditions at return sites). In source it **follows** `RETURN`: locked when 0.25 closed / 0.26 opened — there is no `ENSURE` then `RETURN`. There is **no** special `Result` / `old` syntax in v1: a function postcondition can mention formals and (if still in scope) locals, not a built-in result name. Assign to a local, `RETURN` that local, then `ENSURE` it.

```mod-c
function clamp(n, lo, hi: integer): integer
begin
	require lo <= hi
	var r: integer = n
	if r < lo then r := lo end
	if r > hi then r := hi end
	return r
	ensure (r >= lo) and (r <= hi)
end clamp
```

Loop invariant — checked at the start of each iteration (and thus before the body for `WHILE` / `FOR` / `LOOP`; at the corresponding point for `REPEAT`):

```mod-c
i := 0
while i < n do
	invariant i >= 0
	invariant i <= n
	inc(i)
end
```

Several `REQUIRE` / `ENSURE` / `INVARIANT` lines may appear; each is a separate `assert`. Nested `BEGIN`…`END` blocks may have their own contracts.

```mod-c
begin
	require p <> nil
	require n > 0
	(* statements *)
	ensure p^.n >= 0
end
```

`(* C: assert(p != nil); /* precondition */  …  assert(p->n >= 0); /* postcondition */ *)`

---

## 8. Procedures, functions, and parameters

### 8.1 Procedure vs function

- **`PROCEDURE`** — no result type.  
- **`FUNCTION`** — has a result type; the body must `RETURN` a value.  

Avoid “returns void” as a type.

**`RECURSIVE` (enforced 0.25.4):** required on a procedure/function that **directly** calls itself. The completing declaration (the one with the body) must carry the tag. Mutual recursion is not checked.

**Examples:**

```mod-c
procedure Swap(var a: integer, var b: integer)
begin
	var temp: integer = a
	a := b
	b := temp
end Swap

recursive function Fact(n: integer): integer
begin
	if n <= 1 then
		return 1
	end
	return n * Fact(n - 1)
end Fact
```

`(* C: void Swap(integer *a, integer *b);  integer Fact(integer n); *)`

### 8.2 Parameter modes *Implemented (0.25.0 / item 20)*

Formals may be prefixed with **`VAR`**, **`REF`**, or **`CONST`**. Parameter **`CONST`** is a **passing-mode / deep read-only** qualifier — not a compile-time `CONST` declaration.

| Mode | Bare name as LHS of `:=` / `INC` / `DEC` | Through designator (`p.x`, `a[i]`, `p^`) |
|------|------------------------------------------|------------------------------------------|
| **`VAR p: T`** | **Allowed** | Allowed |
| **`REF p: T`** | **Forbidden** | Allowed |
| **Bare `p: T`** | **Forbidden** | Selectors if used; whole-name assign illegal |
| **`CONST p: T`** | **Forbidden** | **Forbidden** (deep freeze) |

**Scalar `REF n: integer`:** no fields → effectively read-only for updates. Use **`VAR`** to change the caller’s integer.

**`VAR` / `REF` vs stacked pointers:** C out-parameters and “pointer to the caller’s object” are **`VAR p: T` / `REF p: T`**, not `^^T`. That is how TMod-c keeps APIs to one `^` in source (Power of Ten rule 9 on types; §5.3). Field auto-deref on `^T` (`p.x`) is **Done (0.26.5.176)** and does **not** replace `VAR`/`REF`. Instance method on a pointer receiver is still *Planned*.

**Bare formals are by-value** in C (expression actuals allowed). They share **non-`VAR` body discipline** with `REF` (and with **`LET` locals**, §4.2) but are **not** full `REF` at the ABI. See [`parameter-passing.md`](parameter-passing.md).

**C `...` last formal (0.26.7):** After at least one named formal, `, ...` is legal and lowers to C `, ...`. TMod-c does **not** type extra actuals and has **no** `va_list` / `va_arg` builtin. Extra actuals at the call site already parse; the C compiler accepts them only because of the emitted ellipsis. Consuming them is FFI: `import va_list, va_start, va_end from "stdarg.h"` and `vprintf` / `vsnprintf`. Illegal: `procedure f(...)` (no named formal); `...` not last; `PROGRAM` / `MODULE` parameter lists. `.mh` may write `(string, ...)`.

**Examples:**

```mod-c
procedure Swap(var a: integer, var b: integer)
	(* … *)
procedure Scale(ref p: Point, n: integer)     (* mutate p.x; cannot p := … *)
procedure Show(const p: Point)                (* no writes through p *)
procedure Id(n: integer): integer             (* bare: by-value; n := illegal *)

Swap(x, y)          (* auto-& → Swap(&x, &y) *)
Scale(pt, 2)
Show(pt)
k := Id(a + b)      (* expression actual: needs bare, not VAR/REF on T *)

procedure log_msg(fmt: string, ...)
begin
	var ap: va_list
	va_start(ap, fmt)
	vprintf(fmt, ap)
	va_end(ap)
end
```

| Formal | Typical C |
|--------|-----------|
| `VAR` / `REF` on non-pointer `T` | `T *p` |
| `REF p: ^T` | `T *p` |
| `VAR p: ^T` | `T **p` |
| Bare `p: T` | `T p` |

Expression actuals (`a + b`, `g()`) are **illegal** for `VAR`/`REF` on non-pointer `T` (no address). `REF p: ^T` does not auto-`&`.

### 8.3 Type-qualified methods *Implemented (0.23.9–0.25.3; 0.26.4; `^T` instance 0.26.5.178; `Type::m(p)` 0.26.5.179; parent-chain 0.26.5.180; C-index `p[i].m()` 0.26.7.191; named-type owner 0.26.8.196)*

Methods are ordinary `procedure` / `function` declarations whose name is **`Type::identifier`**. They are **not** declared inside `STRUCT` bodies. C mangling: `Type::name` → **`Type__name`**.

Classification uses the **written type of the first formal** only. The formal’s name is free (need not be `self`). The **owner is the name**, not the layout after aliases: `type sds = ^char` then `s: sds` is instance; `s: ^sds` is not (**0.26.8.196**). Do not treat a named pointer alias as “not a type.” First formal `^Owner` as instance remains deferred.

**A pointer alias is not a written `^`.** `type pERow = ^ERow` makes `pERow` its own name. For a type-bound call, `var row: pERow` looks up `pERow::updateRow`. `var q: ^ERow` looks up `ERow::updateRow`, because the `^` is written at the use site and the name under it is `ERow`. `row^.updateRow()` and `row[i].updateRow()` also call `ERow::`: the caret and the index both yield `ERow`. Field auto-deref still follows the alias, so `row.size` stays legal. Declare `pERow::updateRow(row: pERow)` when the alias itself should own the method, the same way `sds` and `Handle` do.

| Kind | First formal | Call |
|------|----------------|------|
| **Instance** | Written name is the owner `Type` (not `^Type`) | `Type::m(obj, …)` and `obj.m(…)`; `p.m(…)` when `p` is written `^Type` (**0.26.5.178**); a TYPE alias of that pointer is a different owner (`type pERow = ^ERow`, then `row: pERow` looks up `pERow::`, not `ERow::`) (**0.26.8.196**); `Type::m(p)` when `p` is `^Type` (**0.26.5.179**); `c.m()` / `pc.m()` when `m` is on an `EXTENDS` ancestor (**0.26.5.180**); `p[i].m()` when `p` is `^Type` (**0.26.7.191**); `tokens[0].m()` when `tokens` is `^sds` (**0.26.8.196**) |
| **Static / factory** | No formals, or first type ≠ `Type` | **`Type::m(…)` only** |

Method-typed **fields** are Oberon procedure variables: `obj.field(args)` → `(obj.field)(args)` — **no** auto-receiver. If the same identifier is both an instance method and a method-typed field, `obj.name(...)` is a **compile-time error**; use `Type::name(obj, …)`.

**Examples:**

```mod-c
function Point::getX(self: Point): integer
begin
	return self.x
end Point::getX

function Point::new(x: integer, y: integer): Point
begin
	var p: Point
	p.x := x
	p.y := y
	return p
end Point::new

procedure Point::print(self: Point)
begin
	printf("(%d, %d)\n", self.getX(), self.y)
end Point::print

type THandler = procedure (n: integer)
type Box = struct
	h: THandler
	n: integer
end

var p: Point = Point::new(5, 6)
Point::print(p)
p.print()
p.getX()
(* p.new(1, 2)  — illegal: new is static *)

var pp: ^Point = @p
n := pp.getX()         (* C: Point__getX((*pp)) *)
pp.print()             (* C: Point__print((*pp)) *)
Point::print(pp)       (* same peel; C: Point__print((*pp)) *)
Point::print(pp^)      (* explicit caret; still one peel *)
var pts: ^Point
pts[i].print()         (* C-index; type Point; C: Point__print(&pts[i]) *)
Point::print(pts[i])
(* kilo: E.row[at].updateRow() → ERow__updateRow(&E.row[at]) *)

type pERow = ^ERow
var row: pERow
var q: ^ERow
q.updateRow()           (* written ^ERow; ERow__updateRow *)
row[at].updateRow()     (* index type is ERow *)
row^.updateRow()        (* explicit pointee is ERow *)
(* row.updateRow() — looks up pERow__updateRow *)
(* TLexer::next(@p.lexer) — @ already an address; do not wrap (*&) *)
(* Child extends Parent: c.show() → Parent__show(c.base); pc.show() → Parent__show((*pc).base) *)
(* Child::show(c) looks up Child__show only — not a chain walk *)

var box: Box
box.h := say
box.h(42)              (* (box.h)(42) — no auto-self *)
```

No vtables. Cross-module: `import Type::name`; `.mh` carries `instance`/`static` and formals; `VAR`/`REF` auto-`&` applies. `REF`/`VAR` first formal on a `^T` receiver: auto-`&` outside the peel (`Type__scale(&(*pp), n)`). `Type::m(@x)` is not peeled (`@` is already the address). Parent-chain: `c.m()` walks `EXTENDS` (first instance hit; Child shadows Parent); C `.base` × N after peel (`Parent__show((*pc).base)`; `REF` `&((*pc).base)`). Qualified `Child::m` does not walk. C-index: `p[i].m()` when `p` is `^T` (**0.26.7.191**) is an ordinary `T` receiver — C `Type__m(&p[i])` for `REF`; not `(*p)[i]`. Deferred: first formal `^Owner` as instance.

---

## 9. Storage, ownership, and memory

### 9.1 No mandatory garbage collector

Safety comes from types, explicit pointers, structured `defer`, allocator discipline, and `countof` on complete arrays — not a tracing collector.

### 9.2 Ownership modes (API contracts)

| Mode | Who allocates | Who frees |
|------|---------------|-----------|
| **Borrow** | Caller (or static) | Caller |
| **Transfer** | Callee | Caller (`create` / `new` / `copy` + `defer`) |
| **Arena / region** | From arena `a` | Arena end / reset |
| **Optional RC** | Shared heap | Last `release` — not the default |

### 9.3 `defer` and leaks

On successful acquisition of an owned resource, schedule release with `defer` on the next lines. One owner, one free path on success. `RETURN` / `BREAK` / `CONTINUE` still run it; `exit` / abort do not (§7.3).

### 9.4 Arenas

Phased work: one compilation unit, one request, one parse. Initialize / reset at phase start; bulk free at phase end; **copy out** only what must outlive the arena.

### 9.5 Block `VAR` vs heap

- **Block `VAR`:** mutable **locals** (frame).  
- **Arena / heap:** dynamic structures; ownership per §9.2.  
Declaring `VAR` up front does **not** replace explicit heap policy.

---

## 10. Builtins and standard facilities

### 10.1 Builtin types *Partially implemented*

Everyday portable names answer **“what exactly is this?”** — not C’s rank ladder.

| Name | Role | Default lowering (unbound unit) |
|------|------|----------------------------------|
| `integer` | Everyday signed | `int` |
| `cardinal` | Everyday unsigned | `unsigned int` |
| `real` | Everyday floating | `float` |
| `string` | Immutable text (TMod-c **`const ^char`**) | `const char *` |
| `bool`, `byte`, `char` | Fixed small types | `bool`; `byte` is `uint8_t`; `char` is host `char`. Not rebindable |

**Unit binding:** at most one bind per unit via `TYPE` or named `.mh` import. Unbound defaults as above. `import integer as i64` does not bind `integer`. Include-only and foreign `.h` imports do not count.

**Width forms:** exact C11 `intN_t` / `uintN_t` / `float` / `double`. `.mh` type-spec may write `integer 32`. **Alias RHS** in the export table: `export type integer complete integer 64` (optional; old lines without a tail stay valid). **Packs:** `tests/fixtures/lp64` and `ilp32` (lean `.h`; stand-in for `tmodc.lp64` until item 15). **Build-time defaults** (unbound `cint` vs `lp64`) deferred.

**Not C rank:** bare `integer` always has a known unit binding or a documented default.

**`string` and literals:** unbound `string` **is** `const ^char`. That is the portable spelling for a pointer to static text (`let s: string = "ok"`). After LET locals are ordinary C (0.26.5.183), `let t: ^char = "hello"` discards C const; use `string` or `const ^char`.

**Examples:**

```mod-c
var i: integer = 1              (* typedef int integer; unless rebound *)
var u: cardinal
var r: real
var s: string = "ok"
var w: integer 32               (* int32_t *)
assert sizeof(w) == 4
```

### 10.2 `COUNTOF` and `SIZEOF`

`countof(designator | type)` — outermost element count of a **complete fixed array**. Type **`integer`**. Keyword `COUNTOF` (case-insensitive); the identifier `len` is not reserved (*0.26.9.198*). A known bound folds, so `array[countof(a)]` is a constant bound and C emits `((integer)N)`. An unfolded designator falls back to `((integer)(sizeof(n) / sizeof((n)[0])))`.

A type operand is legal (`countof(array[4] of integer)`). A type alias of a fixed array is legal (`type Buf = array[4] of integer`). Nested arrays report the outer bound only.

Rejected: pointers, scalars, `string`, and open arrays. `array_size == 0` is an open array and is also how `array[0]` is spelled. This is not string length. No VLAs.

**Planned (0.27):** `countof` of an open-array formal reads the hidden `integer` length inserted after the pointer (§5.4). That result is not a constant. `countof` of a fixed array is unchanged. `countof` of a flexible array member stays rejected.

Interim `LEN(designator)` (*0.26.8.194*) is removed. It accepted a designator only and always emitted the sizeof division.

`SIZEOF(...)` — size in bytes; type **`integer`**; C `((integer)sizeof(...))` — not `size_t` (*0.25.4*).

Lengths and indexes are **signed**. `cardinal` is for bits / wrap / C unsigned ABI. `size_t` is an imported C name.

**Examples:**

```mod-c
n := sizeof(integer)
n := sizeof(p)
var len: integer
var a: array[4] of integer
var m: array[7] of array[3] of integer
len := countof(a)                         (* 4; C ((integer)4) *)
var b: array[countof(a)] of integer
n := countof(array[4] of integer)
n := countof(m)                           (* 7 — outer bound *)
```

### 10.3 Standard library

Richer facilities (`StringBuffer`, containers, …) are **stdlib**, not core syntax.

---

## 11. C lowering and interop

Generated C is **C11**, intended for pedantic/warning-heavy flags.

- **Automatic includes (0.26.1):** `<stdint.h>`, `<stdbool.h>`, `<assert.h>` only. Prelude: `typedef uint8_t byte;`, `#define nil ((void *)0)`, `#define NIL nil`, plus the portable four typedefs unless rebound.  
- **Prelude location (0.26.5):** prelude and unit prototype live in the generated **`.h`**. Generated `.c` begins with `#include "UnitName.h"`. **`-C` writes a companion `.h`**.  
- Multi-TU hand-written C: `#include "tmodc.h"` (planned `tmodc.mc` → `tmodc.h`). Per-unit binds stay on that unit’s `.h`.  
- Foreign functions: `IMPORT` / `EXTERN`. Unresolved free calls and unknown types are errors.
- **Slice formals (planned, 0.27):** an open-array parameter lowers to `T *name, integer name_length`. The length follows the pointer. `countof` on that formal is the inserted integer. Fixed arrays and `^T` do not gain a parameter. See §5.4.  
- Preprocessor lines (`#define` / `#if`) in `.mc` are emitted as-is; they do not create TMod-c symbols. **`DEFINE`** (§4.1.1) emits `#define` **and** binds the name.

**Example** — source:

```mod-c
program Sum()
	type integer = integer 32
	var a: integer = 1
begin
	a := a + 1
end
```

Sketch of generated header (shape, not a golden file):

```c
#ifndef MODC_PROGRAM_Sum_H
#define MODC_PROGRAM_Sum_H
#include <stdint.h>
#include <stdbool.h>
#include <assert.h>
#define nil ((void *)0)
typedef uint8_t byte;
typedef const char* string;
typedef uint32_t cardinal;
typedef float real;
typedef int32_t integer;     /* unit bind; default typedef skipped */
void Sum(void);
#endif
```

---

## 12. Complete syntax

**Normative formal grammar:**

### → [`syntax-ebnf.md`](syntax-ebnf.md)

Do not maintain a second full EBNF elsewhere.

---

## 13. Document map

| Document | Role |
|----------|------|
| **[`language-report.md`](language-report.md)** (this file) | What the **language** is — prose, rules, intent, examples |
| **[`syntax-ebnf.md`](syntax-ebnf.md)** | Complete **formal EBNF** only |
| **[`parameter-passing.md`](parameter-passing.md)** | Parameter Passing Rules |
| **[`../CURRENT.md`](../CURRENT.md)** | What the **compiler** is doing this week; TODOs; version |
| **[`../changelog.md`](../changelog.md)** | Version-oriented change list |
| **`grok_report-*.md`**, **`project_bible.md`** | Session history — **not** daily language reference |

`grammar.md` is a stub pointing here. Filenames use hyphens (`language-report.md`, `syntax-ebnf.md`).

---

## Revision notes (report only)

| Date | Change |
|------|--------|
| 18 July 2026 | Initial draft report; SSOT split from monolithic `grammar.md`. Incorporates `OPAQUE`, discard, Oberon auto-deref intent, ownership modes, no mandatory GC, `VAR`/`LET` placement. |
| 21 July 2026 | `union-type` EBNF drafted (sibling of `struct-type`; no `EXTENDS`). Implementation TBD. |
| 21 July 2026 | **`STRUCT EXTENDS`:** Oberon record model + C lowering **option A**. |
| 21 July 2026 | **`OPAQUE` types implemented** (item 13a). |
| 23 July 2026 | **Bare `UNION` implemented** (item 13c). |
| 29 July 2026 | **Discard enforcement (Policy A / item 13b).** |
| 1 August 2026 | **EXTENDS by-value auto-upcast** (0.24.16). |
| 3 August 2026 | **Type-qualified methods §8.3** (0.24.17 / item 21). |
| 6 August 2026 | **§5.5 / §10.1 portable rebind Phase A** (0.24.18). |
| 6 August 2026 | **§8.2 parameter modes implemented** (0.25.0 / item 20). |
| 7 August 2026 | **§8.2 actuals:** bare stays by-value. **§8.3 callable fields** (0.25.1). |
| 11–12 August 2026 | Cross-module methods, formal signatures, **7a** module-entry bind. |
| 14 August 2026 | **`RECURSIVE`**; `SIZEOF` as `integer`; lean C prelude. |
| 18 August 2026 | Free-call and unknown-type enforcement (0.26.0 / 0.26.1). |
| 24–26 August 2026 | Parser split note; ident ≤ 255; `.mh` field lists and method-type RHS. |
| 27 August 2026 | Width forms; C prelude in generated `.h`. |
| 28 August 2026 | Import-as-bind; `.mh` width tails. **Examples throughout** (Oberon-report pattern; C-facing gloss). |
| 28 August 2026 | **§5.3 / §6.2 / §8.2 pointer depth:** one `^` per type-specifier (named inner type or `^T[]`); postfix `p^^` legal, not preferred (Po10 rule 9); `VAR`/`REF` instead of `^^T`. Field auto-deref landed 0.26.5.176. |
| 28 August 2026 | **§7.5 Design by contract:** `REQUIRE` / `ENSURE` / loop `INVARIANT`; examples; C `assert`; vs `ASSERT`. |
| 28 August 2026 | **§7.3 `DEFER`:** runs on `RETURN` / `BREAK` / `CONTINUE`; not on `exit` / abort; no exceptions. |
| 2 September 2026 | **§5 sets of enumerations *Planned*:** `SET OF` enum (0..63), `{ … }` literals, `IN` `+` `*` `-`. `IS` dropped; `IN` is membership only. |
| 2 September 2026 | **§5.4.0 EXTENDS polish (0.26.5.175):** `p^.field` parent fields; `as` ancestor → `.base`; pointer / `REF` upcast. |
| 3 September 2026 | **§5.3 / §6.2 field auto-deref (0.26.5.176):** `p.field` = `p^.field` when `p` is `^T`; C `(*(p)).field`. `p[i]` / instance on `^T` closed in **178**. |
| 4 September 2026 | **§5.3 / §6.2 / §8.3 `p[i]` and instance on `^T` (0.26.5.178):** pointer-to-array peel (not `^char[]`); `p.method` when `p` is `^T`; caret `(*(expr))` so `p^[i]` is not `*p[i]`. `Type::m(p)` closed in **179**. |
| 4 September 2026 | **§8.3 `Type::m(p)` peel (0.26.5.179):** first actual `^Owner` peels like `p.m()`; do not peel `@x` or `p^`. |
| 4 September 2026 | **§5.4.0 / §8.3 parent-chain methods (0.26.5.180):** `c.m()` / `pc.m()` bind ancestor `Parent::m`; C `.base` × N after peel; `Type::m(p)` peels when pointee extends owner. |
| 7 September 2026 | **§4.2 / §8.2 `LET` write-forbid (0.26.5.181):** three mutability states; `LET` = rebind lock (rule 2); through-writes legal; declaration `CONST` stays compile-time at block head. |
| 7 September 2026 | **§4.2 / §6.2 / §10.1 LET C `const` and `@` (0.26.5.183):** LET/VAR ordinary C locals; `@` of `LET`/`CONST` illegal; unbound `string` = `const ^char`. |
| 8 September 2026 | **§2.3 / §3.2 / §6.2 (0.26.5.186):** `extern type Name = struct [tag]`; char `'\xhh'`; `parse_primary` `'&'` vs `'@'`; array `{ a, b, }` trailing comma. |
| 8 September 2026 | **§7.3 `DEFER` only if executed (0.26.5.187):** cutoff is whether control passed that `DEFER`; nested `if … then return` then later `defer` does not run it. |
| 14 September 2026 | **§3.2 / §4.1.1 / §4.2 / §11 `DEFINE` (0.26.5.188):** `[EXPORT] DEFINE identifier rest-of-line`; bind like untyped `IMPORT`; `#define` pass-through stays unbound; `CONST` stays `static const`. |
| 17 September 2026 | **§5.3 C specifier order:** `^unsigned char` not `unsigned ^char`; `unsigned` is not a typedef modifier. |
| 17 September 2026 | **§8.2 `...` last formal (0.26.7):** emit C `, ...`; extras via `stdarg.h` FFI; not on PROGRAM/MODULE. |
| 18 September 2026 | **§5.3 / §6.2 / §8.3 C-index `p[i]` on `^T` (0.26.7.191):** type `T` (same strip as `p^`); C `p[i]` not `(*p)[i]`; `p[i].method()`; kilo `E.row[at].updateRow()`. Pointer-to-array peel unchanged (**178**). |
| 22 September 2026 | **§3.2 / §5.5 / §10.1 / §10.2 (0.26.8.194):** `.mh` alias RHS; in-tree `lp64`/`ilp32` packs; `LEN(designator)` interim C `sizeof/sizeof[0]`. Build-time defaults deferred. |
| 2 October 2026 | **§6.2 / §8.3 alias name versus written `^` (0.26.8.196):** `type pERow = ^ERow` is its own method owner. `var q: ^ERow` calls `ERow::`; `var row: pERow` calls `pERow::`. `row^`, `row[i]`, and field auto-deref still see `ERow`. |
| 2 October 2026 | **§9.1 / §10.2 `COUNTOF` (0.26.9.198):** replaces interim `LEN`. Outermost bound of a complete fixed array; type or designator; type `integer`; folded `((integer)N)`. `len` is an identifier. Pointers, scalars, `string`, and open arrays are errors. |
| 5 October 2026 | **§5.4 / §10.2 / §11 slice formals (planned, 0.27):** open-array formal `T[]` / `array[] of T` lowers to a pointer plus a hidden `integer` length. `countof` on that formal reads it and is not a constant. Fixed `array[N]` and `^T` stay one C parameter. Flexible array members stay bare. `a[i..j]` is not part of the plan. Not implemented. |

---

*End of TMod-c Language Report (draft).*
