# TMod-c Parameter Passing Rules

**Version:** 17 September 2026 (0.25.0 / item 20; `...` last formal 0.26.7)  
**Status:** Implemented — matches Language Report §8.2 and the current compiler  
**SSOT for prose:** [`language-report.md`](language-report.md) §8.2  
**Formal syntax:** [`syntax-ebnf.md`](syntax-ebnf.md) — `parameter-def`, `formal-parameters`

> **Note:** Parameter **`CONST`** is a *passing-mode / deep read-only* qualifier.  
> It is **not** a compile-time `CONST` declaration (Pascal/Oberon named constant).

---

## Philosophy

Keep **body discipline** and **how the actual is passed** separate:

| Layer | Bare `p: T` | Explicit `REF p: T` / `VAR p: T` |
|--------|-------------|----------------------------------|
| **In-callee use** | No bare-name `:=` / `INC` / `DEC` (not `VAR`) | `REF`: no bare-name assign; through-designator writes OK. `VAR`: bare-name assign OK |
| **Passing (ABI)** | **By value** — expression actuals allowed | Non-pointer `T`: **by reference** (`T*` + address of an **lvalue**) |

- Only **`VAR`** may use the **bare formal name** as the LHS of `:=` / `INC` / `DEC`.
- **`REF`** is a **view** of the caller’s object: through-designator writes (`p.x`, `a[i]`, …) are allowed; bare-name assign is **not**.
- **`CONST`** freezes the formal **root**: no write through name, fields, or indices.
- **Bare** formals share **non-`VAR` body rules** with `REF` (no rebind of the name) but **must remain pass-by-value**. They are **not** “full `REF`” and will **not** be unified with `REF` at the call site (see [Locked: bare is not full REF](#locked-bare-is-not-full-ref)).
- **Locals** use the same three **body** states: `VAR` = 1, `LET` = 2 (`REF` / bare), declaration `CONST` = compile-time (not mid-block like `LET`). `LET` is not a `CONST` formal: `let pc: ^T` may write through a **`VAR` object**. `@` of a `LET` or declaration `CONST` is illegal (0.26.5.183) — no mutable alias. Language Report §4.2.
- Call sites for by-ref **value** formals (`VAR`/`REF` on non-pointer `T`) get auto-`&` when needed (`Swap(x, y)`). Explicit `@x` is still allowed and is not double-addressed.

---

## Locked: bare is not full REF

Older notes sometimes said bare “defaults to REF.” That is only true for **binding discipline** (no bare-name assign). It is **not** true for **passing**:

- Full `REF`/`VAR` on non-pointer `T` needs a pointer into the caller’s storage → the actual must be **addressable** (variable, field, element, …). The compiler takes its address (`f(x)` → `f(&x)`).
- An **expression** (`a + b`, `len * 2`, `g()`, `Point::new(1, 2)`, …) is not an addressable object in the source language. Taking its address is rejected (or would require hidden temporaries with different lifetime rules).
- Therefore **bare** (and pointer-value formals such as bare / `REF` `^T` where the pointer **value** is passed) are what allow **expression actuals**. Making bare lower like full `REF` would break ordinary calls such as `f(a + b)`.

**Locked design:** bare = by-value + non-`VAR` body rules. Explicit `REF`/`VAR` on `T` = opt-in aliasing when the actual is an lvalue. Do **not** plan “bare-as-full-REF” as a future unification.

---

## Rules at a glance

### Value or record type `T` (not a pointer)

| Form | Bare name `n := …` / `INC(n)` | Through `n.x` / `n[i]` / … | Typical C formal (v1) |
|------|-------------------------------|----------------------------|------------------------|
| `VAR p: T` | **Yes** | Yes | `T *p` |
| `REF p: T` | **No** | Yes | `T *p` |
| `CONST p: T` | **No** | **No** | `const` qualification (scalar often by value) |
| `p: T` (bare) | **No** | Selectors if used | ordinary `T` (by value) |

**Scalar `REF n: integer`:** no fields, so bare assign is illegal → effectively **read-only** for updates. Use **`VAR`** to change the caller’s integer.

### Pointer type `^T`

| Form | Bare `p := …` (rebind pointer) | Mutate through pointer | Typical C formal (v1) |
|------|--------------------------------|------------------------|------------------------|
| `VAR p: ^T` | **Yes** | Yes | `T **p` |
| `REF p: ^T` | **No** | Yes (e.g. `p[i]`) | `T *p` (one level) |
| `CONST p: ^T` | **No** | **No** | e.g. `const T *p` |
| `p: ^T` (bare) | **No** | Yes (as for bare pointer-by-value) | `T *p` |

---

## Quick decision guide

| Goal | Use |
|------|-----|
| Change caller’s scalar / replace whole value via formal name | `VAR p: T` |
| Mutate struct fields / array elements; **not** bare `p :=` | `REF p: T` |
| Fully read-only through the formal | `CONST p: T` |
| Rebind a pointer variable in the caller (`p := nil`) | `VAR p: ^T` |
| Pass a pointer; mutate target; do not rebind the pointer | `REF p: ^T` or bare `p: ^T` |
| Pass an **expression** (not an lvalue) | Bare `p: T` (or pass a pointer **value** into `^T` formals) — **not** `REF`/`VAR` on non-pointer `T` |
| Mutate caller’s record via formal | `REF p: T` or `VAR p: T` with an **lvalue** actual |

---

## Call site

### What actuals are legal

| Formal (non-pointer `T`) | Lvalue actual (`x`, `s.f`, `a[i]`, …) | Expression actual (`a+b`, `g()`, …) |
|--------------------------|----------------------------------------|-------------------------------------|
| Bare `p: T` | Yes (copy) | **Yes** (copy of result) |
| `REF p: T` / `VAR p: T` | Yes (auto-`&` / `@`) | **No** — cannot take address of expression |
| `CONST p: T` | Yes (read-only view / copy as lowered) | Depends on lowering; prefer bare for pure expression inputs |

| Formal (pointer `^T`) | Typical actual |
|-----------------------|----------------|
| Bare / `REF` / `CONST` `p: ^T` | Expression or variable that yields a pointer **value** (no auto-`&` of the pointer object for `REF`) |
| `VAR p: ^T` | Lvalue of type `^T` (auto-`&` of that pointer variable so the callee can rebind it) |

### Behaviour table

| Situation | Behaviour |
|-----------|-----------|
| Actual for `VAR`/`REF` on non-pointer `T` | Compiler inserts `&` on an **lvalue** when needed (`f(x)` → `f(&x)`); expression actuals error |
| Actual already `@x` | Single address; no `&&` |
| Actual for bare `p: T` | Pass by value; expressions OK |
| Actual for `REF p: ^T` / bare `^T` | Pass pointer value; no auto-`&` of the pointer object |
| Callee unknown (e.g. bare C import) | No auto-`&` (formals not known) |
| Callee from **`.mh` with signature** (0.25.3) | Same auto-`&` rules as same-unit (synthetic formals on import) |
| Callee from **`.mh` without signature** (legacy) | No auto-`&`; use `@actual` or update the exporting unit |

Explicit call-site spellings `VAR x` / `REF x` as actuals are **not** required in v1.

---

## Examples

```mod-c
(* Whole-value alias — only VAR may assign the bare name *)
procedure Swap(VAR a: integer, VAR b: integer)
begin
	var temp: integer = a
	a := b
	b := temp
end

(* REF: members OK; bare name assign illegal *)
procedure bump_hour(REF dt: DateTime)
begin
	dt.hour := dt.hour + 1
	(* dt := other;  -- error: non-VAR bare name *)
end

(* CONST: no writes through the formal *)
procedure print_time(CONST dt: DateTime)
begin
	printf("%d:%d\n", dt.hour, dt.minute)
	(* dt.hour := 0;  -- error: CONST *)
end

(* Pointer rebind — only VAR *)
procedure clear(VAR p: ^char)
begin
	p := nil
end

(* Pass pointer; mutate chars; do not rebind p *)
procedure fill(REF p: ^char, n: integer)
begin
	(* p[i] := ... OK under REF; p := nil would error *)
end

(* Expression actuals need bare (by-value) formals *)
function twice(n: integer): integer
begin
	return n * 2
end
```

Call examples:

```mod-c
Swap(x, y)           (* auto-& → Swap(&x, &y) *)
Swap(@x, @y)         (* still single & *)
(* Swap(a + 1, b);   -- error: need addressable actuals for VAR *)
clear(ptr)           (* VAR ^T → auto-& of ptr → clear(&ptr) *)
ReadOnly(msg, 11)    (* CONST ^char: pass char* value *)
r := twice(a + b)    (* bare formal: expression OK, by value *)
r := twice(x)        (* also fine — copy of x *)
bump_hour(dt)        (* REF: lvalue; mutates caller’s dt *)
(* bump_hour(make_dt()); -- error if make_dt() is not an lvalue *)
```

---

## C `...` last formal (0.26.7)

Not a fourth passing mode. After at least one named formal, `, ...` lowers to C `, ...`. Extra actuals are untyped in TMod-c; consume them with imported `va_list` / `va_start` / `va_end` and `vprintf` / `vsnprintf`. Illegal on `PROGRAM` / `MODULE` and as the only formal.

See Language Report §8.2.

---

## Implementation notes (0.25.0)

- Semantic: `semantic_forbid_param_mode_write` on ASSIGN / INC / DEC (after resolve).
- Codegen: `codegen_common.c` — formal `*`, pointee load `(*p)`, call-site auto-`&` for by-ref value formals.
- **Breaking:** mutating a non-`VAR` formal as scratch is illegal; use a local.
- Soft spot: named open-array **typedef** as `REF`/`VAR` formal may get awkward C until aliases expose `is_array`; prefer writing open-array type-specifiers directly.
- **Not planned:** lowering bare formals as full `REF` (would forbid or rewrite expression actuals).

---

## Related documents

| Document | Role |
|----------|------|
| [language-report.md](language-report.md) §8.2 | Normative language prose |
| [syntax-ebnf.md](syntax-ebnf.md) | `parameter-def` / `formal-parameters` |
| [../CURRENT.md](../CURRENT.md) | Compiler status / version |
| [parameter-passing.md](parameter-passing.md) (this file) | Practical tables and examples |

---

*End of parameter-passing notes.*
