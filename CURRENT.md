# TMod-c — Current Status

> **Rebrand (July 2026):** Public project and language name is **TMod-c** (TYPE compiler). Development tree is **TMod-c-dev** (the old **Mod-c** directory and the **TMod-c** symlink are gone). **Mod-c** remains the legacy name for the `modc` binary and the `modc-mh/1` format id until that cutover. Target compiler binary: **`tmodc`**; system ABI module: **`tmodc.mc`** / **`tmodc.h`**. Domains: tmodc.com, tmodc.org, tmodc.net.

**Version:** 0.27.5 (build 232)  
**Last updated:** 2026-10-30  
**Active branch:** `main`  
**Public source drop:** [TMod-c-release](https://github.com/mscottreynolds/TMod-c-release) — contents of `make tar` only (`build/tmod-c-VERSION.BUILD/`). Development tree is **TMod-c-dev** (this clone). Do not push development branches or tags to GitHub.  
**Tag:** `MOD-C_0.23.7` (items 5–6); **0.23.8** postfix `FORWARD`; **0.23.9** type-qualified methods; **0.24.0** `.mh` writer + reader; **0.24.2** test-tier Makefiles; **0.24.3** builtin `integer`/`cardinal` lowering; **0.24.4** `codegen_header.mc` self-host step; **0.24.5** qualident `IMPORT … FROM`; **0.24.6** ENUM Phase A/B; **0.24.7** ENUM Phase C + `.mh` negative import tests; **0.24.8** named `CONST` array bounds + const-eval; **0.24.9** `symkind` / `mh_exportkind` as `.mc`; **0.24.10** `statement.mc`; **0.24.11** `expression.mc` + **`OPAQUE` (13a)**; **0.24.12** **`UNION` (13c)**; **0.24.13** **linked-chunk arena** + **`STRUCT EXTENDS` option A (13d)**; **0.24.14** **`Lexer.mc` self-host** + **`type_of_expr` / init inference (21a)**; **0.24.15** **discard enforcement (13b Policy A)**; **0.24.16** **`declaration.mc` self-host** + **EXTENDS by-value auto-upcast**; **0.24.17** **instance methods (21)** + static/instance by first formal; **0.24.17.135** **`type Name FORWARD`**; **0.24.18** **#11 Phase A** portable unit rebind; **0.25.0** **item 20** VAR/REF/CONST formals (**breaking**); **0.25.1** **callable field call-through**; **0.25.2** **cross-module method Phase A**; **0.25.3** **`.mh` formal signatures + 7a**; **0.25.4** **`RECURSIVE` enforce + signed `SIZEOF` + lean C prelude**; **0.26.0** **free-call soft-miss closed**; **0.26.1** **unknown types closed + no automatic `stddef.h`**; **0.26.2** **`Parser` → `TParser`**; **0.26.3** **`parser.c` → `parser_common.mc` + `parser_main.mc`**; **0.26.3.170** **`.mh` field lists**; **0.26.4** **method-type `.mh` RHS / cross-module field call-through**; **0.26.5** **width forms + `.h` prelude**; **0.26.5.174** **#11 import-bind + `.mh` widths**; **0.26.5.175** **EXTENDS polish** (`p^.x`, `as` → `.base`, pointer/`REF` upcast); **0.26.5.176** **Oberon `p.x` auto-deref**; **0.26.5.177** **Shapes example + light refactor**; **0.26.5.178** **`p[i]` peel + instance method on `^T`**; **0.26.5.179** **`Type::m(p)` peel**; **0.26.5.180** **parent-chain methods**; **0.26.5.181** **`LET` write-forbid**; **0.26.5.183** **drop C `const` on LET + `@` of LET/CONST**; **0.26.5.186** **`extern type = struct`, `'\x1b'`, `&` vs `@`, trailing `{ , }`**; **0.26.5.187** **`DEFER` only if executed**; **0.26.5.188** **`DEFINE`**; **0.26.7.190** **`...` pass-through**; **0.26.7.191** **C-index `p[i]` on `^T`**; **0.26.7.192** **several `.mc` inputs**; **0.26.8.194** **`.mh` alias RHS + packs + `LEN`**; **0.26.8.196** **named-type method owner + C-index of `^Named` + unreachable warning**; **0.26.9.198** **`COUNTOF` replaces interim `LEN`**; **0.26.9.199** **`codegen_common.mc` self-host**; **0.26.9.200** **`^opaque` type-specifier**; **0.26.9.201** **`codegen_c.mc` self-host**; **0.26.10.203** **21a-ternary**; **0.26.10.204** **named open-array alias formals**; **0.26.10.206** **`@` tighter than `as`**; **0.26.11.208** **`HEADER` unit**; **0.26.12.212** **package path** and **`Ident()` → `Ident::Ident`**; **0.26.12.213** **`src/` tree build**, **`codegen` package**, several inputs use each file's path; **0.27.1.216** **`DEFINE` with `=`**; **0.27.1.217** **`.mh` array type-specs**; **0.27.1.218** **package directories**; **0.27.1.219** **slice formals**; **0.27.2.221** **dual `FOR`**; **0.27.2.222** **C under `src/c`**; **0.27.2.223** **compiler `.mc` under `src/tmodc/`**; **0.27.2.225** **`FOR` end temporary**; **0.27.2.226** **`tmodc.lib` wrappers**; **0.27.3.227** **`FOR` index type**; **0.27.4.228** **anonymous nested `UNION`**; **0.27.4.229** **pointer-alias `as`** + **`.mh` export free**; **0.27.4.230** **VAR/REF designator**; **0.27.5.232** **loop `BOUND`**.

## Current Focus

**Calm path (ordered — do in sequence):**

| Step | Item | Work |
|------|------|------|
| ~~**1**~~ | ~~**13a**~~ | ~~`OPAQUE` end-to-end~~ **Done (0.24.11)**. |
| ~~**2**~~ | ~~**13c**~~ | ~~Bare `UNION`~~ **Done (0.24.12)** — parse / semantic / `codegen_common_union_decl`; tests green. |
| ~~**3**~~ | ~~**13d**~~ | ~~`STRUCT EXTENDS` option A~~ **Done (0.24.13)** — chain clashes; synthetic `base` reserved **only on EXTENDS**; `c.x` → `c.base.x`; multi-level. |
| ~~**4**~~ | ~~**21a**~~ | ~~`type_of_expr` + simple init inference~~ **Done (0.24.14)** — unlocks discard (13b), auto-upcast, VAR/REF, `obj.method`. |
| ~~**5**~~ | ~~**13b**~~ | ~~Discard enforcement (Policy A)~~ **Done (0.24.15)** — known result requires `(f())` or use; unknown/procedure bare OK. |

**Suggested next language work** (on **`main`**, where **0.27.2.221** already sits; **`TMod-c_0.27`** is still at **0.27.1.216**; **`mod-c_0.26`** closed at **0.26.12.213**):

**Loop `BOUND` (0.27.5.232).** Optional on `WHILE`, `REPEAT`, and `LOOP`. `loop bound 0` is the idle loop. The largest trusted value is 2,147,483,647. Stem **0.27.5**. See [Recent Accomplishments (0.27.5.232)](#recent-accomplishments-30-october-2026--0275232--loop-bound).

**`VAR` / `REF` designator (0.27.4.230).** A `VAR` or `REF` formal that takes an address requires a designator. `self as Object` is an error. `(@p[1]).bump()` stays legal. Stem **0.27.4**. See [Recent Accomplishments (0.27.4.230)](#recent-accomplishments-28-october-2026--0274230--var-ref-designator).

**Pointer-alias `as` and `.mh` free (0.27.4.229).** `upcast_ptr` follows one alias step, so `type Object = ^TObject` emits the pointer upcast. `mh_module_free` frees export `name` and `method_owner`. See [Recent Accomplishments (0.27.4.229)](#recent-accomplishments-27-october-2026--0274229--pointer-alias-and-mh-free).

**Anonymous nested `UNION` (0.27.4.228).** A field written `union` … `end` inside a `struct` or a named `union` has no name. Its members are in scope on the enclosing aggregate. C is an unnamed `union { ... };`. `@format` stays 1. Stem **0.27.4**. See [Recent Accomplishments (0.27.4.228)](#recent-accomplishments-26-october-2026--0274228--anonymous-nested-union).

**`FOR` index type (0.27.3.227).** On `for i =`, an omitted type is the type of the start expression. A numeric literal stays `integer`. The declaring form accepts any type C can step with `++` or `--`. Stem **0.27.3**. See [Future plan: loop-local FOR](#future-plan-loop-local-for-jpl-rule-6).

**C tree (0.27.2.222; sources under `src/tmodc/` in 0.27.2.223).** Compiler `.mc` and `.mh` live in package `tmodc` (`src/tmodc/`). Generated C mirrors that path under `src/c/tmodc/`. Hand-written `node.c`, `node.h`, and `version.h` stay in `src/c/`. `.mh` stays beside the `.mc`. `-M` is required to write an `.mh`. See [Recent Accomplishments (0.27.2.222)](#recent-accomplishments-20-october-2026--0272222--c-tree).

**Dual `FOR` (0.27.2.221).** `for i :=` assigns a predeclared variable. `for i =` and `for i: integer =` declare a loop-scoped `integer`. Stem **0.27.2**. See [Recent Accomplishments (0.27.2.221)](#recent-accomplishments-19-october-2026--0272221--dual-for).

**Slice formals (0.27.1.219).** An open-array parameter (`char[]`, `array[] of T`, `^char[]`, a one-step alias) lowers to the pointer plus a hidden `integer` `{name}_length`. `countof` on that formal reads it. Hosted `main` stays `(int argc, char **argv)` and calls `program modc(args: ^char[])` as `modc(argv, argc)`. See [Recent Accomplishments (0.27.1.219)](#recent-accomplishments-19-october-2026--0271219--slice-formals).

**Package directories (0.27.1.218).** Lexer, mh, parser, and semantic units live in package directories (`lexer.Lexer`, `mh.*`, `parser.*`, `semantic.semantic`). `src/codegen/` was already package `codegen`.

**`.mh` array type-specs (0.27.1.217).** An exported `^Node[]`, `T[]`, `integer[4]`, or `^array[] of T` round-trips. `@format` stays 1. See [Recent Accomplishments (0.27.1.217)](#recent-accomplishments-16-october-2026--0271217--mh-array-type-specs).

**`DEFINE` with `=` (0.27.1.216).** `define Name = replacement` and `define Name(params) = replacement`. The `=` is required and is omitted from `#define`. A raw `#define` line stays a pass-through. See [Recent Accomplishments (0.27.1.216)](#recent-accomplishments-16-october-2026--0271216--define-equals).

**Subdirectory build and several-inputs path (0.26.12.213).** `src/**` compiles, self-hosts, and promotes with its relative path. The codegen units live in `src/codegen/` as `module codegen.…`. Each file on a multi-file command line is analyzed with its own path. Last planned build on `mod-c_0.26`. See [Recent Accomplishments (0.26.12.213)](#recent-accomplishments-15-october-2026--02612213--subdirectory-build).

**Package path and type call (0.26.12.212).** A `PROGRAM`, `MODULE`, or `HEADER` name may be a qualident. The last identifier is the unit name (`module tmodc.lib.String()` is `String()`). An unquoted import is the one directory file `<root>/something/else/Something.mh`. A quoted path stays the written file. `Ident(...)` on a declared type is `Ident::Ident(...)`. See Language Report §3.1.1 and §8.3.

**TODO next:** nothing soft is queued on this stem. ~~Slice formals (item 16 / TODO 10c)~~ **Done (0.27.1.219)**. `.mh` array type-specs (TODO 6b) are **done (0.27.1.217)**. Package directories are **done (0.27.1.218)**. ~~Item **20** named open-array alias formals~~ **Done (0.26.10.204)**. ~~Item **16** `@` vs `as`~~ **Done (0.26.10.206)**. **24** discard `_` **dropped** (12 October 2026): `(f())` is the discard. **#11** build-time defaults (`TMODC_ARCH`) **parked indefinitely** (12 October 2026) until another architecture can prove a compiler-build default. Unbound units stay `cint`. See [After that: #11 architecture packs](#after-that-11-architecture-packs).

1. ~~**Close name soft-miss (breaking)**~~ — **Done.** Calls **0.26.0**; unknown types + drop automatic `<stddef.h>` **0.26.1**. Prelude builtins and multi-word C spellings (`long long`, `unsigned int`) stay. `size_t` / `FILE` / `void` must be imported.
2. ~~**`.mh` type completeness**~~ — **Done (0.26.3.170 field lists; 0.26.4 method-type RHS).** Cross-module `obj.field` and `obj.field(...)` call-through. Import the method type **and** the struct (`TFn` + `TBox`). Identifiers ≤ 255; whole-file `.mh` load; writer `DynBuf`.
3. ~~**#11 width forms**~~ — **Done (0.26.5).** Exact `integer N` / `cardinal N` / `real N` (8/16/32/64; `real` 32/64). Generated `.h` owns the C prelude; `-C` writes a companion `.h`. ~~**Import as the one unit bind**~~ **Done (0.26.5.174).** ~~**`.mh` width spelling**~~ **Done (0.26.5.174).** ~~**`.mh` alias RHS**~~ — **Done (0.26.8.194).** ~~**In-tree packs**~~ — **Done (0.26.8.194)** (`tests/fixtures/lp64`, `ilp32`; stand-in for `tmodc.lp64`). Directory compilation landed **0.26.12.213**. **Parked indefinitely (12 October 2026, same item):** build-time defaults (`TMODC_ARCH`), until another architecture can prove a compiler-build default. See [Recent Accomplishments (0.26.8.194)](#recent-accomplishments-22-september-2026--0268194--mh-alias-rhs-packs-len).
4. Optional **EXTENDS polish** — ~~aggregate `as` → `.base`~~ **Done (0.26.5.175)**; ~~pointer/`REF` upcast~~ **Done (0.26.5.175)**; ~~`^T` parent fields (`p^.x`)~~ **Done (0.26.5.175)**; ~~Oberon `p.x` auto-deref~~ **Done (0.26.5.176)**; ~~`p[i]` peel~~ **Done (0.26.5.178)**; ~~instance method on `^T`~~ **Done (0.26.5.178)**; ~~`Type::m(p)` peel~~ **Done (0.26.5.179)**; ~~parent-chain methods~~ **Done (0.26.5.180)**; ~~C-index `p[i]` on `^T`~~ **Done (0.26.7.191)**; ~~named-type method owner + C-index of `^Named`~~ **Done (0.26.8.196)**. See [Recent Accomplishments (0.26.8.196)](#recent-accomplishments-30-september-2026--0268196--named-type-owner-c-index-of-named).
5. ~~**`LET` write-forbid**~~ — **Done (0.26.5.181)**. ~~**Drop C `const` on LET (27b) + `@` of `LET`/`CONST`**~~ — **Done (0.26.5.183)**. ~~**C struct-tag `extern type` + char `\x` + parse `&`/`{ , }`**~~ — **Done (0.26.5.186)**. ~~**`DEFER` only if executed**~~ — **Done (0.26.5.187)**. ~~**`DEFINE`**~~ — **Done (0.26.5.188)**. ~~**`...` pass-through**~~ — **Done (0.26.7.190)**. ~~**C-index `p[i]` on `^T`**~~ — **Done (0.26.7.191)**. ~~**Kilo snaptoken tutorial**~~ — **Done (19 September 2026)**; **ABuffer** grow-by-doubling **(0.26.8.196)**. ~~**Several `.mc` inputs**~~ — **Done (0.26.7.192)**. ~~**`.mh` alias RHS + packs + `LEN`**~~ — **Done (0.26.8.194)**. ~~**Named-type owner / `^sds[i]` / unreachable warning / TSDSLib**~~ — **Done (0.26.8.196)**. See [Recent Accomplishments (0.26.8.196)](#recent-accomplishments-30-september-2026--0268196--named-type-owner-c-index-of-named). ~~**`COUNTOF` (replaces `LEN`)**~~ — **Done (0.26.9.198)**. See [Recent Accomplishments (0.26.9.198)](#recent-accomplishments-2-october-2026--0269198--countof). ~~**`codegen_common.mc` self-host**~~ — **Done (0.26.9.199)**. See [Recent Accomplishments (0.26.9.199)](#recent-accomplishments-3-october-2026--0269199--codegen_commonmc). ~~**`^opaque` type-specifier**~~ — **Done (0.26.9.200)**. See [Recent Accomplishments (0.26.9.200)](#recent-accomplishments-6-october-2026--0269200--opaque-type-specifier). ~~**`codegen_c.mc` self-host**~~ — **Done (0.26.9.201)**. See [Recent Accomplishments (0.26.9.201)](#recent-accomplishments-10-october-2026--0269201--codegen_cmc). ~~**21a-ternary**~~ — **Done (0.26.10.203)**. See [Recent Accomplishments (0.26.10.203)](#recent-accomplishments-12-october-2026--02610203--21a-ternary). ~~**Named open-array alias formals**~~ — **Done (0.26.10.204)**. See [Recent Accomplishments (0.26.10.204)](#recent-accomplishments-12-october-2026--02610204--open-array-alias-formals). ~~**`@` tighter than `as`**~~ — **Done (0.26.10.206)**. See [Recent Accomplishments (0.26.10.206)](#recent-accomplishments-12-october-2026--02610206--at-and-as). ~~**`HEADER` unit**~~ — **Done (0.26.11.208)**. See [Recent Accomplishments (0.26.11.208)](#recent-accomplishments-13-october-2026--02611208--header-unit). ~~**Package path**~~ — **Done (0.26.12.212)**. ~~**`Ident()` → `Ident::Ident`**~~ — **Done (0.26.12.212)**. See [Recent Accomplishments (0.26.12.212)](#recent-accomplishments-14-october-2026--02612212--package-path-and-type-call). **#11** build-time defaults **parked indefinitely** (12 October 2026). `src/c/node.c` / `src/c/node.h` remain hand-written C. Anonymous nested unions (**0.27.4.228**) unblock that port. `src/c/tmodc/tmodc.h` is generated from `src/tmodc/tmodc.mc` (**0.27.2.223**). `.mh` stays beside the `.mc`.
6. Soft **item 20** — ~~named open-array alias formals~~ **Done (0.26.10.204)**. **Bare formals stay by-value** — see `docs/parameter-passing.md`.
7. Soft: ~~**21a-ternary**~~ **Done (0.26.10.203)**; ~~discard `_` (**24**)~~ **Dropped** (12 October 2026). **`CONST` stays `static const`** — C `#define` constants are **`DEFINE`**, not item 19 lowering. Self-host remains background. ~~**7b** startup auto-init~~ — **Cancelled** (31 August 2026). Call module entries explicitly (7a). No generated `main` walk of imports.
8. ~~Later: **loop-local `FOR`** (**breaking**)~~ — **Done (0.27.2.221), both forms.** `for i :=` assigns a predeclared variable. `for i =` and `for i: integer =` declare a loop-scoped `integer`. See [Future plan: loop-local FOR](#future-plan-loop-local-for-jpl-rule-6).
9. ~~Later: **optional `BOUND`** on `WHILE` / `REPEAT` / `LOOP` (JPL rule 2)~~ — **Done (0.27.5.232).** Const trip count; `loop bound 0` is the idle loop. The largest trusted value is 2,147,483,647. See [Future plan: BOUND](#future-plan-bound-on-while-repeat-loop-jpl-rule-2).
10. Later: **drop unused `IS`** — lexer keyword / EBNF relational op; never parsed. No type guards / RTTI. See [Drop `IS`](#drop-is-no-type-guards). `IN` stays reserved for **`SET OF` membership** (item 12).
11. Later: **cyclic TMod-c `IMPORT`** — directories landed in **0.26.12.213** (TODO 15). The language rule is still later, not a 0.26 change. `parser_main` ↔ `declaration` / `expression` / `statement` works today via generated C headers and previously emitted `.mh`. Interim: extract a shared module (`parser_common`).
12. When a **stdlib** is designed: borrowed / pre-allocated buffers (e.g. `TStringBuffer::init_at`), not only `malloc`/`realloc`. See [Stdlib: borrowed buffers](#stdlib-borrowed-buffers-when-designed).
13. Later: **`SET OF` enum** (Wirth bitset, not a hash set) — `IN`, `{ … }` literals, named `CONST` sets, `+` `*` `-` `==` `!=`. See [Future plan: SET OF enum](#future-plan-set-of-enum-wirth-bitset). Not 0.26.x.
14. Later: **shebang scripts** — `#!/usr/bin/env -S tmodc -run` then `PROGRAM`/`MODULE`; wrapper already has `-run`; cache the binary so a later run can skip `modc`/`cc`. Parser: leading `#` before the unit keyword (`#!` drop, other directives emit early). See [Future plan: shebang / `-run` scripts](#future-plan-shebang--run-scripts). Not 0.26.x calm-path. **#11** is parked indefinitely.
15. ~~**`.mh` array type-specs**~~ — **Done (0.27.1.217)**. An exported `^Node[]`, `T[]`, `T[N]`, or `^array[] of T` round-trips. `@format` stays 1. See [Future plan: `.mh` array type-specs](#future-plan-mh-array-type-specs).
16. ~~**0.27:** **slice formals**~~ — **Done (0.27.1.219)**. `T[]` / `array[] of T` / `^char[]` as a parameter gains a hidden `integer` length after the pointer. `countof` on that formal reads it. Fixed `array[N]`, `^T`, and `^array[] of T` stay one C parameter. See [Future plan: slice formals (0.27)](#future-plan-slice-formals-027).
17. Later: **`ELSE CASE`** — `else case A, B:` names constants that share the required else body. `else` stays first. One body; generated C lists those labels and ends the arm with `default:`. Not parsed yet. See Language Report §7.1. Not 0.26.x calm-path.
18. ~~**0.27:** **`DEFINE` with `=`**~~ — **Done (0.27.1.216)**. `define Name = replacement` and `define Name(params) = replacement`. The `=` is required and is omitted from `#define`. A raw `#define` line stays unbound. See [Recent Accomplishments (0.27.1.216)](#recent-accomplishments-16-october-2026--0271216--define-equals).

**0.27.5.232** adds an optional `BOUND` on `WHILE`, `REPEAT`, and `LOOP`. `loop bound 0` emits no counter. The largest trusted value is 2,147,483,647. The user reported that all tests pass and that gcc, clang, and tcc each pass. Stem **0.27.5**. **0.27.4.230** requires a designator for a `VAR` or `REF` actual when that formal takes an address. `self as Object` is an error. `(@p[1]).bump()` stays legal. The user reported that gcc, clang, and tcc each pass. Stem **0.27.4**. **0.27.4.229** sets `upcast_ptr` through one alias step, and frees each `.mh` export `name` and `method_owner`. **0.27.4.228** adds an anonymous nested `union` … `end` inside a `struct` or a named `union`. Members are in scope on the enclosing aggregate. C is an unnamed `union { ... };`. The user reported that gcc, clang, and tcc each pass `clean-all`, `all`, `test-all`, `selfhost`, `bootstrap`, and `promote`. Stem **0.27.4**. **0.27.3.227** takes an omitted `for i =` type from the start expression. **0.27.2.226** adds `tmodc.lib` wrappers for `String`, `Cardinal`, `Integer`, and `Real`. **0.27.2.225** types the `FOR` end temporary from the index. **0.27.2.223** moves compiler `.mc` under `src/tmodc/`. **0.27.2.222** puts generated and hand-written C under `src/c/`, mirroring the `.mc` path. `.mh` stays beside the `.mc`. `-M` is required to write an `.mh`. The user reported that gcc, clang, and tcc each pass `clean-all`, `all`, `test-all`, `selfhost`, `bootstrap`, and `promote`. Stem **0.27.2**. **0.27.2.221** adds a loop-scoped index on `for i =` and `for i: integer =`. `for i :=` still assigns a predeclared variable. The user reported that gcc, clang, and tcc each pass `clean-all`, `all`, `test-all`, `selfhost`, `bootstrap`, and `promote`. Stem **0.27.2**. **0.27.1.219** inserts the hidden length on an open-array formal (`T[]`, `array[] of T`, `^char[]`). `countof` on that formal reads `{name}_length`. Hosted `main` stays `(int argc, char **argv)`. `program modc(args: ^char[])` and `program kilo(args: ^char[])` are called as `modc(argv, argc)` and `kilo(argv, argc)`. The user reported that self-host succeeds and that gcc, clang, and tcc each pass. **0.27.1.218** moves lexer, mh, parser, and semantic units into package directories. **0.27.1.217** spells `.mh` array type-specs (`^Node[]`, `T[]`, `T[N]`, `^array[] of T`). `@format` stays 1. The user reported the `test_mh_array` / `test2_mh_array` round-trip compiles. **0.27.1.216** requires `=` on `DEFINE` and omits it from `#define`. The 0.26.5.188 rest-of-line form is a parse error. A raw `#define INIT = 0` stays a pass-through. User promoted **0.27.1.216** on branch **`TMod-c_0.27`**. `Makefile` `VERSION` is **0.27.1**. **0.26.12.213** closes Makefile subdirectory compilation and the several-inputs source path. `src/codegen/` is package `codegen`. User promoted **0.26.12.213**. This is the last planned build on `mod-c_0.26`. **0.26.12.212** adds the package path and the type call. A unit qualident's last identifier is the unit name. An unquoted import is one directory path from that unit's package root. `Ident(...)` on a declared type is `Ident::Ident(...)`. User promoted **0.26.12.212** after gcc, clang, and tcc each passed **test-all** / **selfhost** / **bootstrap** / **promote**. **0.26.11.208** adds a **`HEADER`** unit: `header Name` … `end`, no parameters, no `BEGIN`, no `.c` file. `-C` still writes `.h` and `.mh`. No unit-entry export. `src/tmodc.mc` generates `tmodc.h` and `tmodc.mh`. User promoted **0.26.11.208**. **0.26.10.206** makes `@e as T` mean `(@e) as T` and names each `FOR` end temporary with its line and column. User reported `make all` (compiler, string lib, examples) after the Kilo casts. **0.26.10.204** decays a `VAR` / `REF` named open-array alias like a written `integer[]`. **0.26.10.203** types `cond ? a : b` when both arms share one static type (**21a-ternary**). The result is the then arm's type. One alias step counts. Stem **0.26.10**. **203** and **204:** tests green on **gcc**, **clang**, and **tcc** through **selfhost** / **bootstrap** / **promote**. **0.26.9.201** ports **`codegen_c.c`** to **`codegen_c.mc`** (statements and the full program). Generated `.c` / `.h` / `.mh`. No new language behavior. Tests green on **gcc**, **clang**, and **tcc** through **selfhost** / **bootstrap** / **promote**. **0.26.9.200** makes **`^opaque`** and **`POINTER TO opaque`** type-specifiers (`void *`; `const ^opaque` is `const void *`). Bare `opaque` stays a TYPE RHS. Named `type Handle = opaque` stays `typedef void *Name`. Tests green on **gcc**, **clang**, and **tcc**. **0.26.9.199** ports **`codegen_common.c`** to **`codegen_common.mc`** (shared emitter). Tests green on **gcc**, **clang**, and **tcc**. **0.26.9.198** replaces interim **`LEN`** with **`countof`**: outermost bound of a complete fixed array, type or designator, type `integer`, folded to `((integer)N)`. The identifier `len` is free. Pointers, scalars, `string`, and open arrays (`array_size == 0`, including `array[0]`) are errors. **0.26.8.196** closes named-type method owner (`s: sds` instance; `s: ^sds` not), C-index of written `^Named` (`tokens[0].length()`), and unreachable-after-exit as a **warning**. **TSDSLib 2.0** (`examples/sds/`). Kilo `ABuffer` prealloc. **0.26.8.194** closed `.mh` alias RHS, in-tree packs, and interim **`LEN`**. **#11** build-time defaults parked indefinitely (12 October 2026). **0.26.7.192** closes several `.mc` inputs (`tmodc -C -d dir *.mc`; one unit per arena; not a dep walker). **0.26.7.191** closes C-index `p[i]` on `^T` (`E.row[at].updateRow()`; not a pointer-to-array peel). **0.26.7.190** closes `...` last-formal pass-through (emit `, ...`; consume extras via `stdarg.h` FFI). **0.26.5.188** closes `[EXPORT] DEFINE identifier RestOfLine` (bind like untyped `IMPORT`; `#define` pass-through unbound). **0.26.5.187** closes `DEFER` only if control passed that statement (`stmt_index` cutoff). **0.26.5.186** closes C struct-tag `extern type`, `'\x1b'`, `&` vs `@` parse error, and array trailing comma. **0.26.5.183** closes drop C `const` on LET and `@` of `LET`/`CONST`. **0.26.5.181** closes `LET` write-forbid (bare name only). **0.26.5.180** closes parent-chain methods (`Child` → `Parent::m`). **0.26.5.179** closed `Type::m(p)` peel (`@x` not peeled). **0.26.5.178** closed `p[i]` peel and instance method on `^T`. **0.26.5.177** is a light refactor plus `examples/Shapes.mc`. **0.26.5.176** closed Oberon `p.x` auto-deref. **0.26.5.175** closed EXTENDS polish (`p^.x` / `as` / pointer·`REF`). **0.26.5.174** closes import-as-bind and `.mh` width tails. **0.26.5.173** closed width forms and moved the C prelude into generated `.h`. **0.26.4.172** closed `.mh` type completeness. **0.26.3.168** closed `parser.c` self-host. **0.26.1.158** closed unknown type names and dropped automatic `<stddef.h>`. **0.26.0.156** closed free-call soft-miss. No hidden RTTI / type tags / vtables on structs (Modula-2 + C stance).

EOS layout rules (0.24.3) remain in force. Arena growth is **pointer-stable** (linked chunks; no whole-slab `realloc`).

## DEFINE statement (0.26.5.188)

**Status:** **Done.** Design locked 12 September 2026; implemented and promoted 14 September 2026. Tests: `tests/test_define.mc`, `tests/test3_define.mc`.

**Syntax** (Wirth; rest of line is C, not TMod-c):

```
define-decl = [ "EXPORT" ] "DEFINE" identifier rest-of-line .
```

Example:

```
define CTRL_KEY(k) ((k) & 0x1f)
export define PUBLIC_FLAG 1
```

- Keyword `DEFINE` (case-insensitive). Optional `EXPORT`. Top-level only.
- Parse only the identifier. Copy identifier + rest of line (including `\` continuations) and emit C `#define identifier …`.
- Bind like an untyped `IMPORT`. `case CTRL_KEY('q'):` is a legal TMod-c name.
- No `EXPORT` → generated **`.c`** only. `EXPORT` → also **`.h`** and `export define Name complete` in **`.mh`**.
- Feature-test macros (`_GNU_SOURCE`) stay on the **Makefile** (`-D`).
- `#define` / `#if` pass-through stays unbound. `CONST` stays `static const` (item 19 demoted).

**Not done (later):** macro expansion; `#undef`; `#if` as TMod-c; leading feature-test-before-includes.

**0.27.1.216:** the grammar above is the 0.26.5.188 form. It is no longer accepted. `DEFINE` requires `=`. See [DEFINE equals (0.27.1.216)](#future-plan-define-equals-027).

## After DEFINE: `...` pass-through (`TOK_DOT_DOT_DOT`)

**Status:** **Done (0.26.7.190).** At least one named formal, then `, ...` last. Emit `, ...` in C. No TMod-c `va_list` / `va_arg`. Consume extras via FFI (`stdarg.h` + `vprintf` / `vsnprintf`). `PROGRAM` / `MODULE` lists reject `...`. `.mh` signatures may end `(string, ...)`. Tests: `tests/test_ellipsis.mc`, `tests/test3_ellipsis.mc`, `tests/test3_ellipsis_tail.mc`. Kilo: `define CTRL_KEY`; `editorSetStatusMessage(fmt: string, ...)`. Language Report §8.2; EBNF `formal-parameters`.

**Not this slice:** stdarg builtins; printf format checking; dedicated method/`...` tests.

## C-style `p[i]` on `^T` (0.26.7.191; named pointer alias **0.26.8.196**)

**Status:** **Done (0.26.7.191; 0.26.8.196).** If `p` is `^T` and `T` is not an array, `p[i]` has type `T` (C `*(p + i)`). Not `array_index.auto_deref` — that flag is pointer-to-array (`(*(p))[i]`, **0.26.5.178**).

**Written `^` first (0.26.8.196):** do **not** chase `resolved_type` before stripping a use-site pointer. `tokens: ^sds` with `type sds = ^char` → `tokens[0]` is **`sds`** (keep the name). `x: sds` (no extra `^`) still indexes the buffer (`char`). Copy-shell and clear `is_pointer`. Instance `p[i].method()` then follows ordinary `T` / named-owner rules; `REF` still auto-`&` → `Type__m(&p[i])`. Named alias (`pERow = ^ERow`) and bare `^T` both work. Unknown fields on `p[i]` are checked. Tests: `tests/test_ptr_index.mc`, `tests/test3_ptr_index.mc`, `tests/test_method_named_ptr.mc` (`p[0].get()`). Kilo: `E.row[at].updateRow()`. TSDSLib: `tokens[0].length()`. Language Report §5.3 / §6.2 / §8.3.

**Not this slice:** first formal `^Owner` as instance; changing `realloc` buffers into real `array[N]` types.

## Named type as method owner (0.26.8.196)

**Status:** **Done (0.26.8.196).** Instance iff the first formal’s **written** type name is the owner and that spelling is not `^Owner`. Layout after alias expansion does not count.

| First formal | Kind |
|--------------|------|
| `s: sds` (`type sds = ^char`) | Instance — `x.free()`, `sds::free(x)` |
| `s: ^sds` | Not instance (v1) — `sds::free(p)` only |
| `self: Point` / `self: ^Point` | Unchanged |

`x.free()` looks up `sds`, not `char`. `auto_deref` is use-site `^.is_pointer` only (`p: ^sds` peels; `x: sds` does not). `.mh` `instance`/`static` uses the same written-name test (`mh_first_formal_type_name`). Tests: `test_method_named_ptr`, `test3_method_named_ptr`. Language Report §8.3.

**Still deferred:** first formal `^Owner` as instance.

## Unreachable after `RETURN` / `BREAK` / `CONTINUE` (0.26.8.196)

**Status:** **Warning** (was fatal since 0.24.3). Parser still drops those statements from the AST. Needed so a C preprocessor line can follow `return` (`#endif` after `sdsTest` in TSDSLib). Language Report §7.1.

## TSDSLib 2.0 (`examples/sds/`)

**Status:** **Done (0.26.8.196).** TMod-c port of [antirez SDS 2.0](https://github.com/antirez/sds) by M. Scott Reynolds. Type-bound wrappers (`sds::new`, `x.cat`, `var s` on grow, `x.free()` nils). `sdscatvfmt` + `sds::catFmt`. Extra `sdsTest` cases (`splitLen` / `splitArgs` / `mapChars` / `join`). BSD notices retained; not affiliated with or endorsed by SDS or Redis. See `examples/sds/README.md`, `LICENSE`, `Changelog`.

## Several `.mc` inputs (0.26.7.192)

**Status:** **Done (0.26.7.192).** `tmodc` accepts more than one leftover non-option. Each unit is a fresh source buffer + arena + parser (`process_one_unit` in `src/modc.mc`). Nothing is shared. `error_at` still `exit(1)`; a non-zero generate or a missing file stops the batch.

Several inputs: **bare** `-C` / `-H` / `-M` (auto names from PROGRAM/MODULE) and optional **`-d`**. Explicit `-C file.c` / `-H` / `-M` / **`-b`** is an error. `-C` / `-H` / `-M` never consume a following `.mc`. Cap `MAX_MC_INPUTS` 512. Use `while i < mc_input_count` (not `FOR … TO count - 1`) so gcc `-Wstrict-overflow` stays quiet.

Not a dependency walker and not item **15**. `--print-imports` / `--deps` still later. Language Report / EBNF unchanged.

## After that: #11 architecture packs

**Status:** **Partial (0.26.8.194).** Widths, import-bind, `.mh` alias RHS, and in-tree packs are done. **Build-time defaults parked indefinitely (12 October 2026)** until another architecture can prove a compiler-build default. Unbound units stay `int` / `unsigned int` / `float` / `const char *` (`cint`).

**Done (item #11):** width forms; import-as-bind; `.mh` width tails; **`.mh` alias RHS** (`export type integer complete integer 64`); **packs** `tests/fixtures/lp64` and `ilp32` (lean `.h`; `-M` only — do not `tmodc -H` a pack header). Stand-in for `tmodc.lp64` / `tmodc.ilp32` until item **15** (`include/tmodc/` + search). Quoted `import integer from "fixtures/lp64.mh"`.

**Parked indefinitely (12 October 2026, same item):** `TMODC_ARCH` / compiler-build default selection, until another architecture can prove it. A unit that wants 64-bit `integer` still binds (`TYPE` or pack import).

**Not that slice:** first formal `^Owner` as instance; item **19** `CONST` codegen; `@n` as `const ^T`; `import integer from tmodc.lp64`.

## `COUNTOF` (0.26.9.198)

**Status:** **Done (0.26.9.198).** Replaces interim `LEN` (0.26.8.194). Keyword `COUNTOF` (case-insensitive). `len` is an ordinary identifier.

`countof(designator | type)` is the outermost element count of a **complete fixed array**. Type **`integer`**. A known bound folds, so `array[countof(a)]` is a constant bound and C emits `((integer)N)`. An unfolded designator falls back to `((integer)(sizeof(n) / sizeof((n)[0])))`.

Accepted: a fixed array designator, a type alias of one (`type Buf = array[4] of integer`), and a type operand (`countof(array[4] of integer)`). Nested `array[7] of array[3] of integer` yields **7**.

Rejected (`semantic_countof_value: operand must be a complete array`): pointers, scalars, `string`, and open arrays (`array_size == 0`, which is also how `array[0]` is spelled). Not string length. No VLAs.

Tests: `tests/test_countof.mc`, `tests/test3_countof.mc` (`countof(integer)`), `tests/test3_countof_ptr.mc`. `tests/test_len.mc` and `tests/test3_len.mc` are removed. EBNF: `countof-expression` in `docs/syntax-ebnf.md`. Language Report §10.2.

## LEN (C element count) (0.26.8.194)

**Status:** **Superseded (0.26.9.198)** by [`COUNTOF`](#countof-0269198). Was interim: `LEN(designator)` only, always the sizeof division.

`LEN(designator)` only (not a type). Type **`integer`**. C:

```c
((integer)(sizeof(n) / sizeof((n)[0])))
```

Same signed type as `SIZEOF`. Designator is written twice in C; `sizeof` does not evaluate it (except VLAs). Pointers/`string` were `sizeof(pointer)/1` under this interim form. Tests were `tests/test_len.mc` and `tests/test3_len.mc` (removed in 0.26.9.198).

## Future plan: loop-local `FOR` (JPL Rule 6)

**Status:** **Done.** Both forms **0.27.2.221**. End temporary **0.27.2.225**. Index type **0.27.3.227**. The 20 August 2026 sole-form lock was not taken. Existing `for i :=` loops were left in place. Spec in `docs/syntax-ebnf.md` and Language Report §7.1.

**Why:** JPL Power of Ten rule 6 wants the smallest scope. `=` declares that scope. `:=` keeps the Oberon/Pascal assignment to a predeclared variable.

**Syntax:**

```
for-statement =
    "FOR" identifier ( ":=" | [ ":" type-specifier ] "=" ) expression
        ( "TO" | "DOWNTO" ) expression
        [ "BY" const-expression ]
    "DO" { invariant-clause } statement-sequence "END" ;
```

```
for i := 0 to n do … end
for i = 0 to n do … end
for i: integer = 0 to n do … end
for i := n downto 0 by 1 do … end
```

**Semantics**

- `for i :=` assigns the `i` already in scope. After `end`, that variable has whatever value the generated C `for` left.
- `for i =` and `for i: integer =` / `for i: int =` declare `i` for the loop. It may shadow an outer `i`. After `end`, the outer variable is unchanged.
- On `for i =`, an omitted type is the type of the start expression (*0.27.3.227*). A numeric literal stays `integer`. An unknown start type stays `integer`. `for i: T =` uses `T`. `for i :=` uses the variable's type. A type is legal when C can step it with `++` or `--`: `integer`, `int`, `char`, `size_t`, `cardinal`, `byte`, an enumeration, or a pointer. `real`, `bool`, `string`, arrays, and structs are rejected. Both bounds use that test. An enumeration constant is typed `integer`, so `for i = Red to Blue` is an `integer` loop. `for i: integer :=` is a parse error.
- The body must not assign, `INC`, or `DEC` the control name. Passing that name as a `VAR` or `REF` actual is still accepted.
- Empty `TO` (`for i = 5 to 1`) does not enter the body.

**Codegen (0.27.2.225).** The declaring form emits the type on the C `for`. The end temporary has the index type (item **18**). The test is direct.

```c
{
    const integer __for_end_lN_cC = (end);
    for (integer i = start; i <= __for_end_lN_cC; i++) { … }
}
```

`:=` emits `for (i = start; …)` and types the temporary from the variable (`const size_t` when `i` is `size_t`). `BY` is still a numeric literal. `BY 0` is rewritten to step 1. A named constant after `BY` is also forced to 1.

`for c = 'A' to 'Z'` emits `char` for the index and the end temporary. `for s = n to n`, when `n` is `size_t`, emits `size_t`.

## Future plan: `BOUND` on `WHILE` / `REPEAT` / `LOOP` (JPL Rule 2)

**Status:** **Done (0.27.5.232).** Optional in the language. A later `--pot` may require it. `FOR` does not take `BOUND` (it already has `TO`/`DOWNTO`). The largest trusted value is 2,147,483,647. The counter is `cardinal`. See Language Report §7.1.

**Why:** Holzmann rule 2 — every loop has a tool-visible trip ceiling, except one identified non-terminating task loop. `INVARIANT` is a boolean, not a max count.

**Syntax** (`const-expression`, same family as `FOR` … `BY` / array bounds):

```
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

loop-statement =
    "LOOP"
        [ "BOUND" const-expression ]
        { invariant-clause }
        statement-sequence
    "END" ;
```

```
while p <> nil do
	bound 4096
	p := p^.next
end

repeat
	bound 8
	try_once
until done

loop
	bound 0
	wait_for_cmd
end
```

**Semantics**

- Bound is compile-time; not a runtime `n` that changes.
- Codegen: `cardinal __bound_l{line}_c{column}` and `assert(__bound < Nu)`. Reaching the bound aborts. It does not `break`.
- **`BOUND 0` only on `LOOP`:** the idle / task loop. Illegal on `WHILE` / `REPEAT`.
- Omitted `BOUND`: legal in ordinary TMod-c. `--pot` (later, not scheduled) may require a bound except one `loop bound 0` per task.
- `--assert-off` omits the counter. `--dbc-off` leaves it. `BOUND` is not a contract clause.

**Landed (0.27.5.232):** `Lexer.mc`, `statement.mc`, `semantic.mc`, `codegen_c.mc`, `src/c/node.h`, `src/c/node.c`. Tests: `tests/test_bound.mc`, `tests/test3_bound_while0.mc`, `tests/test3_bound_repeat0.mc`, `tests/test3_bound_neg.mc`, `tests/test3_bound_var.mc`.

## Drop `IS` (no type guards)

**Status:** Locked (31 August 2026). **Not implemented.** Lexer still reserves `IS` (`TOK_KEYWORD_IS`); **parser never uses it.** EBNF no longer lists `IS` (relational-op is `IN` only). Language Report §6.3: `IN` is planned set membership; `IS` is dropped.

Oberon `IS` is a runtime type test (`p is T`) — needs RTTI or a tag. TMod-c: **no vtables / no `IS` on structs.** Remove the keyword (lexer table, `TokenKind::string`, EBNF `relational-op` / `keyword`, report). `is` becomes a legal identifier.

**`IN`:** still reserved; unused as an operator. Keep — v1 **`SET OF` enum** membership (not a type guard). See [Future plan: SET OF enum](#future-plan-set-of-enum-wirth-bitset).

**When implementing:** small mechanical drop; any `test3` that used `IS` as a keyword should expect an identifier. Spec in `docs/syntax-ebnf.md` + Language Report. Not 0.26.x calm-path.

## Future plan: `SET OF` enum (Wirth bitset)

**Status:** Design locked (2 September 2026). **Not implemented.** After the current higher-priority list. Do not slip into 0.26.x. Spec in `docs/syntax-ebnf.md` + Language Report §5 / §6.3 when the bump starts (productions already drafted as *Planned*).

**Why:** `IN` is in the grammar for **set membership**, not type guards (`IS` is dropped). Compiler source wants named groups (`LOOP_KINDS`) and `kind in LOOP_KINDS` instead of `or` chains. This is Pascal/Modula-2 `SET OF`: a **bit vector** on a small ordinal, not Julia/Python `Set{T}` (hash table, heap, arbitrary `T`). Hash sets, if ever, are stdlib — not `IN`.

**v1 surface**

- Type: `SET OF E` where `E` is an **enum**. Every enumerator value is a distinct constant in **0 .. 63**. One `cardinal 64` / `uint64_t` mask.
- Constructor: Modula-2 **`{ a, b, c }`** — same braces as `array-literal`; semantic picks set vs array from the expected type / element types. Empty `{}` needs a type ascription.
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

**v1 rejects:** `SET OF integer` / `real` / `struct` / `string`; enumerator `= 1000` or more than 64 members; `SET OF char` (256 bits — later); `FOR x IN s`; `CARD`; hash `Set`. Optional later: `<=` subset, `XOR` symmetric difference, `NOT` complement in `E`, Ada-style `x in (A, B)` sugar.

**When implementing:** keyword `SET`; `set-type` in `type-expression` / `type-specifier`; `IN` in the relational parser (token exists); `{ … }` set vs array in semantic; operator types; tests (`test_*` membership/algebra, `test3_*` bad base type / ordinal out of 0..63). Version bump (not a quiet 0.26.x patch). May land after `IS` drop so `IN` is the only leftover relational keyword.

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

## Future plan: `.mh` array type-specs

**Status:** **Done (0.27.1.217).** Noted 3 October 2026 during the `codegen_common.mc` port (**0.26.9.199**). `@format` stays 1. A line with no array suffix still parses. An older compiler rejects a new array line.

An anonymous array used to be written as `?`, because the array node has no name. The writer and the reader now spell it. One `^` per type-specifier stays the rule (§5.3).

Suffix form when the element is a named or `opaque` leaf, the array itself is not a pointer, and the const flags match: `Node[]`, `^Node[]`, `const ^char[]`, `integer 32[4]`, `^opaque[]`. Open is `[]`. A folded bound is `[N]`. An unfolded `size_expr` is a fatal writer error.

Keyword form otherwise: `const array[] of Node`, `array[] of const Node`, `^array[] of Node`, `array[] of integer[4]`.

A named formal such as `s: Buf` still emits the name. Fields, results, and an alias RHS use the same spelling. Naming an inner pointer (`type pNode = ^Node`, formal `^pNode`) still exports as `^pNode`.

One limitation: a `CONST` formal of `array[] of Node` and a formal whose type is `const array[] of Node` print as the same text. A leading `const` that is not followed by `^` is `CONST` mode. The slice shapes (`T[]`, `^T[]`, `T[N]`, `^array[] of T`) do not hit that hole.

Tests: `tests/test_mh_array.mc` writes the `.mh`. `tests/test2_mh_array.mc` imports it and checks `countof(r.cells) == 4`. The user reported that round-trip compiles after `src/codegen/codegen_mh.mc` was regenerated. The hidden length on a slice formal landed in [slice formals (0.27.1.219)](#future-plan-slice-formals-027). The module `main` in that test uses `argv: ^pchar`, so the operating system entry does not grow a length parameter.

## Future plan: slice formals (0.27)

**Status:** **Done (0.27.1.219).** Proposed 5 October 2026. `countof` on a complete fixed array stays as shipped in **0.26.9.198**. The hidden length is this build.

An open-array **formal** is a slice. The source parameter list does not gain a length argument. The generated C keeps the pointer and inserts an `integer` count immediately after it. `countof` on that formal reads the inserted word.

```mod-c
function show(s: char[]): integer
begin
	return countof(s)
end
```

```c
integer show(char *s, integer s_length)
{
    return s_length;
}
```

`array[] of char` is the same formal. The C name `s_length` is only an illustration. It is not a TMod-c identifier. It must not collide with a real parameter in the generated list.

**What gets the extra word**

- `s: char[]`, `s: array[] of integer`, `s: ^char[]`, and a type alias of an open array (`type Buf = char[]`, then `s: Buf`). One `resolved_type` chase, the same depth `countof` already uses for a fixed alias. `^char[]` is an array of pointers. `^pchar` after `type pchar = ^char` is one pointer and is not a slice.
- Each open-array formal gets its own count, placed immediately after that pointer. `f(a: char[], n: integer, b: integer[])` lowers to `f(char *a, integer a_length, integer n, integer *b, integer b_length)`. A slice that is not last still has its count before the next source formal. The count is before `...` when the slice is the last named formal.

**What does not**

- `array[N] of T` and `T[N]`. The bound is the type. `countof` already folds it. The formal stays one C parameter.
- `^T`, including `^pchar`. One pointer. A C function that is a pointer in C is declared `^char`, not `char[]`. Declaring it `char[]` would pass an extra argument the C definition does not take.
- `^array[] of T` and `^array[N] of T`. The pointer is on the array (`T (*p)[]`).
- A field `buf: array[] of char`. That stays a C flexible array member (`char buf[]`). `countof` of that field still has no stored length.
- `a[i..j]` view syntax. Not this plan. `TOK_DOT_DOT` stays unparsed.

**Calls.** The compiler inserts the count. The source call does not write it.

- Actual is a fixed array: pass the folded bound. `var buf: array[32] of char` then `show(buf)` emits `show(buf, ((integer)32))`.
- Actual is a slice formal (bare name, parentheses only): pass that formal's hidden integer through.
- Actual of a `VAR` or `REF` open-array formal may be written `@array`. Peel that one `@` and take the count from the operand. A plain `@` in front of a non-`VAR` / non-`REF` `char[]` formal is still an error.
- Actual is `^char`, `string`, a scalar, a local open array, or any value with no element count: error `semantic_resolve_call: open_array actual has no element count`. Do not call `strlen`.

**`countof`.** On a slice formal the result is `integer` and is not a constant. `array[countof(s)]` stays illegal when `s` is a slice. On a complete fixed array, `countof` is unchanged (`((integer)N)`). The unfolded `sizeof(s)/sizeof(s[0])` fallback must not be used for a slice: after decay, `sizeof(s)` is the pointer width.

**`main`.** Hosted `main` stays `int main(int argc, char **argv)`, or `(void)` when the program has no parameters. It does not copy the program parameter list. When the program has parameters, the wrapper emits `(void)argc;` and `(void)argv;` before the call. `program kilo(args: ^char[])` lowers the program function to `(char **args, integer args_length)` and the wrapper calls `kilo(argv, argc)`. `countof(args)` is `argc`. That count includes `args[0]` and excludes the `NULL` at `argv[argc]`. `program Demo(argc: integer, argv: ^char[])` lowers to `(integer argc, char **argv, integer argv_length)` and the wrapper calls `Demo(argc, argv, argc)`. `argv: ^pchar` is not a slice, so the call stays `Demo(argc, argv)`. A module `function main` is emitted as written. `argv: ^char[]` there grows `argv_length`, and the operating system does not pass it. Use `^pchar`. Do not use `countof` on that formal.

**Migration.** Done for the compiler and Kilo. `src/modc.mc` and `examples/kilo/kilo.mc` are `program …(args: ^char[])`, and `countof(args)` is the argument count. `examples/ComputePi.mc` still writes `(argc: integer, argv: ^char[])`. The wrapper calls it as `ComputePi(argc, argv, argc)`. `sds::freeSplitRes` was `tokens: sds[]` and is now `tokens: ^sds`, so that formal stays one pointer beside the explicit `count`. `tests/test_mh_array.mc` changed its module `main` from `argv: ^char[]` to `argv: ^pchar`. Generated `.h` signatures of open-array formals gain the length. A call through a function pointer or a callable field does not insert the length yet. A wrong C arity fails when that C is compiled.

**Where the work is.** Landed. Parser: none. `src/node.h`: `call.slice_arg` (parallel to the arguments; `0` none, `-2` pass the actual's `_length`, `>0` folded count) and `call.receiver_slice`. `src/semantic/semantic.mc`: the open-slice predicate, the length-name collision, `countof` of a slice without folding, and the call stamp. An imported formal is resolved for the slice test only when its name is already a type in scope, so an unimported `^DynBuf` is not a fatal unknown type. `src/codegen/codegen_common.mc`: `codegen_type_is_open_slice`, `emit_param_list`, the `NODE_CALL` arm, and `codegen_common_countof_expr`. `src/codegen/codegen_c.mc`: `codegen_c_emit_program_call`. Tests: `tests/test_slice.mc`, `tests/test_slice_argv.mc`, `tests/test3_slice_ptr.mc`. The user reported that self-host succeeds and that gcc, clang, and tcc each pass.

**`.mh`.** Same-unit calls do not need it. The export spells `[]` as of **0.27.1.217** ([array type-specs](#future-plan-mh-array-type-specs)). No new export flag. Both sides insert the length from the type. A `?` from an older compiler cannot.

## Future plan: DEFINE equals (0.27)

**Status:** **Done (0.27.1.216).** Proposed 15 October 2026. Promoted on branch **`TMod-c_0.27`**. The 0.26.5.188 rest-of-line form is a parse error.

The `=` matches `CONST`, `TYPE`, and `LET`. It is TMod-c punctuation. Generated C omits it.

```
define-decl     = [ "EXPORT" ] "DEFINE" identifier [ "(" define-params ")" ] "=" [ replacement-list ] ;
define-params   = "..."
                | identifier { "," identifier } [ "," "..." ] ;
```

```mod-c
define ANSWER = 42
define CTRL_KEY(k) = ((k) & 0x1f)
export define PUBLIC_FLAG = 1
export define SDS_HDR_VAR(T, s) = struct sdshdr##T *sh = (void*)((s)-(sizeof(struct sdshdr##T)));
```

```c
#define ANSWER 42
#define CTRL_KEY(k) ((k) & 0x1f)
#define PUBLIC_FLAG 1
#define SDS_HDR_VAR(T, s) struct sdshdr##T *sh = (void*)((s)-(sizeof(struct sdshdr##T)));
```

- A `(` with no space after the identifier selects the function-like arm. Parameters are C macro names, plus `...`. They are not procedure formals and have no types.
- The replacement list is C text from after `=` through the newline, including `\` continuations. It may be empty. Do not tokenize it as TMod-c. `#`, `##`, and a later `=` belong to that text. In `SDS_HDR_VAR`, the separator is the `=` after `)`.
- Top-level only. Bind like an untyped `IMPORT`. `EXPORT` still writes the `#define` to the `.h` and `export define Name complete` to the `.mh`. The `.mh` record does not gain a body.
- A raw `#define` or `#if` line stays pass-through and unbound. Feature-test macros stay `-D` on the Makefile.

- If the replacement is non-empty and does not already start with whitespace, one space is inserted. `define ANSWER=42` emits `#define ANSWER 42`. Spaces the author wrote are kept. `define INIT = = 0` emits `#define INIT = 0`.

**Migration.** Done. `tests/test_define.mc`, `examples/kilo/kilo.mc`, `examples/kilo/read_key.mc`, and `examples/sds/Tsds.mc` use `=`.

**Where the work is.** Landed in `TParser::parse_define` in `src/parser_main.mc`. After the identifier, a source `(` with no space copies the parameter span through the matching `)`. `=` is required either way. The name, that span when present, and the replacement go into one arena buffer. `codegen_common_define` is unchanged. Tests: `tests/test_define.mc` (spacing around `=`, empty replacement, `##`, a body `=` reached through a raw `#define INIT = 0`, variadic `...`), `tests/test3_define.mc` (missing name), `tests/test3_define_eq.mc` (missing `=`). The user reported that gcc, clang, and tcc each pass.

## 7b cancelled — no startup auto-init

**Status:** **Won’t do** (31 August 2026). Item **7a** (module entry as an importable symbol) stays.

Do **not** generate calls of imported `MODULE` bodies from `PROGRAM` / `main` (Modula-2 / Delphi style). Hidden init is extra control flow (JPL rule 1) and a place to hide `malloc` (rule 3). Authors **call** the bound module entry explicitly when they want it. Optional module `BEGIN`…`END` remains a procedure the programmer invokes — not a constructor the compiler schedules.

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

## DbC resolve (REQUIRE / ENSURE)

**Done** in `semantic_analyze_block_body` — `requires[]` / `ensures[]` go through `semantic_resolve_expr` (same as loop `INVARIANT` and `ASSERT`). `REF`/`VAR` formals load as in the rest of the language.

Still not a nil-check of a `REF T`: `n` is the object. Nil-check `^T` formals and pointer **fields**; check `p <> nil` **before** `foo(p^)`. Remaining polish (not planned): side-effect-free contract lint; optional `--pot` “two assertions per routine” warn.

## Recent Accomplishments (30 October 2026 — 0.27.5.232 / loop BOUND)

### Loop `BOUND` **Done**

- Optional on `WHILE`, `REPEAT`, and `LOOP`, before any `INVARIANT`. One const-expression. `FOR` does not take it. An omitted bound leaves the loop as it is. A second `BOUND` is a parse error.
- The largest trusted value is 2,147,483,647. A larger literal is cut to 32 bits before the sign check. A negative value is an error. `0` is legal only on `LOOP` and emits no counter.
- A positive bound counts body entries with `cardinal __bound_l{line}_c{column}`. The check is `assert(__bound < Nu)` at the start of the body, then the counter increments. `--assert-off` omits the counter. `--dbc-off` leaves it.
- Tests: `tests/test_bound.mc`, `tests/test3_bound_while0.mc`, `tests/test3_bound_repeat0.mc`, `tests/test3_bound_neg.mc`, `tests/test3_bound_var.mc`.
- **19 remainder** stays open. `const LIM = 4` then `bound LIM` still emits an unused `static const`.
- `src/c/version.h` is `0.27.5.232`. `Makefile` `VERSION` is **0.27.5**. Branch **`main`**.

The user reported that all tests pass and that gcc, clang, and tcc each pass.

## Recent Accomplishments (28 October 2026 — 0.27.4.230 / VAR REF designator)

### `VAR` / `REF` designator **Done**

- A `VAR` or `REF` formal that codegen addresses requires a designator: a name, or that name through a field, an index, or a postfix `^`. Parentheses are skipped.
- The written formal's `is_pointer` decides the address, the same test as codegen. `type Object = ^TObject` keeps `is_pointer` false, so `var self: Object` and `ref self: Object` both require a variable. A written `ref p: ^T` passes the pointer value.
- `self as Object` is rejected. A designator with `upcast_ptr` set is rejected. That call is the one that lowered to `&&`.
- `@` of a designator is accepted, including `(@p[1]).bump()` in `tests/test_ptr_index.mc`.
- A `CONST` formal and a bare formal stay by value. A child variable passed to `ref Parent` stays legal.
- Tests: `tests/test3_byref_cast.mc`, `tests/test3_byref_ref.mc`. `tests/Nodes.mc` is renamed `tests/test_Nodes.mc`.
- `src/c/version.h` is `0.27.4.230`. `Makefile` `VERSION` is **0.27.4**. Branch **`main`**.

The user reported that gcc, clang, and tcc each pass.

## Recent Accomplishments (27 October 2026 — 0.27.4.229 / pointer alias and mh free)

### Pointer-alias `as` and `.mh` free **Done**

- `semantic_type_is_pointer` reads the type and one `resolved_type` step. An explicit `as` and `semantic_maybe_upcast` set `upcast_ptr` from that. `type Node = ^TNode` emits `&((*(expr)).base)`.
- `mh_module_free` frees each export's `name` and `method_owner` and sets them to nil. Those two are `mh_strdup_n` copies. The other name pointers remain inside `source`.
- Commit `7e157f7`. `tests/Nodes.mc` showed the cast. **0.27.4.230** renames it to `tests/test_Nodes.mc`.
- `src/c/version.h` at that commit is `0.27.4.229`. `Makefile` `VERSION` is **0.27.4**. Branch **`main`**. No suite result is in the commit message.

## Recent Accomplishments (26 October 2026 — 0.27.4.228 / anonymous nested UNION)

### Anonymous nested `UNION` **Done**

- A field written `union` … `end` inside a `struct` or a named `union` has no name. Its members are in scope on the enclosing aggregate (`box.tag`, `box.a.n`, `box.b`).
- C is an unnamed `union { ... };`. Named `type T = union` is unchanged and still has no `EXTENDS`.
- A promoted name that clashes with the parent, a sibling promoted member, or an `EXTENDS` ancestor is an error. `base` stays reserved on `EXTENDS` types. Nested anonymous unions are allowed. A nested struct stays a named type.
- `.mh` spells the field `union (a: Arm, b: integer)` inside the field list. `@format` stays 1. An older reader rejects that line. The word `union` followed by `:` is a field name.
- Tests: `tests/test_anon_union.mc`, `tests/test3_anon_union.mc`. `tests/test_union.mc` and `tests/test3_union.mc` stay.
- `src/c/node.c` and `src/c/node.h` stay hand-written. This form is what a later port of `Node` needs. The port is not started.
- `src/c/version.h` is `0.27.4.228`. `Makefile` `VERSION` is **0.27.4**. Branch **`main`**.

The user reported `make CC=gcc clean-all all test-all selfhost bootstrap promote` clean on gcc, clang, and tcc. Since the 20 October report: **0.27.2.223** moved compiler `.mc` to `src/tmodc/` (package `tmodc`). **0.27.2.225** typed the `FOR` end temporary from the index. **0.27.2.226** added the `tmodc.lib` wrappers. **0.27.3.227** took an omitted `for i =` type from the start expression. Session archive: `docs/grok_report-20261026-1932.md`.

## Recent Accomplishments (26 October 2026 — 0.27.3.227 / FOR index type)

### `FOR` index type **Done**

- On `for i =`, an omitted type is the type of the start expression. A numeric literal stays `integer`. An unknown start stays `integer`. `for i: T =` uses `T`. `for i :=` uses the variable's type.
- The declaring form accepts `integer`, `int`, `char`, `size_t`, `cardinal`, `byte`, an enumeration, or a pointer. It rejects `real`, `bool`, `string`, arrays, and structs. Both bounds use that test.
- An enumeration constant stays `integer`. `for e: Color = Red to Blue` is the enumeration loop.
- The end temporary already follows this type (item **18**, **0.27.2.225**).
- Tests: `tests/test_for.mc`, `tests/test3_for_real.mc`. `tests/test3_for_cardinal.mc` is removed. `tests/test3_for_assign.mc` and `tests/test3_for_mix.mc` stay.
- `src/c/version.h` is `0.27.3.227`. `Makefile` `VERSION` is **0.27.3**. Branch **`main`**.

The user reported `make CC=gcc clean-all all test-all selfhost bootstrap promote` clean on gcc, clang, and tcc.

## Recent Accomplishments (20 October 2026 — 0.27.2.222 / C tree)

### Generated C under `src/c` **Done**

- `.mc` and `.mh` stay under `src/` and its package directories (`src/parser/`, `src/codegen/`, `src/lexer/`, `src/mh/`, `src/semantic/`). Generated `.c` and `.h`, plus hand-written `node.c`, `node.h`, and Makefile-written `version.h`, live under `src/c/` with the same relative path. `src/parser/parser_main.mc` lowers to `src/c/parser/parser_main.c`.
- Those relative `#include` paths still resolve. `#include "../arena.h"` from `src/c/parser/` finds `src/c/arena.h`. `#include "parser/parser_common.h"` from `src/c/modc.c` finds `src/c/parser/parser_common.h`.
- `-d` uses the basename only. A package unit is regenerated with an explicit `-C` and `-H` (`src/c/parser/parser_main.c`, `src/c/parser/parser_main.h`). A flat `src/*.mc` batch can use `-d src/c`.
- `-M` is the only flag that writes an `.mh`. `-C` writes the `.c` and the companion `.h`. With no `-d` and no explicit `-M` path, the `.mh` is written beside the `.mc`.
- `make`, `selfhost`, `bootstrap`, and `promote` compile and copy through `src/c`. Objects stay `build/c/parser/parser_main.o`. `make version` writes `src/c/version.h`. `src/build.number` stays in `src/`.
- A `HEADER` unit still has no `.c`. Promote removes a stale `.c` under `src/c/` when the verified output has none, and it still copies `src/c/tmodc.h`.
- `src/c/version.h` is `0.27.2.222`. `Makefile` `VERSION` is **0.27.2**. This commit is on **`main`**. `TMod-c_0.27` is still at **0.27.1.216**.

The user reported `make CC=gcc clean-all all test-all selfhost bootstrap promote` clean on gcc, clang, and tcc. See `docs/grok_report-20261020-222.md`.

## Recent Accomplishments (19 October 2026 — 0.27.2.221 / dual FOR)

### Dual `FOR` **Done**

- `for i :=` assigns a predeclared variable. `for i =` and `for i: integer =` / `for i: int =` declare a loop-scoped `integer`. The index may shadow an outer name. After `end`, that outer name is unchanged.
- `cardinal` is rejected as the index type. A `cardinal` bound expression is accepted. `for i: integer :=` is a parse error.
- The body must not assign, `INC`, or `DEC` the control name. A `VAR` or `REF` actual of that name is still accepted.
- The end temporary stays `const long long` (item **18**). `BY` is still a numeric literal. `BY 0` is rewritten to step 1.
- Tests: `tests/test_for.mc`, `tests/test3_for_assign.mc`, `tests/test3_for_cardinal.mc`, `tests/test3_for_mix.mc`.
- `src/version.h` is `0.27.2.221`. `Makefile` `VERSION` is **0.27.2**. Branch **`TMod-c_0.27`**.

The user reported `make CC=gcc clean-all all test-all selfhost bootstrap promote` clean on gcc, clang, and tcc. See `docs/grok_report-20261019-221.md`.

## Recent Accomplishments (19 October 2026 — 0.27.1.219 / slice formals)

### Slice formals **Done**

- An open-array formal (`char[]`, `array[] of T`, `^char[]`, a one-step alias such as `type Buf = char[]`) lowers to the pointer plus a hidden `integer` `{name}_length`. The length is not a TMod-c identifier. A parameter that already uses that spelling is a semantic error.
- Fixed `array[N]` / `T[N]`, `^T` (including `^pchar`), and `^array[] of T` / `^array[N] of T` stay one C parameter. A field `buf: array[] of char` stays a flexible array member.
- The call inserts the count. A fixed array passes `((integer)N)`. A slice formal passes its `_length`. A `VAR` / `REF` actual written `@array` counts the operand. Anything else with no count is `semantic_resolve_call: open_array actual has no element count`.
- `countof` on a slice formal emits `{name}_length`. It is not a constant. `array[countof(s)]` stays illegal. Fixed-array `countof` is unchanged.
- Hosted `main` stays `int main(int argc, char **argv)`. `program modc(args: ^char[])` and `program kilo(args: ^char[])` are called as `name(argv, argc)`. `countof(args)` is `argc`. `examples/ComputePi.mc` still uses `(argc, argv: ^char[])`, which the wrapper calls as `ComputePi(argc, argv, argc)`.
- A module `function main(…, argv: ^char[])` would grow `argv_length` that the operating system does not pass. `tests/test_mh_array.mc` uses `argv: ^pchar`. `sds::freeSplitRes` takes `^sds` beside an explicit count.
- A call through a function pointer or a callable field does not insert the length yet.
- Tests: `tests/test_slice.mc`, `tests/test_slice_argv.mc`, `tests/test3_slice_ptr.mc`. `tests/test2_var_ref.mc` covers `@data` on a `REF` / `VAR` open array.
- `src/version.h` is `0.27.1.219`. `Makefile` `VERSION` is **0.27.1**. Branch **`TMod-c_0.27`**.

The user reported that self-host succeeds and that gcc, clang, and tcc each pass. See `docs/grok_report-20261019-1430.md`.

**0.27.1.218** (checked in as `ddfabeb`) moves `Lexer.mc` to `src/lexer/`, `mh_*` to `src/mh/`, the parser units to `src/parser/`, and `semantic.mc` to `src/semantic/`. The changelog records that move. This report is the first session note for it.

Still later, not this build: a function-pointer or callable-field call does not insert the hidden length. `BOUND`, drop `IS`, `SET OF`, shebang scripts, `ELSE CASE`, and cyclic `IMPORT` stay later.

## Recent Accomplishments (16 October 2026 — 0.27.1.217 / .mh array type-specs)

### `.mh` array type-specs **Done**

- An anonymous array on an export round-trips. `@format` stays 1. A line with no array suffix still parses. An older compiler rejects a new array line.
- Suffix form when the element is a named or `opaque` leaf, the array is not a pointer, and the const flags match: `Node[]`, `^Node[]`, `const ^char[]`, `integer 32[4]`, `^opaque[]`. Open is `[]`. A folded bound is `[N]`.
- Keyword form otherwise: `const array[] of Node`, `array[] of const Node`, `^array[] of Node`, `array[] of integer[4]`.
- A named formal (`s: Buf`) still emits the name. A `CONST` formal of `array[] of Node` prints the same text as a formal of type `const array[] of Node`. The slice shapes do not hit that hole.
- Tests: `tests/test_mh_array.mc`, `tests/test2_mh_array.mc` (`countof(r.cells) == 4`). The user reported the round-trip compiles after regenerating `src/codegen/codegen_mh.mc`.
- `src/version.h` is `0.27.1.217`. `Makefile` `VERSION` is **0.27.1**. Branch **`TMod-c_0.27`**.

The hidden length landed in **0.27.1.219** (focus item 16 / TODO 10c). Package directories landed in **0.27.1.218**.

## Recent Accomplishments (16 October 2026 — 0.27.1.216 / DEFINE equals)

### `DEFINE` with `=` **Done**

- `define Name = replacement` and `define Name(params) = replacement`. The `=` is required TMod-c punctuation and is omitted from `#define`. The 0.26.5.188 rest-of-line form is a parse error.
- A `(` with no space after the name selects the function-like arm. The replacement is C text, including `\`, `#`, `##`, and a later `=`. It may be empty. `define INIT = = 0` emits `#define INIT = 0`.
- A missing space before a non-whitespace replacement is inserted, so `define ANSWER=42` emits `#define ANSWER 42`. Spaces the author wrote are kept.
- A raw `#define` or `#if` line stays pass-through and unbound. `#define INIT = 0` keeps the `=`.
- Tests: `tests/test_define.mc` (spacing around `=`, empty body, `##`, variadic, raw `#define INIT = 0`). `tests/test3_define.mc` (missing name). `tests/test3_define_eq.mc` (missing `=`).
- Examples: `examples/kilo/kilo.mc`, `examples/kilo/read_key.mc`, `examples/sds/Tsds.mc`.
- The user reported that `tests/test_define.mc` passes and that gcc, clang, and tcc each pass.

User promoted **0.27.1.216**. `src/version.h` is `0.27.1.216`. `Makefile` `VERSION` is **0.27.1**. Branch **`TMod-c_0.27`**. Development tree is **TMod-c-dev**. Closed branch `mod-c_0.26` stays at **0.26.12.213**. See `docs/grok_report-20261016-1455.md`.

`.mh` array type-specs landed in **0.27.1.217**. The hidden length landed in **0.27.1.219**. Package directories landed in **0.27.1.218**.

## Recent Accomplishments (15 October 2026 — 0.26.12.213 / subdirectory build)

### `src/` tree **Done**

- `make`, `selfhost`, `bootstrap`, and `promote` keep the path under `src/`. `src/codegen/foo.c` is `build/c/codegen/foo.o`. Each directory that holds a `.h` is an `-I` root. The self-host mirror is searched before `-Isrc`.
- The six codegen units moved to `src/codegen/` as `module codegen.<unit>`. The package root peels to `src/`, so `from arena` opens `src/arena.mh`. No leftover `src/codegen_*.mc`.

### Several inputs, own source path **Done**

- `process_one_unit` parsed `input_file` and still passed `options.mc_input_file` (the first `.mc`) to semantic analysis, `context.source_path`, and `resolve_output_path`.
- A later prefixed unit failed the `<package>/<unit>.mc` peel and looked for `.mh` files beside the first file. `tmodc src/codegen/*.mc -a` asked for `src/codegen/arena.mh`. One file was already correct.
- The six sites in `src/modc.mc` now pass `input_file`. Flat `src/*.mc` hid the bug: every dirname is `src/`.

### Docs the same day

- Language Report §4.2: a `const-expression` is an integer literal, an enumeration constant, a character constant, or arithmetic on those, plus the ISO C §6.6 examples. A `const` object is not a constant expression. `tcc` rejects it as a static initializer; gcc and clang accept that extra form.
- **`DEFINE` with `=`** is planned for **0.27** and is not implemented. `docs/syntax-ebnf.md` has the production. **0.26.5.188** still parses the rest-of-line form.

User promoted **0.26.12.213**. `src/version.h` is `0.26.12.213`. `Makefile` `VERSION` stays `0.26.12`. Last planned build on `mod-c_0.26`. See `docs/grok_report-20261015-1939.md`.

## Recent Accomplishments (14 October 2026 — 0.26.12.212 / package path and type call)

### Package path **Done**

- A `PROGRAM`, `MODULE`, or `HEADER` name may be a qualident. The last identifier is the unit name and the C function. The prefix is the package path, with no trailing dot. `module tmodc.lib.String()` is unit `String`. The `end` tag repeats that unit name.
- The source file is the directory form `tmodc/lib/String.mc`. The default output stem is the source filename. The unit's own `#include` and header guard use the `.h` basename (`"String.h"`, `MODC_MODULE_String_H`).
- An unquoted import has one candidate: `<root>/<dots as slashes>.mh`. The flat filename is not tried. A quoted path is the written file. A quote that does not end in `.mh` is a C `#include`.
- The root peels only when the source path is the directory form of the declared qualident. The root is the directory above the first package component. A unit with no prefix uses the directory that contains the source, so `from fixtures.minimod` in `tests/` still finds `tests/fixtures/minimod.mh`.
- The `#include` of that module is the `.mh` path with `.h`, relative to the compiling `.mc`. `tests/tmodc/tests/test_String.mc` includes `"../lib/String.h"`.
- Bootstrap stage 5 writes `build/bootstrap-verify/<stem>.c` so the guard matches stage 1. A `*.regen.h` output name would change the guard.
- The 13 October flat-then-directory lock was dropped the same day, before it was implemented.

### Type call `Ident()` → `Ident::Ident` **Done**

- A free call whose name is a declared type is `Ident::Ident` when that function is in scope. Struct, union, enum, alias, method type, and `type Handle = opaque` all qualify.
- Prelude names (`integer` and the rest of the prelude) have no type declaration and stay non-callable. The keyword `opaque` is not a symbol, so `opaque(...)` and `opaque::opaque` are rejected. `Handle(...)` is the named-opaque case and is allowed.
- `type Alias = Point` calls `Alias::Alias`, not `Point::Point`. The lookup does not walk `EXTENDS`. C is `Ident__Ident`. Another unit imports `Ident::Ident`. A free function cannot share the ordinary name `Ident` with the type.
- Tests: `tests/test_struct_ctor.mc`, `tests/test_type_ctor.mc`, `tests/test3_struct_ctor.mc`, `tests/test3_opaque_ctor.mc`. Language Report §3.1.1 and §8.3. EBNF `module-name = qualident`.
- User promoted **0.26.12.212**. Stem **0.26.12**. Branch **`mod-c_0.26`**. gcc, clang, and tcc: **test-all**, **selfhost**, **bootstrap**, **promote**.

## Recent Accomplishments (13 October 2026 — 0.26.11.208 / HEADER unit)

### `HEADER` unit **Done**

- A compilation unit may be `header Name`, then a declaration sequence, then `END`. No parameter list and no return type. `header Name()` is an error.
- `BEGIN` is an error. The parser rejects a unit body. Semantic analysis rejects a procedure or function body before that body is walked. `EXTERN`, `FORWARD`, and a body-less procedure stay prototypes.
- `codegen_c` leaves the buffer empty. `generate_from_ast` writes a file only when `out_buffer.used > 0`. `-C` still writes the companion `.h` and, when there is an export, the `.mh`. The `.h` has no unit prototype. The `.mh` keeps `@module` and does not emit a unit-entry export.
- `src/tmodc.mc` is that unit. `src/tmodc.h` and `src/tmodc.mh` are generated. `node.c` / `node.h` stay hand-written C.
- Bootstrap removes the `.c` path before each `-C`. Both `.c` files absent is agreement. One side present is an error. Promote copies a `.c` only when it exists, and removes a stale `src/*.c` when the verified output has none.
- Tests: `tests/test2_header.mc`, `tests/test3_header.mc`. Language Report §3.1. EBNF `header-unit`.
- User promoted **0.26.11.208**. Stem **0.26.11**. Branch **`mod-c_0.26`**.

## Recent Accomplishments (12 October 2026 — 0.26.10.206 / at and as)

### `@` binds tighter than `as` **Done**

- `@e as T` is `(@e) as T`. The operand of `@` is a postfix. `(@e) as T` stays legal.
- `as` stays tighter than `&` and the arithmetic operators: `exp & 1 as cardinal` is `exp & (1 as cardinal)`. Other prefixes still wrap the cast: `-n as integer` is `-(n as integer)`, and `^p as T` is `^(p as T)`.
- Parser: `parse_unary` on `@` calls `parse_postfix`, then an optional `as`. Other prefixes still call `parse_unary`. EBNF adds `"@" postfix-expression [ "AS" type-specifier ]`. `prefix-op` no longer includes `@`.
- Language Report §6.3. Motivating source was `(@imp^.import_stmt.items) as ppvoid` in `src/statement.mc`. The parentheses stay legal.

### Same-line `FOR` temporary **Done** (same promote)

- Each `FOR` already has its own C block, so sibling loops on one line compile. A nested `FOR` on the same line reused `__for_end_l` plus the line. clang and tcc warn under `-Wshadow`. gcc's default `CFLAGS` omit `-Wshadow`, and the test recipe discards stderr, so `make test` stayed green.
- The name is `__for_end_l{line}_c{column}` (`"%d_c%d"` at both `snprintf` sites in `codegen_c_for_stmt`). Test: `tests/test_for.mc`, nested one-liner, indexes `i` and `j`, `nested == 6`.
- Item **18** stays open: the end temporary is still `long long`. A valued `return` still uses `__ret_l` plus the line only. Two returns on one line would redefine that name. Not changed.

### Kilo status bar

- `as` binds tighter than `? :`, so a cast on the then arm covers only that arm. `filetype` is `pchar` (`^char`). A string literal has type `string`. Those are different types in `? :`, as are `const ^char`.
- Kilo now writes `E.filename as string` and `E.syntax.filetype as string`. `"no filetype" as pchar` on the else arm also type-checks. No checker change. Language Report §6.3 records the string-arm rule as a clarification of **0.26.10.203**.

### Verification

- User typed the parser, the EBNF, the `FOR` name, and the Kilo casts. User reported `make all` (compiler, string lib, examples) after the casts. Promoted **0.26.10.206**. Stem stays **0.26.10**. See `docs/grok_report-20261012-1618.md`.

## Recent Accomplishments (12 October 2026 — 0.26.10.204 / open-array alias formals)

### Named open-array alias formals **Done**

- `VAR` / `REF` of a named open-array alias (`type array_of_integer = integer[]`) decays like a written `integer[]`: C element pointer, the call passes the array, the body indexes `arr[i]`.
- File-local `codegen_param_array_view` reads one `resolved_type` step when that step is an array, has an element type, and is not a pointer. A local holds that view. The use type's `is_array` flag stays clear, so `array_of_integer::fill(self: array_of_integer)` stays an instance method.
- `semantic_method_is_instance` compares the written name and does not follow `resolved_type`. `pTType = ^TType` stays a different owner from `TType` and from a written `^TType`.
- A bare `arr: array_of_integer` stays the typedef spelling. A fixed-array alias takes the same decay path. No hidden length. That remains the **0.27** slice plan.
- **Tests:** `tests/test_var_ref.mc` (`IncrementAll` on the alias, `IncrementAllWritten` on `integer[]`). `tests/test2_var_ref.mc` stays an `-a` dump and still writes `@data`. `codegen_common.mh` has no new export.
- **Verification:** user typed the change. Tests green on **gcc**, **clang**, and **tcc** through **make test-all** / **selfhost** / **bootstrap** / **promote**. Build **204**. Stem stays **0.26.10**.

## Recent Accomplishments (12 October 2026 — 0.26.10.203 / 21a-ternary)

### Ternary typing **Done**

- `cond ? a : b` has the type of the then arm when both arms have one static type. `semantic_types_same` follows one `resolved_type` step, then `type_equals` (name, width, pointer, array, `const`).
- `type Count = integer` matches an `integer` arm. `integer`, `integer 32`, `cardinal`, and `real` stay distinct.
- Both arms known and different: `semantic_resolve_expr` errors (`ternary arms must have the same type`). Either arm untyped: the conditional has no type, and init inference reports that it cannot infer one.
- The condition is unchecked. Brace lists `{ … }` stay untyped until a target type is written. A `CONST` ternary receives a type and is not folded, so it cannot size an array.
- Codegen was already `(cond ? a : b)`. Parser and EBNF unchanged.
- A string literal has type `string`. In `? :`, `string`, `^char`, and `const ^char` are three types. `as` gives that arm the target type. Clarified in Language Report §6.3 the same day. No checker change.
- **Tests:** `tests/test_infer.mc` (`true ? 1 : 2`, nested `false ? 1 : true ? 2 : 3`); `tests/test3_infer.mc` (integer vs string); `tests/test3_ternary_width.mc` (`integer 32` vs an integer literal).
- **Verification:** user typed the change. Tests green on **gcc**, **clang**, and **tcc** through **make test-all** / **selfhost** / **bootstrap** / **promote**. Build **203**. Version **0.26.10**. Language Report §6.3.
- **#11** build-time defaults **parked indefinitely** (12 October 2026) until another architecture can prove `TMODC_ARCH`. Slice formals remain the **0.27** plan. `ELSE CASE` remains planned. `node.c` / `node.h` remain hand-written C.

## Recent Accomplishments (10 October 2026 — 0.26.9.201 / `codegen_c.mc`)

### Self-host: `codegen_c.c` → `codegen_c.mc` **Done**

- The statement and full-program emitter is now `src/codegen_c.mc`. `codegen_c.c`, `.h`, and `.mh` are generated by Mod-c 0.26.9. `src/codegen.mc` calls `codegen_c` for `TARGET_C`.
- Covers the unit banner, imports and top-level declarations, the program or module body, the hosted `main` wrapper, and statements (`if`, `while`, `for`, `repeat`, `loop`, `switch`, blocks, `return`, `break`, `continue`, `DEFER` unwind, `assert`, `debug`). Expressions, types, parameters, and imports stay in `codegen_common.mc`. File-local helpers stay unexported. The `.mh` export is `codegen_c(CodegenContext)`.
- **Port fix:** `for i := 0 to defer_count` includes `defer_count`. A block with no `DEFER` has a null `defers` pointer, so `return` / `break` / `continue` segfaulted in `codegen_c_block_has_reached_defer`. The bound is `to defer_count - 1`. The LIFO `downto` loop was already correct. Empty module body comment is `/* Empty body */`.
- **Still C:** `src/node.c` / `src/node.h` (AST). `src/tmodc.h` stays the hand-written ABI header.
- **Verification:** user typed the port. Tests green on **gcc**, **clang**, and **tcc** through **make test-all** / **selfhost** / **bootstrap** / **promote**. Build **201**. Version **0.26.9**. Language Report / EBNF unchanged. See `docs/grok_report-20261010-1958.md`.
- **Next:** **#11** defaults deferred; soft **21a-ternary**. Slice formals remain the **0.27** plan. `ELSE CASE` remains planned.

## Recent Accomplishments (6 October 2026 — 0.26.9.200 / ^opaque type-specifier)

### `^opaque` as a type-specifier **Done**

- `^opaque` and `POINTER TO opaque` are legal type-specifiers: formals, fields, `VAR` / `LET`, results, casts, and `sizeof`. C is `void *`. `const ^opaque` is `const void *`.
- `^opaque[N]` and `array[N] of ^opaque` are arrays of `void *`. An open-array parameter `array[] of ^opaque` decays to `void **`. A block-scope `var a: ^opaque[]` is an incomplete C array, same as `var a: char[]`.
- Bare `opaque` stays a TYPE RHS. `var x: opaque`, `procedure f(p: opaque)`, and `array[N] of opaque` are errors.
- Named aliases are unchanged: `type Handle = opaque` and `type address = ^opaque` still emit `typedef void *Name`. `const` on that typedef is still dropped. The alias is distinct from a written `^opaque`.
- `emit_type_leaf_name` prints `void` for an unnamed opaque type. `.mh` already wrote `^opaque`; `semantic_mh_make_type` builds that unnamed pointer when the type-spec name is `opaque` and the pointer flag is set. `sizeof(^opaque)` is legal.
- Tests: `test_opaque_ptr`, `test2_opaque_import` (`fixtures/opqview.mh`), `test3_opaque_param`, `test3_opaque_array`. `test3_opaque_parse` (`var z: opaque`) still fails. `test_opaque` (named aliases) unchanged.
- **Verification:** user typed the compiler changes. Tests green on **gcc**, **clang**, and **tcc**. Build **200**. Version **0.26.9**. Promoted **0.26.9.200**. See `docs/grok_report-20261006.md`.
- **Next:** **#11** defaults deferred; soft **21a-ternary**. Slice formals remain the **0.27** plan.

## Recent Accomplishments (3 October 2026 — 0.26.9.199 / `codegen_common.mc`)

### Self-host: `codegen_common.c` → `codegen_common.mc` **Done**

- The shared emitter used by `codegen_c.c` and `codegen_header.mc` is now `src/codegen_common.mc`. `codegen_common.c`, `.h`, and `.mh` are generated by Mod-c 0.26.9.
- Covers the C prelude, type and parameter emission, struct, union, enum, and method types, expressions, `sizeof`, `countof`, `inc`/`dec`, and imports. `emit_array_type`, `emit_type_specifier`, and `codegen_common_expr` are `RECURSIVE`. File-local helpers stay unexported.
- **`emit_param_list`:** C `Node **` is `params: ^pNode` after unit-local `type pNode = ^Node`. Anonymous `^Node[]` still exports as `?`. Spelled in **0.27.1.217**. See [Future plan: `.mh` array type-specs](#future-plan-mh-array-type-specs).
- **Still C:** `src/codegen_c.c` (statements / full program) and `src/node.c` / `src/node.h` (AST). `src/tmodc.h` stays the hand-written ABI header.
- **Verification:** tests green on **gcc**, **clang**, and **tcc**. Build **199**. Version **0.26.9**. Language Report / EBNF unchanged.
- **Next:** **#11** defaults deferred; soft **21a-ternary**.

## Recent Accomplishments (2 October 2026 — 0.26.9.198 / `COUNTOF`)

### `COUNTOF` **Done** (replaces interim `LEN`)

- Keyword `COUNTOF`. `TOK_KEYWORD_LEN` renamed in place to `TOK_KEYWORD_COUNTOF`; `NODE_LEN` renamed in place to `NODE_COUNTOF`. `len` is an identifier.
- Operand is a type or a designator. Success only for a complete fixed array (`is_array`, not a pointer, `array_size > 0`). Outermost bound. One `resolved_type` chase, so `type Buf = array[4] of integer` works.
- Const-folded (`sizeof_expr.folded` / `count`). `array[countof(a)]` is a legal bound. C emit `((integer)N)`; unfolded designator keeps the sizeof division.
- Not string length. Open arrays and `array[0]` share `array_size == 0` and are rejected.
- Tests: `test_countof`, `test3_countof`, `test3_countof_ptr`. Removed `test_len` / `test3_len`.
- Kilo highlighter keyword list: `countof|`.
- **Verification:** user typed the compiler changes. Compiler tests pass. Build **198**. Version **0.26.9**. See `docs/grok_report-20261002.md`.
- **Next:** **#11** defaults deferred; soft **21a-ternary**.

## Recent Accomplishments (30 September 2026 — 0.26.8.196 / named-type owner, C-index of `^Named`)

### Named type as method owner **Done**

- Instance: first formal’s **written** name is the owner, and not use-site `^` / array. `type sds = ^char` then `sds::free(s: sds)` is instance. `s: ^sds` is static (v1).
- Do not follow `resolved_type` in `semantic_method_is_instance`, `mh_first_formal_type_name`, `semantic_find_instance_on_chain`, or `obj.m()` owner lookup. `auto_deref` is `recv_ty^.is_pointer` (written `^` only).
- `Type::m(p)` peels only if the actual is use-site `^Owner` (or EXTENDS ancestor). `sds::free(x)` with `x: sds` is `sds__free(x)`, not `(*x)`.
- Tests: `tests/test_method_named_ptr.mc`; `tests/test3_method_named_ptr.mc`.

### C-index of written `^Named` **Done**

- `semantic_type_of_designator` `NODE_ARRAY_INDEX`: if the array side is use-site `is_pointer`, copy-shell and clear `is_pointer` **before** chasing the alias. `^sds[i]` is `sds`; `sds[i]` still chases to `char`.
- `tokens[0].length()`; `p[0].get()` on `^Handle`.

### Unreachable after exit **Warning**

- `TParser::parse_block` / `parse_statement_sequence`: `error_at(..., false)`. TSDSLib `#endif` after `return 0` in `sdsTest`.

### Examples

- **TSDSLib 2.0** — `examples/sds/Tsds.mc` (port of SDS 2.0; type-bound API; extra tests).
- **Kilo `ABuffer`** — `capacity`; first alloc 1024; double on grow.

**Verification:** user typed in; **make test-all** / **selfhost** / **bootstrap** / **promote** green on **gcc**, **clang**, and **tcc**. Build **196**. Promoted **0.26.8.196**. See `docs/grok_report-20260930.md`.

**Next:** **#11** defaults deferred; soft **21a-ternary**. Parked: `INLINE`; `export var` header/`extern`; item **19** `CONST` codegen; first formal `^Owner` as instance.

## Recent Accomplishments (22 September 2026 — 0.26.8.194 / `.mh` alias RHS, packs, `LEN`)

### `.mh` alias RHS **Done**

- Optional tail after `complete`/`opaque` when the TYPE is an alias: `export type integer complete integer 64`, `export type string complete const ^char`, `export type I32 complete integer 32`. Old lines without a tail stay valid.
- Writer (`mh_emit_export_type`): `mh_append_type_spec` of the RHS. Reader: `mh_parse_alias_rhs`. Semantic: `has_alias` → `symbol_type`; `IMPORT_ITEM` with `symbol_type` uses that type. Bare `integer` is still a builtin name; pack `.h` still supplies the C typedef for portable binds.
- Same kind of alias as `type I32 = integer 32`, but it **travels in the `.mh`**. Most committed `.mh` files regenerated — reason for the **0.26.8** stem.

### In-tree packs **Done** (fixtures)

- `tests/fixtures/lp64` — integer/cardinal/real 64. `tests/fixtures/ilp32` — 32/32/32. Lean `.h` (stdint + four typedefs); do not replace with `tmodc -H`.
- Tests: `test_import_rebind`, `test_import_ilp32`, `test_import_alias`.
- **Not this slice:** `include/tmodc/` + search (item **15**).

### `LEN` **Done** (interim)

- `NODE_LEN`; parse designator only; emit `((integer)(sizeof(n) / sizeof((n)[0])))`.
- **#11** build-time defaults **deferred**.
- **Verification:** user typed in; **make test-all** / **selfhost** / **bootstrap** / **promote** green on **gcc**, **clang**, and **tcc**. Build **194**. Promoted **0.26.8.194**. See `docs/grok_report-20260922.md`.
- **Next:** **#11** defaults deferred; soft **21a-ternary**.

## Recent Accomplishments (21 September 2026 — 0.26.7.192 / several `.mc` inputs)

### Several `.mc` on the command line **Done**

- `src/modc.mc` only. Collect leftover non-options (`tmodc *.mc -C` and `tmodc -C *.mc`). Loop `process_one_unit` with a new arena each time.
- Several inputs: omit named `-C`/`-H`/`-M` paths and `-b`; use defaults or `-d`.
- Fail-fast. Missing input file returns 1 (no silent success).
- Example: `./bin/tmodc -C -d /tmp/tmodc-out/ examples/*.mc`.
- **Not this slice:** `--deps` / `--print-imports`; compiling the import graph; item **15**.
- **Verification:** user typed in; promoted **0.26.7.192**. See `docs/grok_report-20260921.md`.
- **Next:** **#11** arch packs.

## Recent Accomplishments (19 September 2026 — Kilo tutorial finished)

### Snaptoken Kilo port **Done** (`examples/kilo/kilo.mc`)

- Author: M. Scott Reynolds. Started 7 September 2026; finished 19 September 2026.
- Follows [Build Your Own Text Editor](https://viewsourcecode.org/snaptoken/kilo/index.html) in TMod-c. Not a compiler language change and not a version bump.
- Editor state lives on `EditorConfig`, `ERow`, and `ABuffer` with TYPE-bound procedures. `E.row[at].updateRow()` uses C-index `p[i]` on `^ERow` (**0.26.7.191**). **0.26.8.196:** `ABuffer` grows by doubling from a 1024-byte first allocation (`capacity`).
- Surface used: `DEFINE` (`CTRL_KEY`, `HLDB_ENTRIES`); `...` + `stdarg.h` FFI (`EditorConfig::setStatusMessage`); `DEFER` (`save`); `RECURSIVE` (`ERow::updateSyntax`); `extern type Termios = struct termios`. Extra HLDB entry covers TMod-c (`.mc` / `.mh`, `(* *)`).
- `g_orig_termios` is global because `atexit(disableRawMode)` has no receiver. Find uses `fnCallback` plus `EditorConfig::findCallback` (procedure types do not prepend a receiver; no first-class `Type::method` values).
- Nested `(* *)` comments do not nest (noted in the source). Keywords are case-insensitive.
- Build: `examples/kilo/` — `make kilo` with `TMODC=../../bin/tmodc`.
- **Next compiler work:** **#11** arch packs. Example extras (nested comments, case-insensitive keyword highlight) are notes, not language items. See `docs/grok_report-20260919.md`.

## Recent Accomplishments (18 September 2026 — 0.26.7.191 / C-index `p[i]` on `^T`)

### C-style `p[i]` on `^T` **Done**

- **`p[i]` type is `T`** when `p` is `^T` (or an alias such as `pERow = ^ERow`) and `T` is not an array. `semantic_type_of_designator` (`NODE_ARRAY_INDEX`) copy-shells and clears `is_pointer` after the array-element branch. Same strip as postfix `p^`.
- **Not a peel.** Do **not** set `array_index.auto_deref`. Pointer-to-array (`^Vector3` / `^array[N] of T`) still hits `is_array` first → element type; C stays `(*(p))[i]` (**0.26.5.178**). `^char[]` `argv[i]` unchanged.
- **Methods:** `p[i].m()` is an ordinary `T` receiver. `REF`/`VAR` auto-`&` → `Type__m(&p[i])`. `Type::m(p[i])` and `(@p[i]).m()` work once the index is typed.
- **Fields:** `p[i].field` is checked against the struct (was foreign C while the index type was `nil`).
- **Tests:** `tests/test_ptr_index.mc` (alias, bare `^Cell`, `p[i].bump()`, `Cell::bump(p[i])`, `(@p[i]).bump()`); `tests/test3_ptr_index.mc` (`p[0].no_such_field`).
- **Kilo (then still in progress):** `E.row[at].updateRow()`; `ERow::` and `EditorConfig::` type-bound procedures (`E.open` / `E.refreshScreen` / `E.processKeypress`). **Finished 19 September 2026** — see [Kilo tutorial finished](#recent-accomplishments-19-september-2026--kilo-tutorial-finished).
- **Verification:** user typed in; **make test-all** / **selfhost** / **bootstrap** / **promote** green on **gcc**, **clang**, and **tcc**. Build **191**. Promoted **0.26.7.191**. See `docs/grok_report-20260918.md`.
- **Next:** **#11** arch packs.

## Recent Accomplishments (17 September 2026 — 0.26.7.190 / `...` pass-through)

### `...` last formal **Done**

- Parse last `, ...` after ≥1 named formal (`NODE_PARAM_LIST.has_ellipsis`). Emit C `, ...`. Extra actuals already parsed; gcc needs the ellipsis. No builtin `va_list`.
- `.mh` `(string, ...)`; `MhFormal.is_ellipsis`. PROGRAM/MODULE reject `...`.
- Consume extras: `import va_list, va_start, va_end from "stdarg.h"` + `vprintf` / `vsnprintf`.
- Kilo: `define CTRL_KEY(k) …`; `editorSetStatusMessage` varargs; `type puchar = ^uchar` (not `unsigned ^char` — Language Report §5.3).
- Tests: `tests/test_ellipsis.mc`, `tests/test3_ellipsis.mc`, `tests/test3_ellipsis_tail.mc`.
- **Parked:** `TYPEOF`; vendoring single-file C libs into `tmodc`.
- **Verification:** user typed in; promoted **0.26.7.190**. See `docs/grok_report-20260917-ellipsis.md`.
- **Next then:** C-index `p[i]` on `^T` (closed **0.26.7.191**); then **#11** arch packs.

## Recent Accomplishments (14 September 2026 — 0.26.5.188 / DEFINE)

### `[EXPORT] DEFINE identifier RestOfLine` **Done**

- Keyword `DEFINE`; rest of line is C (`TLexer::capture_line_from`, including `\` continuations). Bind `SYM_KIND_IMPORT`. Emit `#define ` + source span. `EXPORT` also `.h` and `.mh` (`MH_KIND_DEFINE`).
- `#define` pass-through unbound. `CONST` still `static const`. Feature-test macros stay `-D`.
- Tests: `tests/test_define.mc`, `tests/test3_define.mc`. `p.lexer` is a legal `ref` actual.
- **Verification:** user typed in; **make clean tmodc test-all selfhost bootstrap promote** green on **gcc**, **clang**, and **tcc**. Build **188**. Promoted **0.26.5.188**.
- **Next then:** `...` formals (closed **0.26.7.190**); kilo `CTRL_KEY` / `editorSetStatusMessage`.

## Recent Accomplishments (8 September 2026 — 0.26.5.186 / extern struct, escapes, parse)

### C struct-tag `extern type`, char `\x`, `parse_primary` **Done**

- **`extern type Name = struct [tag]`** — `typedef struct tag Name;` after the include. Bare `extern type FILE` still emits nothing. Not `opaque` / not `FORWARD`. Tests: `test_extern_struct` + `fixtures/ctag.h`. Kilo: `extern type TTermios = struct termios`.
- **`'\x1b'`** — lexer `\x` + two hex digits; octal 1..3. `tests/test_char_esc.mc`.
- **`&` vs `@`** — `parse_primary` no longer returns silent `nil` (that core-dumped `ioctl(..., &ws)`). Hint: `'&' is bitwise AND; use '@' for address-of`. Unary `&` is not address-of.
- **`{ a, b, }`** — `parse_array_literal` treats `}` after a comma as end (needed once `nil` was no longer a trailing-comma signal).
- **Verification:** user typed in; **make clean tmodc test-all selfhost bootstrap promote** green on **gcc**, **clang**, and **tcc**. Build **186**. Promoted **0.26.5.186**.

## Recent Accomplishments (7 September 2026 — 0.26.5.183 / LET C const and `@`)

### Drop C `const` on LET **Done** (27b) and `@` of `LET`/`CONST` **Done**

- **C:** `NODE_LET_DECL` is an ordinary local (`codegen_c.c`, `codegen_header.mc`). Declaration `CONST` still `const` (item **19**).
- **`@`:** `semantic_forbid_at_immutable` — operand rooted at `LET` or declaration `CONST` is an error (`test3_let_addr`, `test3_let_addr_var`). `let p: Point` then `p.x :=` stays legal. Pointer through-write needs a **`VAR`** object (`test_let_field`: `var n` then `let pc = @n`).
- **Static text:** unbound **`string`** = **`const ^char`** (`typedef const char* string`). Prefer `let s: string = "…"`. Explicit `const ^char` is the same pointee `const`. Do not restore C `const` on LET (would freeze `let pc: ^T` pointees).
- **Still open:** `@n` as `const ^T`; item **19**.
- **Verification:** user typed in; **make clean tmodc test-all selfhost bootstrap promote** green on **gcc**, **clang**, and **tcc**. Build **183**. Promoted **0.26.5.183**.

## Recent Accomplishments (7 September 2026 — 0.26.5.181 / LET write-forbid)

### `LET` write-forbid **Done** (Slice A)

- **Rule 2:** a `LET` **name** may not be the LHS of `:=` / `INC` / `DEC`. Through-writes (`p.x`, `pc^`, `a[i]`) are legal — same body rule as `REF` / bare formals. Not a `CONST` formal (not pointer-to-const).
- **`semantic_forbid_let_write`** — bare `NODE_IDENT` + `SYM_KIND_LET`. Call sites: `NODE_ASSIGN`; `INC`/`DEC` as statements **and** expressions (`y := INC(n)`). Expression `INC`/`DEC` also got the existing FOR / param forbids.
- **Declaration `CONST`:** still compile-time, block-head with `VAR` — not mid-block like `LET`.
- **Tests:** `test3_let_assign` / `test3_let_inc` / `test3_let_inc_expr`; `test_let_rebind`.
- **Closed in 0.26.5.183:** drop C `const` on LET; `@` of LET/CONST.
- **Verification:** user typed in; **make clean tmodc test-all selfhost bootstrap promote** green on **gcc**, **clang**, and **tcc**. Build **181**. Promoted **0.26.5.181**.

## Recent Accomplishments (4 September 2026 — 0.26.5.180 / parent-chain methods)

### Parent-chain instance methods **Done**

- **`c.show()` / `pc.show()` / `g.show()`** bind `Parent::show` when the receiver is `Child` / `^Child` / `Grand`. Walk `EXTENDS`; first **instance** hit wins (Child shadows Parent). A static `Type__name` at that level is an error; do not skip to a parent instance.
- **`call.base_depth`** — `.base` hops after peel. Do **not** `maybe_upcast` the `receiver_expr` (would double `.base`). Argument `maybe_upcast` unchanged.
- **C** — `Parent__show(c.base)` / `Parent__show((*pc).base)` / `Parent__bump(&((*pc).base), n)`. No `->`.
- **`Type::m(p)`** — peel if pointee is owner **or ancestor** (`Parent::show(pc)`). Skip `@`. Qualified `Child::show` does not walk.
- **Tests:** `tests/test_extends.mc` (`c.show()` / `g.show()` / `pc.show()` / `Parent::show(pc)` / `pc.bump` / `c.ownY()` / `g.ownY()`).
- **Still open:** first formal `^Owner` as instance (not this item).
- **Verification:** user typed in; **make clean tmodc test-all selfhost bootstrap promote** green on **gcc**, **clang**, and **tcc**. Build **180**. Promoted **0.26.5.180**.

## Recent Accomplishments (4 September 2026 — 0.26.5.179 / `Type::m(p)` peel)

### Qualified instance `Type::m(p)` on `^Owner` **Done**

- **`Point::print(pp)` = `pp.print()`** when `pp` is `^Point`. First actual only; pointee name must be the owner. Reuses `call.auto_deref`; codegen peels `args[0]` when there is no `receiver_expr`.
- **C** — by-value `Point__print((*pp))`; `REF` `Point__scale(&(*pp), n)`.
- **Do not peel `@`:** `TLexer::next(@p.lexer)` stays `&(p.lexer)`. `(*&x)` passed a struct by value (selfhost `TParser::advance`).
- **Do not peel `pp^`:** already a value (one caret wrap).
- **After** `semantic_resolve_expr` on args. **Only if** `receiver_expr == nil` — an unconditional `auto_deref := false` wiped `pp.getX()` (`argc` is 0).
- **Tests:** `tests/test_smoke.mc` (`Point::print(pp)` / `Point::scale(pp, 3)` / `Point::getX(pp)`). Selfhost lexer `@` calls.
- **Still open then (closed 0.26.5.180):** parent-chain method lookup.
- **Verification:** user typed in; **make test-all** / **selfhost** / **bootstrap** / **promote** green on **gcc**, **clang**, and **tcc**. Build **179**. Promoted **0.26.5.179**.

## Recent Accomplishments (4 September 2026 — 0.26.5.178 / `p[i]` peel + instance on `^T`)

### Pointer-to-array `p[i]` and `p.method` on `^T` **Done**

- **`p[i]` = `p^[i]`** when the left side is a pointer-to-array (`^array[N] of T` or `^Name` with `Name` an array typedef). One implied peel per `[]`. AST stays `NODE_ARRAY_INDEX` (`array_index.auto_deref`); no inserted caret.
- **Do not peel `^char[]`** — `argv[i]` is `^char` (array-of-pointer, not pointer-to-array).
- **C** — `(*(p))[i]`. Anonymous `^array[N] of T` emits `T (*name)[N]` (caret was previously ignored). Named `^Vector3` stays `Vector3 *p`.
- **Explicit `p^[i]`** — postfix `^` emits `(*(expr))` so C `[]` does not bind tighter than unary `*` (`*p[i]` was `*(p[i])`).
- **`p.method` on `^T`** — `call.auto_deref`; first formal still owner **value** (`self: Point` / `ref self: Point`), not `^Point`. C by-value `Type__m((*p))`; `REF`/`VAR` `&(*p)`. `Type::m(p)` closed in **179**. No `->`.
- **Tests:** `tests/test_array.mc` (`pv[i]` / `pv^[i]` / `pa[i]` / `argv[0]`); `tests/test_smoke.mc` (`pp.getX()` / `pp.print()` / `pp.scale(2)` / `Point::print(pp^)`).
- **Still open then (closed 0.26.5.179):** auto-peel of `Type::m(p)`. **Still open then (closed 0.26.5.180):** parent-chain method lookup.
- **Verification:** user typed in; **make test-all** / **selfhost** / **bootstrap** green on **gcc**, **clang**, and **tcc**. Build **178**. Promoted **0.26.5.178**.

## Recent Accomplishments (4 September 2026 — 0.26.5.177 / Shapes + refactor)

Light refactoring already checked in. `examples/Shapes.mc` — tagged `EXTENDS` scene (no `IS`); field auto-deref (176); downcast `p as ^Circle` after a programmer tag.

## Recent Accomplishments (3 September 2026 — 0.26.5.176 / Oberon `p.x` auto-deref)

### Field auto-deref **Done**; `p[i]` and `p.method` on `^T` **not** in this build *(closed 0.26.5.178)*

- **`p.x` = `p^.x`** when the left side is a pointer (`^T` or named alias). One implied peel per `.`. AST stays `NODE_FIELD_ACCESS` (`field_access.auto_deref`); no inserted caret. Explicit `p^.x` unchanged.
- **Pointer test** — use type **or** `resolved_type` is a pointer. Do not chase the alias first (`^Child` would become named `Child` and drop the flag).
- **C** — `(*(p)).field`, then `.base` × `base_depth`. No `->`. `REF`/`VAR` formals still go through `emit_let_ident` (`(*formal)`); those are not TMod-c `^T`.
- **EXTENDS** — parent fields work: `c5.x` → `(*(c5)).base.x` (same `base_depth` as `c5^.x`).
- **Tests:** `tests/test_extends.mc` (`c5.x` / `pp.x` / `pg.z`, `p.x` in `takeParentPtr`); `tests/test_pointer_var.mc` (`root.value`, `p.next.value` beside `^.` forms).
- **Still open then (closed 0.26.5.178):** `p[i]` peel for pointer-to-array — do **not** peel `^char[]` `argv[i]`; instance method on `^T`.
- **Verification:** user typed in; **make test-all** / **selfhost** / **bootstrap** green on **gcc**, **clang**, and **tcc**. Build **176**. Promoted **0.26.5.176**.

## Recent Accomplishments (2 September 2026 — 0.26.5.175 / EXTENDS polish)

### Optional #4 — three slices **Done**; Oberon `p.x` **not** in this build

- **`p^.x` parent fields** — `semantic_type_of_designator` handles postfix `^` and `AS`. `c5^.x` sets `base_depth`; C `(*c5).base.x`. (`c5^.y` already worked.)
- **`g as Parent`** — `upcast_depth` from inner type vs `AS` target; codegen omits `(Parent)g` and uses `.base` × N. Pointer `as` (`(@g) as ^Child`) stays a C pointer cast unless it is an ancestor upcast (then `upcast_ptr`).
- **Pointer / `REF` upcast** — both-pointer or both-value in `semantic_extends_upcast_depth`. `Node.upcast_ptr`: value `((expr).base × N)` so `REF Parent` + Child actual is `&((c).base)`; `^Child` where `^Parent` is needed is `&((*(pc)).base)`.
- Sites already wired: typed init, `:=`, `RETURN`, same-unit call formals, plus `AS`.
- **Tests:** `tests/test_extends.mc` (user typed; green).
- **Still open then (field `.` closed in 0.26.5.176; `p[i]` / `p.method` closed in 0.26.5.178):** `p[i]` peel for pointer-to-array; instance `p.method` on pointer receivers. Do not peel `^char[]` `argv[i]`.

**Verification:** user typed in; tests green. Build **175**.

## Recent Accomplishments (31 August 2026 — one Makefile / gcc · clang · tcc)

- **Single `Makefile`** — `CC ?= gcc`; `CC_FAMILY` from `clang` / `tcc` / else gcc (paths and `clang-18` / `gcc-14` included).
- **Flags:** gcc keeps `-pedantic-errors` and `-Wcast-align=strict`; clang same minus the GCC-only align flag; tcc matches the old `Makefile.tcc` set (no pedantic/conversion; `-Wswitch-enum`).
- **`debug`:** gcc/clang `-fsanitize=address` on compile and link (no `-lasan`); tcc `-g -O0` only.
- **`make tar`** no longer copies `Makefile.clang` / `Makefile.tcc`. Those files moved to **`archive/`**.
- **Switch compiler:** `make clean` first so `build/c` objects are not mixed.
- **Verification:** `make test-all` green on **gcc**, **clang**, and **tcc**.

```bash
make                              # gcc (default)
make clean && make CC=clang test-all
make clean && make CC=tcc test-all
```

## Recent Accomplishments (28 August 2026 — 0.26.5.174 / #11 import-bind + `.mh` widths)

### Import as the one unit bind **Done**

- Named `.mh` import of `integer` / `cardinal` / `real` / `string` is the unit bind (Language Report §5.5). Prelude `decl == nil`; second bind is an error.
- Only `.mh` TYPE exports. Include-only and foreign `.h` imports do not skip the default `typedef`. `import integer as i64` does not bind `integer`.
- `codegen_unit_binds_portable` walks `.mh` import items (qualident, else `AS` alias). Pack `.h` supplies the C ABI.
- **Tests:** `test_import_rebind` + `fixtures/lp64` (lean header); `test3_import_rebind_second` / `test3_import_then_rebind`.

### `.mh` width spelling **Done**

- Writer: `integer 32` (and `cardinal` / `real`) on field, formal, and result type-spec. Name stays `integer`; `TType.width` is separate.
- Reader: `type_width` / `result_width`; optional decimal *N* before multi-word C names; closed *N*; two-digit cap (no signed overflow under `-Wstrict-overflow=4`).
- Semantic: imported field/formal/result types keep the width.
- **Tests:** `test2_export_width` / `test2_import_width`; `test_import_width` + `fixtures/wpoint`; `test3_import_width` (`integer 99`).
- **Still open (#11):** arch packs; build-time defaults; `.mh` alias RHS.

**Verification:** user typed in; tests green. Build **174**.

## Recent Accomplishments (27 August 2026 — 0.26.5.173 / width forms + `.h` prelude)

### Width forms **Done** (`integer N` / `cardinal N` / `real N`)

- Exact C11 widths. Closed *N:* **8 / 16 / 32 / 64** (`real` **32 / 64**). Decimal *N* only.
- `TType.width`; `type_c_spelling` → `intN_t` / `uintN_t` / `float` / `double`.
- `type integer = integer 64` is the Phase A unit bind with a width RHS.
- **Tests:** `test_width`, `test_width_rebind`, `test3_width`, `test3_width_real`.

### Generated `.h` owns the C prelude **Done**

- `codegen_emit_c_prelude` in the header (after the include guard): stdint/stdbool/assert, `nil`/`NIL`, `byte`, portable four unless this unit bound the name.
- Unexported portable `TYPE` binds still appear in the `.h`.
- Generated `.c` `#include "UnitName.h"`; no second prelude. `-C` writes a companion `.h`.
- Header always emits the unit prototype (PROGRAM and MODULE).
- **PROGRAM/MODULE name must match the output stem** (`#include "Name.h"`).
- `tmodc.h` remains optional for hand-written C. `.mh` width spelling still deferred.

**Verification:** `make test-all` on **gcc**, **clang**, and **tcc**. In-tree modules regenerated. Promoted **0.26.5.173**.

## Recent Accomplishments (26 August 2026 — 0.26.4.172 / method-type `.mh` RHS)

### Method-type export / import **Done**

- Writer: `export type TFn complete function (integer) : integer` (always `(…)` on the type line; `procedure` likewise). Same physical `@format 1` line as field tails.
- Reader: `is_func_type` + reuse `mh_parse_signature` after `complete` when the type is not `struct`/`union`.
- Semantic: synthetic `NODE_TYPE_DECL.method_type` (`NODE_METHOD_TYPE` + formals). Must assign `method_type := mt` (not `nil`).
- Field call-through uses existing `semantic_method_type_node` / Policy A discard (`(f())` as a statement when the result is known).
- Import **both** the method type and the owner struct (`TFn` and `TBox`).
- **Tests:** `test2_export_fn_type` / `test2_import_fn_type` (`(b.fn(1))`); `test3_import_fn_type` (no `TFn` import); `test_import_fn_type` + `fixtures/fnbox.{mc,mh,h}` (`b.fn := twice`; `assert b.fn(21) == 42`).
- **Verification:** `make test-all` on **gcc**, **clang**, and **tcc**. Promoted **0.26.4.172**.

## Recent Accomplishments (25 August 2026 — 0.26.3.170 / `.mh` field lists)

### Identifiers ≤ 255 **Done**

- Lexer: `IDENT_MAX_LEN` 255; longer names are `TOK_ERROR` (`identifier longer than 255 characters`).
- `parser_common` `error_at` prints `error_msg` for `TOK_ERROR`.
- `.mh` `mh_read_ident` same bound. Mangled `Owner__name` may be 512 (not a source identifier).
- **Test:** `tests/test3_ident_long.mc`.

### `.mh` reader whole-file **Done**

- `mh_reader_load`: file size → `malloc(n+1)` → parse in place (no 4096 `fgets` cap).
- `MhModule.source` owned until `mh_module_free`. Layout/formal strings may point into that buffer.

### Writer DynBuf prefixes **Done**

- Export lines (including `@module`, type/enum/binding/unit entry, method `Owner__name`) built on `DynBuf`. `snprintf` 256 only for the short generated-by comment.

### Field lists — writer / reader / import **Done**

- `export type Name complete struct (f: T { , … })`; `union`; optional `extends Parent`. `export type Name opaque` unchanged (`EXTERN TYPE`, `type T = opaque`).
- `mh_type_opaque`: no longer treats `struct_body <> nil` as opaque.
- Reader: `MhField` on `MhExport`; old `opaque` / bare `complete` still legal.
- Semantic: synthetic `NODE_TYPE_DECL` + `struct_body` on import (arena-copied names). Unknown field on a complete imported struct is an error. Parent fields need the parent type imported (not flattened).
- **Tests:** `test2_export_struct` / `test2_import_struct` / `test3_import_struct_field`; union and EXTENDS pair; `test_import_struct` + `fixtures/tpoint.{mc,mh,h}` (compile + run). Writer `.mh` for `test2_*` still generated with `-M` (not a Makefile golden).
- **Verification:** `make test-all` green. Method-type RHS **Done (0.26.4)**.

## Recent Accomplishments (24 August 2026 — 0.26.3.168 / parser self-host)

### `parser.c` → `parser_common.mc` + `parser_main.mc` **Done**

- Shared parser state and token helpers live in **`parser_common`**: `TParser` / `pParser`, type-name registry, `advance` / `check` / `match` / `consume` / EOS / comments / assignment / skip helpers / `error_at` / `isEOF`.
- **`parser_main`** is the recursive-descent driver (`TParser::init` / `parse` / `parse_expr` / `parse_stmt` / blocks / types).
- Each common helper has **two** exports: old `advance(p: pParser)` (still used by `declaration` / `expression` / `statement`) and new `TParser::advance(ref p: TParser)` (used by `parser_main` only). Migrate the other three units later.
- Hand-authored **`parser.c` / `parser.h`** replaced. `modc` includes `parser_common.h` + `parser_main.h`.
- **Verification:** `make test-all`, **selfhost**, **bootstrap**, **promote** green on **gcc**, **clang**, and **tcc**. Promoted **0.26.3.168**.

### Cyclic `.mh` imports — noted, not designed

- `parser_main` imports parse entry points from `declaration` / `expression` / `statement`; those units import `TParser::parse_expr` / `parse_stmt` / … from `parser_main`.
- This is legal **today** because C headers can include each other and `.mh` is loaded from a prior generate. As `.mh` grows (field lists, signatures), mutual TMod-c imports will get fragile — a problem almost every new module language hits.
- **Do not address until after item 15** (Makefile subdirectory compilation / module directories). Interim: keep extracting a common module rather than closing a cycle.

## Recent Accomplishments (18 August 2026 — 0.26.1.158 / unknown types + no automatic stddef.h)

### Unknown type names are errors **Done (breaking)**

- `semantic_resolve_type_inner`: unbound **single-word** type name is fatal (`unknown type`).
- Still legal: prelude builtins (`bool`, `int`, `integer`, `long`, …); named `IMPORT` / `EXTERN TYPE`; `.mh` opaques; multi-word C spellings (`long long`, `unsigned int`). Bare `unsigned` is not a type — write `unsigned int` or a typedef.
- **`size_t`**, **`FILE`**, **`void`**, and compiler types (`Node`, `Parser`, …) must be listed on `IMPORT` (or declared). That import also emits the C `#include`.
- **Tests:** `test3_undef_type.mc` (`var f: FILE`). Compiler / test / example type import sweep.

### Automatic `<stddef.h>` dropped **Done**

- Generated prelude: `<stdint.h>`, `<stdbool.h>`, `<assert.h>` only.
- `#define nil ((void *)0)` / `#define NIL nil`. `byte` remains `uint8_t`.
- `size_t` is no longer free via the prelude; `import size_t from "stddef.h"` where used.

**Verification:** `make test-all`, **selfhost**, **bootstrap**, **promote** green on **gcc**, **clang**, and **tcc**. Promoted **0.26.1.158**.

## Recent Accomplishments (18 August 2026 — 0.26.0.156 / free-call soft-miss closed)

### Unresolved free calls are errors **Done (breaking)**

- `semantic_resolve_call`: `sym == nil` on a free `name(...)` or `Type::name(...)` is fatal (`undefined procedure or function` / `undefined type-bound method`).
- Still legal: same-unit `PROC`/`FUNC`; named `IMPORT` / `EXTERN`; 7a module-entry bind; method-typed locals (`fp(...)`); field call-through; prelude type names.
- Include-only `IMPORT FROM source` still binds **no** names. Quoted `FROM "hdr.h"` does not parse the header.
- **C preprocessor** is pass-through only. `#define` does not create TMod-c symbols. A macro used from `.mc` belongs in a real `.h` and on an `IMPORT`.
- **Not this bump:** unknown type names (`size_t`, `FILE`) still soft-miss; automatic `<stddef.h>` stays.
- **Tests:** `test3_undef_call.mc`, `test3_undef_method.mc`; `test_tmodc.mc` uses a real `TSTRING` function (no dummy import / same-file `#define`). Compiler `src/*.mc` import sweep so self-host stays legal.
- **Verification:** `make test-all`, **selfhost**, **bootstrap**, **promote** green on **gcc**, **clang**, and **tcc**. Promoted **0.26.0.156**.

## Recent Accomplishments (14 August 2026 — 0.25.4.154 / RECURSIVE + signed SIZEOF + lean prelude)

### `RECURSIVE` required on direct self-calls **Done**

- A call whose `resolved_sym.decl` is the enclosing `NODE_PROC_DECL` / `NODE_FUNC_DECL` is a **direct self-call**. The completing declaration (the one with the body) must have `RECURSIVE`.
- Field call-through (`resolved_sym` nil) and the unit `NODE_PROGRAM` body are not treated as self-calls. Mutual recursion is not checked (later analyzer).
- Tag belongs on the **body** decl after `FORWARD` refine (`symtab_refine_symbol` replaces the symbol).
- Sweep: `semantic.mc`, `ttype.mc`, `expression.mc`, and other compiler `.mc` self-calls tagged.
- **Tests:** `tests/test3_recursive.mc`; positive: `test_FactorialDemo` / `test_FibonacciDemo`.

### `SIZEOF` is `integer` in C as well as in the type system **Done**

- Semantic type was already `integer`. Emit is now `((integer)sizeof(...))` in `codegen_common_sizeof_expr` (headers and `-C`).
- Follows the unit’s `integer` typedef (default `int`; rebind applies when that typedef is in scope).
- **`LEN`** not emitted yet — same type and cast when implemented.
- Design lock (not implemented as a hard mix-ban yet): lengths / indexes / `SIZEOF` / `LEN` are **signed** (`integer`); `cardinal` is for bits / wrap / C unsigned ABI; `size_t` stays an imported C name.

### Lean generated C prelude **Done** (partial; `<stddef.h>` stays until 0.26)

Automatic includes: `<stddef.h>` (`NULL`, `size_t`), `<stdint.h>` (`uint8_t`), `<stdbool.h>`, `<assert.h>`.  
`typedef uint8_t byte;` — `#define nil NULL` / `#define NIL NULL`.  
Portable four typedefs unchanged. **No** automatic `<stdlib.h>` / `<stdio.h>` / `<string.h>` / `<math.h>` / `<limits.h>` / `<float.h>`. `exit` and friends must be imported. Tests, examples, and `src/*.mc` updated.

**Verification:** `make test-all`, **selfhost**, **bootstrap** green on **gcc**, **clang**, and **tcc**. Promoted **0.25.4.154**.

~~**0.26:** drop `<stddef.h>` / require every non-builtin name~~ — **Done (0.26.0–0.26.1)**. Next: `.mh` field lists.

## Recent Accomplishments (12 August 2026 — 0.25.3.150 / 7a module-entry bind)

### Item **7a** — Module entry as a real symbol **Done**

- **Same-unit:** `MODULE` name is registered as `PROC`/`FUNC` after pass 1; `sym.decl` is a synthetic `NODE_PROC_DECL` / `NODE_FUNC_DECL` whose `PARAM_LIST` aliases `program_decl.params` so existing auto-`&` applies (`test_module_ref(b, 1)` needs no `@`).
- **Import:** any **named** import from an `.mh` also binds the `@module` unit-entry export (skip if already in scope or no matching export; include-only `import from "x.mh"` unchanged). `PROGRAM` names are not bound.
- **Names:** `.mh` strings are arena-copied in `semantic_bind_mh_export` before `mh_module_free` (auto-bound constructor names must not dangle).
- **Callee ABI (same arc):** module/program `emit_param_list(..., true)` so `VAR`/`REF` formals lower to `T*` (Lexer `module Lexer(ref lexer: TLexer, …)`).
- **Tests:** `tests/test_module_ref.mc`; `tests/test_module_entry.mc` + `tests/fixtures/bumpint.mh` / `include/fixtures/bumpint.h` (`import TBump` only; `bumpint(n)` auto-bound + auto-`&`). **make test** green on **gcc**, **clang**, **tcc**.
- **Not 7b** — no generated startup calls of imported module bodies. **7b cancelled** 31 August 2026 (explicit 7a calls only).

## Recent Accomplishments (11 August 2026 — 0.25.3 / formal signatures + cross-module auto-`&`)

### Item **6a** — `.mh` formal signatures **Done**

- **Writer (`codegen_mh`):** one-line `@format 1` tails — `( [var|ref|const] type-spec { , … } ) [ : result ]`; surface type names preferred (aliases like `long_long`); multi-word C spellings only when written that way.
- **Reader (`mh_reader`):** `MhFormal` / `has_signature` / result fields; multi-word type-spec (`long long`, `unsigned int`); free formals on unload.
- **Import (`semantic`):** synthetic `NODE_PROC_DECL` / `NODE_FUNC_DECL` + param list from export (arena-copied strings); `sym.decl` is the synthetic node so existing codegen auto-`&` applies cross-module.
- **Phase A (0.25.2) retained:** `instance`/`static` Owner; `import Type::name`; `is_method_instance`; `obj.method` across modules.
- **Tests:** `tests/test5_mh_method_import_string.mc` (`-a`); `tests/test4_string.mc` + **`make string-lib`** (link `libtmod_string.a`); auto-`&` on `sb.free()` / `TStringBuffer::free(sb)` without `@`. Not wired into default `make test` (needs `include/*.mh` + archive).
- **Then still deferred:** field lists / complete struct export; field call-through across modules; **7b** (later **cancelled**); `^T` instance receivers. Field lists / call-through **Done** 0.26.3–0.26.4.

## Recent Accomplishments (11 August 2026 — 0.25.2 / cross-module methods Phase A)

### Cross-module `Type::method` / `obj.method` **Done (Phase A)**

- **`.mh` writer (A1):** type-bound exports emit optional `instance Owner` / `static Owner` after completeness (still `@format 1`).
- **`.mh` reader (A2):** `MhExport` stores `is_method`, `is_instance`, `method_owner` / `method_owner_len`.
- **Import (A3):** `import-item` may be `Type::name` (or mangled `Type__name`); lookup mangled export; bind mangled name (or `AS` alias); set `TSymbol.is_method_instance`.
- **Semantic (A4):** `obj.method(...)` treats `sym.is_method_instance` like same-unit instance methods.
- **Module entries** (`String(...)`, `StringBuffer()`): ~~free-call soft-miss~~ — **7a Done (12 August)**.
- Superseded for formals by **0.25.3** (above).

## Recent Accomplishments (7 August 2026 — 0.25.1 / callable fields)

### Callable field call-through **Done**

- **`obj.field(args)`** when `field` has a **method type** (`TYPE T = PROCEDURE/FUNCTION …`) → C `(obj.field)(args)`; **no** auto-receiver (Oberon procedure variables).
- **Disambiguation:** instance `Type::name` vs method-typed field — if both apply, **compile-time error** (use `Type::name(obj, …)`).
- **Locals / params:** `fp(args)` when `fp` is `VAR` / `PARAM` / `LET` (or `CONST`) of method type.
- **AST / codegen:** `call.callee_expr` for call-through; instance sugar still uses `receiver_expr` prepend.
- **Semantic:** `semantic_method_type_node`, `semantic_field_type_on`, `semantic_sym_is_method_value`; `semantic_resolve_call` reclassifies dot-calls.
- Tests: `tests/test_callable_field.mc`, `tests/test3_callable_field_ambig.mc` (as applicable); **`tests/test_Math.mc`** — struct “object” with method-typed fields + `Type::create` / module entry as factory (compile-time only; no vtables).
- **make test-all**, selfhost / bootstrap / promote as verified by user; **gcc** / **clang** / **tcc** green.
- Still deferred: first formal `^Owner` as instance; `^T` / `VAR` self auto-`&` on instance methods. Parent-chain lookup **Done (0.26.5.180)**.

## Recent Accomplishments (6 August 2026 — 0.25.0 / item 20)

### Item 20 — VAR / REF / CONST formals **Done (breaking)**

- **Only `VAR`** may use the bare formal name as LHS of `:=` / `INC` / `DEC`.
- **`REF`:** through-designator writes OK (`p.x`, `a[i]`); bare-name assign **illegal** (scalar `REF n: integer` is effectively read-only for updates).
- **`CONST`:** deep freeze — no write through the formal root (name, fields, indices).
- **Bare formals:** no bare-name assign; still largely by-value in C (not full Oberon “default REF”).
- **Codegen:** non-pointer `VAR`/`REF` → `T*`; `REF ^T` → one `*`; `VAR ^T` → `T**`; call-site auto-`&` for by-ref value formals (`Swap(x, y)`).
- **Self-host:** scratch mutation of non-`VAR` formals uses locals (`arena` / `semantic` / `utils`, etc.).
- Tests: `test_var_ref`, `test_var_pointer`, `test_const_param`, `test3_var_ref*`, `test3_const_param*`, `test3_var_pointer*`; **make test-all**, **selfhost**, **bootstrap**, **promote** green.
- Soft spot: named open-array typedef as `REF`/`VAR` formal (prefer true open-array type-specifiers until alias chase).
- Docs: Language Report §8.2; `docs/grok_report-20260806-2042.md`.

## Recent Accomplishments (6 August 2026 — 0.24.18 / #11 Phase A)

### Item #11 Phase A — portable builtin unit rebind **Done**

- Only the four Wirth-family names may be **bound once per compilation unit** via top-level `TYPE`: **`integer`**, **`cardinal`**, **`real`**, **`string`**.
- Unbound defaults in generated C: `int`, `unsigned int`, **`float`**, `const char *` (portable names remain the typedef *aliases*; C names are not rebindable prelude slots).
- `type_is_portable_rebindable`; semantic first-bind refines prelude (`decl == nil`); second bind and rebind of fixed builtins (`bool` / `byte` / `char` / C-ish prelude names) are errors.
- Codegen skips the default `typedef` for a portable name when the unit supplies a complete `TYPE` binding.
- Tests: `tests/test_rebind.mc`, `tests/test3_rebind_second.mc`, `tests/test3_rebind_bool.mc`; suite green.
- **Width forms Done (0.26.5).** **Import-as-bind and `.mh` width tails Done (0.26.5.174).** **Still open (same item #11):** architecture packs (`tmodc.lp64`, …); compiler-build default selection; optional `.mh` alias RHS.

### `type Name FORWARD` (0.24.17.135) **Done**

- Incomplete type in-unit: `type TString forward` then complete with `type TString = …`.
- Completes prior incomplete TYPE via symtab refine (same family as proc postfix `FORWARD`).
- Codegen: incomplete tag/typedef as needed; method-type typedefs ordered after layout types where required for C.
- Tests: `tests/test_type_forward.mc`, `tests/test3_type_forward_dup.mc`, `tests/test3_type_forward_reforward.mc` (as applicable).

## Recent Accomplishments (3 August 2026 — 0.24.17 / item 21)

### Item 21 — `obj.method` + instance vs static **Done**

- **Instance sugar:** `obj.method(args)` → `Type__method(obj, args…)` when static type of `obj` is `Type` and the method is an **instance** method.
- **Always available:** `Type::method(args…)` (Phase 1 since 0.23.9).
- **Instance vs static** (first formal type only; formal name free, Oberon-style):
  - **Instance:** first formal’s type is the owner type → `Type::m(obj, …)` and `obj.m(…)`.
  - **Static / factory:** no formals, or first formal type ≠ owner → **`Type::m(…)` only** (e.g. `Point::new(x, y)`; `p.new(…)` is an error).
- **Statement path:** designator + postfix chain (calls, `.`, `[]`, `^`) so `p.print()` and `b.topLeft().print()` work as statements.
- **Optional `end` tags:** `end`, `end name`, `end Type::name` (`parse_optional_end_tag` in `parse_block`).
- Helper: `semantic_method_is_instance`; codegen prepends `receiver_expr`.
- Tests: `tests/test_smoke.mc`, `tests/test3_smoke.mc` (static via `.` fails); **make test-all** green on **gcc**, **clang**, **tcc**.
- ~~Callable field call-through~~ — **Done (0.25.1)**. ~~Parent-chain method lookup~~ — **Done (0.26.5.180)**. Still deferred: first formal `^Owner` as instance.

## Recent Accomplishments (1 August 2026 — 0.24.16 / auto-upcast)

### EXTENDS by-value auto-upcast **Done**

- Child (or further descendant) used where an ancestor is required → C **`.base` × N** (option A); not a blind struct cast.
- `Node.upcast_depth`; `semantic_extends_upcast_depth` / `semantic_maybe_upcast`; sites: typed init, `:=`, `RETURN` (`enclosing_func`), same-unit call formals.
- Codegen: `codegen_common_expr` appends `.base` after the expression when depth &gt; 0.
- Multi-level verified (e.g. `Grand` → `Parent` = two `.base` steps). Tests: `tests/test_extends.mc`.
- **Deferred polish (1 August):** pointer/`REF` upcast; aggregate `as` → `.base`; `^T` parent fields (`c5^.x`). **Closed 0.26.5.175.** Oberon `p.x` auto-deref **Closed 0.26.5.176.** `p[i]` peel and instance method on `^T` **Closed 0.26.5.178.** Parent-chain methods **Closed 0.26.5.180.** Still later: cross-module formals (richer `.mh`); hard assignability errors.
- **Design lock:** no compiler-inserted type tags / vtables; programmer may add tags manually (enum+union style). No Oberon `IS` without opt-in runtime identity later.

## Recent Accomplishments (31 July 2026 — 0.24.16 / declaration self-host)

### Self-host: `declaration.c` → `declaration.mc` **Done**

- Converted declaration parsing to **`src/declaration.mc`**; generated **`declaration.c`** (and paired header / `.mh` as in the build).
- Hand-authored **`declaration.c`** replaced by compiler output from the `.mc` source.
- Conversion cleanup: stale comments removed; most obsolete **receiver** parse path dropped (type-qualified methods own that story).
- Version **0.24.16 (build 130)**; **make test-all** green on **gcc**, **clang**, and **tcc**.

## Recent Accomplishments (29 July 2026 — 0.24.15 / 13b)

### Item 13b — discard enforcement (Policy A) **Done**

- Bare `NODE_CALL` as `NODE_EXPR_STMT`: if `semantic_type_of_expr` yields a **known** result type → fatal; require `(f())` or use the value (`x := f()`, arg, …).
- **Unknown** result (procedure, untyped foreign import such as bare `printf`) → bare call still allowed.
- Explicit discard: `(expression)` / `(f())` (`NODE_PAREN`) always allowed as a statement.
- Tests: `tests/test_discard.mc`, `tests/test3_discard.mc`; **make test-all** green on **gcc**, **clang**, and **tcc**.
- Optional later (then): discard binding `_` (item **24**). **Dropped (12 October 2026).** Thin wrapper procedures if an API later gains a known result and callers never care.

## Recent Accomplishments (29 July 2026 — 0.24.14 / 21a)

### Item 21a — `type_of_expr` + simple init inference **Done**

- **`semantic_type_of_expr`** — thin expression typing (not full type-check / not Hindley–Milner).
- Coverage: literals; designators; paren; cast; sizeof; call return type; unary `-` / `not` / `~` / `@` / `^`; binary arith / bitwise / logical / compare; real arith.
- **Init inference** — when `:` is omitted on `VAR` / `LET` / `CONST`, type from initializer; error if unknown.
- Tests: `tests/test_infer.mc` (and related); suite green.
- **Deferred polish (then):** ternary `cond ? a : b` (and array-literal) typing — item **21a-ternary**. Ternary **Done (0.26.10.203)**. Array-literal typing still open.
- Unlocked: ~~**13b** discard~~ **Done (0.24.15)**; still open: EXTENDS auto-upcast, **21** `obj.method`, **20** `VAR` formals.

### Design (same period)

- Portable builtins Option A locked in Language Report §5.5 / §10.1 (not implemented).

## Recent Accomplishments (28 July 2026 — 0.24.14)

### Self-host: `lexer.c` → `Lexer.mc` **Done**

### Self-host: `lexer.c` → `Lexer.mc` **Done**

- Converted the full tokenizer to **`src/Lexer.mc`** (module `Lexer`); generated **`Lexer.c` / `Lexer.h` / `Lexer.mh`**.
- Hand-written **`lexer.c` / `lexer.h`** replaced; capital **`Lexer`** module name matches self-host naming for large units.
- Exports include **`TokenKind`** enum, **`TToken` / `TLexer`**, **`TLexer::init` / `TLexer::next`**, **`TokenKind::string`**, **`TToken::print`**.
- Keyword table includes **`OPAQUE`** (spelling fixed vs older `OPQAUE` typo note).
- Version **0.24.14 (build 125)**; self-host / bootstrap path exercises the lexer as TMod-c source.

### Related (same period — exploratory, not calm-path)

- Experimental **`src/String.mc`** — `TString` wrapper for const C strings; documents deferred **`type … forward`**, callable fields, and future **`obj.method`** / builtin **`string`** direction.
- Discussed: callable function-pointer fields vs **`Type::method`** / planned **`obj.method`** (item **21** after **21a**); neither call path fully enables vtable-style dispatch yet.

## Recent Accomplishments (25 July 2026 — 0.24.13)

### Item 13d — `STRUCT EXTENDS` option A **Done**

- Oberon model: unique field names on the extension chain; flat `c.x` in TMod-c source.
- C option A: embed `Parent base` at offset 0; field rewrite via `field_access.base_depth` → emit `.base` × depth.
- Synthetic `base` for explicit parent value (`c.base`); **reserved only on types that use `EXTENDS`** (plain structs may use a field named `base`).
- Semantic: `semantic_find_field_depth`, `semantic_type_of_designator` (designator-only), clash / base-must-be-struct checks.
- Tests: `tests/test_extends.mc` (multi-level + `c.base`); `test3_extends_clash.mc`; `test3_extends_base_reserved.mc`; existing `test2_extends.mc`.
- Auto-upcast child → parent still deferred (needs **21a**).

### Infrastructure — linked-chunk arena **Done**

- Replaced single-slab `realloc` growth (ASan UAF when analyzing large units such as `semantic.mc` with `-a`).
- `ArenaChunk` list: never relocate live slabs; `arena_alloc` zeros returned bytes; `calloc` for new chunks; `ARENA_MIN_SIZE` = 1 MiB default.
- Stress-tested with small min size (multi-chunk creates); production min restored to 1 MiB.

## Recent Accomplishments (23 July 2026 — 0.24.12)

### Item 13c — bare `UNION` types **Done**

- `type Value = union … end` on TYPE RHS (sibling of `STRUCT`).
- Lexer `TOK_KEYWORD_UNION`; `struct_decl.is_union`; `parse_union_type`; no `EXTENDS` / no `PACKED` in v1.
- Semantic resolves field types; rejects `EXTENDS` on unions.
- Codegen: **`codegen_common_union_decl`** → C `union` (separate from struct emitter for consistency).
- Nested use: define named type first, then field type = name (no anonymous nested unions yet). Anonymous nested `union` … `end` is **0.27.4.228**.
- Tests: `tests/test_union.mc`, `tests/test3_union.mc` (and related); full suite green on gcc, clang, tcc.

### Item 13a — `OPAQUE` types **Done** (0.24.11.x)

- End-to-end: `type T = opaque`, `^opaque`, `POINTER TO opaque`; C `typedef void *Name`.
- Bare `opaque` in type-specifier rejected (`test3_opaque_parse.mc`).
- Note: unknown type *names* still allowed as possible foreign C types (pre-existing policy).

### Design discussion (future — not implemented)

- Language-level **tagged unions** / ADTs (constructors + match/`is`) explored as pseudocode; distinct from bare `UNION`. Manual pattern remains: enum tag + struct + union (as in compiler `Node`).
- Embed of struct/union in another: name the nested type first, then use as field type. Anonymous nested `union` … `end` is **0.27.4.228**. A nested struct stays a named type.

## Recent Accomplishments (0.24.11 — `expression.mc`)

### Self-host: `expression.c` → `expression.mc`

- Converted **`src/expression.mc`**; compiles; all tests run; promoted through 0.24.11.x builds.

## Recent Accomplishments (18 July 2026 — design + self-host)

### Self-host: `statement.c` → `statement.mc` (0.24.10.110)

- Converted **`src/statement.mc`** (paired `.c` / `.h` / `.mh` as needed).
- Full rebuild, test suite, self-host, bootstrap, and promote — **green** at **0.24.10.110**.

### Design — no user-facing `void`; `OPAQUE` types

- Prefer **procedure vs function** (no result type) over a void return type.
- **`type T = opaque`** — named type with no language-visible layout (Wirth-style; Windows-style handles as user-chosen names).
- **`type address = ^opaque`** (or `POINTER TO opaque`) — C `void *` equivalent via **user-defined** alias, not a baked-in `void`.
- **`OPAQUE` only on TYPE RHS** (`opaque-type-expression`); not in `type-specifier` (`var x: opaque` illegal — name first).
- Distinct from **`type T FORWARD`** (incomplete, completed later in-unit) and from **`.mh`** completeness flag `export type name opaque`.
- Reserved keyword **`OPAQUE`** replaces **`OBJECT`** (Language Report + `syntax-ebnf.md`).

### Design — explicit discard of function results **Implemented (0.24.15 / 13b Policy A)**

- Grammar: **`expr-statement = "(" expression ")"`** — intentional drop of a result.
- **Policy A:** bare call as statement illegal when result type is **known**; require `(f())` or use the value. Unknown result / procedure → bare OK.
- C source / generated C may use **`(void) call(...)`**; TMod-c source uses parentheses, not a cast-to-void type.
- Item **24** (`_`) still deferred — distinct sugar from `(f())`.

### Grammar + lexer groundwork

- **`docs/language-report.md`** + **`docs/syntax-ebnf.md`** — SSOT split (18 July 2026); `OPAQUE` in report + EBNF; former `grammar.md` archived as `grammar_working_notes.md`.
- **`TOK_KEYWORD_OPAQUE`** — keyword table now lives in **`src/Lexer.mc`** (self-hosted 0.24.14); spelling is **`OPAQUE`**.

### Prior same line (0.24.9)

- **`symkind.h` → `symkind.mc`**, **`mh_exportkind.h` → `mh_exportkind.mc`**.

## Recent Accomplishments (16 July 2026 — 0.24.8)

### Named `CONST` in array bounds

- **`array[LIMIT] of T`** and **`array[LIMIT+1] of T`** when `LIMIT` is a compile-time integer `CONST` (and general integer const-exprs).
- **`TType.size_expr`** — parser stores unevaluated bound; semantic folds to `array_size` in place before codegen (`char l[100]`, not open `l[]`).
- **`type_create_array_expr`**; parser paths for `array[…] of T` and suffix `T[…]`.

### Integer const-eval (shared)

- **`semantic_try_eval_const_expr`** — soft fold; optional `msg` out-parameter for distinct errors; `nil` msg for quiet non-integer `CONST`.
- **`semantic_eval_const_expr`** — thin fatal wrapper over try (single implementation).
- **`CONST` registration** — `has_const_value` only when integer fold succeeds; string/pointer `CONST` (e.g. `const c2: ^char = "bye"`) unchanged.
- **`TOK_MOD` / `TOK_KEYWORD_MOD`** both accepted in const-exprs.
- Review fixes: fallback error message when hard eval fails without msg; `semantic_register_var_decl` error string.

### Release process

- Version **0.24.8.104**; rebuilt, tested, self-hosted, bootstrapped, and promoted.

## Recent Accomplishments (15 July 2026 — 0.24.7)

### ENUM Phase C

- **`MH_KIND_ENUM`** in `mh_exportkind.h`; `.mh` writer emits `export enum Type complete` plus `export const Member complete` lines per member.
- **`mh_reader`** parses `export enum`; maps to `SYM_KIND_TYPE`; cross-module enum import via explicit item list.
- **Tests:** `tests/test_mh_enum_export.mc`, `tests/test2_mh_enum_import.mc`, `tests/test_mh_enum_import.mc`; fixtures `tests/fixtures/colors.{mh,h}`.

### `.mh` negative import tests

- Tier-3 **`test3_*`** convention: each `tests/test3_*.mc` runs through `modc -a`; **non-zero exit = pass**.

### Test include paths (Makefile)

- **`INCLUDE_DIR`** (`include/`) with `include/fixtures` → `tests/fixtures/` symlink; **`CFLAGS`** adds `-I$(SRC_DIR) -I$(INCLUDE_DIR) -I$(LIB_DIR)` so generated `#include "fixtures/…"` and experimental `tmodc.h` resolve in tier-1 host C builds. Test-harness aid — not a substitute for item 15 (subdir compilation). Host compiler is **`CC`** (default gcc; `CC=clang` / `CC=tcc`).

### Design — `WHILE … BY` not planned

- Iteration step at loop head via **`defer`** (see `tests/test_defer.mc`); documented in `docs/grammar.md`.

## Recent Accomplishments (14 July 2026 — 0.24.6)

### ENUM Phase A/B

- **`TYPE name = ENUM … END`** — parse (`parse_enum_type`), semantic (`semantic_register_enum_type`, `semantic_eval_const_expr`), codegen (`codegen_common_enum_type` → C `typedef enum`).
- **`TSymbol.const_value`** for enum member integers; duplicate-member error.
- **Tests:** `tests/test2_enum_parse.mc`, `tests/test_enum.mc`, `tests/test3_enum_dup.mc`.
- Phase C completed in **0.24.7** (see above).

### `tmodc` ABI prelude (planned)

- Experimental **`src/tmodc.h`** for hand-written C including generated headers.
- Target: **`tmodc.mc` → `tmodc.h`** system module (width types, `nil`); multi-TU `#include` instead of inlined prelude.

### TMod-c rebrand (documentation)

- Public project/language name: **TMod-c** (TYPE compiler; Pascal `T` prefix alignment).
- Target compiler binary: **`tmodc`**; **Mod-c** / **`modc`** retained as legacy aliases during transition.
- **Docs:** `docs/grammar.md`, `CURRENT.md`, `changelog.md`, `AGENTS.md`, `docs/grok_report-20260714-1939.md`; append `docs/project_bible.md`.

## Recent Accomplishments (13 July 2026 — 0.24.5)

### Qualident `IMPORT … FROM`

- **`import-source = string-literal | qualident`** — parser, semantic, and codegen.
- **Unquoted qualident** names a Mod-c module: dots → slashes, `.mh` for symtab, paired `.h` for `#include`.
- **Quoted string** unchanged for foreign/C and explicit `"path.mh"` paths.
- **Path resolution:** relative to compiling `.mc` file directory (project-root `src/` search paths still deferred).
- **`mh_reader`:** `mh_qualident_to_mh_relpath`, `mh_format_h_include`; updated `mh_path_is_mh`, `mh_resolve_import_path`.
- **Tests:** `tests/test2_mh_import_qual.mc` (qualident form of `fixtures.minimod`).
- **`docs/grammar.md`** updated (0.24.5).

## Recent Accomplishments (11 July 2026 — 0.24.4)

### `codegen_header.mc` (self-host)

- **`src/codegen_header.mc`** — converted from `.c`; behaviour unchanged (minor release **0.24.4**, not 0.25).

## Recent Accomplishments (9–10 July 2026 — 0.24.3)

### Import sources — documented (phase 1 vs phase 2)

- **`IMPORT FROM "path"`** — include-only form in grammar (optional empty item list); not `IMPORT *`.
- **Two worlds:** quoted string = foreign/C; unquoted **qualident** = Mod-c module (`utils.dynbuf` → `utils/dynbuf.mh` + `#include "utils/dynbuf.h"`). *Qualident `FROM` implemented 0.24.5.*
- **Quoted paths** still valid for foreign/C and explicit `"codegen_header.mh"` spelling.
- **Still deferred:** project-`src/`-root paths, `import * from M.N` bulk `.mh` import; blocked until subdirectory compilation in Makefiles.
- **Policy:** paths and identifiers **case-sensitive**; generated C **`#include`s `.h` only**, never `.mh`.
- **`docs/grammar.md`** — full *Phase 1* / *Phase 2* import section.

### EOS / layout (expressions, statements, RETURN)

- **`parse_unary`** — `skip_layout_breaks` at entry; trailing operators (`or`, `and`, `+`, …) may continue on the next line.
- **`consume`** — calls `skip_layout_breaks` before matching; **`match`** unchanged (EOS / `matchEOS` must see `NEWLINE` as-is).
- **`RETURN`** — newline after bare `return` **ends** the statement; multiline return **values** use `(...)`. No layout skip before optional expression (avoids swallowing the next statement).
- **Unreachable code** — statements after `RETURN` / `BREAK` / `CONTINUE` in the same sequence → **fatal error** (was warning); dead nodes still excluded from AST.
- **Tests:** `tests/test_layout.mc` (tier-1 smoke); `tests/test3_loop.mc` (tier-3: unreachable after `break`/`continue`).

## Prior — 0.24.3 (9 July 2026)

### Builtin `integer` / `cardinal` lowering

- **`integer`** lowers to C **`int`**; **`cardinal`** to **`unsigned int`** (Oberon-like everyday types on typical LP64 targets — **not** pointer-sized).
- Changed in **`codegen_c`** prelude typedefs; verified with **`make test-all`** on gcc, clang, and tcc (no new errors/warnings).
- **`printf`:** `%d` / `%u` match Mod-c `integer` / `cardinal` on LP64. For `size_t` or pointer-sized values, use C imports or future width-qualified types.
- **`docs/grammar.md`** updated (0.24.3): builtin policy, generated width typedefs (`int8`…`uint64`), EOS rules.

### Parser / layout (9 July — import/decl)

- **End-of-statement rules** documented; **`IMPORT … FROM`** anchor layout; `skip_layout_breaks` for multi-line import/declaration lists.
- **`tests/test_import_layout.mc`** — multi-line `import` / `var` layout smoke test.

## Prior — 0.24.2 infrastructure (9 July 2026)

### Three-tier test targets (gcc / clang / tcc)

- **`test`** — `test_*`: modc compile → host C compile → run; stdout to `/dev/null`; summary `N run, M failed`; includes `test_Pi` diff check.
- **`test2`** — `test2_*`: `modc -a` semantic pass expected; counted summary.
- **`test3`** — `test3_*`: negative tests — **non-zero exit = pass**; counted summary.
- **`test-all`** — runs all three tiers; **`dist`** depends on `test-all`.
- **Then (0.24.2):** three files (`Makefile`, `Makefile.clang`, `Makefile.tcc`). **Now (31 August 2026):** one **`Makefile`**, `CC=gcc|clang|tcc`; old files in **`archive/`**.

### Negative test fixtures (`test3_*`)

- `tests/test3_dup.mc` — duplicate declaration
- `tests/test3_undef.mc` — undefined identifier
- `tests/test3_for_assign.mc` — invalid `for` assignment
- `tests/test3_let_over_var.mc` — `let` over `var` conflict
- `tests/test3_loop.mc` — unreachable code after `break` / `continue`

### Version / build numbering

- **`make version`** — manual only; increments `src/build.number` and regenerates `src/c/version.h`.
- **`BUILD_NUMBER`** stored in **`src/build.number`** (survives `make clean`, which removes `bin/` and `build/`).
- Modc displays **`0.24.12 (118)`** style (release stem + build in parentheses); generated headers use **`VERSION_BASE`** only.

### Project housekeeping

- **`AGENTS.md`** refreshed at repo root (canonical agent instructions); duplicate `.grok/AGENTS.md` removed.

## Prior Release — 0.24.0 (7 July 2026)

### `.mh` module linking — items 7–8

Cross-module Mod-c imports work end-to-end: `EXPORT` emits `modc-mh/1` tables; `IMPORT … FROM "*.mh"` loads them at semantic analysis; generated C `#include`s the associated `.h`.

- **Writer:** `src/codegen_mh.mc` — `TARGET_MH`, `-M`, auto-emit with `-C`.
- **Reader:** `src/mh_reader.mc` — parse `modc-mh/1`; `semantic_register_import` loads real symbol kinds from `.mh`.
- **Codegen:** `codegen_common_import` — `.mh` imports emit `#include "…h"`.
- **Semantic fix:** `NODE_IMPORT_ITEM` branch in `semantic_resolve_type_inner` for `.mh` type imports.
- **Module entry:** `mh_emit_unit_entry()` emits `module` proc/func in `.mh` export table.
- Tests: `test_mh_export.mc`, `test2_mh_import.mc`, `fixtures/minimod.{mh,h}`.

Self-host in progress: `src/*.mc` modules import from corresponding `.mh` files.

## Design Decisions (still in force)

See **`docs/language-report.md`** (prose) and **`docs/syntax-ebnf.md`** (full EBNF). Filenames use hyphens (no `_`; `syntax-ebnf.md` not `syntax.ebnf.md`). Former monolithic `docs/grammar.md` is a redirect; archive in `docs/grammar_working_notes.md`. Highlights:

- **`.mh` / `.h` split** — `.mh` for modc semantics (export table); `.h` for C ABI (`#include` in generated C). Same stem/path layout rule.
- **Import sources** — quoted `"stdio.h"` / `"symbols/foo.h"` = foreign; unquoted qualident (`symtab`, `fixtures.minimod`, `codegen.codegen_header`) = Mod-c module (0.24.5). Resolution relative to compiling unit directory; project-root `src/` search paths deferred. `import from "…"` / `import from M.N` = include-only, no symtab. `import * from …` = bulk `.mh` import (deferred). **Package path (Done 0.26.12.212)** — the unit qualident's last identifier is the unit name. An unquoted import is one directory file from that unit's package root (Language Report §3.1.1). **Type call (Done 0.26.12.212)** — `Ident(...)` on a declared type is `Ident::Ident(...)` (§8.3). The keyword `opaque` is not that call.
- **`HEADER` unit (Done 0.26.11.208)** — `header Name` … `end`. No parameters, no return type, no `BEGIN`. Prototypes only. No `.c` file. `-C` writes the `.h`. An `.mh` is written only with `-M` (**0.27.2.222**). No unit-entry export. `@module` still names the unit. See Language Report §3.1.
- **`EXTERN`** — prefix only; never a body in this unit; refines `IMPORT`.
- **`FORWARD`** — postfix on proc/func; **`type ident FORWARD`** incomplete types **Done (0.24.17.135)** (complete later in the same unit).
- **Blocks** — `extern … end` / `forward … end` **parked indefinitely (19 October 2026).** Per-line `extern`, postfix `forward`, and `type T forward` stay.
- **`CONST` declarations** — compile-time named constants (Pascal/Oberon); not C read-only objects; block-head with `VAR`, not mid-block like `LET`. **`LET`** — runtime rebind lock (**Done 0.26.5.181**); through-writes legal (rule 2 / `REF` body). **No C `const` on LET locals (Done 0.26.5.183).** `@` of `LET` / declaration `CONST` illegal (**183**). Parameter **`CONST`** — deep read-only qualifier, not compile-time `CONST`. Unbound **`string`** = **`const ^char`**. Lowering stays C `static const`; preprocessor constants use **`DEFINE`**.
- **`CONST` codegen** — C `static const` objects (unchanged). Integer **values** fold for array bounds via `has_const_value` (0.24.8). C `#define` names are **`DEFINE`**, not a `CONST` rewrite (item 19 demoted 12 September 2026).
- **`DEFINE` (Done 0.26.5.188; `=` required 0.27.1.216)** — `define Name = replacement` and `define Name(params) = replacement`. The `=` is required and is omitted from `#define`. A `(` with no space after the name selects the function-like arm. `#define` pass-through still does **not** enter the symbol table. Feature-test macros stay `-D` on the Makefile. The 0.26.5.188 rest-of-line form is a parse error. See [DEFINE equals (0.27.1.216)](#future-plan-define-equals-027).
- **No user-facing `void`** — **`OPAQUE` implemented (13a):** TYPE RHS `opaque` / `^opaque` / `POINTER TO opaque` names an alias (`typedef void *Name`). **0.26.9.200:** `^opaque` and `POINTER TO opaque` are also type-specifiers (`void *`; `const ^opaque` is `const void *`). Bare `opaque` stays a TYPE RHS. Procedures have no result type.
- **Discard (13b Policy A — Done 0.24.15)** — `(expression)` as statement; bare call only when result type unknown; known results require `(f())` or use. C may lower with `(void)`.
- **`OPAQUE` vs `.mh` `opaque`** — source type constructor vs export completeness flag (same word, different grammars).
- **`STRUCT EXTENDS`** — Oberon-shaped record **layout** (single base at offset 0, unique field names, flat `c.x` in source); C lowering **option A** (`Parent base;`, emit `c.base.x` for parent fields). Synthetic `base` reserved **only on EXTENDS** types. Not class/vtable; **no hidden RTTI**. See Language Report §5.4.0. **13d Done (0.24.13)**; **by-value auto-upcast Done (0.24.16)**; **`p^.x` / `as` → `.base` / pointer·`REF` upcast Done (0.26.5.175)**; **Oberon `p.x` auto-deref Done (0.26.5.176)**; **`p[i]` peel + instance on `^T` Done (0.26.5.178)**; **`Type::m(p)` peel Done (0.26.5.179)**; **parent-chain methods Done (0.26.5.180)**.
- **`type_of_expr` / init inference (21a)** — **Done (0.24.14)**. Ternary/`? :` typing **Done (0.26.10.203)**. Brace-list inference still open.
- **Bare `UNION`** — C overlapping members; `codegen_common_union_decl`; no EXTENDS; not language-level tagged unions. A nested struct is a named type used as a field type. An anonymous `union` … `end` promotes its members into the enclosing struct or union (**0.27.4.228**).
- **Arena** — linked chunks (pointer-stable); no whole-buffer `realloc` of live AST/symtab storage.
- **Portable builtins (Option A — Phase A Done 0.24.18; widths Done 0.26.5; import-bind / `.mh` widths Done 0.26.5.174; alias RHS / packs Done 0.26.8.194)** — Only `integer`, `cardinal`, `real`, `string` may be **bound once per compilation unit** via top-level `TYPE` **or** a named `.mh` import of that name. Unbound → defaults `int` / `unsigned int` / `float` / `const char *` (`cint`). Width forms **`integer N` / `cardinal N` / `real N`** are exact, RHS-only constructors (closed *N*); `.mh` type-spec may carry the same tail; **alias RHS** `export type integer complete integer 64`. Packs: `tests/fixtures/lp64`, `ilp32`. **Parked indefinitely (12 October 2026):** build-time defaults, until another architecture can prove `TMODC_ARCH`. Not C rank. See Language Report §5.5 / §10.1.
- **`RECURSIVE` (0.25.4)** — required on a **direct** self-call (same PROC/FUNC node as `enclosing_func`). Review/lint flag for JPL rule 1; mutual recursion not checked.
- **`SIZEOF` (0.25.4)** — TMod-c type `integer`; C emit `((integer)sizeof(...))`. Not C `size_t`.
- **`COUNTOF` (0.26.9.198)** — `countof(designator | type)`; outermost bound of a complete fixed array; type `integer`; folded `((integer)N)`. `len` is an identifier. Pointers, scalars, `string`, and open arrays that are not slice formals are errors. A slice formal's `countof` is the hidden length (**0.27.1.219**). Replaces interim **`LEN` (0.26.8.194)**. Not string length.
- **Generated C prelude (0.26.1 / 0.26.5)** — `<stdint.h>` `<stdbool.h>` `<assert.h>` only; `byte` = `uint8_t`; `#define nil ((void *)0)` / `#define NIL nil`. No automatic `<stddef.h>`. **0.26.5:** prelude and unit prototype live in the generated `.h`; `.c` includes `"Unit.h"`; `-C` writes a companion `.h`.
- **Name soft-miss** — **closed.** Calls **0.26.0**; types **0.26.1**.
- **Cyclic TMod-c `IMPORT` (later)** — known from parser split (0.26.3). Address after **item 15**. See Language Report §3.2.
- **Identifiers ≤ 255 (0.26.3.170)** — lexer / `.mh` error if longer. Mangled `Owner__name` may be 512. See Language Report §2.2.
- **`.mh` type layouts (0.26.3.170 / 0.26.4 / 0.26.5.174 / 0.26.8.194)** — one physical line; field tail on `complete struct`/`union` / `extends`; method-type `complete function|procedure ( … ) [ : T ]`; type-spec may be `integer N` / `cardinal N` / `real N`, or an array (`Node[]`, `^Node[]`, `integer[4]`, `^array[] of Node`, **0.27.1.217**); **alias RHS** after `complete` (`export type integer complete integer 64`); whole-file reader; `DynBuf` writer; synthetic struct / `NODE_METHOD_TYPE` on import. See Language Report §3.2.

## TODO / Next Actions

**`IMPORT` / `EXPORT` / `.mh` polish**

1. ~~Items 1–4 semantics phase 2 core.~~ **Done (0.23.3–0.23.5)**
2. ~~Item 5 — `sizeof(UserType)` at parse time.~~ **Done (0.23.7)**
3. ~~Item 6 — `EXTERN TYPE | VAR | PROCEDURE | FUNCTION`.~~ **Done (0.23.7)**
4. ~~Item 7 — `.mh` writer on `EXPORT`.~~ **Done (0.24.0)**
5. ~~Item 8 — `.mh` reader on `IMPORT … FROM "*.mh"`.~~ **Done (0.24.0)**
6. `.mh` completeness / signature richness; method export coverage. ~~Negative import tests.~~ **Done (0.24.7)** — `test3_*` tier. ~~**Method instance/static + `import Type::name` + cross-module `obj.method` (Phase A)**~~ — **Done (0.25.2)**. ~~**Formal signatures + cross-module auto-`&` (6a)**~~ — **Done (0.25.3)**.
6a. ~~**`.mh` formal signatures**~~ — **Done (0.25.3)**. ~~**Type field lists / cross-module `obj.field`**~~ — **Done (0.26.3.170)**. ~~**Method-type RHS / field call-through**~~ — **Done (0.26.4.172)** — `complete function|procedure ( … ) [ : T ]`; synthetic `method_type`; import the method type name as well as the struct.
6b. ~~**`.mh` array type-specs**~~ — **Done (0.27.1.217)**. `^Node[]`, `T[]`, `T[N]`, and `^array[] of T` round-trip. `@format` stays 1. See [Future plan: `.mh` array type-specs](#future-plan-mh-array-type-specs).
7. ~~Qualident `FROM`.~~ **Done (0.24.5)** — project-root path resolution (after Makefile subdirs); `IMPORT *` bulk import; `IMPORT … AS …` remain.
7a. ~~**Module entry as real import symbol**~~ — **Done (12 August 2026 / 0.25.3.150)** — same-unit `MODULE` name + importer auto-bind of `@module` export; synthetic proc + formals; arena-copied names; module `VAR`/`REF` ABI. Tests `test_module_ref` / `test_module_entry`.
7b. ~~**Module startup initialization**~~ — **Cancelled (31 August 2026).** No generated calls of imported module bodies. Call the 7a-bound entry explicitly. See [7b cancelled](#7b-cancelled--no-startup-auto-init).

**Language (after `.mh` polish or parallel)**

8. ~~`FORWARD … END` / `EXTERN … END` declaration blocks.~~ **Parked indefinitely (19 October 2026).** Per-declaration `EXTERN`, postfix `FORWARD`, and `type T FORWARD` cover the cases that have come up.
9. ~~`type ident FORWARD`~~ — **Done (0.24.17.135)** — incomplete types completed later in-unit.
10. ~~**`COUNTOF`**~~ — **Done (0.26.9.198)** — replaces interim **`LEN` (0.26.8.194)**. Complete fixed array, type or designator, outermost bound, type `integer`, folded `((integer)N)`. ~~**`SIZEOF` C type**~~ — **Done (0.25.4)** — `((integer)sizeof(...))`. See [`COUNTOF`](#countof-0269198).
10c. ~~**Slice formals (0.27)**~~ — **Done (0.27.1.219)**. An open-array parameter `T[]` / `array[] of T` / `^char[]` lowers to a pointer plus a hidden `integer` length. `countof` on that formal reads the length. See [Future plan: slice formals (0.27)](#future-plan-slice-formals-027).
10e. ~~**`DEFINE` with `=` (0.27)**~~ — **Done (0.27.1.216)** — `define Name = replacement` and `define Name(params) = replacement`. The `=` is omitted from `#define`. See [DEFINE equals (0.27.1.216)](#future-plan-define-equals-027).
10d. **`ELSE CASE` (later)** — `else case A, B, C:` shares one body with the required `ELSE`. Generated C lists those labels and ends the arm with `default:`. Not parsed. See Language Report §7.1.
10b. ~~**`RECURSIVE` on direct self-call**~~ — **Done (0.25.4)** — `test3_recursive`; mutual recursion later.
11. ~~**Unit binding** of bare `integer` / `cardinal` / `real` / `string` (Phase A `TYPE`)~~ — **Done (0.24.18)**. ~~**Width forms** `integer N` / `cardinal N` / `real N`~~ — **Done (0.26.5)**. ~~**Import as the one bind**~~ **Done (0.26.5.174)**. ~~**`.mh` width spelling**~~ **Done (0.26.5.174)**. ~~**`.mh` alias RHS**~~ **Done (0.26.8.194)**. ~~**In-tree packs**~~ **Done (0.26.8.194)**. **Parked indefinitely (12 October 2026):** build-time default selection, until another architecture can prove `TMODC_ARCH`.
12. **`ENUM`** — Phase A/B/C **done** (0.24.6–0.24.7). Tests: `test2_enum_parse.mc`, `test_enum.mc`, `test3_enum_dup.mc`, `test_mh_enum_export.mc`, `test2_mh_enum_import.mc`, `test_mh_enum_import.mc`.
13. ~~**Named constants in array bounds**~~ — **Done (0.24.8)** — `array[LIMIT]` / `array[LIMIT+1]`; integer `CONST` fold; string `CONST` excluded from fold.
13a. ~~**`OPAQUE` types**~~ — **Done (0.24.11)** — TYPE RHS `opaque` / `^opaque` / `POINTER TO opaque`; codegen `void *`; tests incl. negative bare `opaque`. ~~**`^opaque` as a type-specifier**~~ — **Done (0.26.9.200)** — written `^opaque` is `void *` without a named alias. Tests `test_opaque_ptr`, `test2_opaque_import`, `test3_opaque_param`, `test3_opaque_array`.
13b. ~~**Enforce discard form (Policy A)**~~ — **Done (0.24.15)** — known result → `(f())` or use; unknown/procedure bare OK; tests `test_discard` / `test3_discard`; gcc/clang/tcc green.
13c. ~~**`UNION` types**~~ — **Done (0.24.12)** — bare C `union`; `is_union` + `codegen_common_union_decl`; tests `test_union` / `test3_union`; gcc/clang/tcc green. Anonymous nested `union` … `end` **Done (0.27.4.228)**. See [Recent Accomplishments (0.27.4.228)](#recent-accomplishments-26-october-2026--0274228--anonymous-nested-union).
13d. ~~**`STRUCT EXTENDS` (Oberon layout / option A)**~~ — **Done (0.24.13)** — clashes; `base_depth` rewrite; synthetic `base` (reserved only on EXTENDS); tests `test_extends` / `test3_extends_*`. ~~**By-value auto-upcast**~~ — **Done (0.24.16)** — `upcast_depth`; init / assign / return / same-unit call args; C `.base` × N. ~~**Polish: `p^.x`, `as` → `.base`, pointer/`REF` upcast**~~ — **Done (0.26.5.175)**. ~~**Oberon `p.x` auto-deref**~~ — **Done (0.26.5.176)**. ~~**`p[i]` peel + instance on `^T`**~~ — **Done (0.26.5.178)**. ~~**`Type::m(p)` peel**~~ — **Done (0.26.5.179)**. ~~**Parent-chain methods**~~ — **Done (0.26.5.180)**.

**Infrastructure**

14. ~~Makefile **`test3`** target — negative semantic tests.~~ **Done (0.24.2)**
15. ~~**Makefile subdirectory compilation**~~ — **Done (0.26.12.213)** — `src/**` mirrors into `build/`. `src/codegen/` is package `codegen`. Several inputs use each file's own path. **0.27.2.222:** generated and hand-written C is `src/c/<rel>`. `.mh` stays beside the `.mc`. `-C` does not write an `.mh`.
15a. **Cyclic `IMPORT` policy** — directories landed in **213**. Candidates later: extract-common (current), interface/implementation split, cycle ban, or interface-only first pass. Not a 0.26.x language change. Still later.
15b. ~~**Package path**~~ — **Done (0.26.12.212)** — unit qualident; last identifier is the unit name; one directory candidate from the importing unit's package root. A quoted path stays the written file. Did not wait on item 15. See Language Report §3.1.1. ~~**`Ident()` → `Ident::Ident`**~~ — **Done (0.26.12.212)** — declared types only. See §8.3.
16. ~~Codegen: `@` vs `as` precedence.~~ **Done (0.26.10.206)** — `@e as T` is `(@e) as T`. The operand of `@` is a postfix. `as` stays tighter than `&` and the arithmetic operators.
16b. ~~**`HEADER` unit**~~ — **Done (0.26.11.208)** — `header Name` … `end`. No parameter list, no `BEGIN`, no `.c`. `-C` writes the `.h`. An `.mh` is `-M` only (**0.27.2.222**). No unit-entry export. `src/tmodc/tmodc.mc` generates `src/c/tmodc/tmodc.h` and `src/tmodc/tmodc.mh` (**0.27.2.223**).
17. Codegen: struct forward-declare / deferred `p*` typedefs.
18. ~~FOR end temp type from the index type.~~ **Done (0.27.2.225).** Direct `<=` / `>=`. No `long long` cast.
28. ~~`FOR` index type from the start expression.~~ **Done (0.27.3.227).** The declaring form accepts any type C can step with `++` or `--`, including `char` and `size_t`. See [Future plan: loop-local FOR](#future-plan-loop-local-for-jpl-rule-6).
19. **Compile-time `CONST` codegen** — **demoted (12 September 2026).** Stays C `static const`. Integer fold for bounds already (0.24.8). Need a preprocessor constant → **`DEFINE`**. Not a `CONST` → `#define` rewrite.
20. ~~**`VAR` / `REF` / `CONST` formals**~~ — **Done (0.25.0)** — codegen + semantic modes; call-site auto-`&`; **breaking** non-VAR bare-name assign. ~~Soft: named array-alias formals.~~ **Done (0.26.10.204)** — `VAR` / `REF` of a named array alias decays like a written open array. The use type's `is_array` flag stays clear.
20b. ~~**Callable field call-through**~~ — **Done (0.25.1)** — method-typed fields / values; Oberon no auto-self; ambiguity with instance methods; `test_callable_field` / `test_Math`.
21. ~~**Instance methods phase 2**~~ — **Done (0.24.17)** — `obj.method` / chains / statements; instance vs static by first formal type; `test_smoke` / `test3_smoke`; gcc/clang/tcc green.
21a. ~~**`type_of_expr` + simple init inference**~~ — **Done (0.24.14)** — `semantic_type_of_expr`; init when `:` omitted; tests `test_infer.mc`; suite green.
21a-ternary. ~~**Ternary typing**~~ — **Done (0.26.10.203)** — `cond ? a : b` when both arms share one static type (one alias step, then `type_equals`). Result is the then arm. Tests `test_infer`, `test3_infer`, `test3_ternary_width`. **Still open:** array-literal inference (a brace list takes its type from a written target).

**Deferred**

22. ~~Type guard selectors (`IS`)~~ — **dropped** (31 August 2026). Range expressions still deferred. `IN` unused as an operator; reserved.
23. Stdlib `BitSet`; `SET OF` unlikely. **Borrowed-buffer / `init_at` API** when stdlib is designed (not `malloc`-only).
24. ~~Discard binding `_`~~ — **Dropped (12 October 2026).** `(f())` is the discard for a known result. One result per function; a second value is a named struct or a `VAR` / `REF` formal.
25. Optional `BOUND` on `WHILE` / `REPEAT` / `LOOP` — [plan](#future-plan-bound-on-while-repeat-loop-jpl-rule-2).
26. Drop keyword `IS` — [plan](#drop-is-no-type-guards).
27. ~~**`LET` write-forbid**~~ — **Done (0.26.5.181)** — [notes](#recent-accomplishments-7-september-2026--0265181--let-write-forbid). Bare LET name not LHS of `:=` / `INC` / `DEC`.
27b. ~~**Drop C `const` on LET locals**~~ — **Done (0.26.5.183)** — ordinary C locals; `@` of LET/CONST illegal. Not item 19 (`CONST` declarations).

## Strategic Direction

0. **TMod-c rebrand (in progress)** — documentation and user-facing naming move to **TMod-c** / **`tmodc`** first; code and build artifacts keep **`modc`** aliases until deliberate cutover. The development directory is **TMod-c-dev**. Upcoming work is on branch **`main`**. **`tmodc` system module** (started **0.26.11.208**): `src/tmodc/tmodc.mc` is `header tmodc.tmodc` and generates `src/c/tmodc/tmodc.h` and `src/tmodc/tmodc.mh` (**0.27.2.223**). Language builtins stay in the semantic prelude for now. Multi-TU generated C does not yet `#include` `tmodc.h`.
1. **Self-host with `.mh` imports** — convert remaining hand-written C to `.mc`. **`codegen_common.mc` Done (0.26.9.199).** **`codegen_c.mc` Done (0.26.9.201).** Recent: **`parser_common` / `parser_main`**, **`declaration`**, **`Lexer`**, `expression`, `statement`, `codegen_header`, `symkind`, `mh_exportkind`. Still hand-written: **`src/c/node.c` / `src/c/node.h`**. **0.27.4.228** anonymous nested unions unblock that port. Compiler `.mc` is package `tmodc` under `src/tmodc/` (**0.27.2.223**). Generated C mirrors it under `src/c/tmodc/`. `src/c/tmodc/tmodc.h` is generated from `src/tmodc/tmodc.mc`. Keep the chain green under `make test-all`.
2. **Polish `.mh` linking** — method Phase A + formals (**6a**) **Done (0.25.2–0.25.3)**; module-entry bind (**7a**) **Done (12 August)**; type field lists **Done (0.26.3.170)**; method-type RHS / field call-through **Done (0.26.4.172)**. ~~**7b**~~ **Cancelled** (explicit module-entry calls only).
3. ~~**Declaration blocks**~~ — **Parked indefinitely (19 October 2026).** `forward … end` / `extern … end` groups. Per-line markers stay.
4. ~~Expression types / init inference (21a)~~ **Done.** ~~Discard (**13b** Policy A)~~ **Done.** ~~Instance methods (**21**)~~ **Done.** ~~`VAR` formals (**20**)~~ **Done (0.25.0).** ~~Callable fields~~ **Done (0.25.1).** ~~Cross-module method Phase A~~ **Done (0.25.2).** ~~Formal signatures / cross-module auto-`&`~~ **Done (0.25.3).** ~~Module-entry bind (**7a**)~~ **Done (12 August).** ~~**`RECURSIVE` + signed `SIZEOF` + lean prelude**~~ **Done (0.25.4).** ~~**Free-call soft-miss**~~ **Done (0.26.0).** ~~**Unknown types + drop `stddef.h`**~~ **Done (0.26.1).** ~~**Parser self-host (`parser_common` / `parser_main`)**~~ **Done (0.26.3).** ~~**`.mh` field lists**~~ **Done (0.26.3.170).** ~~**Method-type RHS / field call-through**~~ **Done (0.26.4.172).** ~~**Width forms + `.h` prelude**~~ **Done (0.26.5.173).** ~~**#11 import-bind + `.mh` widths**~~ **Done (0.26.5.174).** ~~**EXTENDS polish (`p^.x` / `as` / pointer·`REF`)**~~ **Done (0.26.5.175).** ~~**Oberon `p.x` auto-deref**~~ **Done (0.26.5.176).** ~~**`p[i]` peel + instance on `^T`**~~ **Done (0.26.5.178).** ~~**`Type::m(p)` peel**~~ **Done (0.26.5.179).** ~~**Parent-chain methods**~~ **Done (0.26.5.180).** ~~**`.mh` alias RHS + packs + `LEN`**~~ **Done (0.26.8.194).** **#11** build-time defaults **parked indefinitely** (12 October 2026) until another architecture can prove `TMODC_ARCH`. `CONST` codegen demoted (use `DEFINE` for `#define` constants).
5. ~~**`OPAQUE` (13a)**~~ … ~~**0.26.5.186 extern struct / `'\x'` / `&` vs `@`**~~ **Done.** ~~**`DEFINE`**~~ **Done (0.26.5.188).** ~~**`...`**~~ **Done (0.26.7.190).** ~~**Kilo snaptoken tutorial**~~ **Done (19 September 2026).** ~~**Several `.mc` inputs**~~ **Done (0.26.7.192).** ~~**0.26.8.194**~~ **Done.** ~~**`codegen_common.mc`**~~ **Done (0.26.9.199).** ~~**`^opaque` type-specifier**~~ **Done (0.26.9.200).** ~~**`codegen_c.mc`**~~ **Done (0.26.9.201).** ~~**21a-ternary**~~ **Done (0.26.10.203).** ~~**Named open-array alias formals**~~ **Done (0.26.10.204).** ~~**`@` vs `as`**~~ **Done (0.26.10.206).** **#11** defaults parked indefinitely (12 October 2026). Cyclic `IMPORT` still later (directories landed **0.26.12.213**). ~~Loop-local `FOR`~~ **Done (0.27.2.221).** Later (not 0.26.x): optional `BOUND`; drop `IS`; `SET OF` enum. ~~`DEFINE` with `=`~~ **Done (0.27.1.216).** ~~Slice formals~~ **Done (0.27.1.219).** Package directories **Done (0.27.1.218).**

## Useful Commands

```bash
make                              # gcc (default)
make CC=clang                     # clang flags
make CC=tcc                       # tcc flags
make clean && make CC=clang test-all
make clean && make CC=tcc test-all

make test                         # test_* compile + run
make test2                        # test2_* semantic (-a)
make test3                        # test3_* negative (failure = pass)
make test-all                     # all three tiers

make version                      # manual: bump BUILD_NUMBER + src/c/version.h
make selfhost
make bootstrap
make promote

./bin/modc.0.25.4 tests/test_smoke.mc -C build/test/test_smoke.c
./bin/modc.0.25.4 tests/test_var_ref.mc -C build/test/test_var_ref.c
./bin/modc.0.25.4 tests/test_callable_field.mc -C build/test/test_callable_field.c
./bin/modc.0.25.4 tests/test_Math.mc -C build/test/test_Math.c
./bin/modc.0.25.4 tests/test3_var_ref1.mc -a              # expect non-zero (non-VAR assign)
./bin/modc.0.25.4 tests/test3_smoke.mc -a                 # expect non-zero (static via .)
./bin/modc.0.25.4 tests/test3_callable_field_ambig.mc -a  # expect non-zero (field vs instance)
./bin/modc.0.25.4 tests/test3_recursive.mc -a             # expect non-zero (self-call without RECURSIVE)
./bin/modc.0.25.4 tests/test_method.mc -C build/test/test_method.c
./bin/modc.0.25.4 tests/test_discard.mc -C build/test/test_discard.c
./bin/modc.0.25.4 tests/test3_discard.mc -a              # expect non-zero (tier-3 pass)
./bin/modc.0.25.4 tests/test_opaque.mc -C build/test/test_opaque.c
./bin/modc.0.25.4 -a tests/test5_mh_method_import_string.mc   # cross-module methods (needs include/*.mh)
./bin/modc.0.25.4 tests/test_module_ref.mc -C build/test/test_module_ref.c
./bin/modc.0.25.4 tests/test_module_entry.mc -C build/test/test_module_entry.c
./bin/modc.0.25.4 -a tests/test_mh_enum_import.mc
# make string-lib && link test4_string against -ltmod_string (manual; auto-& on free)
./bin/modc.0.24.17 tests/test_union.mc -C build/test/test_union.c
./bin/modc.0.24.17 tests/test_extends.mc -C build/test/test_extends.c
./bin/modc.0.24.17 tests/test3_extends_clash.mc -a           # expect non-zero (tier-3 pass)
./bin/modc.0.24.17 tests/test3_extends_base_reserved.mc -a # expect non-zero (tier-3 pass)
./bin/modc.0.24.17 tests/test3_opaque_parse.mc -a    # expect non-zero (tier-3 pass)
./bin/modc.0.24.17 tests/test3_union.mc -a           # expect non-zero if negative
./bin/modc.0.24.17 tests/test_mh_export.mc -C build/test/test_mh_export.c -M
./bin/modc.0.24.17 tests/test2_mh_import.mc -C tests/test2_mh_import.c -a
./bin/modc.0.24.17 tests/test_enum.mc -C build/test/test_enum.c
./bin/modc.0.24.17 tests/test_const.mc -C build/test/test_const.c
./bin/modc.0.24.17 tests/test3_enum_dup.mc -a    # expect non-zero (tier-3 pass)
```

## Context & History

- **Live (30 October 2026 / 0.27.5.232):** `docs/grok_report-20261030-2000.md` (loop `BOUND`; also 229 and 230)
- **Prior (28 October 2026 / 0.27.4.230):** `changelog.md` and this file. `VAR`/`REF` designator. **0.27.4.229** is the pointer-alias `as` fix and the `.mh` `name` / `method_owner` free. Those two builds are now in the 30 October report.
- **Prior (26 October 2026 / 0.27.4.228):** `docs/grok_report-20261026-1932.md` (anonymous nested `UNION`; also 223, 225, 226, and 227)
- **Prior (20 October 2026 / 0.27.2.222):** `docs/grok_report-20261020-222.md` (C under `src/c`)
- **Prior (19 October 2026 / 0.27.2.221):** `docs/grok_report-20261019-221.md` (dual `FOR`)
- **Prior (19 October 2026 / 0.27.1.219):** `docs/grok_report-20261019-1430.md` (slice formals)
- **Prior (16 October 2026 / 0.27.1.216):** `docs/grok_report-20261016-1455.md` (`DEFINE` with required `=`)
- **Prior (15 October 2026 / 0.26.12.213):** `docs/grok_report-20261015-1939.md` (subdirectory build; close of `mod-c_0.26`)
- **Prior (12 October 2026 / 0.26.10.206):** `docs/grok_report-20261012-1618.md` (also records **0.26.10.204**, **0.26.10.203**, the **#11** park, and dropping discard `_`)
- **Prior (10 October 2026 / 0.26.9.201 / `codegen_c.mc`):** `docs/grok_report-20261010-1958.md`
- **Prior (6 October 2026 / 0.26.9.200 / `^opaque` type-specifier):** `docs/grok_report-20261006.md` (also records **0.26.9.199** and the **0.27** slice plan)
- **Prior (3 October 2026 / 0.26.9.199 / `codegen_common.mc`):** this file; `changelog.md` (no separate grok report; folded into `docs/grok_report-20261006.md`)
- **Prior (2 October 2026 / 0.26.9.198 / `COUNTOF`):** `docs/grok_report-20261002.md`
- **Prior (30 September 2026 / 0.26.8.196 / named-type owner):** `docs/grok_report-20260930.md`
- **Prior (22 September 2026 / 0.26.8.194 / `.mh` alias RHS + packs + `LEN`):** `docs/grok_report-20260922.md`
- **Prior (21 September 2026 / 0.26.7.192 / several `.mc` inputs):** `docs/grok_report-20260921.md`
- **Prior (19 September 2026 / Kilo tutorial finished):** `docs/grok_report-20260919.md`
- **Prior (18 September 2026 / 0.26.7.191 / C-index `p[i]` on `^T`):** `docs/grok_report-20260918.md`
- **Prior (17 September 2026 / 0.26.7.190 / `...` pass-through):** `docs/grok_report-20260917-ellipsis.md`
- **Prior (14 September 2026 / 0.26.5.188 / DEFINE):** `docs/grok_report-20260914-define.md`
- **Prior (8 September 2026 / 0.26.5.186 / extern struct + escapes + parse):** `docs/grok_report-20260908-ffi-parse.md`
- **Prior (7 September 2026 / 0.26.5.183 / LET C const + `@`):** `docs/grok_report-20260907-let-const-addr.md`
- **Prior (7 September 2026 / 0.26.5.181 / LET write-forbid):** `docs/grok_report-20260907-let-write-forbid.md`
- **Prior (4 September 2026 / 0.26.5.180 / parent-chain methods):** `docs/grok_report-20260904-parent-chain-methods.md`
- **Prior (4 September 2026 / 0.26.5.179 / `Type::m(p)` peel):** `docs/grok_report-20260904-type-m-peel.md`
- **Prior (4 September 2026 / 0.26.5.178 / `p[i]` + instance on `^T`):** `docs/grok_report-20260904-ptr-index-method.md`
- **Prior (3 September 2026 / 0.26.5.176 / Oberon `p.x` auto-deref):** `docs/grok_report-20260903-auto-deref.md`
- **Prior (2 September 2026 / 0.26.5.175 / EXTENDS polish):** `docs/grok_report-20260902-extends-polish.md`
- **Prior (28 August 2026 / 0.26.5.174 / #11 import-bind + `.mh` widths):** `docs/grok_report-20260828-import-bind.md`
- **Prior (27 August 2026 / 0.26.5.173 / width forms + `.h` prelude):** `docs/grok_report-20260827-1548.md`
- **Prior (26 August 2026 / 0.26.4.172 / method-type `.mh` RHS):** `docs/grok_report-20260826-2130.md`
- **Prior (25 August 2026 / 0.26.3.170 / `.mh` field lists):** `docs/grok_report-20260825-mh-field-lists.md`
- **Prior (24 August 2026 / 0.26.3 / parser self-host):** `docs/grok_report-20260824-parser-split.md`
- **Prior (18 August 2026 / 0.26.0 / free-call soft-miss):** `docs/grok_report-20260818-1311.md`
- **Prior (14 August 2026 / 0.25.4 / RECURSIVE + SIZEOF + prelude):** `docs/grok_report-20260814-1645.md`
- **Prior (11 August 2026 / 0.25.3 / formals + cross-module methods):** `docs/grok_report-20260811-2216.md`
- **Prior (6 August 2026 / 0.25.0 / item 20):** `docs/grok_report-20260806-2042.md`
- **Prior (3 August 2026 / 0.24.17 / item 21 methods):** `docs/grok_report-20260803-2318.md`
- **Prior (1 August 2026 / 0.24.16 / declaration + auto-upcast):** `docs/grok_report-080126-2008.md`
- **Prior status (31 July 2026 / `declaration.mc`):** this file; `changelog.md`
- **Prior session report (30 July 2026 / 0.24.15 / 21a + 13b Policy A):** `docs/grok_report-20260730-1800.md`
- **Prior (28 July 2026 / 0.24.14 Lexer):** `docs/grok_report-20260728-2052.md`
- **Prior (25 July 2026 / 0.24.13 arena + EXTENDS 13d):** `docs/grok_report-20260725-2251.md`
- **Prior (23 July 2026 / 0.24.12 OPAQUE + UNION):** `docs/grok_report-20260723-2250.md`
- **Prior (18 July 2026 / `statement.mc` + `OPAQUE` design):** `docs/grok_report-20260718-1906.md`
- **Prior (0.24.10 / `statement.mc` self-host):** this file; build 110
- **Prior (0.24.9 / `symkind` + `mh_exportkind` `.mc`):** changelog
- **Prior (0.24.8 / CONST array bounds):** `docs/grok_report-20260716-2236.md`
- **Prior (0.24.7 / ENUM Phase C):** `docs/grok_report-20260715-2248.md`
- **Prior (0.24.6 / ENUM + TMod-c rebrand):** `docs/grok_report-20260714-1939.md`
- **Prior (0.24.5 / qualident FROM):** `docs/grok_report-20260713-1200.md`
- **Prior (0.24.4 / self-host):** `docs/grok_report-20260711-1911.md`
- **Prior (0.24.3 layout):** `docs/grok_report-20260710-1200.md`
- **Prior (0.24.3 builtins/infra):** `docs/grok_report-20260709-2338.md`
- **Prior (0.24.2 infra):** pending `docs/grok_report-*.md`
- **Prior (0.24.0):** `docs/grok_report-20260707.1439.md`
- **Prior (0.23.9):** `docs/grok_report-20260704-2239.md`
- **Prior (0.23.7 → 0.23.8):** `docs/grok_report-20260703-2321.md`
- Language report: `docs/language-report.md` (hyphen; not `language_report.md`)
- Complete EBNF: `docs/syntax-ebnf.md` (hyphen; not `syntax.ebnf.md`)
- Grammar redirect: `docs/grammar.md` → report + syntax; archive `docs/grammar_working_notes.md`
- Long-term knowledge: `docs/project_bible.md`
- Agent instructions: `AGENTS.md`

## Prior Releases (summary)

- **0.26.5.186:** `extern type Name = struct [tag]`; `'\x1b'`; `parse_primary` `&` vs `@`; array trailing comma. **make clean tmodc test-all selfhost bootstrap promote** on gcc, clang, tcc. Date 8 September 2026.
- **0.26.5.183:** drop C `const` on LET; `@` of `LET`/`CONST` illegal; unbound `string` is `const ^char`. **make clean tmodc test-all selfhost bootstrap promote** on gcc, clang, tcc. Date 7 September 2026.
- **0.26.5.181:** `LET` write-forbid — bare name not LHS of `:=` / `INC` / `DEC`; through-writes legal. **make clean tmodc test-all selfhost bootstrap promote** on gcc, clang, tcc. Date 7 September 2026.
- **0.26.5.180:** parent-chain methods — `Child` → `Parent::m`; `call.base_depth`; `Type::m(p)` peel when pointee extends owner. **make clean tmodc test-all selfhost bootstrap promote** on gcc, clang, tcc. Date 4 September 2026.
- **0.26.5.179:** `Type::m(p)` peel when `p` is `^Owner`; do not peel `@x`. **make test-all** / selfhost / bootstrap / promote on gcc, clang, tcc. Date 4 September 2026.
- **0.26.5.178:** `p[i]` peel (not `^char[]`) + instance method on `^T`; caret `(*(expr))` for `p^[i]`. `Type::m(p)` closed in **179**. **make test-all** / selfhost / bootstrap on gcc, clang, tcc. Date 4 September 2026.
- **0.26.5.177:** Light refactor; `examples/Shapes.mc`. Date 4 September 2026.
- **0.26.5.176:** Oberon `p.x` auto-deref — `field_access.auto_deref`; C `(*(p)).field`. `p[i]` / instance on `^T` closed in **178**. **make test-all** / selfhost / bootstrap on gcc, clang, tcc. Date 3 September 2026.
- **0.26.5.175:** EXTENDS polish — `p^.x` parent fields; aggregate `as` → `.base`; pointer/`REF` upcast (`upcast_ptr`). Field auto-deref closed in **176**. Tests green. Date 2 September 2026.
- **0.26.5.174:** #11 import as the one unit bind; `.mh` width tails on fields/formals/results. Tests green. Date 28 August 2026. **31 August:** one `Makefile` (`CC=gcc|clang|tcc`); `Makefile.clang` / `Makefile.tcc` → `archive/`; `test-all` green on all three.
- **0.26.5.173:** Width forms + generated `.h` prelude; `-C` companion header. **make test-all** / promote on **gcc**, **clang**, **tcc**. Date 27 August 2026.
- **0.26.4.172:** Method-type `.mh` RHS; cross-module field call-through; field lists from **0.26.3.170**. **make test-all** / promote on **gcc**, **clang**, **tcc**. Date 26 August 2026.
- **0.26.3.170:** `.mh` struct/union field lists; ident ≤ 255; whole-file `.mh` reader; DynBuf export lines; synthetic layout on import. **make test-all** green. Date 25 August 2026.
- **0.26.3.168:** **`parser.c`** → **`parser_common.mc` + `parser_main.mc`**; dual `pParser` / `TParser::` helpers; cyclic `.mh` `IMPORT` noted (after item 15). **make test-all** / selfhost / bootstrap / promote on **gcc**, **clang**, **tcc**. Date 24 August 2026.
- **0.26.1.158:** Unknown type names closed; automatic `<stddef.h>` dropped; `nil` is `((void *)0)`. Date 18 August 2026.
- **0.26.0.156:** Free-call soft-miss closed. Date 18 August 2026.
- **0.25.4.154:** **`RECURSIVE`** required on direct self-calls; **`SIZEOF`** emits `((integer)sizeof(...))`; lean C prelude (`stddef`/`stdint`/`stdbool`/`assert`; `byte` = `uint8_t`; no auto `stdlib.h`). **make test-all** / selfhost / bootstrap on **gcc**, **clang**, **tcc**. Date 14 August 2026. Closes branch **`mod-c_0.25`**.
- **0.25.3.150:** **7a** module-entry bind — same-unit + importer auto-bind; arena-copied `.mh` names; module `VAR`/`REF` ABI; `test_module_ref` / `test_module_entry`; **gcc** / **clang** / **tcc**. Date 12 August 2026.
- **0.25.3.149:** **`.mh` formal signatures (6a)** — one-line formals + result; multi-word type-spec; synthetic proc on import; cross-module `VAR`/`REF` auto-`&`; `test4`/`test5` + string lib; build **149**. Date 11 August 2026.
- **0.25.2:** **Cross-module method Phase A** — `.mh` `instance`/`static` Owner; `import Type::name`; `is_method_instance`; `obj.method` across modules; string lib Makefile; build **146**. Date 11 August 2026.
- **0.25.1:** **Callable field call-through** — method-typed fields/values; Oberon no auto-self; ambiguity with instance methods; `test_callable_field` / `test_Math`. Date 7 August 2026.
- **0.25.0:** **Item 20** VAR/REF/CONST formals (**breaking**); call-site auto-`&`; non-VAR bare-name assign illegal. Date 6 August 2026.
- **0.24.17:** **Item 21** — `obj.method` / statement chains; instance vs static by first formal type; factories `Type::new(...)`; optional `end Type::name`; `test_smoke` / `test3_smoke`; build **134**; test-all on **gcc, clang, tcc**. Date 3 August 2026.
- **0.24.16:** **`declaration.mc` self-host** (31 July) + **EXTENDS by-value auto-upcast** (1 August) — `upcast_depth` / `.base` × N; no hidden RTTI; build **130**; test-all on **gcc, clang, tcc**.
- **0.24.15:** **Discard enforcement (13b Policy A)** — known call result requires `(f())` or use; unknown/procedure bare OK; `test_discard` / `test3_discard`; test-all on **gcc, clang, tcc**; build **128**. Date 29 July 2026.
- **0.24.14:** **Lexer.mc** self-host; **`type_of_expr` / init inference (21a)**; builds 125–126. Date 28–29 July 2026.
- **0.24.13:** Linked-chunk **arena** (pointer-stable growth); **`STRUCT EXTENDS` option A (13d)** — clashes, `base_depth`, synthetic `base` reserved only on EXTENDS; tests `test_extends` / `test3_extends_*`; build **121**. Date 25 July 2026.
- **0.24.12:** Bare **`UNION` types (13c)**; `codegen_common_union_decl`; promote build **118**; test-all on **gcc, clang, tcc**. Date 23 July 2026.
- **0.24.11:** `expression.mc` self-host; **`OPAQUE` types (13a)**; builds through 115–116.
- **0.24.10 + design (18 July):** `statement.mc`; `OPAQUE` design; language SSOT; discard plan.
- **0.24.10:** `statement.c` → `statement.mc`; build 110.
- **0.24.9:** `symkind.h` → `symkind.mc`; `mh_exportkind.h` → `mh_exportkind.mc` (build 106).
- **0.24.8:** Named `CONST` in array bounds; `size_expr` + const-eval try/hard split; integer `has_const_value` on `CONST`; string `CONST` safe; self-host/bootstrap/promote. Date 16 July 2026.
- **0.24.7:** ENUM Phase C (`.mh` `export enum`, cross-module); `.mh` negative import tests; test `INCLUDE_DIR` / `-I` paths (gcc Makefile); `WHILE … BY` dropped (use `defer`). Date 15 July 2026.
- **0.24.6:** ENUM Phase A/B (parse, semantic, codegen); `tmodc.h` prelude experiment; TMod-c rebrand documentation. Date 14 July 2026.
- **0.24.5:** Qualident `IMPORT … FROM` (parser, semantic, codegen, `mh_reader` helpers); `test2_mh_import_qual.mc`. Date 13 July 2026.
- **0.24.4:** `codegen_header.mc` self-host step (patch/minor; no API break). Date 11 July 2026.
- **0.24.3:** Builtin `integer` → `int`, `cardinal` → `unsigned int`; EOS layout; import sources documented (phase 1 strings, phase 2 qualidents); `test_layout.mc`, `test3_loop.mc`, `IMPORT FROM` include-only. Dates 9–10 July 2026.
- **0.24.2:** Three-tier test targets (`test`/`test2`/`test3`/`test-all`) in three Makefiles; four `test3_*` negative fixtures; manual `make version`; `src/build.number` survives `make clean`; `AGENTS.md` refresh. Date 9 July 2026. *(Host compilers later unified into one `Makefile` + `CC=`.)*
- **0.24.0:** `.mh` writer (`codegen_mh`, `-M`, auto-emit with `-C`); `.mh` reader (`mh_reader`); `.mh`→`.h` `#include` mapping; `mh_exportkind.h`; `pcchar`; if-body scoping fix; `test_mh_export.mc`, `test2_mh_import.mc`, `fixtures/minimod.{mh,h}`. Date 7 July 2026.
- **0.23.9:** Phase 1 `Type::method` static calls; removed `obj:method` sugar. Date 4 July 2026.
- **0.23.8:** Postfix `FORWARD` on proc/func; mutual recursion. Date 3 July 2026.
- **0.23.7:** Item 5 `sizeof` registry; item 6 `EXTERN`; tag `MOD-C_0.23.7`. Date 3 July 2026.
- Older: `docs/grok_report-*.md`.
