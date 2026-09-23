# LSIP FORMAL MIG Spec

This document defines the preparation target for integrating `FORMAL` into the
LSIP lowering lattice as an admission fabric.

It is not an artifact-ingestion spec.
It is not a `J`-lane or witness-alignment spec.
It is not the live integration patch plan.

It is the edge-contract spec for MIG preparation.

## Goal

Make `FORMAL` usable as a first-class gate on LSIP lowering edges, so LSIP can
treat `FORMAL` as a dependency for edge admission without depending on
hand-coded shape checks or internal `FORMAL` symbols.

The target architecture is:

```text
LSIP lowering edge
  -> compiled FORMAL relation carrier
  -> FORMAL gate family
  -> typed evidence
  -> admit / reject edge result
```

## Non-Goals

This phase does not:

- patch LSIP runtime calls yet,
- replace LSIP lowering functions,
- use `FORMAL` as the semantic authority for LSIP,
- collapse LSIP strata into a generic `module` carrier,
- treat JSON or witness artifacts as the primary integration object.

## LSIP Lattice Scope

The relevant LSIP strata are defined in:

- [docs/ir-lattice-taxonomy.md](../LLL/LSIP/docs/ir-lattice-taxonomy.md)
- [docs/machine-web-current-state.md](../LLL/LSIP/docs/machine-web-current-state.md)
- [docs/metacircular-machine-spec.md](../LLL/LSIP/docs/metacircular-machine-spec.md)

The first integration spine is:

```text
S1 -> T0 -> X0 -> X1 -> X2 -> R0 -> A0
```

Using the concrete LSIP anchors:

- `S1 -> T0`
  - `recognized-typed-tree-from-root`
  - [constitutional.lisp](../LLL/LSIP/lisp/constitutional.lisp)
- `T0 -> X0`
  - `lower-typed-tree-to-ir2`
  - [ir2.lisp](../LLL/LSIP/lisp/ir2.lisp)
- `X0 -> X1`
  - `lower-ir2-to-compiler-ir`
  - [lower_surface_to_ir.lisp](../LLL/LSIP/lisp/lower_surface_to_ir.lisp)
- `X1 -> X2`
  - `rehydrate-runtime-program-from-compiler-ir`
  - [runtime_rehydration.lisp](../LLL/LSIP/lisp/runtime_rehydration.lisp)
- `X2/R0 -> A0`
  - `sync-runtime-state-to-authority`
  - `rehydrate-runtime-state-from-authority`
  - `apply-admission-transaction`
  - [runtime_sync.lisp](../LLL/LSIP/lisp/runtime_sync.lisp)
  - [admission.lisp](../LLL/LSIP/lisp/admission.lisp)

## Integration Unit

The integration unit is a lowering edge contract.

Proposed shape:

```lisp
(:formal-edge-contract
  :id ...
  :source-strata ...
  :target-strata ...
  :lsip-anchor ...
  :relation-compiler ...
  :gate-family ...
  :law-ids ...
  :evidence-kind ...
  :admission-hook ...
  :status ...)
```

Required fields:

- `:id`
  stable edge contract id
- `:source-strata`
  source LSIP lattice strata
- `:target-strata`
  target LSIP lattice strata
- `:lsip-anchor`
  concrete LSIP lowering or admission function family
- `:relation-compiler`
  FORMAL-side compiler from LSIP edge data into a FORMAL relation carrier
- `:gate-family`
  which FORMAL capability family checks the edge
- `:law-ids`
  explicit laws applied on the relation carrier
- `:evidence-kind`
  typed result emitted by FORMAL
- `:admission-hook`
  LSIP-side action on success or failure
- `:status`
  `:prepared`, `:attached`, `:partial`, or `:unsupported`

## FORMAL Gate Families

There are four gate families that matter for LSIP preparation.

### 1. Structural LSIP law

This is the default first gate.

Use it for:

- identity stability,
- callable-surface preservation,
- authority-linkset preservation,
- residency separation,
- inertness,
- admission ordering.

This is the right first-class family for the currently prepared LSIP edges.

### 2. Kernel lane parity

Use this only when an LSIP edge produces a frozen executable fragment whose
behavior must be compared across:

- `KR`
- `KL`
- `DefIR`

This is not the default LSIP gate.

### 3. SMT admitted bridge

Use this only when an LSIP edge carries explicit symbolic side conditions such
as:

- bounded arithmetic,
- layout constraints,
- branch admissibility,
- counterexample-driven edge rejection.

### 4. Closure profile check

Use this for later promotion and self-extension edges.

This belongs after the first structural spine is attached.

## FORMAL Relation Carriers

LSIP should not hand raw rows to arbitrary FORMAL checks.
Each edge must lower into a typed FORMAL relation carrier.

Initial relation families:

- `s1->t0-recognition-relation`
- `t0->x0-normalization-relation`
- `x0->x1-compiler-lowering-relation`
- `x1->x2-runtime-rehydration-relation`
- `x2-r0->a0-sync-admission-relation`

Each relation carrier must include:

- edge id,
- source objects,
- target objects,
- machine context if applicable,
- anchor metadata,
- digest or identity rows needed for stability checks.

## Initial Edge Contracts

### `S1 -> T0`

Anchor:

- `recognized-typed-tree-from-root`

Contract family:

- structural LSIP law

Initial laws:

- recognition determinism on equivalent source payload
- canonical typed-node class stability
- governance metadata continuity
- address continuity into `T0`

Status:

- prepared only

### `T0 -> X0`

Anchor:

- `lower-typed-tree-to-ir2`

Contract family:

- structural LSIP law

Initial laws:

- binding/capture closure preservation
- executable normalization identity stability
- typed child/class continuity into `IR2`
- operator-contract metadata continuity where present

Status:

- prepared only

### `X0 -> X1`

Anchor:

- `lower-ir2-to-compiler-ir`

Contract family:

- structural LSIP law

Initial laws:

- compiler-ir node class validity
- projection metadata preservation
- lambda or callable coverage preservation
- source-to-target address continuity

Status:

- prepared only

### `X1 -> X2`

Anchor:

- `rehydrate-runtime-program-from-compiler-ir`

Contract family:

- structural LSIP law

Initial laws:

- deterministic runtime-program id
- callable-table completeness
- callable node resolution
- authority-linkset continuity

Status:

- closest first live attachment target

### `X2/R0 -> A0`

Anchors:

- `sync-runtime-state-to-authority`
- `rehydrate-runtime-state-from-authority`
- `apply-admission-transaction`

Contract family:

- structural LSIP law

Initial laws:

- machine residency separation
- inertness under bounded evaluation
- authority-linkset preservation through sync
- admission ordering and reindex-before-operativity

Status:

- closest second live attachment target

## Existing LSIP Law Set Already Prepared In FORMAL

The current prepared law surface in `FORMAL` already includes:

- `:x1-to-x2-rehydration-stability`
- `:x2-r0-to-a0-machine-residency-separation`
- `:x2-r0-to-a0-runtime-inertness`
- `:x2-r0-to-a0-authority-linkset-preservation`
- `:x2-r0-to-a0-admission-ordering`

These are the correct first law families to attach to live LSIP edges.

## LSIP Calling Convention

LSIP remains the owner of lowering and admission functions.

The intended calling pattern is:

1. LSIP performs a candidate edge transition.
2. LSIP compiles the edge into a FORMAL relation carrier.
3. LSIP calls the FORMAL gate identified by the edge contract.
4. FORMAL returns typed evidence and status.
5. LSIP treats failure as non-admission of the edge result.
6. LSIP records success or failure alongside its own transaction objects.

This is an admission mesh over LSIP edges, not a replacement compiler.

## Integration Ordering

Do not attach all edges at once.

Recommended order:

1. `X1 -> X2`
2. `X2/R0 -> A0`
3. `X0 -> X1`
4. `T0 -> X0`
5. `S1 -> T0`
6. later `X1 -> P0/P2`
7. later `X1 -> E0/E1`
8. later promotion and self-extension edges

Reason:

- the executable and admission spine is already concrete in LSIP,
- the relevant FORMAL structural laws already exist,
- these edges are the least speculative attachment points.

## MIG Preparation Deliverables

Preparation is complete for MIG when all of the following exist:

1. edge contract registry
   every targeted LSIP edge has a first-class FORMAL contract entry

2. relation compilers
   every targeted edge can compile its before/after objects into a FORMAL
   relation carrier

3. gate mapping
   every targeted edge maps to one explicit FORMAL gate family and law set

4. typed evidence
   every gate emits stable typed evidence suitable for LSIP admission records

5. dry-run checks
   the first live LSIP-produced edge objects can be checked by FORMAL without
   hand-written per-script glue

## What Still Does Not Belong In This Phase

Do not do these in MIG prep:

- full LSIP runtime interception,
- global wrapping of every LSIP function,
- treating witness exports as the semantic integration target,
- using generic artifact ingestion as the integration story,
- adding x86 or `/bits` semantics into FORMAL,
- enabling FORMAL self-extension via synthesis.

Those belong after the edge-contract layer is attached and stable.

## Short Form

The integration target is:

```text
LSIP lowering edge
  -> FORMAL relation compiler
  -> FORMAL gate family
  -> typed evidence
  -> LSIP admission decision
```

The correct first-class object is the lowering edge contract.
The correct first live edges are `X1 -> X2` and `X2/R0 -> A0`.
The correct first gate family is `:structural-lsip-law`.
