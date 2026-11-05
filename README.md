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
- No user-facing `void`. A procedure has no result. C `void *` is `^opaque` or `POINTER TO opaque` (0.26.9.200). A named `type Handle = opaque` stays a distinct `typedef void *Handle`
- Clear distinction between immutable (`const`, `let`) and mutable (`var`) bindings
- `=` for immutable assignments, `:=` for mutable assignments
- Optional type inference with required annotations when ambiguous
- Pascal/Modula-style `PROCEDURE` / `FUNCTION`, `BEGIN` / `END` blocks
- `RECURSIVE` keyword required on a procedure/function that directly calls itself (0.25.4)
- Free calls must resolve: every `name(...)` / `Type::name(...)` is a declaration, `IMPORT`, or `EXTERN` (0.26.0)
- Type names must resolve: every non-builtin type is a declaration, `IMPORT`, or `EXTERN` (0.26.1)
- Newline-aware statement termination with implied continuation inside delimiters
- Header (`.mh`) vs implementation (`.mc`) file distinction
- `HEADER` unit (0.26.11.208): declarations and `END` only. No parameters, no `BEGIN`, no `.c` file. `-C` writes the `.h`. An `.mh` is written only with `-M` (0.27.2.222)
- Subdirectory build (0.26.12.213): sources may live under `src/`. `src/codegen/` is package `codegen`. Several `.mc` inputs each keep their own source path
- Compiler C tree (0.27.2.222): generated and hand-written `.c` / `.h` live under `src/c/`, mirroring the `.mc` path. `.mh` stays beside the `.mc`
- Compiler sources (0.27.2.223): `.mc` and `.mh` live under `src/tmodc/` as package `tmodc`. Generated C mirrors that path under `src/c/tmodc/`. Hand-written `node.c`, `node.h`, and `version.h` stay in `src/c/`
- Package path (0.26.12.212): `module tmodc.lib.String()` is the unit `String` in `tmodc/lib/String.mc`. An unquoted import is one directory path from that unit's package root
- Type call (0.26.12.212): `Ident(...)` on a declared type is `Ident::Ident(...)`. The keyword `opaque` is not a type name
- Open-array formals (0.27.1.219): `T[]`, `array[] of T`, and `^char[]` lower to a pointer plus a hidden `integer` length. `countof` on that formal reads it. Fixed `T[N]`, `^T`, and `^array[] of T` stay one parameter
- Counted `FOR` (0.27.2.221; index type 0.27.3.227): `for i :=` assigns a predeclared variable. `for i =` and `for i: T =` declare a loop-scoped index. On `for i =`, an omitted type is the type of the start. A numeric literal stays `integer`. The declaring form accepts a type C can step, including `cardinal`, `char`, `size_t`, `byte`, an enumeration, and a pointer
- Anonymous nested `UNION` (0.27.4.228): a field `union` … `end` inside a `struct` or a named `union` has no name. Members are in scope on the enclosing aggregate (`box.a`, `box.b`). C is an unnamed `union { ... };`. A nested struct stays a named type
- Safety-oriented design influenced by NASA JPL Power of 10 rules and MISRA principles

Status
------
This is an early-stage personal project (started around February 2026). The language is under active design and implementation. Expect frequent changes to syntax and semantics as the grammar and compiler evolve.

**Public source:** [github.com/mscottreynolds/TMod-c-release](https://github.com/mscottreynolds/TMod-c-release) is the `make release` tree (compiler sources, tests, selected docs, examples). It is a snapshot per promote, not the full development history.

Current focus:
- **0.27.6.237** (2 November 2026): `forward` keyword is optional.
- **0.27.5.232** (30 October 2026):  **`BOUND`** — optional on `WHILE`, `REPEAT`, and `LOOP`, before any `INVARIANT`. One const-expression. `FOR` does not take it. An omitted bound leaves the loop as it is. 
- **0.27.4.228** (26 October 2026): anonymous nested `UNION`. A field `union` … `end` inside a `struct` or a named `union` has no name. Members are in scope on the enclosing aggregate. C is an unnamed `union { ... };`. `.mh` spells `union (a: Arm, b: integer)`. `@format` stays 1. Tests `tests/test_anon_union.mc` and `tests/test3_anon_union.mc`. Branch **`main`**. Stem **0.27.4**. Reported that gcc, clang, and tcc each pass `clean-all`, `all`, `test-all`, `selfhost`, `bootstrap`, and `promote`. `src/c/node.c` and `src/c/node.h` stay hand-written. The port is unblocked
- **0.27.3.227** (26 October 2026): `FOR` index type. On `for i =`, an omitted type is the type of the start. A numeric literal stays `integer`. The declaring form accepts a type C can step with `++` or `--`. Branch **`main`**. Stem **0.27.3**. Reported that gcc, clang, and tcc each pass `clean-all`, `all`, `test-all`, `selfhost`, `bootstrap`, and `promote`
- **0.27.2.226**: `src/tmodc/lib/` wrappers `String`, `Cardinal`, `Integer`, and `Real`. Each module entry returns a small struct. Commit `e4eb090`. Stem **0.27.2**
- **0.27.2.225**: `FOR` end temporary has the index type. The test is a direct `<=` or `>=`. Reported `make clean-all all test-all selfhost bootstrap promote` clean, with no warnings. Branch **`main`**. Stem **0.27.2**
- **0.27.2.223**: compiler `.mc` and `.mh` moved under `src/tmodc/` as package `tmodc`. Generated C mirrors that path under `src/c/tmodc/`. Hand-written `node.c`, `node.h`, and `version.h` stay in `src/c/`. Commit `3c2a043`. Stem **0.27.2**
- **0.27.2.222** (20 October 2026): generated and hand-written C live under `src/c/`, mirroring the `.mc` path. `.mh` stays beside the `.mc`. `-M` is required to write an `.mh`. `make version` writes `src/c/version.h`. Branch **`main`**. Stem **0.27.2**. Reported that gcc, clang, and tcc each pass `clean-all`, `all`, `test-all`, `selfhost`, `bootstrap`, and `promote`
- **0.27.2.221** (19 October 2026): dual `FOR`. `for i :=` assigns a predeclared variable. `for i =` and `for i: integer =` declare a loop-scoped `integer`. `cardinal` is not an index type. Existing `for i :=` loops stay. Branch **`TMod-c_0.27`**. Stem **0.27.2**. Reported that gcc, clang, and tcc each pass `clean-all`, `all`, `test-all`, `selfhost`, `bootstrap`, and `promote`
- **0.27.1.219** (19 October 2026): slice formals. An open-array parameter (`T[]`, `array[] of T`, `^char[]`, a one-step alias) lowers to a pointer plus a hidden `integer` `{name}_length`. `countof` on that formal reads it. Hosted `main` stays `(int argc, char **argv)`. `program modc(args: ^char[])` and `program kilo(args: ^char[])` are called as `name(argv, argc)`. Fixed arrays, `^T`, and `^array[] of T` stay one parameter. A module `main` uses `^pchar`. Branch **`TMod-c_0.27`**. Reported that self-host succeeds and that gcc, clang, and tcc each pass
- **0.27.1.218**: lexer, mh, parser, and semantic units moved into package directories (`src/lexer/`, `src/mh/`, `src/parser/`, `src/semantic/`)
- **0.27.1.217** (16 October 2026): `.mh` array type-specs. An exported `^Node[]`, `T[]`, `integer[4]`, or `^array[] of T` round-trips. `@format` stays 1. A line with no array suffix still parses. Branch **`TMod-c_0.27`**. The user reported the `test_mh_array` / `test2_mh_array` round-trip compiles
- **0.27.1.216** (16 October 2026): `DEFINE` requires `=`. `define Name = replacement` and `define Name(params) = replacement`. The `=` is omitted from `#define`. A raw `#define` stays unbound. The 0.26.5.188 rest-of-line form is a parse error. Branch **`TMod-c_0.27`**. Promoted **0.27.1.216**. Reported that gcc, clang, and tcc each pass.

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

./bin/modc.0.27.6 hello.mc -C hello.c
gcc -std=c11 -o hello hello.c     # or $(CC); generated C is C11
./hello
```

`make clean` before changing `CC` so objects in `build/c` are not mixed.

---

### Other Notes

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
