# TMod-c Change Log

> **Rebrand (July 2026):** Public name **TMod-c**; legacy **Mod-c** during transition. Compiler binary target: **`tmodc`** ( **`modc`** alias retained).

## Version 0.26.9.198
- **`COUNTOF` replaces interim `LEN`** — keyword `COUNTOF` (case-insensitive). `len` is an identifier again. `TOK_KEYWORD_LEN` and `NODE_LEN` renamed in place (`TOK_KEYWORD_COUNTOF`, `NODE_COUNTOF`).
- **Operand** — type or designator. Outermost bound of a complete fixed array (`is_array`, not a pointer, `array_size > 0`). One `resolved_type` chase, so `type Buf = array[4] of integer` works. Nested arrays report the outer bound (`countof` of `array[7] of array[3] of integer` is 7).
- **Result** — type `integer`. Known bounds fold (`sizeof_expr.folded` / `count`), so `array[countof(a)]` is a constant bound. C emit `((integer)N)`. An unfolded designator falls back to `((integer)(sizeof(n) / sizeof((n)[0])))`.
- **Rejected** — pointers, scalars, `string`, and open arrays. `array_size == 0` is both an open array and `array[0]`. Error: `semantic_countof_value: operand must be a complete array`. Not string length. No VLAs.
- **Tests:** `tests/test_countof.mc`, `tests/test3_countof.mc` (`countof(integer)`), `tests/test3_countof_ptr.mc`. Removed `tests/test_len.mc` and `tests/test3_len.mc`.
- **Kilo** — highlighter keyword `countof|`. Locals that call `ERow::` methods are written `^ERow`. `type pERow = ^ERow` remains a different method owner (Language Report §8.3, recorded 2 October 2026 for the 0.26.8.196 rule).
- Compiler tests pass. Build **198**. Branch **`mod-c_0.26`**. Version **0.26.9**.
- Docs this round: `CURRENT.md`, `changelog.md`, `README.md`, Language Report §9.1 / §10.2, `docs/syntax-ebnf.md` (already updated), `docs/grok_report-20261002.md`.

## Version 0.26.8.196
- **Named type is the method owner** — instance iff the first formal’s **written** type name is the owner and that spelling is not `^Owner`. `type sds = ^char` then `sds::free(s: sds)` is instance (`x.free()`); `s: ^sds` is not (v1). Do not chase `resolved_type` / `is_pointer` after alias expansion. Tests: `test_method_named_ptr`, `test3_method_named_ptr`.
- **C-index of written `^T`** — `tokens: ^sds` then `tokens[0]` has type `sds` (keep the name; do not chase `sds → ^char` first). `x: sds` then `x[0]` is still `char` (index the buffer). `p[0].get()` in `test_method_named_ptr`. SDS: `tokens[0].length()`.
- **Unreachable after `RETURN` / `BREAK` / `CONTINUE`** is a **warning** (was a fatal parse error since 0.24.3). Dead statements are still dropped from the AST. Lets a C preprocessor line follow `return` (TSDSLib `#endif` after `return 0` in `sdsTest`).
- **TSDSLib 2.0** — TMod-c port of [antirez/sds](https://github.com/antirez/sds) 2.0 in `examples/sds/Tsds.mc`. Type-bound wrappers; `var s: sds` on grow; `sds::free` nils the handle. BSD notices kept; not an official SDS/Redis release.
- **Kilo `ABuffer`** — grow-by-doubling from a 1024-byte first allocation (`capacity`); fewer `realloc`s on refresh.
- **Public source drop** — [TMod-c-release](https://github.com/mscottreynolds/TMod-c-release) is the `make tar` tree (not the development history).
- Tests green. **make test-all** / **selfhost** / **bootstrap** / **promote** green on **gcc**, **clang**, and **tcc**. Build **196**. Branch **`mod-c_0.26`**. Promoted **0.26.8.196**.
- Docs this round: `CURRENT.md`, `changelog.md`, `README.md`, Language Report §6.2 / §7.1 / §8.3, `docs/syntax-ebnf.md`, `docs/grok_report-20260930.md`.

## Version 0.26.8.194
- **`.mh` alias RHS** — optional type-spec after `complete`/`opaque` on alias TYPE: `export type integer complete integer 64`, `export type string complete const ^char`. Writer `mh_append_type_spec`; reader `mh_parse_alias_rhs`; import `symbol_type`. Old lines without a tail stay valid. Regenerated committed `.mh` files — **0.26.8** stem.
- **In-tree packs** — `tests/fixtures/lp64` (64/64/64) and `ilp32` (32/32/32). Lean `.h`; `-M` only. Stand-in for `tmodc.lp64` / `tmodc.ilp32` until item **15**.
- **`LEN(designator)`** — type `integer`; C `((integer)(sizeof(n) / sizeof((n)[0])))`. Not a type operand. Interim until language-level array / string length. Tests `test_len` / `test3_len`.
- **#11 build-time defaults deferred** — unbound units stay `cint` (`int` / `unsigned int` / `float` / `const char *`).
- Tests green. **make test-all** / **selfhost** / **bootstrap** / **promote** green on **gcc**, **clang**, and **tcc**. Build **194**. Branch **`mod-c_0.26`**. Promoted **0.26.8.194**.
- Docs this round: `CURRENT.md`, `changelog.md`, `README.md`, Language Report §3.2 / §5.5 / §10.1 / §10.2, `docs/syntax-ebnf.md`, `docs/grok_report-20260922.md`.

## Version 0.26.7.192
- **Several `.mc` inputs** — leftover non-options are input files (`tmodc *.mc -C` and `tmodc -C *.mc`). Each unit is a fresh arena / parser / source buffer (`process_one_unit` in `src/modc.mc`). Nothing shared.
- **Several inputs:** bare `-C` / `-H` / `-M` (auto names from PROGRAM/MODULE) and optional `-d`. Explicit `-C file.c` / `-H` / `-M` / `-b` is an error. `-C`/`-H`/`-M` never consume a following `.mc`. Cap 512 (`MAX_MC_INPUTS`).
- **Fail-fast** — `error_at` still `exit(1)`; generate error or missing file stops the batch (missing file returns 1).
- **Loop** — `while i < mc_input_count` (not `FOR … TO count - 1`) so gcc `-Wstrict-overflow` is quiet.
- **Not this slice:** `--deps` / `--print-imports`; compiling the import graph; item **15**. Language Report / EBNF unchanged.
- Promoted **0.26.7.192**. Branch **`mod-c_0.26`**. Build **192**.
- Docs this round: `CURRENT.md`, `changelog.md`, `README.md`, `AGENTS.md` (Key Commands), `docs/grok_report-20260921.md`.

## Examples — Kilo tutorial (19 September 2026)

- **Done** — full [snaptoken Kilo](https://viewsourcecode.org/snaptoken/kilo/index.html) port in `examples/kilo/kilo.mc` (started 7 September 2026; author M. Scott Reynolds). Not a compiler version bump.
- TYPE-bound `EditorConfig::`, `ERow::`, and `ABuffer::`. `E.row[at].updateRow()` (C-index `p[i]` on `^ERow`, **0.26.7.191**). **0.26.8.196:** `ABuffer` grow-by-doubling from 1024 (`capacity`).
- Uses `DEFINE`, `...` + `stdarg.h` FFI, `DEFER`, `RECURSIVE`, `extern type Termios = struct termios`. Extra HLDB entry for TMod-c (`.mc` / `.mh`).
- Build: `examples/kilo/` — `make kilo` (`TMODC=../../bin/tmodc`).
- Docs this round: `CURRENT.md`, `changelog.md`, `README.md`, `docs/grok_report-20260919.md`.

## Version 0.26.7.191
- **C-index `p[i]` on `^T`** — if `p` is `^T` (or a named alias) and `T` is not an array, `p[i]` has type `T` (C `*(p + i)`). `semantic_type_of_designator` copy-shells and clears `is_pointer` after the array-element branch. Same strip as `p^`.
- **Not a peel** — do not set `array_index.auto_deref`. Pointer-to-array (`^array[N] of T` / `^Vector3`) still yields the array element and C `(*(p))[i]` (**0.26.5.178**). `^char[]` `argv[i]` unchanged.
- **Methods / fields** — `p[i].m()` is an ordinary `T` receiver (`REF` auto-`&` → `Type__m(&p[i])`). `Type::m(p[i])` and `(@p[i]).m()` work. Unknown fields on `p[i]` are checked.
- **Kilo** — `E.row[at].updateRow()`; `ERow::` and `Editor::` type-bound procedures (`E.open` / `E.refreshScreen` / `E.processKeypress`).
- **Tests:** `tests/test_ptr_index.mc`; `tests/test3_ptr_index.mc` (`p[0].no_such_field`).
- **Not this slice:** first formal `^Owner` as instance; turning `realloc` buffers into real `array[N]` types.
- Tests green. **make test-all** / **selfhost** / **bootstrap** / **promote** green on **gcc**, **clang**, and **tcc**. Build **191**. Branch **`mod-c_0.26`**. Promoted **0.26.7.191**.
- Docs this round: `CURRENT.md`, `changelog.md`, `README.md`, Language Report §5.3 / §6.2 / §8.3, `docs/syntax-ebnf.md` (designator comment), `docs/grok_report-20260918.md`.

## Version 0.26.7.190
- **`...` last-formal pass-through** — at least one named formal, then `, ...` last. Flag `NODE_PARAM_LIST.has_ellipsis` (not a dummy param). Emit `, ...` in generated C. Extra call actuals already parsed; without the C ellipsis, gcc errors on too many arguments.
- **No language stdarg** — TMod-c does not type extra actuals and has no `va_list` / `va_arg`. Consume extras via FFI: `import va_list, va_start, va_end from "stdarg.h"` plus `vprintf` / `vsnprintf`.
- **PROGRAM / MODULE** — `...` rejected on unit parameter lists.
- **`.mh`** — signatures may end `(string, ...)`; `MhFormal.is_ellipsis`; import rebuild sets `has_ellipsis` and skips a `NODE_PARAM` for that slot.
- **Kilo** — `define CTRL_KEY(k) ((k) & 0x1f)`; `editorSetStatusMessage(fmt: string, ...)` with `vsnprintf`; `type puchar = ^uchar` for C `unsigned char *`.
- **Docs** — Language Report §8.2 (`...`) and §5.3 (C specifier order: `^unsigned char`, not `unsigned ^char`). EBNF `formal-parameters`.
- **Tests:** `tests/test_ellipsis.mc`; `tests/test3_ellipsis.mc` (bare `...`); `tests/test3_ellipsis_tail.mc` (`...` not last).
- **Not this slice:** stdarg builtins; printf format checking; `TYPEOF`; vendoring single-file C libs.
- Promoted **0.26.7.190** (minor bump: language-surface C ABI). Branch **`mod-c_0.26`**.
- Docs this round: `CURRENT.md`, `changelog.md`, `README.md`, Language Report §5.3 / §8.2, `docs/syntax-ebnf.md`, `docs/parameter-passing.md`, `docs/grok_report-20260917-ellipsis.md`.

## Version 0.26.5.188
- **`DEFINE` declaration** — `[EXPORT] DEFINE identifier RestOfLine`. Top-level only. Rest of line is C (including `\` continuations); the compiler does not parse object-like vs function-like. Emit `#define ` + identifier + rest. Bind the name like an untyped `IMPORT` (`SYM_KIND_IMPORT`) so `case CTRL_KEY('q'):` is a legal TMod-c name (C ICE after preprocess).
- **`EXPORT`** — also the generated `.h` and `export define Name complete` in the `.mh` (`MH_KIND_DEFINE`). Importer `FROM "unit.mh"` already `#include`s the paired `.h` (no self-include of `"thisunit.h"`).
- **Unchanged:** `#define` / `#if` pass-through stays unbound. `CONST` stays `static const` (item 19 demoted). Feature-test macros (`_GNU_SOURCE`) stay Makefile `-D`.
- **`TLexer::capture_line_from`** — rewind to the identifier and slurp through newline with `\` continuations. `p.lexer` is a legal `ref` actual (no `@` required).
- **Tests:** `tests/test_define.mc` (object-like, function-like, continuation, `export define`, `switch` `case`); `tests/test3_define.mc` (`define` without identifier).
- Tests green. **make clean tmodc test-all selfhost bootstrap promote** green on **gcc**, **clang**, and **tcc**. Build **188**. Branch **`mod-c_0.26`**. Promoted **0.26.5.188**.
- Docs this round: `CURRENT.md`, `changelog.md`, Language Report §3.2 / §4.1 / §4.2 / §11, `docs/syntax-ebnf.md`, `docs/grok_report-20260914-define.md`.

## Version 0.26.5.187
- **`DEFER` only if executed (§7.3)** — a deferred statement runs only if control passed that `DEFER` (C2y / Language Report). Codegen no longer inserts the action on `RETURN` / `BREAK` / `CONTINUE` that appear *before* the `DEFER` in the same `BEGIN`/`END`. Nested `if … then return end` then later `defer free(buf)` (kilo `editorSave`) does not `free` on the early return. Fall-through of the block still runs every defer that was reached, LIFO.
- **`CodegenContext.stmt_index`** — cutoff in `block.stmts` while emitting that block; unwind walkers (`codegen_c_emit_defers_to_func` / `_to_loop`) emit only defers with index `< stmt_index`. Unwind comments are printed only when at least one defer qualifies (no empty `/* DEFER cleanup (unwinding to function) */`).
- **Tests:** `tests/test_defer.mc` — return before defer; return after defer; first defer runs and second skipped; `continue` before defer in a `FOR` body.
- Tests green. **make clean tmodc test-all selfhost bootstrap promote** green on **gcc**, **clang**, and **tcc**. Build **187**. Branch **`mod-c_0.26`**. Promoted **0.26.5.187**.
- Docs this round: `changelog.md` only. Language Report §7.3 and `CURRENT.md` later.

## Version 0.26.5.186
- **`extern type Name = struct [tag]`** — C struct-tag alias without a shim header. `extern type FILE` still emits nothing. `extern type termios = struct` → `typedef struct termios termios;`. `extern type Foo = struct bar` → `typedef struct bar Foo;`. Not `opaque`, not `FORWARD`. Tests: `tests/test_extern_struct.mc`, `tests/fixtures/ctag.h`. Example: `examples/kilo/kilo.mc`.
- **Char escapes** — `'\x1b'` (`\x` + two hex digits, EBNF); octal `\` + 1..3 digits. `scan_char_escape` in `Lexer.mc`. Test: `tests/test_char_esc.mc`.
- **`parse_primary` no silent `nil`** — unexpected token is `error_at` + exit. `'&' is bitwise AND; use '@' for address-of`. Fixes kilo core dump on C-style `&ws`. Unary `&` is not `@`.
- **Array-literal trailing comma** — `{ a, b, }` no longer needs `parse_expr` to return `nil` (`Lexer.mc` keyword table). `parse_array_literal` breaks on `}` after a comma.
- Builds **184–185** were intermediate promotes of this arc.
- Tests green. **make clean tmodc test-all selfhost bootstrap promote** green on **gcc**, **clang**, and **tcc**. Build **186**. Branch **`mod-c_0.26`**. Promoted **0.26.5.186**.
- Docs: `CURRENT.md`, `changelog.md`, `README.md`, Language Report §2.3 / §3.2 / §6.2, `docs/syntax-ebnf.md`, `docs/grok_report-20260908-ffi-parse.md`.

## Version 0.26.5.183
- **Drop C `const` on LET (27b)** — `NODE_LET_DECL` is an ordinary C local (`codegen_c.c`, `codegen_header.mc`). Declaration `CONST` still emits `const` (item **19**). Type-qualifier `const` unchanged.
- **`@` of `LET` / declaration `CONST` illegal** — `semantic_forbid_at_immutable`. Closes `let n; pc := @n; pc^ :=` without freezing `let p: Point` then `p.x :=`. Read-only `@n` as `const ^T` deferred.
- **Static text:** unbound **`string`** is **`const ^char`** (`typedef const char* string`). Use `let s: string = "…"` (or explicit `const ^char`) so gcc does not see a discarded const after LET is no longer C `const`.
- **Tests:** `tests/test_let_field.mc`; `tests/test3_let_addr.mc`; `tests/test3_let_addr_var.mc`.
- **Still deferred:** item **19** `CONST` codegen; `@n` as `const ^T`.
- Tests green. **make clean tmodc test-all selfhost bootstrap promote** green on **gcc**, **clang**, and **tcc**. Build **183**. Branch **`mod-c_0.26`**. Promoted **0.26.5.183**.
- Docs: `CURRENT.md`, `changelog.md`, `README.md`, Language Report §4.2 / §6.2 / §10.1, `docs/parameter-passing.md`, `docs/grok_report-20260907-let-const-addr.md`.

## Version 0.26.5.181
- **`LET` write-forbid Done (§4.2)** — TMod-c owns rebind of `LET` names. Bare `n :=` / `INC(n)` / `DEC(n)` on a `LET` is a semantic error (statements and `INC`/`DEC` as expressions). Through-writes (`p.x`, `pc^`, `a[i]`) stay legal (same **body** rule as `REF` / bare formals).
- **Three states locked:** `VAR` = rebind + through; `LET` / `REF` / bare = no rebind, through OK; `CONST` formals = deep freeze. Declaration `CONST` stays compile-time, block-head with `VAR` — not mid-block like `LET`.
- **Not pointer-to-const:** `let pc: ^T` may mutate a `VAR` object. C still prefixes `const` on LET locals (wrong for `^T`; **27b** drops it).
- **Tests:** `tests/test3_let_assign.mc`, `tests/test3_let_inc.mc`, `tests/test3_let_inc_expr.mc`; positive `test_let_rebind`. Parked `tests/test3_let_field.mc.keep` until 27b (`-a` OK; gcc `const` member assign still fails).
- **Still deferred:** drop C `const` on `NODE_LET_DECL` (**27b**); item **19** `CONST` codegen.
- Tests green. **make clean tmodc test-all selfhost bootstrap promote** green on **gcc**, **clang**, and **tcc**. Build **181**. Branch **`mod-c_0.26`**. Promoted **0.26.5.181**.
- Docs: `CURRENT.md`, `changelog.md`, `README.md`, Language Report §4.2 / §8.2, `docs/parameter-passing.md`, `docs/grok_report-20260907-let-write-forbid.md`.

## Version 0.26.5.180
- **Parent-chain instance methods (§5.4.0 / §8.3)** — `c.m()` / `p.m()` walk `EXTENDS` and bind `Parent::m` when the receiver is `Child` / `^Child` / further descendant. First instance hit wins (Child shadows Parent). A static `Type__name` at that level is an error; the walk does not skip it.
- **`call.base_depth`** — `.base` hops after peel (0 = method on the receiver type). Receiver upcast uses this flag, **not** `maybe_upcast` on `receiver_expr` (would double `.base`). Argument `maybe_upcast` unchanged (`Parent::show(c)` by value).
- **C** — callee `Parent__show`; value `c.base` × N; pointer `(*pc).base` × N; `REF` `&((*pc).base)` (`.` binds tighter than `&`). No `->`.
- **`Type::m(p)`** — peel if the pointee **is** the owner **or an EXTENDS descendant** (`Parent::show(pc)` when `pc` is `^Child`). Still skip `@`. Qualified `Child::show` does **not** walk.
- **Tests:** `tests/test_extends.mc` (`c.show()` / `g.show()` / `pc.show()` / `Parent::show(pc)` / `pc.bump` / `Child::ownY` on Child and Grand).
- **Still deferred:** first formal `^Owner` as instance.
- Tests green. **make clean tmodc test-all selfhost bootstrap promote** green on **gcc**, **clang**, and **tcc**. Build **180**. Branch **`mod-c_0.26`**. Promoted **0.26.5.180**.
- Docs: `CURRENT.md`, `changelog.md`, `README.md`, Language Report §5.4.0 / §8.3, `docs/grok_report-20260904-parent-chain-methods.md`.

## Version 0.26.5.179
- **`Type::m(p)` peel (§8.3)** — qualified instance call peels the **first** actual when it is `^Owner` (same C as `p.m()`). `Point::print(pp)` → `Point__print((*pp))`; `REF` `Point::scale(pp, n)` → `Point__scale(&(*pp), n)`.
- **Do not peel `@`:** `TLexer::next(@p.lexer)` stays `&(p.lexer)`. `(*&x)` was passing a struct by value (broke selfhost `TParser::advance`).
- **Do not peel `pp^`:** actual is already `Point` (one caret wrap).
- **Placement:** after args are resolved; only when `receiver_expr == nil` (must not clear `pp.getX()`’s flag; `argc` is 0 on that form). Field call-through still clears `auto_deref`.
- **Tests:** `tests/test_smoke.mc` (`Point::print(pp)` / `Point::scale(pp, 3)` / `Point::getX(pp)`). Selfhost `TLexer::next(@p.lexer)`.
- **Still deferred then (closed 0.26.5.180):** parent-chain method lookup. **Still deferred:** first formal `^Owner` as instance.
- Tests green. **make test-all** / **selfhost** / **bootstrap** / **promote** green on **gcc**, **clang**, and **tcc**. Build **179**. Branch **`mod-c_0.26`**. Promoted **0.26.5.179**.
- Docs: `CURRENT.md`, `changelog.md`, `README.md`, Language Report §8.3, `docs/grok_report-20260904-type-m-peel.md`.

## Version 0.26.5.178
- **Oberon `p[i]` peel and instance method on `^T` (§5.3 / §8.3)** — remaining auto-deref after field `.` (176). One implied peel per `[]` or per instance `.method`. AST flags only; no inserted caret. Explicit `p^[i]` / `p^.method` unchanged.
- **`p[i]`** — peel iff pointer-to-array (`^array[N] of T` or `^Name` where `Name` is an array typedef). Do **not** peel `^char[]` `argv[i]` (array-of-`^char`). C `(*(p))[i]`.
- **Anonymous `^array[N] of T`** — `emit_type_specifier` emits `T (*name)[N]` (no longer `T name[N]` / param decay `T *name`). Named `^Vector3` was already `Vector3 *p`.
- **Explicit `p^[i]`** — postfix `^` emits `(*(expr))` so C `[]` does not bind tighter than unary `*` (`*p[i]` was `*(p[i])`).
- **`p.method` on `^T`** — `call.auto_deref`; owner name after the pointer test. First formal still owner **value** (`self: Point` / `ref self: Point`), not `^Point`. C by-value `Type__m((*p))`; `REF`/`VAR` auto-`&` outside the peel (`Type__scale(&(*p), n)`). `Type::m(p)` closed in **179**. No `->`.
- **Tests:** `tests/test_array.mc` (`pv[i]` / `pv^[i]` / `pa[i]` / `argv[0]`); `tests/test_smoke.mc` (`pp.getX()` / `pp.print()` / `pp.scale(2)` / `Point::print(pp^)`).
- **Still deferred then (closed 0.26.5.179):** auto-peel of `Type::m(p)`. **Still deferred then (closed 0.26.5.180):** parent-chain method lookup. **Still deferred:** first formal `^Owner` as instance.
- Tests green. **make test-all** / **selfhost** / **bootstrap** green on **gcc**, **clang**, and **tcc**. Build **178**. Branch **`mod-c_0.26`**. Promoted **0.26.5.178**.
- Docs: `CURRENT.md`, `changelog.md`, `README.md`, Language Report §5.3 / §5.4.0 / §6.2 / §8.3, `docs/grok_report-20260904-ptr-index-method.md`.

## Version 0.26.5.177
- Light refactoring. Include examples/Shapes.mc, an example demonstrating EXTENDS and auto-deref.

## Version 0.26.5.176
- **Oberon `p.x` auto-deref (§5.3)** — one implied peel per `.` when the left side is a pointer (`^T` or alias such as `pNode = ^Node`). Same meaning as `p^.x`. AST stays `NODE_FIELD_ACCESS`; no inserted caret node. Explicit `p^.x` unchanged.
- **Semantic** — `field_access.auto_deref` if the use type or its `resolved_type` is a pointer (do not chase alias first; that would drop `^Child` to named `Child`). Field lookup / `base_depth` already saw `^Child` by name.
- **Codegen** — `(*(p)).field`, then `.base` × N. No `->`. `REF`/`VAR` formals unchanged (`emit_let_ident` already loads `(*formal)`).
- **Tests:** `tests/test_extends.mc` — `c5.x` / `c5.y`, `pp.x`, `pg.z` / `pg.x`, `p.x` in `takeParentPtr` beside `p^.x`. `tests/test_pointer_var.mc` — `root.value` / `p.next.value` beside `^.` forms.
- **Still deferred then (closed 0.26.5.178):** `p[i]` peel for pointer-to-array (do **not** peel `^char[]` `argv[i]`); instance method on `^T`.
- Tests green. **make test-all** / **selfhost** / **bootstrap** green on **gcc**, **clang**, and **tcc**. Build **176**. Branch **`mod-c_0.26`**. Promoted **0.26.5.176**.
- Docs: `CURRENT.md`, `changelog.md`, `README.md`, Language Report §5.3 / §5.4.0 / §6.2, `docs/grok_report-20260903-auto-deref.md`.

## Version 0.26.5.175
- **EXTENDS polish (optional #4)** — three slices; Oberon `p.x` auto-deref **not** in this build.
- **`p^.field` parent fields** — `semantic_type_of_designator` peels postfix `^` and `AS` so `c5^.x` gets `base_depth` (C `(*c5).base.x`). Child fields `c5^.y` were already fine.
- **Aggregate `as` → `.base`** — `g as Parent` records `upcast_depth` from inner vs target; codegen skips `(Parent)g` (invalid C for structs) and emits `((g).base × N)`.
- **Pointer / `REF` upcast** — `semantic_extends_upcast_depth` walks when **both** sides are pointers or **both** are values (mixed still 0). `Node.upcast_ptr`: value `((expr).base × N)` so `REF` actuals are `&((c).base)`; pointer `&((*(pc)).base × N)`.
- **Tests:** `tests/test_extends.mc` — `c5^.x`, `g as Parent` / `g as Child`, `^Parent` init from `^Grand`, `takeParentPtr` / `takeParentRef`.
- **Still deferred then:** Oberon `p.x` / `p[i]` auto-deref (§5.3); instance method on pointer receiver. *(Field `.` closed in 0.26.5.176.)*
- Tests green. Build **175**. Branch **`mod-c_0.26`**.
- Docs: `CURRENT.md`, `changelog.md`, `README.md`, Language Report §5.4.0 / §6.2, `docs/grok_report-20260902-extends-polish.md`.

## Version 0.26.5.174
- **#11 import as the one unit bind** — named `.mh` import of `integer` / `cardinal` / `real` / `string` refines the prelude (once per unit). Foreign `.h` and include-only do not. `AS` alias is not the portable bind.
- Codegen skips the default `typedef` when that name is a listed `.mh` import item; the pack `.h` is the C ABI. Qualident is the bind name unless `AS` is present.
- **`.mh` width spelling** — type-spec tails `integer N` / `cardinal N` / `real N` on fields, formals, and results. Reader stores `type_width` / `result_width`; semantic copies onto imported `TType`. Old lines without a tail stay legal.
- Width token: decimal, no leading zeros, at most two digits (closed *N*; avoids `-Wstrict-overflow` on `n * 10`).
- **Tests:** `test_import_rebind` + `fixtures/lp64`; `test3_import_rebind_second` / `test3_import_then_rebind`; `test2_export_width` / `test2_import_width`; `test_import_width` + `fixtures/wpoint`; `test3_import_width`.
- **Still deferred (#11):** arch packs; build-time defaults; `.mh` alias RHS (`export type integer complete integer 64`).
- Tests green. Build **174**. Branch **`mod-c_0.26`**.
- **31 August 2026 — one Makefile:** `CC ?= gcc`; `make CC=clang` / `make CC=tcc` (family from the `CC` string). Per-family `CFLAGS` / `DEBUG_FLAGS` (no `-lasan`; tcc has no ASan). `make clean` when switching `CC`. `Makefile.clang` and `Makefile.tcc` moved to `archive/`. `make tar` ships only `Makefile`. **make test-all** green on gcc, clang, and tcc.
- Docs: `CURRENT.md`, `changelog.md`, `README.md`, `AGENTS.md`, Language Report §3.2 / §5.5 / §10.1, `docs/syntax-ebnf.md`, `docs/grok_report-20260828-import-bind.md`. Doc filenames: `language-report.md`, `syntax-ebnf.md` (hyphens).

## Version 0.26.5.173
- **Width forms** — `integer N` / `cardinal N` / `real N` (exact C11). Closed *N:* 8/16/32/64; `real` 32/64. Decimal *N* only. `TType.width`; C `intN_t` / `uintN_t` / `float` / `double`.
- `type integer = integer 64` is the Phase A unit bind with a width RHS. Width forms are not rebindable names.
- **Generated `.h` owns the C prelude** — stdint/stdbool/assert, `nil`/`NIL`, `byte`, portable four unless this unit bound the name. Unexported portable `TYPE` binds still appear in the `.h`.
- Generated `.c` `#include "UnitName.h"`; no second prelude. **`-C` writes a companion `.h`**. Header always emits the unit prototype.
- **PROGRAM/MODULE name must match the output stem** (`#include "Name.h"`).
- **Tests:** `test_width`, `test_width_rebind`, `test3_width`, `test3_width_real`.
- **Still deferred (#11 at 173):** import as the one unit bind; arch packs; `.mh` width spelling on fields/formals. *(Import-bind and `.mh` widths closed in 0.26.5.174.)*
- **make test-all**, **promote** green on **gcc**, **clang**, and **tcc**. Promoted **0.26.5.173**.
- Branch **`mod-c_0.26`**; docs: `CURRENT.md`, `changelog.md`, `README.md`, Language Report §5.5 / §10.1 / §11, `docs/syntax-ebnf.md`, `docs/grok_report-20260827-1548.md`

## Version 0.26.4.172
- **Method-type `.mh` RHS** — `export type TFn complete function (integer) : integer` (and `procedure`). Always `(…)` on the type line.
- Reader: `is_func_type` + signature parse after `complete` when the type is not `struct`/`union`.
- Semantic: synthetic `NODE_METHOD_TYPE` on import (`type_decl.method_type := mt`). Cross-module `obj.field(...)` call-through; import the method type **and** the struct.
- Policy A: known function result as a statement still requires `(f())`.
- **Tests:** `test2_export_fn_type` / `test2_import_fn_type` / `test3_import_fn_type`; `test_import_fn_type` + `fixtures/fnbox`. Field lists from **0.26.3.170**.
- **make test-all**, **promote** green on **gcc**, **clang**, and **tcc**. Promoted **0.26.4.172**.
- Branch **`mod-c_0.26`**; docs: `CURRENT.md`, `changelog.md`, `README.md`, Language Report §2.2 / §3.2 / §8.3, `docs/grok_report-20260826-2130.md`

## Version 0.26.3.170
- **`.mh` field lists** — `export type Name complete struct (f: T { , … })`; `union`; optional `extends Parent`. `opaque` unchanged for `EXTERN TYPE` and `type T = opaque`.
- Writer: `mh_type_opaque` no longer treats a struct body as opaque; field tail on `DynBuf` (same one-line `@format 1` as 6a signatures).
- Reader: whole-file load (parse in place); `MhField` on `MhExport`; bare `complete` / `opaque` still legal.
- Semantic: synthetic `NODE_TYPE_DECL` + `struct_body` on import; unknown field is an error. `EXTENDS` parent fields require the parent type imported.
- **Identifiers ≤ 255** — lexer and `.mh` reader; `test3_ident_long.mc`.
- **Tests:** `test2_export_struct` / `test2_import_struct` / `test3_import_struct_field`; union and EXTENDS import pair; `test_import_struct` + `fixtures/tpoint`. Export `.mh` still produced with `-M`.
- **Still deferred (closed in 0.26.4):** method-type RHS / cross-module field call-through.
- **make test-all** green. Branch **`mod-c_0.26`**.

## Version 0.26.3.168
- **Parser self-host closed** — `parser.c` replaced by `parser_common.mc` + `parser_main.mc`.
- Shared helpers in `parser_common` (`TParser` / `pParser`, token/EOS/`error_at` family). Dual exports: `advance(p: pParser)` (declaration / expression / statement) and `TParser::advance(ref p: TParser)` (`parser_main` only).
- `parser_main` is the recursive-descent driver. `modc` includes `parser_common.h` + `parser_main.h`.
- **Cyclic `.mh` imports noted** (parser_main ↔ declaration / expression / statement). Do not design until after Makefile subdirectory compilation (item 15). Interim: extract a common module.
- **make test-all**, **selfhost**, **bootstrap**, **promote** green on **gcc**, **clang**, and **tcc**. Promoted **0.26.3.168**.
- Branch **`mod-c_0.26`**; docs: `CURRENT.md`, `changelog.md`, `README.md`, Language Report §3.2, `docs/grok_report-20260824-parser-split.md`

## Version 0.26.3.167
- Conversion from parser.c to parser_main.mc complete and integrated.

## Version 0.26.2.164
- Renamed struct Parser to TParser

## Version 0.26.1.161
- Extract advance, check, match, error_at, consume, checkEOS, matchEOS, check_comment, match_comment,
  check_assignment, skip_empty_statements, skip_layout_breaks, isEOF 
  from parser.c to parser_common.mc. 
- Update declaration.mc, statement.mc, expression.mc accordingly.

## Version 0.26.1.159
- REQUIRE/ENSURE statements now go through semantic_resolve_expr(...) so REF/VAR parameters are processed.

## Version 0.26.1.158
- **Unknown type names closed (breaking)** — unbound single-word type is an error (`semantic_resolve_type_inner`).
- Still legal: prelude builtins; `IMPORT` / `EXTERN TYPE`; `.mh` opaques; multi-word C (`long long`, `unsigned int`). Bare `unsigned` is not a type.
- **Automatic `<stddef.h>` dropped** — prelude is `<stdint.h>` / `<stdbool.h>` / `<assert.h>`; `#define nil ((void *)0)` / `#define NIL nil`. Import `size_t` (and `FILE`, `void`, …) when used.
- **Tests:** `test3_undef_type.mc`; type import sweep on `src/*.mc`, tests, examples.
- **make test-all**, **selfhost**, **bootstrap**, **promote** green on **gcc**, **clang**, and **tcc**. Promoted.
- Branch **`mod-c_0.26`**; docs: `CURRENT.md`, `changelog.md`, `README.md`, Language Report §3.2 / §11

## Version 0.26.0.156
- **Free-call soft-miss closed (breaking)** — unresolved free `name(...)` and `Type::name(...)` are errors (`semantic_resolve_call`).
- Still legal: same-unit `PROC`/`FUNC`; named `IMPORT` / `EXTERN`; 7a module-entry bind; method-typed values; field call-through.
- Include-only `IMPORT FROM` binds no names. Quoted `FROM "hdr.h"` does not parse the header.
- **C preprocessor** is copied to generated C only; `#define` does not bind TMod-c names. Macros used from `.mc` belong in a real `.h` plus `IMPORT`.
- **Not this bump:** unknown type names (`size_t`, `FILE`) still soft-miss; automatic `<stddef.h>` stays.
- **Tests:** `test3_undef_call.mc`, `test3_undef_method.mc`; `test_tmodc.mc` rewritten to a real `TSTRING` function. Compiler `src/*.mc` import sweep.
- **make test-all**, **selfhost**, **bootstrap**, **promote** green on **gcc**, **clang**, and **tcc**. Promoted.
- Branch **`mod-c_0.26`**; docs: `CURRENT.md`, `changelog.md`, `README.md`, Language Report §3.2 / §11, `docs/syntax.ebnf.md`, `docs/grok_report-20260818-1311.md`

## Version 0.25.4.154
- **`RECURSIVE` enforced** — direct self-call (`resolved_sym.decl == enclosing_func`) requires `RECURSIVE` on the completing PROC/FUNC (the body). `FORWARD` tag on the incomplete decl alone is not enough. Mutual recursion not checked.
- Compiler `.mc` sweep (`semantic`, `ttype`, `expression`, …) so self-host stays legal.
- **Tests:** `tests/test3_recursive.mc`; factorial/fib demos already tagged.
- **`SIZEOF`** — type was already `integer`; C emit is now `((integer)sizeof(...))` (`codegen_common_sizeof_expr`). `LEN` still not emitted.
- **Lean generated prelude** — `#include` only `<stddef.h>`, `<stdint.h>`, `<stdbool.h>`, `<assert.h>`; `typedef uint8_t byte`; `#define nil`/`NIL` `NULL`. No automatic `<stdlib.h>` (import `exit`). Tests, examples, and `src/*.mc` updated.
- **Design notes (0.26):** drop `<stddef.h>` and require every non-builtin name on an `IMPORT`; lengths/indexes stay signed `integer`; `cardinal` for bits/C unsigned; `size_t` imported.
- **make test-all**, **selfhost**, **bootstrap** green on **gcc**, **clang**, and **tcc**. Promoted.
- Branch **`mod-c_0.25`** (stem closed); docs: `CURRENT.md`, `changelog.md`, Language Report §8.1 / §10.1–§10.2 / §11, `docs/syntax.ebnf.md`, `docs/grok_report-20260814-1645.md`

## Version 0.25.3.150
- **Item 7a Done** — module entry is a real `PROC`/`FUNC` symbol (same-unit and on `.mh` import)
- **Same-unit:** `MODULE` name bound after pass 1; synthetic decl shares `program_decl` formals so call-site auto-`&` applies (`ModuleName(obj)` needs no `@`)
- **Import:** any named import from an `.mh` also binds the `@module` unit-entry export (skip if already in scope or no matching export; include-only `import from "x.mh"` unchanged). `PROGRAM` names not bound
- **Names:** `semantic_bind_mh_export` arena-copies bind names before `mh_module_free` (fixes dangling constructor names / false `duplicate TType`)
- **Callee ABI:** module/program `emit_param_list(..., true)` so `VAR`/`REF` formals lower to `T*` (e.g. `module Lexer(ref lexer: TLexer, …)`)
- **Tests:** `tests/test_module_ref.mc`; `tests/test_module_entry.mc` + `fixtures/bumpint.mh` (`import TBump` only). **make test** green on **gcc**, **clang**, and **tcc**
- **Not 7b** — no generated startup calls of imported module bodies
- Branch **`mod-c_0.25`**; docs: `CURRENT.md` (Language Report / grok report later)

## Version 0.25.3.149
- **`.mh` formal signatures (item 6a) Done** — still `@format 1` / one line per export
- **Writer:** `( [var|ref|const] type-spec { , … } ) [ : result ]`; prefer surface type names (aliases); optional multi-word C types when written that way
- **Reader:** `MhFormal` + result fields; multi-word type-spec (`long long`, `unsigned int`); free formals on unload
- **Import:** synthetic `NODE_PROC_DECL` / `NODE_FUNC_DECL` with formals (arena-copied); existing codegen call-site auto-`&` works **cross-module** for `VAR`/`REF`
- Builds on **0.25.2** method Phase A (`instance`/`static`, `import Type::name`, `obj.method`)
- **Tests:** `tests/test5_mh_method_import_string.mc` (`modc -a`); `tests/test4_string.mc` + `make string-lib` / `-ltmod_string` (manual; not default `make test`)
- **Self-host / suite:** `make test` / `test2` / `test3` green; selfhost path loads enriched `.mh` (e.g. `utils.mh`)
- **Deferred:** complete struct field lists in `.mh`; field call-through across modules; module-entry bind (**7a**) / startup init (**7b**)
- Branch **`mod-c_0.25`**; docs: `CURRENT.md`, Language Report §3.2 / §8.2–§8.3, `docs/parameter-passing.md`, `docs/grok_report-20260811-2216.md`

## Version 0.25.2.146
- **Cross-module method Phase A** — `.mh` `instance`/`static` Owner; `import Type::name`; `TSymbol.is_method_instance`; `obj.method` across modules
- Create a small String library for testing with `make string-lib`
- `test4_*` run tests for the library; `test5_*` semantic (`-a`) library import tests
- String library targets must be manually run (depend on regenerated `include/*.mh` + archive)

## Version 0.25.1.144
- Start conversion of parser.c to parser.mc
- Add `pDynBuf` to dynbuf.mc
- "Mod-c" to "TMod-c" in README.md
- Update html from .md

## Version 0.25.1.142
- **Callable field call-through Done** — `obj.field(args)` when `field` has a method type (`TYPE T = PROCEDURE/FUNCTION …`)
- **Oberon rule:** no auto-receiver on field calls; C lowering `(obj.field)(args)` (args as written)
- **Disambiguation:** if both an instance `Type::name` and a method-typed field apply, compile-time error (use `Type::name(obj, …)`)
- **Values:** free call `fp(args)` when `fp` is `VAR` / `PARAM` / `LET` / `CONST` of method type
- **AST / semantic / codegen:** `call.callee_expr`; helpers `semantic_method_type_node`, `semantic_field_type_on`, `semantic_sym_is_method_value`; instance sugar still uses `receiver_expr` prepend
- Tests: `tests/test_callable_field.mc`, `tests/test3_callable_field_ambig.mc`; idiom demo **`tests/test_Math.mc`** (struct ops + `Type::create` / module entry factory; no vtables)
- **make test-all** green on **gcc**, **clang**, and **tcc**; promote verified
- Branch **`mod-c_0.25`**; docs: `CURRENT.md`, `changelog.md`

## Version 0.25.0.140
- **Item 20 Done (breaking)** — formal parameter modes **VAR** / **REF** / **CONST** end-to-end
- **Semantics:** only **`VAR`** may appear as the bare LHS of `:=` / `INC` / `DEC`; **`CONST`** forbids any write through the formal (name, fields, indices); **`REF`** allows through-selectors (`p.x`, `a[i]`) but not bare-name assign
- **Codegen 20A:** `VAR`/`REF` on non-pointer `T` → `T*`; body loads `(*p)` where needed; `REF p: ^T` stays one pointer level; `VAR p: ^T` → `T**`
- **Codegen 20B:** call-site auto-`&` for by-ref value formals (`Swap(x, y)` → `Swap(&x, &y)`); already-`@` args not double-addressed
- **Self-host:** `arena.mc` / `semantic.mc` / `utils.mc` (and related) use locals for scratch mutation of non-`VAR` formals
- Tests: `test_var_ref`, `test_var_pointer`, `test_const_param`, `test3_var_ref*`, `test3_const_param*`, `test3_var_pointer*`; **make test-all**, **selfhost**, **bootstrap**, **promote** green
- Known soft spot: named open-array typedefs used as `REF`/`VAR` formals (prefer true open-array type-specifiers until alias chase lands)
- Branch **`mod-c_0.25`**; docs: `CURRENT.md`, Language Report §8.2, `docs/grok_report-20260806-2042.md`

## Version 0.24.18.136
- **Item #11 Phase A Done** — portable unit rebind of **`integer`**, **`cardinal`**, **`real`**, **`string`** only (Wirth-family names; not C type names)
- One top-level `TYPE` bind per name per compilation unit; second bind and rebind of fixed builtins (`bool` / `byte` / `char`, …) are errors
- Unbound C defaults: `typedef int integer`, `unsigned int cardinal`, **`float real`**, `const char* string` (rebind skips the default and emits the unit’s `TYPE` typedef)
- Helpers: `type_is_portable_rebindable`; semantic prelude refine; `codegen_c_unit_binds_portable`
- Tests: `tests/test_rebind.mc`, `tests/test3_rebind_second.mc`, `tests/test3_rebind_bool.mc`; **make test-all** green
- **Deferred (#11):** width forms `integer N` / `cardinal N` / `real N`; import as the unit bind; architecture packs; compiler-build default selection
- Docs: `CURRENT.md`, `changelog.md`

## Version 0.24.17.135
- **`type Name FORWARD`** — incomplete TYPE in this unit; complete later with `type Name = …` (symtab refine, same family as proc postfix `FORWARD`)
- Codegen incomplete tag/typedef and method-type ordering so C accepts formals that name the type before the full layout
- Tests: `tests/test_type_forward.mc`, `tests/test3_type_forward_dup.mc`, `tests/test3_type_forward_reforward.mc` (as applicable)
- Docs: `CURRENT.md`, `changelog.md`

## Version 0.24.17.134
- **Item 21 Done** — type-bound **instance** methods: `obj.method(args)` → `Type__method(obj, args…)`
- **Instance vs static** by first formal type (formal name free): instance if first formal type is the owner; else static / factory (`Type::` only)
- Expression + **statement** postfix chains (e.g. `p.print()`, `b.topLeft().print()`)
- Optional **`end Type::name`** (and bare `end name`) after procedure/function bodies
- Factories: e.g. `Point::new(x, y)`; instance call on static methods is an error
- Tests: `tests/test_smoke.mc`, `tests/test3_smoke.mc`; **make test-all** green on **gcc**, **clang**, and **tcc**
- Deferred: callable function-pointer field call-through; pointer/`VAR` self; parent-chain method lookup
- Docs: `CURRENT.md`, `changelog.md`, Language Report §8.3, `docs/grok_report-20260803-2318.md`

## Version 0.24.16.130
- **Self-host: declaration** — hand-written `declaration.c` replaced by **`src/declaration.mc`**; generated `declaration.c` (and build-paired header / `.mh` as applicable)
- Conversion cleanup: stale comments removed; most obsolete **receiver** parse path dropped (type-qualified methods)
- **EXTENDS by-value auto-upcast** — child/descendant used as ancestor → C `.base` × N (option A); `Node.upcast_depth`; sites: typed init, `:=`, `RETURN`, same-unit call formals; multi-level
- **Design lock:** no hidden type tags / RTTI / vtables on structs (Modula-2 + C stance); programmer tags optional; no Oberon `IS` without future opt-in
- Deferred polish: pointer/`REF` upcast; aggregate `as` → `.base`; `^T` parent field lookup; richer `.mh` formals
- **make test-all** green on **gcc**, **clang**, and **tcc**
- Docs: `CURRENT.md`, `changelog.md`, Language Report §5.4.0, `docs/syntax.ebnf.md`, `docs/grok_report-080126-2008.md`, `docs/project_bible.md` append

## Version 0.24.15.128
- **Item 13b Done (Policy A)** — bare call as statement illegal when result type is **known** (`semantic_type_of_expr`); require `(f())` or use the value
- Unknown result (procedure, untyped foreign import e.g. bare `printf`) still allowed as bare call
- Explicit discard remains `(expression)` / `(f())` (`NODE_PAREN` statement)
- Tests: `tests/test_discard.mc`, `tests/test3_discard.mc`; **make test-all** green on **gcc**, **clang**, and **tcc**
- Deferred: discard binding `_` (item **24**); C `(void)` hygiene optional in codegen
- Docs: `CURRENT.md`, Language Report §7.2, `docs/syntax.ebnf.md`

## Version 0.24.14.126
- **Item 21a Done** — `semantic_type_of_expr` + simple init inference when `:` omitted on `VAR` / `LET` / `CONST`
- Typing: literals; designators; paren; cast; sizeof; call returns; unary `-` / `not` / `~` / `@` / `^`; binary arith / bitwise / logical / compare; real arith
- Tests: `tests/test_infer.mc` (and suite); prelude `string` as `const char*` where needed for C
- **Deferred:** ternary `? :` (and array-literal) typing — TODO **21a-ternary**
- Unlocks: discard (**13b**), EXTENDS auto-upcast, **`obj.method` (21)**, **`VAR` formals (20)**
- Docs: `CURRENT.md` calm path step 4 complete

## Version 0.24.14.125
- **Self-host: Lexer** — hand-written `lexer.c` / `lexer.h` replaced by **`src/Lexer.mc`** (module `Lexer`); generated `Lexer.c` / `Lexer.h` / `Lexer.mh`
- Tokenizer is now compiled from TMod-c source in the normal / self-host / bootstrap chain
- Exports: `TokenKind` enum, `TToken` / `TLexer`, `TLexer::init`, `TLexer::next`, `TokenKind::string`, `TToken::print`
- Keyword table includes correctly spelled **`OPAQUE`**
- Docs: `CURRENT.md`, `docs/grok_report-20260728-2052.md`, `docs/project_bible.md` append

## Version 0.24.13.122
- **Linked-chunk arena** — growth never relocates live slabs (fixes ASan heap-use-after-free when `realloc` moved a full 1 MiB arena under AST/symtab pointers during large `-a` runs). `ArenaChunk` chain; `calloc` new chunks; `memset` each `arena_alloc` slice; default `ARENA_MIN_SIZE` 1 MiB
- **`STRUCT EXTENDS` option A (item 13d / calm path step 3) Done** — unique field names on chain; synthetic embed `Parent base`; `field_access.base_depth` → C `.base` × depth; flat `c.x` in source; explicit `c.base`
- Synthetic name **`base` reserved only on types that use `EXTENDS`** (plain structs may declare a field `base`)
- Semantic helpers: designator typing for field lookup; clash / base-must-be-struct checks
- Tests: `tests/test_extends.mc`, `test3_extends_clash.mc`, `test3_extends_base_reserved.mc` (plus existing `test2_extends.mc`)
- Auto-upcast still deferred (after **21a** `type_of_expr`)
- Docs: `CURRENT.md`, Language Report §5.4.0, `docs/syntax.ebnf.md`, `docs/grok_report-20260725-2251.md`

## Version 0.24.12.118
- **Bare `UNION` types (item 13c / calm path step 2) Done** — `type T = union … end`; lexer `UNION`; `struct_decl.is_union`; `parse_union_type`; semantic (no EXTENDS on union); **`codegen_common_union_decl`** → C `union`
- Nested aggregates: define named type first, then use as field type (no anonymous nested union/struct yet)
- Tests: `test_union.mc`, `test3_union.mc` (and opaque suite from 0.24.11)
- Promoted; **make test-all** green on **gcc**, **clang**, and **tcc**
- Docs: `CURRENT.md`, Language Report §5.4.1, `docs/grok_report-20260723-2250.md`

## Version 0.24.11.116
- Remove an unnecessary space before ';' production for 'typedef'.

## Version 0.24.11.115
- **`OPAQUE` types (item 13a / calm path step 1) Done** — `type T = opaque`, `^opaque`, `POINTER TO opaque` on TYPE RHS; `TType.is_opaque` / parse / codegen (`typedef void *Name`); bare `opaque` rejected in type-specifier; tests green

## Version 0.24.11.112
- expression.c is now selfhosted with expression.mc

## Documentation (21–25 July 2026)
- **`STRUCT EXTENDS` design** then **implementation (0.24.13 / 13d)** — Oberon record model + C option A
- **`union-type` EBNF** then **implementation (0.24.12)** — bare C union; not language-level tagged unions
- Language SSOT: `language_report.md` + `syntax.ebnf.md` (from 18 July); session report `docs/grok_report-20260725-2251.md`

## Documentation (18 July 2026)
- **Language SSOT:** `docs/language_report.md` (Wirth-style Language Report draft); `docs/syntax.ebnf.md` (complete formal EBNF only)
- **`docs/grammar.md`** — redirect stub; full prior content archived as `docs/grammar_working_notes.md`
- Design captured in report: `OPAQUE`, discard `(f())`, Oberon auto-deref intent, ownership modes, no mandatory GC, `VAR`/`LET` placement

## Version 0.24.10.110
- statement.c to statement.mc, now selfhosted.

## Version 0.24.9.106
- Converted symkind.h to symkind.mc and mh_exportkind.h to mh_exportkind.mc

## Version 0.24.8.104
- **Named `CONST` in array bounds** — `array[LIMIT] of T` and `array[LIMIT+1] of T` when `LIMIT` is a compile-time integer `CONST`
- **`TType.size_expr`** — deferred bound until semantic fold; `type_create_array_expr`; parser accepts const-expr in `array[…] of T` and `T[…]`
- **`semantic_try_eval_const_expr`** — soft integer fold with optional message out-parameter; `semantic_eval_const_expr` is a thin fatal wrapper (no duplicated logic)
- **`CONST` registration** — set `has_const_value` / `const_value` only when integer fold succeeds; string/pointer `CONST` unchanged (e.g. `const c2: ^char = "bye"`)
- **Operators** — binary `mod` accepts `TOK_MOD` and `TOK_KEYWORD_MOD`
- **Review fixes** — fallback message when hard eval fails without msg; typo in register error string
- Self-host, bootstrap, and promote verified green

## Version 0.24.7.101
- **ENUM Phase C** — `MH_KIND_ENUM`; `.mh` `export enum` + member `export const` lines; cross-module enum import
- **Tests:** `test_mh_enum_export.mc`, `test2_mh_enum_import.mc`, `test_mh_enum_import.mc`; `fixtures/colors.{mh,h}`
- **`.mh` negative import tests** — tier-3 `test3_*` coverage for bad imports
- **Makefile test CFLAGS (gcc)** — `-I$(SRC_DIR) -I$(INCLUDE_DIR) -I$(LIB_DIR)`; `include/fixtures` symlink for fixture headers
- **Design:** `WHILE … BY` not planned — use `defer` at loop head for iteration step (`docs/grammar.md`)

## Version 0.24.7.100
- **ENUM Phase A/B** — `parse_enum_type`, `NODE_ENUM_TYPE` / `NODE_ENUM_ITEM`; `semantic_register_enum_type`, `semantic_eval_const_expr`; `codegen_common_enum_type` (C `typedef enum`)
- `TSymbol.const_value` for enum member constants; duplicate-member negative test
- Experimental **`src/tmodc.h`** — shared C ABI prelude for hand-written C including generated headers
- **TMod-c rebrand (documentation)** — `docs/grammar.md`, `CURRENT.md`, `AGENTS.md`, `changelog.md`; archival `docs/grok_report-20260714-1939.md`
- Tests: `tests/test2_enum_parse.mc`, `tests/test_enum.mc`, `tests/test3_enum_dup.mc`
- Add `src/tmodc.h` for TMod-c symbol types that can be imported by C files.

## Version 0.24.5.97
- Add `skip_layout_breaks` to `parse_param_list`.

## Version 0.24.5.96
- Qualident `IMPORT … FROM` — `import-source = string-literal | qualident`
- Unquoted qualident → Mod-c module (`.mh` symtab + `.h` `#include`); quoted paths unchanged
- `mh_reader`: `mh_qualident_to_mh_relpath`, `mh_format_h_include`; updated path helpers
- `tests/test2_mh_import_qual.mc`; `docs/grammar.md` updated

## Version 0.24.4.93
- See docs/grok_report-20260711-1911.md
- Converted codegen_header.c to codegen_header.mc (functional parity; minor 0.24.4 bump)
- docs/grammar.md: import phase 1 / phase 2 documented

## Version 0.24.3.90
- See docs/grok_report-20260710-1200.md
- `skip_layout_breaks` in `parse_unary` (expression operands) and inside `consume` (required keywords)
- `RETURN`: newline after bare `return` ends statement; multiline values use parentheses
- Unreachable code after `RETURN`/`BREAK`/`CONTINUE` is fatal error (was warning)
- Added tests/test_layout.mc, tests/test3_loop.mc

## Version 0.24.3.79
- See docs/grok_report-20260709-2338.md
- Lowered `integer` and `cardinal` down to `int` and `unsigned int`
- Updated parser so '\' isn't required when statement has an explicit end-of-statement keyword, like `IMPORT` ... `FROM "filename"`. Import items can be left on one line or spread out with one item on each line. Rules spelled out in docs/grammar.md. 
- Added tests/test_import_layout.mc

## Version 0.24.2.76
- Add counters to tests in Makefile.
- Add negative tests, (test3_*) to Makefle.
- Update many sections of Makefile.
- Update several test .mc files.
- Updated Makefile.clang and Makefile.tcc to match Makefile.
- Build number only updates when 'make version' is executed.

## Version 0.24.2
- Add helper to include MODULE name in '.mh' file export list for codegen_mh.mc.
- Update codegen.mc to use corresponding '.mh' files for imports.
- Update the rest of the source files to use the corresponding '.mh' files if there is one.
- Add VERSION, VERSION_BASE, and BUILD_NUMBER to version.h, updated by Makefile everytime a build is done.
- Add changelog.md
- Update version number.

