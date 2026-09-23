# Algorithm Gap Matrix

This file fixes the current distance between the implemented Lisp checker stack and the intended minimal kernel specification.

Scope:

- current fixed configuration `pi0`
- frozen core term grammar only
- hardcoded bootstrap `Nat`, `Eq`, `nat-rec`, `eq-rec`
- current executable kernels:
  - `KL`: handwritten Lisp implementation
- `KR`: small reference checker

Status legend:

- `Implemented`: executable code exists in the current repo
- `Unit-tested`: direct test coverage exists
- `Cross-checked`: `KL` and `KR` are compared on corpus or direct vectors
- `Proved`: mechanized proof exists
- `Spec frozen`: the intended algorithm surface is written down explicitly

Current spec-implementation distance (Lean artifact level):

- implemented kernel algorithms: all core functions have executable coverage and corpus agreement
- mechanized proof closure: still incomplete (5 axioms in `Formal/DeclarativeCore.lean`)
- critical gap: global shift/instantiate commutation is not valid for open bodies; a counterexample is explicitly recorded in `Formal/DeclarativeCore.lean`
- repaired proof boundary: `Formal/DeclarativeCore.lean` now contains an explicit `ClosedN` predicate and a proved `shift_closed_of_closedN` lemma, so closure-side reasoning is no longer implicit
- separate compiling closure fragment: `Formal/ClosureCore.lean` now carries a clean substitution-oriented closure model (`ClosedN`, `up`, `instantiate`, `instantiate_closedN_id`) without pretending to prove the still-missing typing metatheory
- closest measurable closure target: prove all axioms via local-closedness lemmas and complete substitution/weakening/subject-reduction proofs

## Core Algorithm Matrix

| Algorithm | Role | Implemented | Unit-tested | Cross-checked | Proved | Spec frozen | Main remaining obligations |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `shift` | Lift free de Bruijn indices above cutoff | Yes | Yes | Yes | Partly, via `ClosedN` shift-invariance | Yes | Prove substitution interaction, weakening compatibility, and no-capture law |
| `subst` | Capture-avoiding substitution under binders | Yes | Indirect + generated corpus | Partly, through `subst-top` and certificate behavior | No | Yes | Prove substitution lemma and binder descent correctness |
| `subst-top` | Single-binder discharge for beta/zeta/application | Yes | Yes | Yes | No | Yes | Prove equivalence to declarative instantiation |
| `ctx-lookup` | Recover local type with correct lifting | Yes | Yes | Yes | No | Yes | Prove lifted lookup agrees with context discipline |
| `whnf` | Beta/zeta/delta/iota weak-head reduction | Yes | Yes | Yes | No | Yes | Prove reduction soundness, determinism on current core, and relation to conversion |
| `reduce-nat-rec` | `nat-rec` iota on constructor-headed `Nat` | Yes | Yes | Indirect via `whnf` and corpus | No | Yes | Prove matches recursor computation rule exactly |
| `reduce-eq-rec` | `eq-rec` iota on `refl` | Yes | Yes | Indirect via `whnf` and corpus | No | Yes | Prove matches equality eliminator computation rule exactly |
| `conv?` | Algorithmic definitional equality | Yes | Yes | Yes | No | Yes | Prove soundness against declarative definitional equality; decide whether completeness is in scope |
| `check-sort` | Reject non-sort type positions | Yes | Yes | Yes | No | Yes | Prove agreement with declarative sort formation |
| `infer` | Synthesize type of explicit core term | Yes | Yes | Yes | No | Yes | Prove algorithmic typing soundness and syntax-directed completeness for frozen core |
| `check` | Accept iff inferred type converts to expected type | Yes | Yes | Yes | No | Yes | Prove derived correctness from `infer` + `conv?` |
| `validate-certificate` | Carrier well-formedness check | Yes | Yes | Yes, via `KL`/`KR` validation agreement | No | Yes | Specify declarative certificate well-formedness judgment explicitly |
| `check-certificate` | Certificate acceptance API | Yes | Yes | Yes | No | Yes | Prove acceptance equation `K(c, pi0) = accept iff J(c, pi0)` once `KR` is proved |

## Bootstrap And Environment Matrix

| Algorithm | Role | Implemented | Unit-tested | Cross-checked | Proved | Spec frozen | Main remaining obligations |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `make-bootstrap-env` | Seed trusted environment | Yes | Bootstrap/demo coverage | Yes, through `KL`/`KR` corpus agreement | No | Partly | Freeze declarative environment object and prove each seeded declaration matches it |
| `nat-rec-type` | Construct bootstrap type for `nat-rec` | Yes | Indirect | Indirect | No | Partly | Align exact declarative recursor type and computation rule |
| `eq-rec-type` | Construct bootstrap type for `eq-rec` | Yes | Indirect | Indirect | No | Partly | Align exact declarative eliminator type and computation rule |
| `add-value` | Example reducible definition via `nat-rec` | Yes | Yes | Yes, via conversion and corpus | No | No | Only demo-level today; either formalize as example theorem target or keep non-trusted |
| `validate-environment` | Check seeded declarations typecheck | Yes | Yes | Indirect | No | No | Clarify whether this is part of trusted acceptance or bootstrap-only sanity checking |

## Differential Audit Matrix

| Object | Current status | What it gives | What it does not give |
| --- | --- | --- | --- |
| Accepted corpus | Frozen | Regression guard for known good certificates | No proof of completeness |
| Rejected corpus | Frozen | Regression guard for known bad certificates | No proof all bad shapes are represented |
| Malformed corpus | Frozen | Regression guard for carrier validation | No proof of parser/certificate schema completeness |
| Generated corpus | Frozen, deterministic | Structured adversarial slice across `Var`, `Lam`, `Pi`, `Let`, beta, add, malformed, missing | Not exhaustive; still hand-bounded |
| Direct `KL` vs `KR` vectors | Present for `shift`, `subst-top`, `ctx-lookup`, `whnf`, `conv?`, `check-sort`, `infer` | Catches local algorithm drift quickly | Not a proof of equivalence |
| Generated corpus report | Present | Auditable family counts and outcome split | No semantic proof, only classification snapshot |

## Spec Distance By Layer

### 1. Minimal executable kernel

This layer is close to the frozen spec.

- Core grammar exists.
- Trusted algorithm surface exists.
- Bootstrap `Nat` and `Eq` recursors exist.
- Certificates are frozen and consumed by both kernels.
- `KL = KR` is enforced on a nontrivial corpus.

Current distance:

- mostly proof debt, not implementation debt
- one remaining implementation debt class is broader direct coverage for raw `subst`, `reduce-nat-rec`, and `reduce-eq-rec`

### 2. Declarative logic specification

This layer is only partially frozen.

What exists:

- [kernel-backend-spec.md](/home/user0/FORMAL/kernel-backend-spec.md:1)
- [certificate-schema.md](/home/user0/FORMAL/certificate-schema.md:1)

What is still missing:

- one declarative judgment file with exact typing, reduction, and conversion rules
- explicit statement of soundness target for `KR`
- explicit statement of whether algorithmic completeness is required

### 3. Mechanized proof layer

This layer does not exist yet.

Missing:

- substitution lemma
- weakening
- subject reduction
- conversion soundness
- algorithmic typing soundness for `KR`
- certificate acceptance theorem

### 4. Full logic envelope beyond the minimal kernel

This layer is intentionally absent.

Not implemented:

- universe polymorphism
- cumulativity
- general inductives
- strict positivity
- termination checker for user recursion
- elaboration proof obligations

These are not current regressions; they are frozen out of scope.

## Honest Status

If the comparison point is the frozen minimal kernel spec, the code is operationally close:

- implementation status: high
- regression and differential audit status: medium-high
- mechanized proof status: near zero

If the comparison point is the full declarative and mechanized specification envelope, the code is still early:

- algorithm implementation exists
- algorithm justification does not

## Immediate Next Proof Targets

The next proof-facing objects should be introduced in this order:

1. Declarative typing judgment for the frozen core
2. Declarative one-step reduction and definitional equality
3. Substitution lemma
4. Weakening lemma
5. Subject reduction
6. `KR` soundness for `infer`/`check`/`conv?`
7. `check-certificate` soundness against the declarative judgment

## Immediate Remaining Implementation Gaps

If staying inside Lisp before Lean, the highest-value additions are:

1. Direct raw `subst` agreement vectors, not only `subst-top`
2. Direct `reduce-nat-rec` and `reduce-eq-rec` agreement vectors
3. Corpus summary API with pinned totals
4. Optional mutation runner that perturbs generated families but still records a frozen replay set
