# TMod-c — Current Status

> **Rebrand (July 2026):** Public project and language name is **TMod-c** (TYPE compiler). Development tree is **TMod-c-dev** (the old **Mod-c** directory and the **TMod-c** symlink are gone). **Mod-c** remains the legacy name for the `modc` binary and the `modc-mh/1` format id until that cutover. Target compiler binary: **`tmodc`**; system ABI module: **`tmodc.mc`** / **`tmodc.h`**. Domains: tmodc.com, tmodc.org, tmodc.net.

**Version:** 0.27.10 (build 267)  
**Last updated:** 2026-11-25  
**Active branch:** `TMod-c_0.27`  
**Public source drop:** [TMod-c-release](https://github.com/mscottreynolds/TMod-c-release) — contents of `make tar` only (`build/tmod-c-VERSION.BUILD/`). Development tree is **TMod-c-dev** (this clone). Do not push development branches or tags to GitHub.

History through **0.27.10.267** is in `changelog.md`. The session archive for **255**–**258** is `docs/grok_report-20261120-0212.md`. **259**–**261** are `docs/grok_report-20261120-2025.md`. **264** is `docs/grok_report-20261124-1947.md`. **265**, **267**, and the `.mt` plan are `docs/grok_report-20261125-2147.md`. `docs/project_bible.md` runs through **0.27.10.267**. This file is the live focus.

## Current Focus

**Where we are.** Branch **`TMod-c_0.27`**, stem **0.27.10**, build **267**. **`mod-c_0.26`** closed at **0.26.12.213**. Self-host is complete (**0.27.8.250**). No hand-written compiler C remains. The last promote folds a character `CONST` to the host int (**0.27.10.267**). A call through a procedure variable or a callable field inserts the hidden slice length (**0.27.10.265**). Same-unit mutual recursion is **0.27.10.264**. A cycle of named calls requires `RECURSIVE` on every procedure on the cycle. `header System` and `export extern type` are **0.27.9.261**. `countof` of an imported array alias is **0.27.9.260**. `import Alias` alone stays an error. `q.getX()` finds `Point__getX` when `q` is declared `fixtures.starpack.Point` (**0.27.9.259**). The call still needs `import Point::getX`. `import * as Alias` is **0.27.9.258**. `import *` and the package C spelling are **0.27.9.257**. The unused keyword `IS` was dropped in **0.27.8.255**. Brace-list inference is **0.27.8.254**. `IMPORT … AS` is **0.27.8.253**.

**Next:** **15a.** Cyclic `IMPORT`. The `.mt` plan is recorded and not built.

**Still open**

- **15a.** Cyclic `IMPORT`. Plan recorded 25 November 2026. Not implemented. A `.mt` file is an export table in the same text as an `.mh`. `-T` writes it from a skeleton `.mc` with no semantic analysis. `--check-mt` compares a body's exports with that file and writes nothing. When `Unit.mt` is present, `-C`, `-H`, and `-M` run the same comparison and write nothing on failure. `--require-mt` makes a missing template a failure. Lookup uses `Unit.mh` when it exists, and `Unit.mt` only when it does not. `-t` stays token tracing. `parser_main` still meets `declaration`, `expression`, and `statement` through generated C headers and a previously emitted `.mh`. Language Report §3.2.
- **22.** Range expressions stay deferred.
- **Instance methods.** A first formal written `^Owner` is still not instance. Language Report §8.3.
- **Focus 13 / TODO 23.** `SET OF` enum is the plan below. The deferred line also names a stdlib `BitSet` and calls `SET OF` unlikely. Borrowed-buffer `init_at` waits until a stdlib is designed. See [SET OF](#future-plan-set-of-enum-wirth-bitset) and [borrowed buffers](#stdlib-borrowed-buffers-when-designed).
- **Focus 14.** Shebang / `-run` scripts. `tmodc -run` exists. The parser does not yet accept a leading `#!`. See [shebang](#future-plan-shebang--run-scripts).
- **`DEFINE`, later.** Macro expansion, `#undef`, `#if` as TMod-c, and a feature-test macro before includes.
- **`FORWARD`.** The keyword stays until the remaining `forward` lines are gone. Postfix `FORWARD` is already optional (**0.27.6.237**).
- **Strategic 0.** Rebrand cutover of the `modc` binary and the `modc-mh/1` format id. Multi-TU generated C does not yet `#include` `tmodc.h`.

**Parked or closed by decision**

- **#11.** `TMODC_ARCH` / compiler-build defaults, indefinitely (12 October 2026). Widths, import-bind, `.mh` alias RHS, and the in-tree packs are done. Unbound units stay `cint`.
- **8.** `FORWARD … END` / `EXTERN … END` blocks, indefinitely (19 October 2026). Per-line `EXTERN`, postfix `FORWARD`, and `type T FORWARD` stay.
- **7b.** No generated calls of imported module bodies. Call the module entry explicitly.
- **24.** Discard `_` is dropped (12 October 2026). `(f())` is the discard.
- **26.** Drop unused keyword `IS`. Done (**0.27.8.255**). The lexer no longer reserves it. `IN` stays reserved. See [Drop `IS`](#drop-is-no-type-guards).
- **7 remainder.** `IMPORT *` and the package C spelling. Done (**0.27.9.257**). `import * as Alias` is done (**0.27.9.258**). Language Report §3.2.
- **`COUNTOF` of an imported array type.** Done (**0.27.9.260**). An alias follows its target when that type is in scope. `import Alias` alone stays an error. Language Report §10.2.
- **10b remainder.** Mutual recursion of named calls in one unit. Done (**0.27.10.264**). A function pointer, a callable field, and a call into another unit are not edges. The module entry has no tag. Language Report §8.1.
- **10c hole.** A call through a function pointer or a callable field inserts the hidden slice length. Done (**0.27.10.265**). Language Report §5.4.
- **19 remainder.** A character literal `CONST` folds to the host int and emits no C object. Done (**0.27.10.267**). Language Report §4.2.
- **DbC.** `REQUIRE` / `ENSURE` already resolve like `ASSERT`. A nil-check of a `REF T` is a separate check of `^T`. Side-effect-free contract lint and a `--pot` assertion quota are not planned.

**Ongoing.** Expand the test suite as features land. `test_*` compiles and runs. `test2_*` is a semantic or `-a` success. `test3_*` is any non-zero exit. Message text is not locked.

**Scratch, not scheduled.**

- `semantic_resolve_type_inner: unknown type` still prints the whole node under `tmodc -a`. A shorter message would help.
- `WHILE`, `REPEAT`, and `LOOP` store both `bound_expr` and `has_bound`. The printer tests `bound_expr`. Codegen reads `has_bound`. Whether the flag is redundant is open.
- `var n: const pNode` is illegal when `type pNode = ^TNode`. Write `var n: const ^TNode` or `var n: pNode`.

## Future plan: `SET OF` enum (Wirth bitset)

**Status:** Design locked (2 September 2026). **Not implemented.** After the current higher-priority list. Spec in `docs/syntax-ebnf.md` + Language Report §5 / §6.3 when the bump starts (productions already drafted as *Planned*).

**Why:** `IN` is in the grammar for **set membership**, not type guards (`IS` is dropped). Compiler source wants named groups (`LOOP_KINDS`) and `kind in LOOP_KINDS` instead of `or` chains. This is Pascal/Modula-2 `SET OF`: a **bit vector** on a small ordinal, not Julia/Python `Set{T}` (hash table, heap, arbitrary `T`). Hash sets, if ever, are stdlib — not `IN`.

**v1 surface**

- Type: `SET OF E` where `E` is an **enum**. Every enumerator value is a distinct constant in **0 .. 63**. One `cardinal 64` / `uint64_t` mask.
- Constructor: Modula-2 **`{ a, b, c }`** — same braces as `array-literal`. The written target decides set or array. A brace list with no target is an array (§6.3 of the Language Report). Empty `{}` needs a type ascription.
- Named sets: `type NodeKindSet = set of NodeKind` then `const LOOP_KINDS: NodeKindSet = { NODE_FOR, NODE_WHILE, NODE_REPEAT_UNTIL, NODE_LOOP }`.
- `x IN s` — `x` is `E`, `s` is `SET OF E`.
- `s + t` union, `s * t` intersection, `s - t` difference, `s == t` / `s != t`. Include/exclude via `s := s + { x }` / `s := s - { x }`.
- Do **not** use `|` / `&` on sets (those stay integer/enum flags). `SET OF E` and `SET OF F` are different types.

```
type NodeKindSet = set of NodeKind

const LOOP_KINDS: NodeKindSet =
    { NODE_FOR, NODE_WHILE, NODE_REPEAT_UNTIL, NODE_LOOP }

if new_parent^.kind in LOOP_KINDS then
    child.enclosing_loop := new_parent
end
```

**Codegen** — bit test / mask; no heap:

```c
typedef uint64_t NodeKindSet;
static const NodeKindSet LOOP_KINDS =
    (1ULL << NODE_FOR) | (1ULL << NODE_WHILE) |
    (1ULL << NODE_REPEAT_UNTIL) | (1ULL << NODE_LOOP);

if (LOOP_KINDS & (1ULL << new_parent->kind))
    child.enclosing_loop = new_parent;
```

TMod-c still rejects mixing `ColorSet` with `NodeKindSet` even if both are 64-bit in C.

**v1 rejects:** `SET OF integer` / `real` / `struct` / `string`; enumerator `= 1000` or more than 64 members; `SET OF char` (256 bits — later); `FOR x IN s`; `CARD`; hash `Set`. Optional later: `<=` subset, `XOR` symmetric difference, `NOT` complement in `E`, Ada-style `x in (A, B)` sugar. `IS` is an identifier. `IN` is the leftover relational keyword.

**When implementing:** keyword `SET`; `set-type` in `type-expression` / `type-specifier`; `IN` in the relational parser (token exists); `{ … }` set vs array in semantic; operator types; tests (`test_*` membership/algebra, `test3_*` bad base type / ordinal out of 0..63). Version bump (not a quiet 0.26.x patch).

## Future plan: shebang / `-run` scripts

**Status:** Noted 14 September 2026. **Not implemented.** Sometime later; do not slip into 0.26.x calm-path. **#11** is parked indefinitely. `bin/tmodc` already supports **`tmodc -run file.mc [args…]`** (temp `.c` / `.h` / binary, then exec).

**Intent:** a unit can be `chmod +x` and run as:

```
#!/usr/bin/env -S tmodc -run
program hello()
import printf from "stdio.h"
begin
	printf("hello\n")
end
```

Use **`/usr/bin/env`**, not `/bin/env`. GNU `env -S` is required so the kernel does not treat `tmodc -run` as one program name.

**Wrapper (`tmodc.sh.in`):** after `-run`, the next existing file is the unit (not only `*.mc` — a shebang of `./hello` has no extension). Program argv follows that path. Optional: if argv[1] is a file whose first line is `#!`, implied `-run`.

**Parser:** `parse_program` already skips blanks, `;`, and comments before `PROGRAM`/`MODULE`. A shebang is `#` at column 1 → `TOK_PREPROCESSOR`, which is an error today. Allow preprocessor tokens before the unit keyword:

- `#!…` — accept; **do not emit** (invalid C).
- Other leading `#include` / `#define` / `#if` — keep on the program node; emit at the top of generated C (and `.h` if they must precede `<stdint.h>`). That is the deferred feature-test-before-includes rule (`_GNU_SOURCE`). A `DEFINE` after the unit `.h` is still too late.

Lexer already slurps `#` at column 1; no new token.

**Cache (`-run` binaries):** hosted convenience in the wrapper, not in `modc`. Keep the executable under `${XDG_CACHE_HOME:-$HOME/.cache}/tmodc/` (not `/tmp`). Reuse when the cached binary still exists, the unit `.mc` is not newer (mtime or content hash), and compiler identity matches (`modc` version / build.number, `CC`, `TMODC_CFLAGS`). Key: hash of absolute path + compiler-id + cflags. First cut may hash only the main unit; later include imported `.mh` / `.h` (or rebuild if any sibling is newer) — a stale import with an unchanged script mtime is the main foot-gun. Write to a temp name then `mv`. `TMODC_NOCACHE=1` or `-run -B` forces a rebuild. `TMODC_KEEP` may print the cache path. Flight builds must not depend on a user cache.

**Not that slice:** `...` formals; changing `DEFINE`; making unary `env` without `-S` work on non-GNU.

## Stdlib: borrowed buffers (when designed)

**Not scheduled.** `tests/StringBuffer.mc` today `malloc`s / `realloc`s / owns `_data` — fine for hosted tests, not a flight/Wasm default.

When a real stdlib is designed, prefer **caller RAM**:

```
procedure TStringBuffer::init_at(ref b: TStringBuffer, buf: ^char, cap: integer)
```

- `require buf <> nil` and `cap > 0`; no `malloc` / `realloc`; append **fails** (bool or `assert`) at capacity.
- `free` of `_data` only if an optional hosted `init` set an owns-flag; `init_at` does not own.
- Same pattern for other containers: `ARRAY[N]`, or `init_at(p, n)`, never “grow until the heap says no.”

Hosted growing `StringBuffer` may remain for the compiler and Linux tests. Flight / `--pot` / wasm32 guests should not need `realloc`.

## Design Decisions (still in force)

See **`docs/language-report.md`** (prose) and **`docs/syntax-ebnf.md`** (full EBNF). Filenames use hyphens (no `_`; `syntax-ebnf.md` not `syntax.ebnf.md`). Former monolithic `docs/grammar.md` is a redirect; archive in `docs/grammar_working_notes.md`. Highlights:

- **`.mh` / `.h` split** — `.mh` for modc semantics (export table); `.h` for C ABI (`#include` in generated C). Same stem/path layout rule.
- **Import sources** — quoted `"stdio.h"` / `"symbols/foo.h"` = foreign; unquoted qualident (`symtab`, `fixtures.minimod`, `codegen.codegen_header`) = Mod-c module (0.24.5). Resolution relative to compiling unit directory; project-root `src/` search paths deferred. `import from "…"` / `import from M.N` = include-only, no symtab. `import * from …` = bulk `.mh` import (deferred). **Package path (Done 0.26.12.212)** — the unit qualident's last identifier is the unit name. An unquoted import is one directory file from that unit's package root (Language Report §3.1.1). **Type call (Done 0.26.12.212)** — `Ident(...)` on a declared type is `Ident::Ident(...)` (§8.3). The keyword `opaque` is not that call.
- **`HEADER` unit (Done 0.26.11.208)** — `header Name` … `end`. No parameters, no return type, no `BEGIN`. Prototypes only. No `.c` file. `-C` writes the `.h`. An `.mh` is written only with `-M` (**0.27.2.222**). No unit-entry export. `@module` still names the unit. See Language Report §3.1.
- **`EXTERN`** — prefix only; never a body in this unit; refines `IMPORT`.
- **`FORWARD`** — postfix on proc/func; **`type ident FORWARD`** incomplete types **Done (0.24.17.135)** (complete later in the same unit).
- **Blocks** — `extern … end` / `forward … end` **parked indefinitely (19 October 2026).** Per-line `extern`, postfix `forward`, and `type T forward` stay.
- **`CONST` declarations** — compile-time named constants (Pascal/Oberon); block-head with `VAR`, mid-block is `LET`. **`LET`** — runtime rebind lock (**Done 0.26.5.181**); through-writes legal (rule 2 / `REF` body). **No C `const` on LET locals (Done 0.26.5.183).** `@` of `LET` / declaration `CONST` illegal (**183**). Parameter **`CONST`** — deep read-only qualifier, separate from compile-time `CONST`. Unbound **`string`** = **`const ^char`**. A folded integer emits no C object (**0.27.7.243**). A character literal folds to the host int (**0.27.10.267**). A value that does not fold stays `static const`. Preprocessor constants use **`DEFINE`**.
- **`CONST` codegen** — **Done (0.27.7.243, item 19; character literal 0.27.10.267).** A folded integer has no C object in the `.c` or the `.h`. An ordinary use emits the integer. An exported folded integer is `export const Name complete N`. A character literal is that integer (`'\xff'` is -1). An enumeration constant stays its C name. A string, an array, a record, or a brace list stays `static const`. Integer fold for bounds remains `has_const_value` (0.24.8). C `#define` names are **`DEFINE`**.
- **`DEFINE` (Done 0.26.5.188; `=` required 0.27.1.216)** — `define Name = replacement` and `define Name(params) = replacement`. The `=` is required and is omitted from `#define`. A `(` with no space after the name selects the function-like arm. `#define` pass-through still does **not** enter the symbol table. Feature-test macros stay `-D` on the Makefile. The 0.26.5.188 rest-of-line form is a parse error. See Language Report §4.1.1.
- **No user-facing `void`** — **`OPAQUE` implemented (13a):** TYPE RHS `opaque` / `^opaque` / `POINTER TO opaque` names an alias (`typedef void *Name`). **0.26.9.200:** `^opaque` and `POINTER TO opaque` are also type-specifiers (`void *`; `const ^opaque` is `const void *`). Bare `opaque` stays a TYPE RHS. Procedures have no result type.
- **Discard (13b Policy A — Done 0.24.15)** — `(expression)` as statement; bare call only when result type unknown; known results require `(f())` or use. C may lower with `(void)`.
- **`OPAQUE` vs `.mh` `opaque`** — source type constructor vs export completeness flag (same word, different grammars).
- **`STRUCT EXTENDS`** — Oberon-shaped record **layout** (single base at offset 0, unique field names, flat `c.x` in source); C lowering **option A** (`Parent base;`, emit `c.base.x` for parent fields). Synthetic `base` reserved **only on EXTENDS** types. Not class/vtable; **no hidden RTTI**. See Language Report §5.4.0. **13d Done (0.24.13)**; **by-value auto-upcast Done (0.24.16)**; **`p^.x` / `as` → `.base` / pointer·`REF` upcast Done (0.26.5.175)**; **Oberon `p.x` auto-deref Done (0.26.5.176)**; **`p[i]` peel + instance on `^T` Done (0.26.5.178)**; **`Type::m(p)` peel Done (0.26.5.179)**; **parent-chain methods Done (0.26.5.180)**.
- **`type_of_expr` / init inference (21a)** — **Done (0.24.14)**. Ternary/`? :` typing **Done (0.26.10.203)**. Brace-list inference **Done (0.27.8.254)**. A non-empty brace list whose elements share one static type is `array[N] of T`. A written `:` stays the type.
- **Bare `UNION`** — C overlapping members; `codegen_common_union_decl`; no EXTENDS; not language-level tagged unions. A nested struct is a named type used as a field type. An anonymous `union` … `end` promotes its members into the enclosing struct or union (**0.27.4.228**).
- **Arena** — linked chunks (pointer-stable); no whole-buffer `realloc` of live AST/symtab storage.
- **Portable builtins (Option A — Phase A Done 0.24.18; widths Done 0.26.5; import-bind / `.mh` widths Done 0.26.5.174; alias RHS / packs Done 0.26.8.194)** — Only `integer`, `cardinal`, `real`, `string` may be **bound once per compilation unit** via top-level `TYPE` **or** a named `.mh` import of that name. Unbound → defaults `int` / `unsigned int` / `float` / `const char *` (`cint`). Width forms **`integer N` / `cardinal N` / `real N`** are exact, RHS-only constructors (closed *N*); `.mh` type-spec may carry the same tail; **alias RHS** `export type integer complete integer 64`. Packs: `tests/fixtures/lp64`, `ilp32`. **Parked indefinitely (12 October 2026):** build-time defaults, until another architecture can prove `TMODC_ARCH`. Not C rank. See Language Report §5.5 / §10.1.
- **`RECURSIVE` (0.25.4 / 0.27.10.264)** — required on a **direct** self-call (same PROC/FUNC node as `enclosing_func`), and on every procedure or function in a cycle of named calls in the same unit. A function pointer, a callable field, and a call into another unit are not edges. The module entry has no tag. Review/lint flag for JPL rule 1.
- **`SIZEOF` (0.25.4)** — TMod-c type `integer`; C emit `((integer)sizeof(...))`. Not C `size_t`.
- **`COUNTOF` (0.26.9.198)** — `countof(designator | type)`; outermost bound of a complete fixed array; type `integer`; folded `((integer)N)`. `len` is an identifier. Pointers, scalars, `string`, and open arrays that are not slice formals are errors. A slice formal's `countof` is the hidden length (**0.27.1.219**). A call through a procedure variable or a callable field inserts that length (**0.27.10.265**). An imported array type folds, and an alias follows its target when that type is in scope (**0.27.9.260**). `import Alias` alone stays an error. Replaces interim **`LEN` (0.26.8.194)**. Not string length.
- **Generated C prelude (0.26.1 / 0.26.5)** — `<stdint.h>` `<stdbool.h>` `<assert.h>` only; `byte` = `uint8_t`; `#define nil ((void *)0)` / `#define NIL nil`. No automatic `<stddef.h>`. **0.26.5:** prelude and unit prototype live in the generated `.h`; `.c` includes `"Unit.h"`; `-C` writes a companion `.h`.
- **Name soft-miss** — **closed.** Calls **0.26.0**; types **0.26.1**.
- **Cyclic TMod-c `IMPORT`** — plan recorded 25 November 2026, not built. A `.mt` is the temporary export table. `-M` still writes the `.mh`. `--check-mt` is the contract check. `--require-mt` makes a missing template a failure. See Language Report §3.2.
- **Identifiers ≤ 255 (0.26.3.170)** — lexer / `.mh` error if longer. Mangled `Owner__name` may be 512. See Language Report §2.2.
- **`.mh` type layouts (0.26.3.170 / 0.26.4 / 0.26.5.174 / 0.26.8.194)** — one physical line; field tail on `complete struct`/`union` / `extends`; method-type `complete function|procedure ( … ) [ : T ]`; type-spec may be `integer N` / `cardinal N` / `real N`, or an array (`Node[]`, `^Node[]`, `integer[4]`, `^array[] of Node`, **0.27.1.217**); **alias RHS** after `complete` (`export type integer complete integer 64`); whole-file reader; `DynBuf` writer; synthetic struct / `NODE_METHOD_TYPE` on import. See Language Report §3.2.

## TODO / Next Actions

Open work and the scratch notes are [Current Focus](#current-focus). `TODO-items-for-0.27.md` is retired. Finished items from **0.26** and earlier, and the **0.27** promotes through **0.27.10.267**, are in `changelog.md`. `docs/project_bible.md` runs through **0.27.10.267**. **265**, **267**, and the `.mt` plan are `docs/grok_report-20261125-2147.md`.

## Useful Commands

```bash
make
make CC=clang
make CC=tcc
make clean && make CC=clang test-all
make clean && make CC=tcc test-all

make test
make test2
make test3
make test-all

make version
make selfhost
make bootstrap
make promote

./bin/tmodc --help
./bin/tmodc -C input.mc
./bin/tmodc -C -d dir *.mc
./bin/tmodc -H input.mc
./bin/tmodc -M [file.mh]
./bin/tmodc -a input.mc
```

## Archive

Closed releases and session notes are in `changelog.md`, `docs/project_bible.md`, and `docs/grok_report-*.md`. The latest session archive is `docs/grok_report-20261125-2147.md` (**0.27.10.265**, **0.27.10.267**, and the `.mt` plan). Language prose is `docs/language-report.md`. The EBNF is `docs/syntax-ebnf.md`.
