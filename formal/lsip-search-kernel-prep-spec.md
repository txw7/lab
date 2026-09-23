# LSIP Search Kernel Prep Spec

This document fixes the implementation-preparation target for the LSIP search
kernel as a first-class formal machine.

It is not a generic GA note.
It is not a loose research sketch.
It is not the full implementation patch set.

It is the formal preparation spec for the typed, evidence-bearing search kernel
that LSIP will eventually use for governed synthesis over large compiler,
admissible, atomic, placement, and policy state spaces.

## Goal

Make the future LSIP search lane implementable as a disciplined formal kernel
with:

- dependent typed state,
- local operator footprints,
- legality before fitness,
- explicit obligation emission,
- FORMAL bridge totality on hard classes,
- evidential closure,
- admission law,
- quotient-based archive identity,
- layered fitness,
- banded scheduling,
- protected second-order mutation.

The target machine object is:

```text
parent states
  -> operator instance
  -> legality witness
  -> offspring derivation
  -> formal obligations
  -> FORMAL payload projections
  -> formal evidence
  -> evidence update
  -> admission law
  -> quotient / archive identity
  -> layered fitness
  -> scheduler feedback
```

## Kernel Model

The governing kernel object is:

```text
K = (Sigma, X, U, L, T, Omega, Pi, Xi, Lambda, A, Q, F, <=F, Psi)
```

Where:

- `Sigma`
  machine signature
- `X`
  well-typed search states
- `U`
  operator instances
- `L`
  legal transition relation
- `T`
  generative transition map into pending offspring states
- `Omega`
  obligation emission map
- `Pi`
  family of obligation projection maps into FORMAL payloads
- `Xi`
  evidence update map
- `Lambda`
  admission laws
- `A`
  admission classifier under an admission law
- `Q`
  family of band-specific quotient maps
- `F`
  vector fitness map
- `<=F`
  layered fitness preorder
- `Psi`
  banded search scheduler

## State Model

The search state is not one flat Cartesian product.
It is a dependent product over typed graph shape.

The base snapshot is a typed attributed directed hypergraph:

```text
g = (V, H, s, t, tauV, tauH, lambda, z)
```

This is required because:

- derivations are higher-arity,
- crossover is higher-arity,
- obligation scope is often region or seam-local,
- admission and evidence are not ordinary binary edges.

The full state space is a disjoint union over graph shape:

```text
X = coproduct over g in G_Sigma of
    X_comp(g) x X_cat(g) x X_place(g) x X_adm(g) x
    X_form(g) x X_policy(g) x X_archive(g) x X_budget(g)
```

This dependent form is mandatory because many coordinates only exist once a
particular carrier graph and typing context already exist.

## Search Bands

Search bands do not partition states.
They govern:

- operator footprint scale,
- proof and evaluation budget,
- quotient regime,
- scheduler rate,
- archive identity policy.

The current intended bands are:

- `mu`
  micro, local single-carrier or single-seam rewrites
- `nu`
  meso, coordinated seam-neighborhood rewrites
- `Omega`
  macro, policy, bridge, operator-law, and scheduler mutation

## Current FORMAL Surface

`FORMAL` already has several useful pieces for this future kernel.

### Implemented now

- governed capability invocation
  - `mini-kernel:invoke-formal-capability`
  - [constitutional-runtime.lisp](/home/user0/FORMAL/constitutional-runtime.lisp:675)
- SMT checking over the admitted fragment
  - `mini-kernel:check-smt-spec`
  - [smt-spec.lisp](/home/user0/FORMAL/smt-spec.lisp:17)
- capability-governed SMT invocation
  - [constitutional-runtime.lisp](/home/user0/FORMAL/constitutional-runtime.lisp:1149)
- CEGIS family catalog and search IR catalog
  - [cegis.lisp](/home/user0/FORMAL/cegis.lisp:414)
- LSIP preparation and edge-law coverage surfaces
  - [lsip-preparation.lisp](/home/user0/FORMAL/lsip-preparation.lisp:1)
- LSIP search-alignment manifest layer
  - [lsip-preparation.lisp](/home/user0/FORMAL/lsip-preparation.lisp:1)

### Partial now

- obligation-like catalogs
  - present for CEGIS families, not yet frozen for the full search kernel
- evidence-like artifacts
  - present operationally, not yet formalized as a general search-lane closure algebra
- LSIP-facing relation and gate preparation
  - present for edge-preparation and law coverage, not yet for full search-state transitions

### Missing now

- legality as a first-class judgment family
- region algebra and boundary legality
- bridge-totality checking over hard obligation classes
- evidential closure algebra
- admission-law checker family
- quotient/canonicalization family
- layered fitness derivation
- scheduler semantics
- second-order legality for policy and bridge mutation

## Capability Gap Matrix

### 1. Legality kernel

Status:

- missing

Required algorithms:

- typed hypergraph well-formedness checker
- region closure checker
- immutable-boundary context checker
- operator-domain checker
- replay-definition checker
- budget-feasibility checker
- zone-permission checker
- second-order legality checker for policy and bridge mutations

Why it matters:

- without legality, the search engine selects from ill-formed transitions
- legality is the first survival law, fitness is second

### 2. Obligation and bridge totality

Status:

- partial

Required algorithms:

- frozen search-kernel obligation catalog
- obligation severity and freshness schema
- zone-to-hard-obligation classifier
- projection-totality checker
- projection non-emptiness checker on hard classes
- checker-availability versus checker-admissibility distinction

Why it matters:

- without bridge totality, FORMAL is advisory decoration
- hard obligations must always lower into a defined FORMAL payload family

### 3. Evidential closure

Status:

- missing

Required algorithms:

- obligation status lattice
  - `:open`
  - `:fresh-pass`
  - `:fresh-fail`
  - `:stale`
  - `:superseded`
- evidence-to-obligation attachment checker
- freshness evaluator
- debt-summary derivation checker
- coverage-summary derivation checker
- append-only evidence history checker
- supersession-link builder

Why it matters:

- FORMAL results must be state-transforming objects, not side comments
- admission and fitness both depend on evidence-closed state

### 4. Admission law

Status:

- missing

Required algorithms:

- admission-law schema checker
- zone-relative hard/advisory obligation evaluator
- quarantine classifier
- reject classifier
- admit classifier
- kernel-preservation checker
- shadow-control evaluator for second-order policy and bridge mutation

Why it matters:

- admission must be a formal predicate over evidence-closed states
- otherwise promotion remains loose policy code

### 5. Quotient and archive identity

Status:

- missing

Required algorithms:

- band-specific canonicalizers
- quotient witness objects
- replay-up-to-quotient checker
- archive dedupe checker
- novelty distance over quotient classes
- elite retention identity checker

Why it matters:

- large search without quotienting degrades into duplicate-state noise
- archive identity must be canonical, not raw state id

### 6. Fitness and selection

Status:

- missing

Required algorithms:

- hard debt vector derivation
- advisory debt vector derivation
- novelty vector derivation
- capability gain derivation
- resource cost vector derivation
- stability penalty derivation
- layered preorder comparator

Why it matters:

- scalar reward is too weak for this machine
- FORMAL debt must be the first coordinate block of fitness

### 7. Scheduler semantics

Status:

- missing

Required algorithms:

- band budget allocator
- parent tuple sampler
- operator instance sampler
- archive-aware novelty sampler
- debt-aware band promotion rule
- macro-band shadow-control scheduler

Why it matters:

- macro policy search cannot compete directly with local compiler rewrites
- search bands must be enforced operationally

## First Carrier Slice To Build

The first implementation slice should stop before full evolutionary strategy and
instead establish the kernel skeleton.

Required LSIP carriers:

- `operator-class`
- `operator-instance`
- `legal-transition`
- `offspring-derivation`
- `formal-obligation`
- `obligation-projection`
- `formal-evidence`
- `evidence-update`
- `admission-law`

Required node families:

- `operator-class-node`
- `operator-instance-node`
- `legal-transition-node`
- `offspring-derivation-node`
- `formal-obligation-node`
- `obligation-projection-node`
- `formal-evidence-node`
- `evidence-update-node`
- `admission-law-node`

Required seams:

- `search-state -> operator-instance`
- `operator-class -> operator-instance`
- `operator-instance -> legal-transition`
- `legal-transition -> offspring-derivation`
- `offspring-derivation -> formal-obligation`
- `formal-obligation -> obligation-projection`
- `obligation-projection -> FORMAL payload`
- `FORMAL result -> formal-evidence`
- `formal-evidence -> evidence-update`
- `evidence-update -> search-state`
- `admission-law -> search-state admission`

## Kernel Invariants

These are the first invariants that should become machine-checkable.

### `I1` Type preservation

For every legal transition, the offspring lies in the pending typed state space.

### `I2` Locality preservation

The structural delta is confined to the declared footprint and immutable
boundary rebinding surface.

### `I3` Hard bridge totality

Every hard emitted obligation has a defined and non-empty FORMAL payload family.

### `I4` Replay determinism up to quotient

Replaying an admitted derivation yields the same canonical identity under the
active band quotient.

### `I5` Evidence monotonicity

Admitted evidence is append-only history.
Supersession adds newer evidence but never rewrites prior evidence.

### `I6` Admission soundness

If a state is admitted under an admission law, then the hard debt vector is
zero on all hard obligation kinds relevant to the touched zones.

### `I7` Kernel preservation under second-order mutation

If a policy or bridge mutation is admitted, then the minimum kernel remains
present, replayable, and total on hard zones.

### `I8` Archive consistency

States with the same canonical key under the active band quotient are treated
as the same archive identity for dedupe, novelty, and elite retention.

## Minimum Non-Removable Kernel

Reflexive search is only coherent if a minimum kernel cannot be removed.

The future minimum kernel should include:

- minimum hard obligation catalog
- minimum projection family on those hard obligations
- minimum replay law set
- minimum provenance and lineage preservation law set

Second-order legality must enforce:

- no removal of minimum hard obligations
- no partiality introduced on minimum hard projections
- no loss of replayability for admitted operator classes
- no destructive rewriting of admitted lineage or evidence
- no self-governed first admission for policy or bridge mutations

Policy and bridge mutations must first run in shadow control under the previous
admitted law plus kernel checks.

## Build Order

### Stage 1. Region and graph basis

Implement:

- typed hypergraph snapshot
- region object
- region closure checker
- immutable boundary row

Reason:

- locality is the first compression device

### Stage 2. Transition legality skeleton

Implement:

- `operator-class`
- `operator-instance`
- `legal-transition`
- `offspring-derivation`

Reason:

- legality and replay come before evolutionary pressure

### Stage 3. Formal bridge skeleton

Implement:

- `formal-obligation`
- `obligation-projection`
- FORMAL payload builders
- first hard bridge-totality checks

Reason:

- obligation emission and projection are constitutive, not optional

### Stage 4. Evidence closure

Implement:

- `formal-evidence`
- `evidence-update`
- freshness rows
- debt summaries
- coverage summaries

Reason:

- admission cannot exist without evidence-closed state

### Stage 5. Admission law

Implement:

- `admission-law`
- admit/quarantine/reject classifier
- minimum-kernel checks
- shadow-control hooks

Reason:

- evidence-backed promotion is the second survival law

### Stage 6. Quotient and archive

Implement:

- `state-quotient`
- canonicalizers
- replay-up-to-quotient checks
- archive identity keys

Reason:

- large search without quotienting will immediately degrade

### Stage 7. Fitness and scheduler

Implement:

- `fitness-vector`
- layered preorder
- `search-schedule`
- band budgets and sampling

Reason:

- only after legality, evidence, admission, and quotient exist does fitness
  become meaningful

## Immediate FORMAL Work Required

Inside `FORMAL`, the next implementation-prep artifacts should be:

1. frozen search obligation catalog
2. frozen projection-totality contract
3. evidence status lattice spec
4. admission-law schema
5. quotient/canonicalization contract
6. layered fitness contract

Those can begin as schema and checker surfaces before full mechanized closure.

## Short Form

Do not evolve source blobs.

Evolve typed carriers over a dependent graph state, with:

- finite local footprints,
- legality before fitness,
- obligation emission on every meaningful transition,
- FORMAL projection totality on all hard classes,
- evidence-bearing closure before admission,
- quotient-based archive identity,
- protected second-order mutation.

The first real implementation slice is:

```text
operator-class
  -> operator-instance
  -> legal-transition
  -> offspring-derivation
  -> formal-obligation
  -> obligation-projection
  -> formal-evidence
  -> evidence-update
  -> admission-law
```

That is the smallest serious kernel slice for LSIP search preparation.
