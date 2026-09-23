# Minimal Kernel Backend Spec

This document fixes the trusted core for a Lisp-hosted dependent type checker.
It assumes:

- fully explicit core terms,
- de Bruijn indices in the kernel,
- a predicative universe tower `Sort u`,
- hardcoded bootstrap inductives `Nat` and `Eq`,
- no trust in parsing, macros, elaboration, tactics, SMT, or model checking.

Acceptance is defined only by the kernel judgment:

```text
accepted(t, T, Γ, env)  iff  Γ ⊢ t : T
```

## Trusted Surface

The trusted kernel owns only:

- context well-formedness,
- type inference and checking,
- shifting and substitution,
- weak-head reduction,
- definitional equality,
- constant lookup and transparency,
- builtin recursor reduction rules.

Everything else is untrusted.

## Core Syntax

Authoritative kernel terms are tagged s-expressions:

```lisp
(:sort u)                  ; universe
(:var k)                   ; de Bruijn index
(:const name levels)       ; global constant
(:app f a)                 ; application
(:lam binder-type body)    ; lambda
(:pi binder-type body)     ; dependent function
(:let value value-type body)
```

For the minimal milestone, `levels` may be present in the term representation but treated as `()` until universe polymorphism is implemented.

## Context And Environment

Local context:

```text
ctx = [A0, A1, ..., An]
```

- `ctx[0]` is the most recently bound variable type.
- `ctx[k]` is stored relative to the suffix context beneath it, so lookup must lift it back into the full current context.

Global environment:

```lisp
(:axiom type)
(:def type value transparency)
(:builtin type reducer-id)
```

Minimal transparency flags:

```text
opaque | reducible
```

Builtin declarations needed at bootstrap:

```text
Nat      : Sort 0
zero     : Nat
succ     : Nat -> Nat
nat-rec  : Π (P : Nat -> Sort u),
             P zero ->
             (Π (n : Nat), P n -> P (succ n)) ->
             Π (n : Nat), P n

Eq       : Π (A : Sort u), A -> A -> Sort u
refl     : Π (A : Sort u) (a : A), Eq A a a
eq-rec   : Π (A : Sort u)
             (a : A)
             (P : Π (b : A), Eq A a b -> Sort v),
             P a (refl A a) ->
             Π (b : A) (h : Eq A a b), P b h
```

The environment also stores reducer hooks for `nat-rec` and `eq-rec`.

## Judgments

The kernel exposes these operations:

```text
infer(env, ctx, t)        -> T | error
check(env, ctx, t, T)     -> ok | error
whnf(env, t)              -> t'
conv?(env, ctx, t, u)     -> boolean
shift(t, cutoff, delta)   -> t'
subst(t, j, s)            -> t'
```

Derived helpers:

```text
ensure-sort(env, ctx, T)  -> universe level | error
instantiate(body, arg)    -> subst(body, 0, arg)
ctx-lookup(ctx, k)        -> type | error
```

## Representation Invariants

- every binder extends the context by exactly one type,
- bound variables are represented only by indices,
- substitution is capture-avoiding,
- reduction never invents terms outside the core grammar,
- conversion compares terms modulo beta, zeta, delta, and iota,
- alpha-equivalence is implicit in de Bruijn representation.

## Shift

`shift` raises free variables at or above a cutoff.

```text
shift(t, cutoff, delta):
  match t with
  | Sort(u) =>
      Sort(u)

  | Var(k) =>
      if k >= cutoff then Var(k + delta) else Var(k)

  | Const(name, levels) =>
      Const(name, levels)

  | App(f, a) =>
      App(shift(f, cutoff, delta),
          shift(a, cutoff, delta))

  | Lam(A, body) =>
      Lam(shift(A, cutoff, delta),
          shift(body, cutoff + 1, delta))

  | Pi(A, body) =>
      Pi(shift(A, cutoff, delta),
         shift(body, cutoff + 1, delta))

  | Let(v, A, body) =>
      Let(shift(v, cutoff, delta),
          shift(A, cutoff, delta),
          shift(body, cutoff + 1, delta))
```

Operational note:

- when descending under a binder, increment the cutoff,
- `delta` is positive for lifting and negative only in carefully controlled internal uses.

## Substitution

`subst(t, j, s)` replaces variable `Var(j)` in `t` with `s`, adjusting binders correctly.

```text
subst(t, j, s):
  go(t, depth = 0):
    match t with
    | Sort(u) =>
        Sort(u)

    | Var(k) =>
        target = j + depth
        if k == target then
          shift(s, 0, depth)
        else if k > target then
          Var(k - 1)
        else
          Var(k)

    | Const(name, levels) =>
        Const(name, levels)

    | App(f, a) =>
        App(go(f, depth),
            go(a, depth))

    | Lam(A, body) =>
        Lam(go(A, depth),
            go(body, depth + 1))

    | Pi(A, body) =>
        Pi(go(A, depth),
           go(body, depth + 1))

    | Let(v, A, body) =>
        Let(go(v, depth),
            go(A, depth),
            go(body, depth + 1))
```

Derived single-binder instantiation:

```text
instantiate(body, arg) = subst(body, 0, arg)
```

Critical law:

```text
instantiate(body, arg) is capture-avoiding because the replacement is shifted by depth on descent.
```

Context lookup:

```text
ctx-lookup(ctx, k):
  if k >= length(ctx) then
    error("unbound variable")
  else
    return shift(ctx[k], 0, k + 1)
```

## Weak-Head Reduction

The kernel only needs weak-head normal form for conversion and type inference.

Reduction rules:

- beta: `App(Lam(A, t), a) -> instantiate(t, a)`
- zeta: `Let(v, A, body) -> instantiate(body, v)`
- delta: unfold reducible definitions
- iota: reduce builtin recursors on constructor-headed arguments

Spine helpers:

```text
collect-apps(App(f, a)) = let (head, args) = collect-apps(f) in (head, args ++ [a])
collect-apps(t)         = (t, [])

mk-apps(head, [a1, ..., an]) = (((head a1) a2) ... an)
```

Pseudocode:

```text
whnf(env, t):
  current = t
  unfolded = {}

  loop:
    match current with
    | Let(v, A, body) =>
        current = instantiate(body, v)
        continue

    | _ =>
        (head, args) = collect-apps(current)

        match head with
        | Let(v, A, body) =>
            current = mk-apps(instantiate(body, v), args)
            continue

        | Const(c, levels) =>
            decl = env.lookup(c)
            if decl is Def(type, value, reducible) and c not in unfolded then
              unfolded = unfolded ∪ {c}
              current = mk-apps(inst-levels(value, levels), args)
              continue
            else if is-iota-redex(c, args) then
              reduced = reduce-builtin(c, args)
              if reduced != none then
                current = reduced
                continue
              else
                return mk-apps(head, args)
            else
              return mk-apps(head, args)

        | Lam(A, body) =>
            if args is [] then
              return Lam(A, body)
            else
              a0 = first(args)
              rest = rest(args)
              current = mk-apps(instantiate(body, a0), rest)
              continue

        | _ =>
            return mk-apps(head, args)
```

Implementation notes:

- `inst-levels` is a no-op in the monomorphic milestone.
- `unfolded` prevents trivial delta loops during a single WHNF call.
- recursion should enter only through builtin recursors with fixed iota rules, not arbitrary transparent recursive definitions.

## Builtin Iota Reduction

The reducer hooks are part of the trusted base.

Naturals:

```text
nat-rec(P, z, s, zero)      -> z
nat-rec(P, z, s, succ(n))   -> s n (nat-rec(P, z, s, n))
```

Equality:

```text
eq-rec(A, a, P, pr, a, refl(A, a)) -> pr
```

Operationally:

```text
reduce-builtin("nat-rec", [P, z, s, n]):
  n' = whnf(env, n)
  match n' with
  | Const("zero", _) =>
      return z
  | App(Const("succ", _), k) =>
      return App(App(s, k), mk-apps(Const("nat-rec", ()), [P, z, s, k]))
  | _ =>
      return none

reduce-builtin("eq-rec", [A, a, P, pr, b, h]):
  h' = whnf(env, h)
  match h' with
  | App(App(Const("refl", _), _A), _a) =>
      return pr
  | _ =>
      return none
```

## Definitional Equality

`conv?` checks judgmental equality, not propositional equality.

Minimal conversion includes:

- beta,
- zeta,
- delta for reducible constants,
- iota for builtin recursors,
- structural comparison on WHNF forms.

This minimal kernel does not require eta.

Pseudocode:

```text
conv?(env, ctx, t, u):
  t1 = whnf(env, t)
  u1 = whnf(env, u)

  match (t1, u1) with
  | (Sort(i), Sort(j)) =>
      return i == j

  | (Var(i), Var(j)) =>
      return i == j

  | (Const(c1, l1), Const(c2, l2)) =>
      return c1 == c2 and l1 == l2

  | (App(f1, a1), App(f2, a2)) =>
      return conv?(env, ctx, f1, f2)
         and conv?(env, ctx, a1, a2)

  | (Pi(A1, B1), Pi(A2, B2)) =>
      return conv?(env, ctx, A1, A2)
         and conv?(env, [A1] + ctx, B1, B2)

  | (Lam(A1, b1), Lam(A2, b2)) =>
      return conv?(env, ctx, A1, A2)
         and conv?(env, [A1] + ctx, b1, b2)

  | (Let(v1, A1, b1), _) =>
      return conv?(env, ctx, instantiate(b1, v1), u1)

  | (_, Let(v2, A2, b2)) =>
      return conv?(env, ctx, t1, instantiate(b2, v2))

  | _ =>
      return false
```

Implementation notes:

- `conv?` may call `whnf` many times; memoization is an optimization, not part of soundness.
- comparing under binders extends the context but does not otherwise rename variables because de Bruijn already quotients alpha-equivalence.

## Type Inference

Inference is authoritative for fully explicit core terms.

Pseudocode:

```text
infer(env, ctx, t):
  match t with
  | Sort(u) =>
      return Sort(u + 1)

  | Var(k) =>
      return ctx-lookup(ctx, k)

  | Const(c, levels) =>
      decl = env.lookup(c) or error("unknown constant")
      return inst-levels(decl.type, levels)

  | Pi(A, B) =>
      u = ensure-sort(env, ctx, infer(env, ctx, A))
      v = ensure-sort(env, [A] + ctx, infer(env, [A] + ctx, B))
      return Sort(max(u, v))

  | Lam(A, body) =>
      ensure-sort(env, ctx, infer(env, ctx, A))
      B = infer(env, [A] + ctx, body)
      return Pi(A, B)

  | App(f, a) =>
      Tf = whnf(env, infer(env, ctx, f))
      match Tf with
      | Pi(A, B) =>
          check(env, ctx, a, A)
          return instantiate(B, a)
      | _ =>
          error("application of non-function")

  | Let(v, A, body) =>
      ensure-sort(env, ctx, infer(env, ctx, A))
      check(env, ctx, v, A)
      B = infer(env, [A] + ctx, body)
      return instantiate(B, v)
```

`ensure-sort` is a helper:

```text
ensure-sort(env, ctx, T):
  T' = whnf(env, T)
  match T' with
  | Sort(u) => return u
  | _       => error("expected a sort")
```

## Type Checking Wrapper

The checker is a convenience layer over inference and conversion.

```text
check(env, ctx, t, expected):
  inferred = infer(env, ctx, t)
  if conv?(env, ctx, inferred, expected) then
    ok
  else
    error("type mismatch")
```

An optimized implementation may special-case lambdas against expected `Pi` types to avoid infering large intermediate terms, but that is not required for the minimal kernel.

## Context Well-Formedness

The context must itself be typed.

```text
wf-ctx(env, []):
  ok

wf-ctx(env, [A] + rest):
  wf-ctx(env, rest)
  ensure-sort(env, rest, infer(env, rest, A))
```

This prevents malformed binder types from entering the kernel.

## Soundness-Critical Constraints

If any of these are wrong, the kernel is unsound:

- de Bruijn lookup convention,
- `shift` cutoff behavior,
- `subst` under binders,
- delta unfolding discipline,
- iota rules for builtin recursors,
- conversion under binders,
- universe formation `Sort(u) : Sort(u + 1)`.

## First Milestone

A minimal serious kernel can ship with exactly this scope:

- `Sort`,
- `Var`,
- `Const`,
- `App`,
- `Lam`,
- `Pi`,
- `Let`,
- `Nat`, `zero`, `succ`, `nat-rec`,
- `Eq`, `refl`, `eq-rec`,
- `shift`, `subst`, `whnf`, `conv?`, `infer`, `check`.

That is enough to check explicit proof terms and total recursive programs expressed through recursors.

## Immediate Next Implementation Step

Implement in this order:

1. term constructors and context lookup,
2. `shift`,
3. `subst`,
4. `whnf`,
5. `conv?`,
6. `infer`,
7. `check`,
8. bootstrap environment with `Nat` and `Eq`,
9. a small suite of explicit core-term tests.

The kernel should not grow an elaborator until these functions are stable and tested in isolation.
