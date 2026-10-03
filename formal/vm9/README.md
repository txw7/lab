# VM9 native certificate seam: infrastructure smoke and open refinement

This additive candidate uses the unchanged `txw7/lab` core at
[`50b9430f0ef8c62caa0ef37d9cf54b942534a612`](https://github.com/txw7/lab/tree/50b9430f0ef8c62caa0ef37d9cf54b942534a612/formal).
It does **not** complete VM9 refinement. It establishes a replayable native
certificate seam and prevents external evidence from being relabeled as a native
proof. Full 9VM remains the verification target. Protocol-governor/stacks are WIP
examples of selecting/expanding/shrinking that flow, not the primary target or a
claim of production activity.

## Actual abstract phase-progress projection

The core environment has the original frozen `pi0` Nat/Eq primitives and
original `add`. The model has two Nat state components, cursor and remaining:

- Init: `(cursor, remaining) = (0, 9)`
- Progress: `(c, succ(r)) -> (succ(c), r)`, emitting phase `succ(c)`
- Invariant: `phase-budget(c,r) := Eq Nat (add(c,r)) 9`

Two closed canonical typing certificates are checked by both original kernels:

1. `phase-budget(0,9)`.
2. For every c,r:Nat, `phase-budget(c,succ(r))` implies
   `phase-budget(succ(c),r)`.

The preservation proof is genuinely inductive. A checked `nat-rec` proof
establishes `add(c,succ(r)) = succ(add(c,r))`; the Eq recursor transports the
pre-state invariant to the post-state invariant. All added definitions are
checked by both kernels before insertion. See `phase-model.json` for the exact
state/transition/theorem schema and `phase-model.lisp` for the terms.

This is a phase-progress projection of the separately repaired temporal model,
not a complete encoding of the phase log. The proposed projection is
`cursor=Len(phaseLog), remaining=9-Len(phaseLog)`; its relation to the TLA model
and actual Rust is still unproved. No native `StrictOrderInv` over recorded logs,
authorization invariant, terminal no-confusion theorem, whole loop or
source/runtime refinement is claimed. The independent Lean/Isabelle lane also
remains open. User-facing completion must not call this full VM9 closure.

Earlier arbitrary-natural count/reflexivity examples remain named smoke
constructors only; they are not emitted by the production envelope and are not
counted as VM9 proof progress.

## Existing owner APIs, no competing checker

- `proof-ir.lisp`: `make-has-type-claim`, `make-proof-evidence`,
  `make-proof-fragment`, `proof-fragment->certificate`.
- `certificate.lisp`: canonical `:typing` and frozen `pi0`, environment binding.
- `typecheck.lisp`, `reduce.lisp`, `subst.lisp`: original native judgment.
- `reference-checker.lisp`: independently implemented original reference judgment.
- `advisory-artifacts.lisp`: residual report storage through the existing
  `model-check` advisory backend.

The new modules construct terms and validates a bounded transport/claim envelope.
It neither replaces a theorem checker nor creates a scheduler. The original
`formal.asd`, all kernels and AutoProof `:proved` path remain unchanged. No solver
result is registered as a new axiom. `checker-ids`, metadata and evidence
`checkedp` flags cannot confer authority: both kernels recheck the actual terms.
Native/reference agreement is a regression check, not a proved checker metatheory.

## Thirteen explicit residuals

All remain `:open`; the current admission path rejects removing, changing, or
promoting them:

- Normative VM9/TLA contracts to the core model
- Actual Rust and all state owners to the core model
- Verus proof/extraction to checkable core proof
- Kani bounded result to checkable core proof
- Whole VM9 phase/contract/configuration composition
- Compiler/ABI/binary/host runtime correspondence
- Exact authoritative mutation and boundary coverage
- Reversible H001/H002/Goggles recursive correspondence
- Independent Lean/Isabelle semantics/refinement proof for the same subject
- Per-child interface proof or explicit TCB identity
- Runtime restart/crash/concurrency/reconciliation evidence
- Cross-lane semantic digest convergence
- Canon admission before materialization and execution

The envelope binds external evidence as evidence only. The five assumptions of
the historical P1/P2 conditional Kani claim are retained exactly: Rust lowering,
Kani's transformation/model, CBMC/CaDiCaL, host integrity, and the replay checker.
They are inherited boundary labels, not sufficient assumptions to discharge all
residuals. Verus and TLC artifacts, if present in the binding manifest, are
advisory supporting inputs and have their own unresolved tool/model/extraction
boundaries. No new external prover run is performed by this lab command.

The old conditional CheckedTheorem concerns a pinned checker accepting a bounded
P1/P2 candidate. It remains a separate subject from newly edited VM9 source and
Verus work. The binding records each input's role; it cannot retroactively make
the old Kani theorem apply to edited source.

## Frozen inputs and replay

`bindings.json` identifies the base repository revision plus the exact bytes of
candidate source/proof/evidence, separately from that base. `replay.py` pins the
binding manifest and verifies all required input bytes before and after each
Lisp process. Supply the external input roots named in that manifest. No paths
outside a supplied root are allowed. Replaying against changed bytes fails and
requires a new explicitly reviewed binding version.

`owner-manifest.json` records exact Git blobs independently fetched through GitHub
for every retained owner source, including normative/proof carrier inspection
inputs. The runner verifies both Git blob SHA-1 and SHA-256 against the exact lab
pin. `load-lab.lisp` uses those unchanged owner files, not a copied implementation.
In an upstream lab checkout, the owner root is that checkout. In this private
candidate the same files live under `owners/lab`.

The certificate environment identity is the full sorted declaration snapshot,
including kinds, types, bodies and reducibility, plus the lab pin. This deliberately
does not treat a supplied `:bootstrap-v1` label as an authenticated environment.
The enclosing input file manifest has cryptographic SHA-256 identities.

The runner produces a plain S-expression envelope, then starts a **new** SBCL
process, parses it as data with reader evaluation disabled, reconstructs the
original certificate structs, checks input identity, rebuilds the fixed model
environment and rechecks both judgments. Residual records are restored and
validated too. Dispatch-reader syntax and trailing data are rejected.

Example (paths are installation-specific):

```sh
python3 formal/vm9/replay.py \
  --sbcl /path/to/sbcl --sbcl-home /path/to/sbcl/lib \
  --lab-root /path/to/pinned-lab \
  --input-root phase12=/path/to/vm9-phase12 \
  --input-root spec-verus=/path/to/vm9-spec-verus \
  --out /path/to/fresh-evidence
python3 -m unittest discover -s formal/vm9 -p 'test_*.py' -v
VM9_LAB_FORMAL_ROOT=/path/to/pinned-lab/formal/ \
  SBCL_HOME=/path/to/sbcl/lib /path/to/sbcl --script formal/vm9/tests.lisp
```

The selected owner load has forward-reference warnings for unused broader owner
APIs. Those APIs are not invoked. Kernel failures still abort the command. This
is not a run of lab's full ASDF test suite or the unrelated Lean metatheory build.

## What actually closes the remaining integration gap

A green Kani/Verus/TLC process is not a core certificate. The next required work is
semantic and proof-producing:

1. Freeze complete VM9 contracts and an explicit state/transition relation with
   hooks, failure paths, dispatch stages and all state owners. Select supported
   configurations and state exclusions explicitly.
2. Define those semantics in core (using checked definitions/encodings) and prove
   their invariants with explicit core proof terms. The Nat count model here is
   insufficient for that task.
3. Prove the relation from actual Rust implementation to the formal transition
   model, including machine integer boundaries, collections, calls/aliasing,
   callbacks and extracted-helper/annotation-erasure correspondence.
4. Either reconstruct external proof steps into existing core proof terms, with
   a checked semantic translation, or retain explicit external assumptions. No
   Kani/Verus proof-export adapter exists at the pinned lab revision. Adding a
   success-log parser, registering an axiom, or counting successful checks does
   not discharge this obligation. A SAT certificate alone would still leave
   Rust-to-GOTO/bitvector/CNF translation obligations.
5. Compose every nine-phase and contract obligation. Bind actual callable roots
   and all unresolved ProgramGraph/KT calls/memory effects. A small prefix is not
   a whole-program refinement.
6. Separately establish source-to-binary, ABI/component and runtime/host behavior.
   Pin the exact deployment artifacts only when that lane is performed.

Only after these obligations are represented and discharged should a distinct
full-refinement certificate and AutoProof admission rule be proposed. This
candidate intentionally has no method that marks a residual `:proved`.

## Full end-to-end target remains open

The user-specified closure chain requires an independently stated Lean or
Isabelle proof lane, exact state/transition/reactor/theorem/correspondence
digests, zero unresolved safety obligations in the declared theorem set, and
zero unmapped authoritative mutations. This candidate has neither a complete
`VM9_FORMAL_SUBJECT_V1` nor a `VM9_FORMAL_CLOSURE_V1`. Its fresh-process
certificate replay is transport/kernel evidence only, not VM9 crash recovery or
logical exactly-once dispatch evidence. No Canon admission, materialization,
Supersession registration, or runtime deployment was attempted. Owner-native
authority facts remain facts of those owners.
