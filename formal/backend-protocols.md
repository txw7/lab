# Backend Protocol Algebra

This document defines the compiler-facing interface for every backend family in the system.
It is not an implementation guide for one engine. It is the authority on:

- what object a backend consumes,
- what object it may emit,
- whether it is trusted or advisory,
- whether it may mutate the trusted environment,
- what evidence format it must return.

The kernel remains the only component that can admit core terms into the trusted logical environment.

## Global Search Algebra

Each backend is an operator family over:

```text
S = (X, Σ, A, ≈, D#, G, C, F, E)
```

with:

- `X`: candidate carrier
- `Σ`: specification carrier
- `A : X × Σ -> {0,1}`: admissibility predicate
- `≈`: equivalence relation or observational quotient
- `D#`: abstract domain, if the backend reasons approximately
- `G`: generator or transition law
- `C`: certificate or evidence carrier
- `F`: objective or preorder, if the backend selects among legal candidates
- `E : X -> Y`: semantics map into a behavior space `Y`

Every backend protocol must pin these objects concretely.

## Trust Classes

There are exactly three trust classes:

- `trusted`: may establish facts directly inside the trusted kernel boundary
- `checked`: may propose results that become authoritative only after kernel or validator re-checking
- `advisory`: may emit summaries, warnings, costs, traces, or counterexamples, but never truth inside the trusted environment

Mutation rights:

- `trusted` backends may extend trusted state only through their own checker rules
- `checked` backends may emit candidate objects but may not mutate trusted state directly
- `advisory` backends may not mutate trusted state at all

## Environment Classes

Separate stores must remain explicit:

- `Γ`: local typing context
- `Δ`: trusted logical environment of constants, definitions, inductives, recursors
- `Ω`: untrusted elaboration state, metavariables, postponed constraints, local search cache
- `Ρ`: runtime or protocol model state
- `Α`: advisory artifact store for summaries, traces, models, reports

Only the kernel checker may mutate `Δ`.

## Core Layer Carriers

Freeze the main candidate spaces first:

```text
X_term     = explicit core terms
X_surface  = named surface terms and declarations
X_exec     = extractable pure executable core
X_rir      = runtime IR graphs, CFGs, closure layouts
X_state    = protocol or machine states / transition systems / invariants
X_trace    = runtime traces, test traces, symbolic traces
```

## Protocol Schema

Every backend must implement a protocol of the form:

```text
name
layer
trust_class
input:
  candidate : X
  spec      : Σ
  context   : store set
output:
  status    : accepted | rejected | counterexample | unknown | timeout | summary
  evidence  : C
  artifacts : advisory outputs
rights:
  may_read
  may_write
  may_propose
invariants:
  soundness obligations
```

## 1. Kernel Checker Protocol

This is the only backend with direct logical authority.

```text
name: kernel-check
layer: core term
trust_class: trusted
```

Algebra:

```text
X   = X_term
Σ   = (Γ, T)
A   = A_typing(t, (Γ, T)) iff Γ ⊢ t : T
≈   = definitional equality
D#  = none
G   = external construction only; kernel itself does not search
C   = checked typing derivation, error trace, convertibility trace
F   = none
E   = core term semantics / normalization behavior
```

Input:

- candidate: explicit core term `t`
- spec: local context `Γ` and target type `T`
- context: reads `Γ`, `Δ`

Output:

- `accepted`: candidate is well-typed
- `rejected`: candidate fails typing or conversion
- evidence: derivation trace or typed rejection payload

Rights:

- may read `Γ`, `Δ`
- may write `Δ` only by admitting checked declarations
- may not read or rely on `Ω`, `Α`, or external solver state for truth

Invariant:

- kernel truth is exactly `Γ ⊢ t : T`

## 2. Frontend Lowering Protocol

This includes parsing, named binders, desugaring, and recursor compilation.

```text
name: frontend-lower
layer: surface
trust_class: checked
```

Algebra:

```text
X   = X_surface
Σ   = lowering mode, local names, expected surface form
A   = syntactic well-formedness of the surface object
≈   = alpha-renaming of surface binders, harmless sugar equivalence
D#  = optional local constraint summaries
G   = macro expansion, binder lowering, recursor compilation
C   = emitted core term, lowering trace, source map
F   = optional formatting or size preference only
E   = surface semantics projected into core syntax
```

Input:

- candidate: surface term or declaration
- spec: lowering configuration and local binder stack
- context: reads `Ω`, optionally reads `Δ` for constant existence checks

Output:

- `accepted`: produced explicit core term
- `rejected`: malformed syntax or lowering failure
- evidence: lowered core term plus source map

Rights:

- may read `Δ`
- may write `Ω`
- may propose core objects for kernel checking
- may not write `Δ`

Invariant:

- frontend output is never authoritative until kernel-checked

## 3. Elaboration Constraint Solver Protocol

This covers metavariables, expected-type propagation, and disciplined unification.

```text
name: elaboration-solve
layer: surface to core bridge
trust_class: checked
```

Algebra:

```text
X   = partial core terms, metavariable states, local goals
Σ   = expected type, local context, declaration environment
A   = constraint consistency
≈   = metavariable-renaming equivalence
D#  = constraint graph summaries
G   = unification steps, implicit insertion, coercion insertion
C   = solved term, residual constraints, explanation trace
F   = minimal coercions / minimal unresolved goals
E   = elaborated core intent
```

Rights:

- may read `Γ`, `Δ`, `Ω`
- may write `Ω`
- may propose solved core terms
- may not write `Δ`

Required evidence:

- fully explicit core candidate
- residual obligations if any

## 4. Proof Search Protocol

This searches for inhabitants or tactic plans, but never admits them.

```text
name: proof-search
layer: proof construction
trust_class: checked
```

Algebra:

```text
X   = proof states, goal states, candidate proof terms
Σ   = local context, target type, search bounds
A   = local proof-state consistency
≈   = alpha-equivalence, goal-state quotienting, optional rewrite quotient
D#  = proof-state summaries
G   = tactic steps, backward chaining, recursor application, rewrite search
C   = candidate proof term, tactic trace, failed branch trace
F   = proof size / proof depth / search cost
E   = term inhabitation behavior
```

Rights:

- may read `Γ`, `Δ`, `Ω`
- may write `Ω`, `Α`
- may propose proof terms
- may not write `Δ`

Required evidence:

- explicit proof term if successful
- otherwise search report or counterexample to a local tactic choice

## 5. SMT / SAT Protocol

This is a symbolic search engine, not a truth source.

```text
name: smt-check
layer: side-condition solving
trust_class: advisory
```

Algebra:

```text
X   = formulas, symbolic obligations, synthesis sketches
Σ   = theory fragment, solver options, timeout budget
A   = satisfiable / valid relative to solver semantics
≈   = theory equivalence modulo normalization
D#  = solver abstraction state
G   = branching, instantiation, CEGIS proposals
C   = model, unsat core, proof artifact if available
F   = minimal model / minimal witness cost
E   = logical model semantics
```

Rights:

- may read `Α` and emitted obligations
- may write `Α`
- may propose models or candidate witnesses
- may not write `Δ`

Invariant:

- solver answers are advisory until reified into explicit core terms or assumptions

## 6. E-Graph / Rewrite Saturation Protocol

This belongs on optimization or elaboration support paths, not inside kernel conversion.

```text
name: eqsat-opt
layer: executable core or runtime IR
trust_class: advisory
```

Algebra:

```text
X   = expressions or IR graphs
Σ   = rewrite set, extraction policy, semantic side conditions
A   = well-formedness under the IR grammar
≈   = congruence closure / semantic equivalence class
D#  = e-class summary domain
G   = rewrite application and saturation
C   = rewrite sequence, extracted representative, cost report
F   = cost metric over equivalent representatives
E   = executable or IR semantics
```

Rights:

- may read `Α`
- may write `Α`
- may propose optimized candidates
- may not write `Δ`

Invariant:

- if used on kernel terms, extracted representatives must still be kernel-checked
- no e-graph engine may define kernel conversion

## 7. Abstract Interpretation Protocol

This computes sound approximations of behaviors.

```text
name: absint-check
layer: runtime IR or protocol state
trust_class: advisory
```

Algebra:

```text
X   = X_rir or X_state
Σ   = safety property, transfer semantics, domain policy
A   = summary soundness for the abstract semantics
≈   = abstraction-induced equivalence, optional state quotient
D#  = chosen abstract domain
G   = abstract transfer, join, widen, narrow
C   = fixpoint summary, invariant set, warning set
F   = precision / cost tradeoff
E   = concrete runtime or transition semantics
```

Rights:

- may read `Ρ`, `Α`
- may write `Α`
- may propose summaries and proof obligations
- may not write `Δ`

Required evidence:

- explicit abstract summary
- proof obligations when approximation is insufficient

## 8. Symbolic Execution Protocol

This explores paths and emits witness traces or path conditions.

```text
name: symexec
layer: runtime IR or executable fragment
trust_class: advisory
```

Algebra:

```text
X   = symbolic states, path conditions, symbolic traces
Σ   = target property, exploration bounds, entry state
A   = path feasibility
≈   = path-state merge relation
D#  = optional path summary abstraction
G   = branch expansion, state merge, solver-guided refinement
C   = witness input, path trace, path condition
F   = coverage / target reachability / path cost
E   = execution semantics
```

Rights:

- may read `Ρ`, `Α`
- may write `Α`
- may propose counterexamples or witness inputs
- may not write `Δ`

## 9. Model Checking Protocol

This validates transition-system properties, not dependent-typing judgments.

```text
name: model-check
layer: protocol or machine state
trust_class: advisory
```

Algebra:

```text
X   = states, invariants, transition systems
Σ   = (I, ->, P) or temporal property package
A   = invariant admissibility or reachability exclusion
≈   = bisimulation or symmetry quotient
D#  = predicate abstraction domain
G   = next-state generation, abstraction refinement
C   = counterexample trace, inductive invariant, liveness witness
F   = none or minimal trace length
E   = transition semantics
```

Rights:

- may read `Ρ`, `Α`
- may write `Α`
- may propose invariants or traces
- may not write `Δ`

Invariant:

- model-checker results do not become kernel theorems without a separate reification path

## 10. Runtime Monitoring Protocol

This validates observed executions only.

```text
name: runtime-monitor
layer: concrete execution
trust_class: advisory
```

Algebra:

```text
X   = X_trace
Σ   = contract set, temporal policy, runtime assertions
A   = trace satisfaction
≈   = trace quotient if monitors compress equivalent events
D#  = online summary domain
G   = event stream progression
C   = blame report, violating trace, monitor summary
F   = monitor overhead
E   = observed execution semantics
```

Rights:

- may read `X_trace`, `Α`
- may write `Α`
- may not propose trusted truths
- may not write `Δ`

## 11. Differential Testing Protocol

This compares two semantics-preserving candidates empirically or symbolically.

```text
name: differential-check
layer: executable core / runtime
trust_class: advisory
```

Algebra:

```text
X   = candidate pairs (x1, x2)
Σ   = input generator, oracle policy, comparison relation
A   = observational agreement on tested inputs
≈   = observational equivalence target
D#  = optional generated input summary
G   = input generation, shrink, replay
C   = distinguishing input, coverage report, agreement report
F   = coverage / bug yield
E   = observed behavior relation
```

Rights:

- may read `Α`, execution harnesses
- may write `Α`
- may not write `Δ`

## Mutation Matrix

This is the main capability boundary.

| Backend | Trust | May Read | May Write | May Propose | May Mutate `Δ` |
|---|---|---|---|---|---|
| Kernel checker | trusted | `Γ`, `Δ` | `Δ` | checked declarations | yes |
| Frontend lowering | checked | `Ω`, optional `Δ` | `Ω` | core terms | no |
| Elaboration solver | checked | `Γ`, `Δ`, `Ω` | `Ω` | core terms, obligations | no |
| Proof search | checked | `Γ`, `Δ`, `Ω` | `Ω`, `Α` | proof terms | no |
| SMT / SAT | advisory | obligations, `Α` | `Α` | models, witnesses | no |
| E-graph optimizer | advisory | IR, rewrites, `Α` | `Α` | optimized candidates | no |
| Abstract interpreter | advisory | `Ρ`, IR, `Α` | `Α` | summaries, obligations | no |
| Symbolic executor | advisory | `Ρ`, IR, `Α` | `Α` | traces, witness inputs | no |
| Model checker | advisory | `Ρ`, `Α` | `Α` | invariants, traces | no |
| Runtime monitor | advisory | traces, `Α` | `Α` | reports only | no |
| Differential tester | advisory | harness, traces, `Α` | `Α` | distinguishing tests | no |

## Evidence Types

Backends must emit typed evidence, never bare booleans:

```text
C_kernel      = typing_derivation | conversion_trace | rejection
C_frontend    = lowered_term | source_map | lowering_error
C_elab        = solved_term | residual_constraints | elaboration_trace
C_proof       = proof_term | tactic_trace | failed_branch_report
C_smt         = model | unsat_core | solver_proof | unknown
C_eqsat       = eclass_report | extracted_term | rewrite_chain
C_absint      = abstract_fixpoint | invariant_summary | alarm_set
C_symexec     = witness_input | path_condition | symbolic_trace
C_model       = counterexample_trace | inductive_invariant | unknown
C_runtime     = blame_report | monitor_trace | pass_summary
C_diff        = distinguishing_input | equivalence_report
```

This is how composition stays explicit.

## Composition Discipline

Composite workflows must preserve evidence boundaries:

```text
propose -> check -> refine -> quotient -> select
```

Typical composition:

1. frontend or proof search proposes a candidate
2. kernel checks it or rejects it
3. abstract interpretation or SMT emits obligations or counterexamples
4. optimizer saturates an equivalence region
5. selector chooses the cheapest admissible representative

No stage may skip its evidence contract.

## Reification Rules

External backends may influence trusted truth only through reification:

- SMT witness -> explicit core term -> kernel check
- model-checker invariant -> explicit statement/proof or explicit assumption
- optimizer output -> equivalence proof or post-check under a validator
- abstract summary -> proof obligation or trusted checker acceptance

If reification is impossible, the result stays advisory or becomes an explicit assumption.

## Layer Instantiations

Freeze these first:

### Kernel Core

```text
X   = explicit core terms
Σ   = (Γ, T)
A   = typing
≈   = definitional equality
D#  = none
G   = external construction only
C   = typing derivation
F   = none
E   = core semantics
```

### Executable Core

```text
X   = pure executable terms
Σ   = observational equivalence target, cost policy
A   = semantic equivalence / refinement
≈   = observational equivalence
D#  = optional reduction summary
G   = rewrite, partial evaluation, extraction
C   = equivalence witness, cost report
F   = runtime cost
E   = observable behavior
```

### Runtime IR

```text
X   = closure-runtime IR graphs
Σ   = safety and optimization policy
A   = safety property or refinement check
≈   = IR observational equivalence
D#  = tag/range/shape abstract domains
G   = lowering, rewrite, symbolic path expansion
C   = summaries, traces, optimized candidate
F   = instruction count, allocation count, latency estimate
E   = runtime semantics
```

### Protocol / Machine State

```text
X   = transition systems, states, invariants
Σ   = temporal property package
A   = invariant admissibility / liveness support
≈   = bisimulation / symmetry quotient
D#  = predicate abstraction
G   = next-state generation, abstraction refinement
C   = invariants, traces, reports
F   = optional trace length or state cost
E   = transition semantics
```

## Non-Negotiable Rules

- The kernel is the only writer of trusted logical truth.
- Frontend, elaboration, proof search, and optimization are proposers, not admitters.
- Solver answers are not theorems.
- Runtime observations are not universal proofs.
- Any backend that cannot emit typed evidence must be treated as advisory only.
- Equivalence saturation must never define kernel conversion.

## Immediate Implementation Mapping

Given the current workspace:

- trusted kernel: `package.lisp`, `term-env.lisp`, `subst.lisp`, `reduce.lisp`, `typecheck.lisp`, `bootstrap.lisp`
- checked frontend: `frontend.lisp`
- checked/advisory regression harnesses: `kernel-tests.lisp`, `frontend-tests.lisp`

The next implementation artifact should be a code-level protocol layer, for example:

- `backend-protocol.lisp`: structs for candidate/spec/evidence/status
- `frontend-api.lisp`: surface declaration lowering contract
- `advisory-artifacts.lisp`: typed storage for models, traces, summaries, reports

That would turn this document from architecture law into executable interface law.
