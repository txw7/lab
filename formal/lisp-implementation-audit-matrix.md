# Lisp Implementation Audit Matrix

This file freezes the verification split for the current handwritten Lisp implementation.

Scope:

- one row per handwritten `defun`
- `defstruct`-generated accessors are omitted
- test functions are omitted
- `kernel.lisp` is omitted because it is only a loader form, not a function

Current configuration note:

- the current kernel is effectively indexed by a trivial configuration `π0`
- universe instantiation is monomorphic
- there are no bitvector or fixed-width arithmetic helpers yet
- therefore `Z3 relevant?` is `No` for the whole current implementation

Legend:

- `Trusted kernel`: bugs can directly change acceptance or rejection of certificates
- `Audited helper`: supports trusted checking but is not itself the core judgment engine
- `Non-trusted convenience`: frontend, protocol, storage, stubs, and demo code; never authoritative
- `Lean proof target`:
  - `Core`: part of checker soundness, conversion soundness, or substitution/reduction lemmas
  - `Aux`: small supporting lemma if mechanized; otherwise covered compositionally
  - `None`: not worth direct mechanized proof in the first verification pass
- `Differential target`:
  - `KR corpus`: compare against small reference checker `KR`
  - `Unit/property`: direct unit and property-based tests
  - `Bootstrap corpus`: accepted/rejected bootstrap environment corpus
  - `Frontend corpus`: surface-to-core regression corpus, then kernel re-check
  - `Protocol tests`: protocol and storage regression suite

## Trusted Kernel Functions

| Function | Module | Contract | Lean proof target | Differential target | Z3 relevant? |
|---|---|---|---|---|---|
| `shift` | `subst.lisp` | Lift free de Bruijn indices above cutoff without capture | Core | KR corpus + mutation corpus around binders | No |
| `subst` | `subst.lisp` | Capture-avoiding substitution under binders | Core | KR corpus + adversarial substitution corpus | No |
| `subst-top` | `subst.lisp` | Discharge one binder via top-level substitution | Core | KR corpus + beta/zeta edge-case corpus | No |
| `ctx-lookup` | `subst.lisp` | Recover binder type with correct lifting into current depth | Core | KR corpus + context lookup corpus | No |
| `reduce-nat-rec` | `reduce.lisp` | Apply `nat-rec` iota rules only on constructor-headed scrutinees | Core | KR corpus + nat recursor corpus | No |
| `reduce-eq-rec` | `reduce.lisp` | Apply `eq-rec` iota rule only on `refl` witnesses | Core | KR corpus + equality recursor corpus | No |
| `whnf` | `reduce.lisp` | Compute weak-head normal form by beta/zeta/delta/iota reduction | Core | KR corpus + normalization regression corpus | No |
| `check-sort` | `typecheck.lisp` | Reject non-sort binder/type positions after WHNF | Core | KR corpus + malformed type corpus | No |
| `conv?` | `typecheck.lisp` | Decide definitional equality over WHNF heads and binder structure | Core | KR corpus + conversion disagreement corpus | No |
| `infer` | `typecheck.lisp` | Infer type of explicit core term or reject | Core | KR corpus + accepted/rejected certificate corpus | No |
| `check` | `typecheck.lisp` | Accept term iff inferred type converts to expected type | Core | KR corpus + accepted/rejected certificate corpus | No |

## Audited Helper Functions

| Function | Module | Contract | Lean proof target | Differential target | Z3 relevant? |
|---|---|---|---|---|---|
| `kernel-error` | `package.lisp` | Raise uniform hard failure for rejected states | None | Unit/property | No |
| `mk-sort` | `term-env.lisp` | Construct canonical `:sort` term node | Aux | Unit/property | No |
| `mk-var` | `term-env.lisp` | Construct canonical `:var` term node | Aux | Unit/property | No |
| `mk-const` | `term-env.lisp` | Construct canonical `:const` term node | Aux | Unit/property | No |
| `mk-app` | `term-env.lisp` | Construct canonical `:app` term node | Aux | Unit/property | No |
| `mk-lam` | `term-env.lisp` | Construct canonical `:lam` term node | Aux | Unit/property | No |
| `mk-pi` | `term-env.lisp` | Construct canonical `:pi` term node | Aux | Unit/property | No |
| `mk-let` | `term-env.lisp` | Construct canonical `:let` term node | Aux | Unit/property | No |
| `app*` | `term-env.lisp` | Left-fold applications in source order | Aux | Unit/property + recursor corpus | No |
| `make-env` | `term-env.lisp` | Create empty global declaration environment | None | Unit/property | No |
| `env-add` | `term-env.lisp` | Insert declaration into environment map | Aux | Bootstrap corpus + env mutation tests | No |
| `env-lookup` | `term-env.lisp` | Retrieve declaration by constant symbol | Aux | KR corpus + env lookup tests | No |
| `instantiate-levels` | `term-env.lisp` | Apply universe instantiation policy; currently identity | Aux | KR corpus under `π0` | No |
| `term-tag` | `term-env.lisp` | Expose outer term constructor tag | Aux | Unit/property | No |
| `app-head+args` | `term-env.lisp` | Decompose application spine into head and ordered args | Aux | KR corpus + spine decomposition tests | No |
| `rebuild-apps` | `term-env.lisp` | Reconstruct application spine from head and args | Aux | Unit/property + inverse-of-spine tests | No |
| `validate-environment` | `bootstrap.lisp` | Check that seeded declarations typecheck under the kernel | Aux | Bootstrap corpus | No |
| `nat-type` | `bootstrap.lisp` | Canonical constructor for `Nat` constant term | Aux | Bootstrap corpus | No |
| `zero-term` | `bootstrap.lisp` | Canonical constructor for `zero` term | Aux | Bootstrap corpus | No |
| `succ-term` | `bootstrap.lisp` | Canonical constructor for `succ` application | Aux | Bootstrap corpus | No |
| `eq-term` | `bootstrap.lisp` | Canonical constructor for `Eq` application | Aux | Bootstrap corpus | No |
| `refl-term` | `bootstrap.lisp` | Canonical constructor for `refl` application | Aux | Bootstrap corpus | No |
| `nat-rec-type` | `bootstrap.lisp` | Build trusted bootstrap type for `nat-rec` | Aux | Bootstrap corpus + KR agreement | No |
| `eq-type` | `bootstrap.lisp` | Build trusted bootstrap type for `Eq` | Aux | Bootstrap corpus + KR agreement | No |
| `refl-type` | `bootstrap.lisp` | Build trusted bootstrap type for `refl` | Aux | Bootstrap corpus + KR agreement | No |
| `eq-rec-type` | `bootstrap.lisp` | Build trusted bootstrap type for `eq-rec` | Aux | Bootstrap corpus + KR agreement | No |
| `add-type` | `bootstrap.lisp` | Build type of reducible demo definition `add` | None | Bootstrap corpus + reduction tests | No |
| `add-value` | `bootstrap.lisp` | Build explicit `nat-rec` implementation of `add` | None | Bootstrap corpus + reduction tests | No |
| `make-bootstrap-env` | `bootstrap.lisp` | Seed canonical environment used by kernel/tests/demo | Aux | Bootstrap corpus + KR agreement | No |

## Non-Trusted Convenience Functions

| Function | Module | Contract | Lean proof target | Differential target | Z3 relevant? |
|---|---|---|---|---|---|
| `frontend-error` | `frontend.lisp` | Raise frontend-specific lowering failure | None | Frontend corpus | No |
| `local-index` | `frontend.lisp` | Find named binder position in local stack | None | Frontend corpus | No |
| `lower-term` | `frontend.lisp` | Lower named surface syntax into explicit core term candidates | None | Frontend corpus + kernel re-check | No |
| `subsetp-eq` | `backend-protocol.lisp` | Check symbol-set inclusion under `eq` | None | Protocol tests | No |
| `validate-backend` | `backend-protocol.lisp` | Enforce trust/capability invariants on backend metadata | None | Protocol tests | No |
| `register-backend` | `backend-protocol.lisp` | Insert validated backend into registry | None | Protocol tests | No |
| `find-backend` | `backend-protocol.lisp` | Retrieve backend metadata by id | None | Protocol tests | No |
| `list-backends` | `backend-protocol.lisp` | Return stable sorted backend registry view | None | Protocol tests | No |
| `initialize-backend-registry` | `backend-protocol.lisp` | Seed kernel, frontend, and solver backend metadata | None | Protocol tests | No |
| `validate-advisory-artifact` | `advisory-artifacts.lisp` | Enforce advisory-only artifact emission discipline | None | Protocol tests | No |
| `make-advisory-store` | `advisory-artifacts.lisp` | Create advisory artifact storage | None | Protocol tests | No |
| `advisory-store-add` | `advisory-artifacts.lisp` | Insert validated advisory artifact into store | None | Protocol tests | No |
| `emit-advisory-artifact` | `advisory-artifacts.lisp` | Capability-checked advisory artifact emission API | None | Protocol tests | No |
| `advisory-store-find-by-kind` | `advisory-artifacts.lisp` | Query advisory artifacts by kind | None | Protocol tests | No |
| `advisory-store-find-by-backend` | `advisory-artifacts.lisp` | Query advisory artifacts by backend id | None | Protocol tests | No |
| `validate-checked-proposal` | `checked-proposals.lisp` | Enforce checked-backend proposal discipline | None | Protocol tests | No |
| `make-proposal-store` | `checked-proposals.lisp` | Create checked proposal storage | None | Protocol tests | No |
| `proposal-store-add` | `checked-proposals.lisp` | Insert validated checked proposal into store | None | Protocol tests | No |
| `emit-checked-proposal` | `checked-proposals.lisp` | Capability-checked checked proposal emission API | None | Protocol tests | No |
| `proposal-store-find-by-kind` | `checked-proposals.lisp` | Query checked proposals by kind | None | Protocol tests | No |
| `proposal-store-find-by-backend` | `checked-proposals.lisp` | Query checked proposals by backend id | None | Protocol tests | No |
| `run-smt-check` | `solver-stub.lisp` | Stub advisory solver API returning typed backend results | None | Protocol tests | No |
| `proof-example-type` | `demo.lisp` | Construct demo theorem type `Π n : Nat, Eq Nat n n` | None | Unit/property | No |
| `proof-example-term` | `demo.lisp` | Construct demo proof term `λ n, refl Nat n` | None | Unit/property | No |
| `nat-reduction-demo-term` | `demo.lisp` | Construct demo reduction witness `add zero (succ zero)` | None | Unit/property | No |
| `run-demo` | `demo.lisp` | Smoke-test bootstrap env, proof checking, and reduction | None | Unit/property | No |

## Immediate Audit Priority

If the goal is to verify the original Lisp implementation of the logic kernel first, audit in this order:

1. `shift`
2. `subst`
3. `subst-top`
4. `whnf`
5. `conv?`
6. `infer`
7. `check`
8. `ctx-lookup`
9. `reduce-nat-rec`
10. `reduce-eq-rec`
11. `check-sort`

Those eleven functions are the ones that materially determine certificate acceptance.

## Minimal Verification Envelope

For the current codebase, the shortest disciplined plan is:

1. Freeze a canonical certificate corpus for the trusted kernel functions above.
2. Build a tiny reference checker `KR` over the same core syntax and judgments.
3. Require exact `KR = KL` agreement for the corpus under the fixed current configuration `π0`.
4. Mechanize declarative typing, substitution, reduction, conversion, and checker soundness in Lean for the same frozen core.
5. Keep the frontend, protocol, solver-stub, advisory store, proposal store, and demo outside the trust base until they are only emitting candidates or artifacts checked by the kernel.
