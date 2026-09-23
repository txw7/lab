# Minimal Closure Manifest

This document fixes the exact closure boundary for the current Lisp-hosted kernelized system.

The goal is to make this sentence precise:

Any surface construct, macro, search result, synthesized branch, or compiler output counts as logically valid only if it is reified into a canonical core certificate that a tiny kernel can check under a frozen theory and configuration.

## 1. Authoritative Core

The kernel accepts only explicit core terms:

```text
t ::= Sort(u)
    | Var(k)
    | Const(c)
    | App(f, a)
    | Lam(A, b)
    | Pi(A, B)
    | Let(v, A, b)
```

Concrete carrier in this repo:

- [certificate-schema.md](/home/user0/FORMAL/certificate-schema.md:1)
- [certificate.lisp](/home/user0/FORMAL/certificate.lisp:1)
- [kernel-backend-spec.md](/home/user0/FORMAL/kernel-backend-spec.md:32)

Non-authoritative by definition:

- surface Lisp syntax
- macros
- frontend lowering
- solver artifacts
- proposal stores
- advisory artifacts
- demo terms

## 2. Frozen Judgments

The intended declarative relations are:

```text
Gamma |-pi t : T
Gamma |-pi t == u
t --> u
```

Current frozen configuration index:

```text
pi = pi0
```

Concrete spec in this repo:

- [declarative-core-spec.md](/home/user0/FORMAL/declarative-core-spec.md:1)
- [Formal/DeclarativeCore.lean](/home/user0/FORMAL/Formal/DeclarativeCore.lean:1)

## 3. Frozen Reduction Discipline

Kernel conversion is allowed to use only:

- beta
- zeta
- delta for reducible constants
- iota for `nat-rec`
- iota for `eq-rec`

No host Lisp evaluation, macro execution, or general reflective computation is authoritative for judgmental equality.

Concrete implementation:

- [reduce.lisp](/home/user0/FORMAL/reduce.lisp:1)
- [typecheck.lisp](/home/user0/FORMAL/typecheck.lisp:1)

## 4. Universe Discipline

The current kernel uses a monomorphic predicative tower:

```text
Sort(u) : Sort(u + 1)
```

Current scope:

- monomorphic universes only
- no cumulativity
- no universe polymorphism

Concrete freeze:

- [certificate-schema.md](/home/user0/FORMAL/certificate-schema.md:42)
- [declarative-core-spec.md](/home/user0/FORMAL/declarative-core-spec.md:1)

## 5. Inductive Discipline

The current closure surface admits only hardcoded bootstrap inductives:

- `Nat`
- `Eq`

with fixed recursor types and fixed iota rules.

Out of scope:

- user-defined inductives
- strict positivity checker
- generated eliminators

Concrete freeze:

- [bootstrap.lisp](/home/user0/FORMAL/bootstrap.lisp:28)
- [declarative-core-spec.md](/home/user0/FORMAL/declarative-core-spec.md:40)

## 6. Canonical Certificate Shape

Every authoritative kernel input is a certificate with:

- `context`
- `term`
- `type`
- `env_digest`
- `config_digest`
- `checker_ids`
- `metadata`

Authority rule:

- `metadata` is non-authoritative
- `checker_ids` is provenance only
- acceptance is decided only by kernel checking of `context`, `term`, `type`, `env_digest`, `config_digest`

Concrete carrier:

- [certificate-schema.md](/home/user0/FORMAL/certificate-schema.md:22)
- [certificate.lisp](/home/user0/FORMAL/certificate.lisp:11)

## 7. Trusted Kernel Surface

Only these functions are acceptance-critical:

- `shift`
- `subst`
- `subst-top`
- `ctx-lookup`
- `reduce-nat-rec`
- `reduce-eq-rec`
- `whnf`
- `check-sort`
- `conv?`
- `infer`
- `check`
- `validate-certificate`
- `check-certificate`

Concrete audit split:

- [lisp-implementation-audit-matrix.md](/home/user0/FORMAL/lisp-implementation-audit-matrix.md:35)

## 8. Untrusted Construction Surface

These components may construct candidates but never establish truth:

- [frontend.lisp](/home/user0/FORMAL/frontend.lisp:1)
- [solver-stub.lisp](/home/user0/FORMAL/solver-stub.lisp:1)
- [advisory-artifacts.lisp](/home/user0/FORMAL/advisory-artifacts.lisp:1)
- [checked-proposals.lisp](/home/user0/FORMAL/checked-proposals.lisp:1)
- [backend-protocol.lisp](/home/user0/FORMAL/backend-protocol.lisp:1)

Closure rule:

Anything produced here must be reified into a canonical certificate before it can count as logically valid.

## 9. Independent Cross-Check Path

The current system has two executable kernel-family members:

- `KL`: handwritten Lisp kernel
- `KR`: small reference checker

Current closure audit condition:

```text
KL(c, pi0) = KR(c, pi0)
```

for the frozen accepted, rejected, malformed, and generated corpus slices.

Concrete artifacts:

- [reference-checker.lisp](/home/user0/FORMAL/reference-checker.lisp:1)
- [reference-checker-tests.lisp](/home/user0/FORMAL/reference-checker-tests.lisp:1)
- [certificate-corpus.lisp](/home/user0/FORMAL/certificate-corpus.lisp:1)
- [generated-corpus-report.md](/home/user0/FORMAL/generated-corpus-report.md:1)

## 10. Current Closure Claim

The current system is allowed to claim only this:

1. Logical admission is kernelized around a frozen explicit core.
2. The authoritative carrier is a canonical certificate format.
3. `KL` and `KR` are differentially checked on a frozen corpus under `pi0`.
4. The declarative target is frozen in prose and in a compiling Lean project.

The current system is not yet allowed to claim this:

1. Mechanized proof of kernel soundness
2. Proven equivalence of `KL` and `KR`
3. General inductive admissibility
4. Universe polymorphism or cumulativity
5. Verified elaboration

## 11. Closure Threshold

This repo has Lean-style closure exactly to the extent that the following remains true:

```text
Only canonical core certificates are authoritative,
only the trusted kernel family may admit them,
and every non-kernel producer is logically irrelevant until kernel re-check.
```

If arbitrary Lisp runtime objects, macro results, or search outputs become authoritative directly, closure is lost.

## 12. Next Obligations

The next proof-facing obligations are:

1. weakening
2. substitution
3. subject reduction
4. algorithmic soundness for `KR`
5. stronger audit relation from `KL` to `KR`

Concrete current Lean target:

- [Formal/DeclarativeCore.lean](/home/user0/FORMAL/Formal/DeclarativeCore.lean:1)
