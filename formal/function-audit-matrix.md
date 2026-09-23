# Function Trust Matrix

Scope:

- single fixed configuration `π0`
- frozen core grammar only (`sort`, `var`, `const`, `app`, `lam`, `pi`, `let`)
- target is verification of the original Lisp implementation against a small reference checker
- `Z3` is only used by the SMT stub in this slice; it is not part of core trusted checking

Legend:

- `Trusted`: determines certificate acceptance
- `Audited`: supports trusted checks but is not itself the authority
- `Convenience`: input, protocol, logging, and non-acceptance helpers
- `Proof target`:
  - `Core`: part of checker soundness, conversion soundness, or key kernel lemmas
  - `Aux`: smaller support invariant
  - `None`: not currently in proof-critical path
- `Diff target`: mandatory corpus or differential check against reference checker

## Trusted Core Functions

| Function | Module | Proof target | Diff target | Z3 relevant? |
|---|---|---|---|---|
| `shift` | `subst.lisp` | Core | `subst`/`subst-top` corpus | No |
| `subst` | `subst.lisp` | Core | `subst` corpus | No |
| `subst-top` | `subst.lisp` | Core | `subst-top` corpus | No |
| `ctx-lookup` | `subst.lisp` | Core | `ctx-lookup` corpus | No |
| `reduce-nat-rec` | `reduce.lisp` | Core | `reduce-nat-rec` corpus | No |
| `reduce-eq-rec` | `reduce.lisp` | Core | `reduce-eq-rec` corpus | No |
| `whnf` | `reduce.lisp` | Core | `whnf` corpus | No |
| `check-sort` | `typecheck.lisp` | Core | `check-sort` corpus | No |
| `conv?` | `typecheck.lisp` | Core | `conv?` corpus | No |
| `infer` | `typecheck.lisp` | Core | `infer` corpus | No |
| `check` | `typecheck.lisp` | Core | `check-certificate`-equivalent checks | No |
| `validate-certificate` | `certificate.lisp` | Aux | `certificate` malformed/negative corpus | No |
| `check-certificate` | `certificate.lisp` | Aux | `certificate` accepted/rejected/malformed corpus | No |

## Audited Helpers

| Function | Module | Proof target | Diff target | Z3 relevant? |
|---|---|---|---|---|
| `kernel-error` | `package.lisp` | None | Unit/property | No |
| `mk-sort` | `term-env.lisp` | Aux | Unit/property | No |
| `mk-var` | `term-env.lisp` | Aux | Unit/property | No |
| `mk-const` | `term-env.lisp` | Aux | Unit/property | No |
| `mk-app` | `term-env.lisp` | Aux | Unit/property | No |
| `mk-lam` | `term-env.lisp` | Aux | Unit/property | No |
| `mk-pi` | `term-env.lisp` | Aux | Unit/property | No |
| `mk-let` | `term-env.lisp` | Aux | Unit/property | No |
| `app*` | `term-env.lisp` | Aux | Unit/property + `app` shape corpus | No |
| `make-env` | `term-env.lisp` | Aux | Unit/property | No |
| `env-add` | `term-env.lisp` | Aux | `env` mutation corpus | No |
| `env-lookup` | `term-env.lisp` | Aux | `env` lookup corpus | No |
| `instantiate-levels` | `term-env.lisp` | Aux | Unit/property | No |
| `term-tag` | `term-env.lisp` | Aux | Unit/property | No |
| `app-head+args` | `term-env.lisp` | Aux | Spine corpus | No |
| `rebuild-apps` | `term-env.lisp` | Aux | Spine inverse corpus | No |
| `run-demo` | `demo.lisp` | None | Unit/property | No |
| `lower-term` | `frontend.lisp` | None | `frontend` corpus + KL re-check | No |
| `local-index` | `frontend.lisp` | None | `frontend` corpus | No |
| `frontend-error` | `frontend.lisp` | None | Unit/property | No |
| `nat-type` | `bootstrap.lisp` | Aux | Bootstrap + KL/KR agreement | No |
| `zero-term` | `bootstrap.lisp` | Aux | Bootstrap + KL/KR agreement | No |
| `succ-term` | `bootstrap.lisp` | Aux | Bootstrap + KL/KR agreement | No |
| `eq-term` | `bootstrap.lisp` | Aux | Bootstrap + KL/KR agreement | No |
| `refl-term` | `bootstrap.lisp` | Aux | Bootstrap + KL/KR agreement | No |
| `nat-rec-type` | `bootstrap.lisp` | Aux | Bootstrap + KL/KR agreement | No |
| `eq-type` | `bootstrap.lisp` | Aux | Bootstrap + KL/KR agreement | No |
| `refl-type` | `bootstrap.lisp` | Aux | Bootstrap + KL/KR agreement | No |
| `eq-rec-type` | `bootstrap.lisp` | Aux | Bootstrap + KL/KR agreement | No |
| `add-type` | `bootstrap.lisp` | None | Demo + KL/KR agreement | No |
| `add-value` | `bootstrap.lisp` | None | Demo + KL/KR agreement | No |
| `validate-environment` | `bootstrap.lisp` | Aux | Bootstrap sanity corpus | No |
| `run-smt-check` | `solver-stub.lisp` | None | Unit/property | No |
| `emit-advisory-artifact` | `advisory-artifacts.lisp` | None | Protocol tests | No |
| `advisory-store-add` | `advisory-artifacts.lisp` | None | Protocol tests | No |
| `advisory-store-find-by-kind` | `advisory-artifacts.lisp` | None | Protocol tests | No |
| `advisory-store-find-by-backend` | `advisory-artifacts.lisp` | None | Protocol tests | No |
| `emit-checked-proposal` | `checked-proposals.lisp` | None | Protocol tests | No |
| `proposal-store-add` | `checked-proposals.lisp` | None | Protocol tests | No |
| `proposal-store-find-by-kind` | `checked-proposals.lisp` | None | Protocol tests | No |
| `proposal-store-find-by-backend` | `checked-proposals.lisp` | None | Protocol tests | No |
| `initialize-backend-registry` | `backend-protocol.lisp` | None | Protocol tests | No |
| `validate-backend` | `backend-protocol.lisp` | None | Protocol tests | No |
| `register-backend` | `backend-protocol.lisp` | None | Protocol tests | No |
| `find-backend` | `backend-protocol.lisp` | None | Protocol tests | No |
| `list-backends` | `backend-protocol.lisp` | None | Protocol tests | No |

## Reference Checker Functions (KL Cross-Check)

| Function | Module | Proof target | Diff target | Z3 relevant? |
|---|---|---|---|---|
| `r-shift` | `reference-checker.lisp` | Core | KR corpus seed | No |
| `r-subst` | `reference-checker.lisp` | Core | `subst` corpus | No |
| `r-subst-top` | `reference-checker.lisp` | Core | `subst-top` corpus | No |
| `r-ctx-lookup` | `reference-checker.lisp` | Core | `ctx-lookup` corpus | No |
| `r-reduce-nat-rec` | `reference-checker.lisp` | Core | `reduce-nat-rec` corpus | No |
| `r-reduce-eq-rec` | `reference-checker.lisp` | Core | `reduce-eq-rec` corpus | No |
| `r-whnf` | `reference-checker.lisp` | Core | `whnf` corpus | No |
| `r-check-sort` | `reference-checker.lisp` | Core | `check-sort` corpus | No |
| `r-conv` | `reference-checker.lisp` | Core | `conv?` corpus | No |
| `r-infer` | `reference-checker.lisp` | Core | `infer` corpus | No |
| `r-check` | `reference-checker.lisp` | Core | `check` corpus | No |
| `r-check-certificate` | `reference-checker.lisp` | Core | Accepted/rejected/malformed certificate corpus | No |
