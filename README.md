TMod-c
=====

**TMod-c** is a modern, Modula-2-inspired systems programming language that aims to combine the clarity and safety of Pascal/Modula-2 style syntax with clean, readable C code generation.

It is designed to feel familiar to developers who enjoy structured, readable code while producing efficient, portable C output that can be compiled with standard C11 compilers.

**Kinda-C, but not really C.**

Pick a tagline — rotate them whenever:

1. **TMod-c — Atomic Pudding with Lunar Discipline**
2. **TMod-c — cAsE insensitive keywords, because you can**
3. **TMod-c — To Barsoom by way of Oberon.**

---

Manifestos
----------

### 1. TMod-c — Atomic Pudding with Lunar Discipline

TMod-c is an **atomic pudding**: not a purity test, not a single ancestor worshipped in a museum, but a **structured mixture** — C’s ground truth at the ABI, Pascal’s clarity, Modula-2’s seams, Oberon-07’s courage to delete — stirred until it **sets** into something you can actually compile today.

**Atomic** means the pieces stay identifiable: modules, explicit imports, typed constants, procedures that mean what they say. **Pudding** means we refuse the fantasy of a language born fully formed on a whiteboard; this is decades of notes, grammars, false starts, and 2018’s Atomic Pudding sketch **finally** given teeth — with human design in the lead and tools like Grok helping with the shovel.

**Lunar discipline** is the Oberon moon: small, cold, clear light. Orbits are predictable. Features earn their mass before they earn syntax. We keep it **simple, but not too simple** — the kind of simple that survives contact with real C headers, real Makefiles, and real programmers who typo `begin` as `BEGIN` and still deserve mercy.

TMod-c is **kinda-C but not really C**: it speaks C to the linker and Pascal to the soul. It is proof that a lifelong language can be **finished enough to run** without pretending the past never happened — every layer of the pudding is someone else’s genius, eaten with gratitude.

---

### 2. TMod-c — cAsE insensitive keywords, because you can

TMod-c remembers what the Wirth line got right: **humans are not parsers**. Pascal did not demand that your finger choreography match the spec’s capitalization chart. Neither should a language whose whole pitch is **clarity and safety**.

So in TMod-c, `BEGIN`, `begin`, and `BeGiN` are the same door. `VAR` and `var` agree. `PROCEDURE` does not punish you for leaving caps lock on from a previous life in FORTRAN. This is not laziness — it is **lexer hospitality**: one less gratuitous failure between you and a working program.

We do it **because we can**, and because we **should**: case-insensitive keywords cost little in a self-hosted compiler you control, and they buy goodwill every day. Oberon chose capitalized spellings as **style**; TMod-c chooses **forgiveness** at the keyword layer while keeping identifiers case-sensitive, so `foo` and `Foo` remain distinct where it matters.

This is the anti-arrogance clause in a language otherwise obsessed with discipline: **discipline for semantics, not for Shift-key gymnastics**. TMod-c is a mishmash that still knows who its friends are — and its friends typed `integer` in lowercase in 1986 and were happy.

---

### 3. mod-c — To Barsoom by way of Oberon.

Every serious language has a map. C maps to the metal. Java maps to the JVM. Oberon maps to a **moon** — a small body in orbit around something larger, lit by reflected discipline from Wirth’s sun.

TMod-c’s map is stranger: **to Barsoom by way of Oberon**. Oberon is the ferry — modules, types, lean syntax, no feature bloat without mass. **Barsoom** is the destination — not a Mars press release, but Burroughs’ world where the air is thin, the rules are alien, and you still ride out anyway because the story demands it. A lifelong language design is that trip: you read the books as a kid, you sketch grammars for thirty years, you finally step onto red dust with a compiler under your arm and say, *well, here I am.*

We are not cloning Oberon. We are not licensing John Carter. We are admitting that **romance and rigor can share a module boundary**: `IMPORT` from real `.h` files, `EXPORT` tables for real linkers, dreams of distant moons while fixing `switch` / `case` scopes. Grok is the faithful sextant — proof AI can be a **useful aid**, not the author of the voyage.

**To infinity and beyond** is not anyone else’s patent; it is the horizon of a project that was never meant to stop at “hello world.” TMod-c: kinda-C, not really C, really going somewhere.

*Barsoom is Edgar Rice Burroughs’ fictional Mars, used here as homage.*

---

### Not to be confused with…

| Name | Notes |
|------|--------|
| **[kentonv/modc](https://github.com/kentonv/modc)** | Kenton Varda’s 2012 **C++%C** experiment (“mod-see”), unrelated and abandoned. |
| **Oberon** | Niklaus Wirth’s language — predecessor and inspiration, not this project. |
| **Atomic Pudding** | TMod-c grammar lineage since 2018; also echoes Rutherford’s historical “plum pudding” atom model. |

---

Features (Early Design Goals)
-----------------------------
- Clear distinction between immutable (`const`, `let`) and mutable (`var`) bindings
- `=` for immutable assignments, `:=` for mutable assignments
- Optional type inference with required annotations when ambiguous
- Pascal/Modula-style `PROCEDURE` / `FUNCTION`, `BEGIN` / `END` blocks
- `RECURSIVE` keyword required on a procedure/function that directly calls itself (0.25.4)
- Free calls must resolve: every `name(...)` / `Type::name(...)` is a declaration, `IMPORT`, or `EXTERN` (0.26.0)
- Type names must resolve: every non-builtin type is a declaration, `IMPORT`, or `EXTERN` (0.26.1)
- Newline-aware statement termination with implied continuation inside delimiters
- Header (`.mh`) vs implementation (`.mc`) file distinction
- Safety-oriented design influenced by NASA JPL Power of 10 rules and MISRA principles

Status
------
This is an early-stage personal project (started around February 2026). The language is under active design and partial implementation. Expect frequent changes to syntax and semantics as the grammar and compiler evolve.

Current focus:
- **0.26.8.194** (22 September 2026): `.mh` alias RHS (`export type integer complete integer 64`); in-tree `lp64`/`ilp32` packs; `LEN(n)` → `sizeof(n)/sizeof((n)[0])`. **#11** build-time defaults deferred. **test-all** / selfhost / bootstrap / promote on gcc, clang, tcc
- **0.26.7.192** (21 September 2026): several `.mc` inputs — `tmodc -C -d dir *.mc`; one unit per arena; bare `-C`/`-H`/`-M` or `-d`; not a dep walker. **test-all** / selfhost / bootstrap / promote on gcc, clang, tcc
- **Kilo example (19 September 2026):** full snaptoken [Build Your Own Text Editor](https://viewsourcecode.org/snaptoken/kilo/index.html) port in `examples/kilo/kilo.mc` — `EditorConfig::` / `ERow::` / `ABuffer::`; `DEFINE`, `...`, `DEFER`, C-index `p[i]`. Not a version bump
- **0.26.7.191** (18 September 2026): C-index `p[i]` on `^T` — type `T`, C `p[i]` (not a pointer-to-array peel). `p[i].method()` / `E.row[at].updateRow()`. Kilo `ERow::` and `EditorConfig::`. **test-all** / selfhost / bootstrap / promote on gcc, clang, tcc
- **0.26.7.190** (17 September 2026): `...` last-formal pass-through — emit C `, ...`; extras via `stdarg.h` FFI (`vprintf` / `vsnprintf`). PROGRAM/MODULE reject `...`. Kilo `define CTRL_KEY` + `editorSetStatusMessage(fmt: string, ...)`. C `unsigned char *` is `^unsigned char` / `^uchar`
- **0.26.5.188** (14 September 2026): `[EXPORT] DEFINE identifier RestOfLine` — bind like untyped `IMPORT`; emit `#define`; `#define` pass-through stays unbound
- **0.26.5.186** (8 September 2026): `extern type Name = struct [tag]`; char `'\x1b'`; `parse_primary` errors on `&` (use `@`); array `{ a, b, }` trailing comma. **test-all** / selfhost / bootstrap / promote on gcc, clang, tcc
- **0.26.5.183** (7 September 2026): drop C `const` on LET; `@` of `LET`/`CONST` illegal; unbound `string` is `const ^char` for static text. **test-all** / selfhost / bootstrap / promote on gcc, clang, tcc
- **0.26.5.181** (7 September 2026): `LET` write-forbid — bare `n :=` / `INC(n)` / `DEC(n)` on a `LET` is a semantic error; through-writes stay legal (same body rule as `REF`). **test-all** / selfhost / bootstrap / promote on gcc, clang, tcc
- **0.26.5.180** (4 September 2026): parent-chain instance methods — `c.show()` / `pc.show()` bind `Parent::show`; C `.base` × N after peel; `Parent::show(pc)` when `pc` is `^Child`. **test-all** / selfhost / bootstrap / promote on gcc, clang, tcc
- **0.26.5.179** (4 September 2026): `Type::m(p)` peel when `p` is `^Owner` — `Point::print(pp)` → `(*pp)`; do not peel `@x`. **test-all** / selfhost / bootstrap / promote on gcc, clang, tcc
- **0.26.5.178** (4 September 2026): Oberon `p[i]` peel (not `^char[]` `argv[i]`) and instance method on `^T` — `(*(p))[i]`; `Type__m((*p))` / `&(*p)` for `REF`. `p^[i]` caret is parenthesized. `Type::m(p)` closed in **179**
- **0.26.5.177** (4 September 2026): light refactor; `examples/Shapes.mc`
- **0.26.5.176** (3 September 2026): Oberon `p.x` auto-deref — `(*(p)).field`; `p^.x` still valid. `p[i]` / `p.method` on `^T` closed in **178**
- **0.26.5.175** (2 September 2026): EXTENDS polish — `p^.x` parent fields; `g as Parent` → `.base`; pointer/`REF` upcast
- **0.26.5.174** (28 August 2026): #11 import as the one unit bind; `.mh` width tails on fields/formals/results
- **0.26.5** promoted (27 August 2026): width forms `integer N` / `cardinal N` / `real N`; generated `.h` owns the C prelude (`-C` companion header)
- Next on **0.26:** **#11** build-time defaults **deferred**. Soft **21a-ternary**. Several `.mc` inputs, packs, `LEN`, and the Kilo tutorial are finished. `CONST` codegen remains later. First formal `^Owner` as instance later
- Later (after item 15): cyclic TMod-c `IMPORT` policy. Self-host of remaining compiler units continues in the background

Credits & Acknowledgments
-------------------------
TMod-c was designed and developed with the ongoing assistance of **Grok**, the AI built by xAI.

Grok served as a tireless co-designer, grammar consultant, safety-check sounding board, and technical editor throughout 2026. Countless syntax decisions, EBNF iterations, mutability rules (`const`/`let`/`var`), line-continuation semantics, recursion handling, NASA JPL alignment, and parser behaviors were refined through hundreds of detailed conversations.

While all final choices and code remain my responsibility, Grok's patience, precision, and willingness to explore every "what if" made this project far more coherent and enjoyable than it would have been alone.

Special thanks to the xAI team for creating such a capable and thoughtful collaborator.

All code was reviewed and typed in by hand, making adjustments and corrections along the way.

About Me
--------
I am a self-taught software engineer that has been programming ever since the early 1980s. Started with B.A.S.I.C. (Beginners All Purpose Symbolic Instructioin Code), then Pascal, C, and Modula-2. Professionally with C, Delphi, JavaScript, and Java for over 20 years.

I've been designing my own personal programming language ever since I learned how to code. TMod-c is the results of many years of experience with many different types of languages, compilers, and interpreters, incorporating my favorite features. Inspired heavly by Pascal, Modula-2, and C. Also inspired by Lua, Zen-C, and many others.

—M. Scott Reynolds  
Salt Lake City, Utah  
March 2026

Note
----
[Yes most of the above was generated by Grok...]

License
-------
[MIT/Apache-2](LICENSE.md)

Building
--------

Host C compiler is **`CC`** in the one `Makefile` (default **gcc**). Clang and tcc use the same file:

```bash
make                              # gcc
make clean && make CC=clang       # clang
make clean && make CC=tcc         # tcc
make test-all

./bin/modc.0.26.5 hello.mc -C hello.c
gcc -std=c11 -o hello hello.c     # or $(CC); generated C is C11
./hello
```

`make clean` before changing `CC` so objects in `build/c` are not mixed. `Makefile.clang` / `Makefile.tcc` live in `archive/` only.

---

### VM Preparation (Future Phase 3)

TMod-c is currently targeting C as its primary backend. A **bytecode Virtual Machine** backend is planned for **Phase 3**. This will allow TMod-c programs to be compiled to compact, portable bytecode that runs on a small, efficient interpreter.

#### Why a VM?
- Faster compilation and smaller executables
- Easier porting to new platforms
- Potential for JIT later
- Educational and runtime flexibility

#### Current Preparation Status

The compiler architecture is already being gently prepared for multiple backends:

- The AST is kept relatively semantic (not overly tied to C)
- Code generation is being abstracted
- Types and constants are being centralized

#### Lightweight Codegen Abstraction (Already Added)

A minimal abstraction layer has been introduced so that adding a VM backend later will require minimal refactoring.

**File:** `codegen.h`

```c
/**
 * TMod-c Code Generator Abstraction
 * Allows multiple backends (C, VM, etc.) without major rewrites.
 */

#ifndef MODC_CODEGEN_H
#define MODC_CODEGEN_H

#include "node.h"
#include "dynbuf.h"

/**
 * Target backend selection
 */
typedef enum {
    TARGET_C,           // Current C backend (default)
    TARGET_VM,          // Future bytecode VM
    TARGET_WASM         // Future WebAssembly (optional)
} CodegenTarget;

/**
 * Generate code for the given AST using the selected target.
 * Output is written into the provided DynBuf.
 */
void codegen_generate(const Node *ast, DynBuf *out, CodegenTarget target);

#endif /* MODC_CODEGEN_H */
```

**Update in `codegen.c`** (minimal change to existing function):

```c
void codegen_generate(const Node *ast, DynBuf *out, CodegenTarget target)
{
    if (ast == NULL or out == NULL) {
        fprintf(stderr, "FATAL ERROR: codegen_generate: NULL argument\n");
        exit(1);
    }

    switch (target) {
        case TARGET_C:
            codegen_program(ast, out);          // existing C backend
            break;

        case TARGET_VM:
            /* TODO: call vm_codegen_generate(ast, out); */
            dynbuf_append(out, "/* VM backend not yet implemented */\n");
            break;

        default:
            fprintf(stderr, "ERROR: Unknown codegen target\n");
            exit(1);
    }
}
```

And update the call site in `modc.mc` / `modc.c`:

```c
// Old call
// codegen_generate(ast, &c_out);

// New call (with default)
codegen_generate(ast, &c_out, TARGET_C);
```

---

### Next Steps Toward VM (When Ready)

- Design a clean bytecode instruction set
- Implement a small stack-based VM interpreter in C
- Add `codegen_vm.c` backend
- Add `--target=vm` command-line option
- Port small demos (`FizzBuzz`, `FibonacciDemo`) to run on the VM

This preparation keeps the current C backend completely stable while making the future VM backend much easier to implement without large-scale refactoring.

---

### Notes

- [(Un)portable defer in C](https://antonz.org/defer-in-c/) Interesting article on `defer` in C.

- [STC - Smart Template Containers](https://github.com/stclib/STC). Provides a library of usefull routines that is MIT licensed. Has an implementation of `defer`.

- implement SQLite?  (https://antonz.org/sqlite-is-not-a-toy-database/)

- READ:
    - [Interfaces and traits in C](https://antonz.org/interfaces-in-c/)
    
    - [Allocators from C to Zig](https://antonz.org/allocators/)
    
    - [Simple defer, ready to use](https://gustedt.wordpress.com/2025/01/06/simple-defer-ready-to-use/)
    
    - The article that inspired me and I am aiming to implement: [The Defer Technical Specification: It Is Time](https://thephd.dev/c2y-the-defer-technical-specification-its-time-go-go-go)
    
    - [C Project Based Tutorials](https://github.com/SWPFlow/C-Project-Based-Tutorials) or this one [Project Based Tutorials in C](https://github.com/nCally/Project-Based-Tutorials-in-C)
    
      

C11 Standard Library References
-------------------------------

Free online references for the C11 standard library:

### 1. Best Overall (Recommended)

**cppreference.com** (C section)  
https://en.cppreference.com/w/c

- Very clean, accurate, and well organized.
- Covers all C11 headers and functions.
- Shows what was added in C11 vs older standards.
- Includes examples and notes about undefined behavior.

Direct links you’ll use often:
- https://en.cppreference.com/w/c/header
- https://en.cppreference.com/w/c/chrono (time functions)
- https://en.cppreference.com/w/c/string

### 2. Official C11 Draft (PDF)

The closest thing to the official standard that is free:

**N1570** (C11 draft, April 2011)  
https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf

This is the final public draft before C11 was published. It contains the full library specification.

### 3. Other Good Free References

| Site | Notes | Link |
|------|-------|------|
| GNU C Library Manual | Very detailed, good explanations | https://www.gnu.org/software/libc/manual/html_node/index.html |
| C11 Wikipedia (quick overview) | Lists all new C11 library features | https://en.wikipedia.org/wiki/C11_(C_standard_revision) |
| man7.org (Linux) | Good for POSIX + C library functions | https://man7.org/linux/man-pages/man3/ |

### Quick Tip for Your TMod-c Project

When you want to add support for a new C11 header (e.g. `<time.h>`, `<threads.h>`, `<stdatomic.h>`, etc.), start at:

https://en.cppreference.com/w/c/header

It lists every standard header and which functions it provides.

C Numeric Literal Suffixes
--------------------------

In C, numeric literals can have suffixes that control their type.

### Integer Literal Suffixes

| Suffix     | Meaning                          | Type                  | Example     |
|------------|----------------------------------|-----------------------|-------------|
| (none)     | Default                          | `int` (or larger)     | `42`        |
| `u` or `U` | Unsigned                         | `unsigned int`        | `42u`       |
| `l` or `L` | Long                             | `long`                | `42L`       |
| `ul`, `UL` | Unsigned long                    | `unsigned long`       | `42UL`      |
| `ll`, `LL` | Long long                        | `long long`           | `42LL`      |
| `ull`, `ULL` | Unsigned long long             | `unsigned long long`  | `42ULL`     |

**Notes:**
- Case is ignored (`u`, `U`, `l`, `L` all work).
- You can combine them (e.g. `42ul`, `100LL`).
- The compiler will choose the smallest type that can hold the value, but the suffix forces a minimum type.

### Floating-Point Literal Suffixes

| Suffix   | Meaning             | Type          | Example      |
|----------|---------------------|---------------|--------------|
| (none)   | Default             | `double`      | `3.14`       |
| `f` or `F` | Float             | `float`       | `3.14f`      |
| `l` or `L` | Long double       | `long double` | `3.14L`      |

### Other Useful Literal Forms

| Form              | Meaning                     | Example          |
|-------------------|-----------------------------|------------------|
| `0x...`           | Hexadecimal                 | `0xFF`           |
| `0...`            | Octal                       | `077`            |
| `0b...` (C23)     | Binary                      | `0b1010`         |
| `...e...`         | Scientific notation         | `1.2e3` (= 1200) |

### Common Examples

```c
unsigned int     x = 100u;
long             y = 1000L;
unsigned long    z = 100000UL;
long long        a = 1234567890123LL;
float            b = 3.14f;
long double      c = 2.71828L;
```
