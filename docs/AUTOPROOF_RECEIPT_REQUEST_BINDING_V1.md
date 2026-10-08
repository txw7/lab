# AutoProof receipt request binding V1

## Scope

This is a bounded U1 wire change to the original Lab owner at
`txw7/lab` branch `codex/autoproof-addressed-checker-binding`, base
`4c7334b50d3eecdb033bf72c5e3871c3356cc95d`. It binds the original Research
request envelope to its exact returned Lab judgment and carries the already
validated checker context onward. It creates no alternate object store,
semantic graph, proof authority, permission authority or activation path.

This is **receipt correspondence**, not independent theorem checking. The
wire test's checker-process result is mocked. Even a `CHECKED` Lab result here
means that an incoming receipt satisfies the declared correspondence contract;
it does not authenticate the sender or demonstrate Lean execution. Its
`theorem_status_effect` remains `NONE`. Research retains object-store content
verification and promotion; the checker and its validation remain trusted
boundaries. Downstream currentness tests must keep proof truth `UNKNOWN` for
these fixtures.

## Original-owner field map

The source of the request recipe is Research
[`promote.py::lab_judgment_request`](https://github.com/txw7/research/blob/e154f65e1976754718e4b3ef0726c388e67c7d97/autoproof/src/autoproof/promote.py).
The request has `schema=LSIPTheoremMathSearchResultV1`,
`status=FORMAL_RECEIPT_SUBMITTED`, explicit `candidate=null`, and
`formal_obligation.operation_id=judge_lean_checker_receipt`.

The exact obligation ID is reconstructed using the original producer's string
recipe, not a new digest algorithm:
`autoproof-lean-receipt:{payload_row.target_ref}:{payload_row.checker_result_ref}`.
Missing, foreign and stale correlation IDs are rejected. This ID is carried
unchanged to `LabFormalDischargeResultV1.formal_obligation_id`.

The existing `formal_judgment` remains unchanged:

- `target_ref` identifies the original Research `target_record.object_id` and
  equals the original `checker_plan.goal_ref`.
- `target_occurrence_ref`, `subject_snapshot_ref` and
  `program_graph_address` match the target's original metadata.
- `checker_plan_ref` and `checker_result_ref` identify the embedded original
  plan/result; `checker_result.plan_ref` must match the plan.

Successful `evidence` now also retains:

- `checker_context`: the exact original target metadata context, already
  compared with the plan and result. Its six fields are `module_path`,
  `module_source_sha256`, `dependency_source_digests`, `lean_version`,
  `mathlib_revision`, and `lake_manifest_sha256`.
- `expected_theorem`: the already matched original plan theorem name.
- `stdout_sha256` and `stderr_sha256`: required 64-character lowercase SHA-256
  identities from the original checker result formatter.

An empty dependency map remains `{}`, rather than becoming JSON `null` on
output. JSON member order does not affect the existing context comparison.
No full original proof object is duplicated in the returned evidence.

## Bounded data decoding

Receipt payloads are ordinary JSON and no longer pass through the SMT Lisp
symbol decoder. The existing SMT operation still owns and uses its historical
wire decoder. Incoming Lisp forms are not evaluated.

`read-json-file` has opt-in `strict`, `max-bytes`, `max-depth` and
`max-container-items` options. Legacy callers retain their defaults. The
public runner chooses strict parsing and limits of 1 MiB input, 64 nested
containers and 4,096 members/items per container. The receipt profile accepts
one obligation and explicit null candidate, not an unbounded candidate/trace
batch. Duplicate keys, trailing commas, leading-zero numbers and raw control
characters are rejected. Existing unsupported JSON constructs remain
unsupported. Unknown top-level request schemas are rejected before dispatch.

Malformed or over-limit input returns a retained
`LabFormalDischargeResultV1` with `status=REJECTED`,
`theorem_status_effect=NONE`, no formal judgment, and a rejection reason. Such
rejection is operational wire rejection, not mathematical refutation.

## Verification

Run:

    python3 scripts/check-autoproof-receipt-pins-v1.py

`SBCL` may point to an existing SBCL binary. `SBCL_HOME` may be needed for a
relocated binary. No dependency installation is part of this test.

Set `AUTOPROOF_RESEARCH_ROOT` to the original pinned Research
`autoproof/src/autoproof` package to exercise its actual model, object store,
checker-result formatter and request builder. The harness verifies all five
source blobs before import. It supplies a **MOCKED checker-process outcome**;
no Lean process or theorem promotion occurs.

Optionally set `AUTOPROOF_PORTABLE_EVIDENCE_DIR` to retain the exact positive
request and actual Lab runner output as `portable-request.json` and
`portable-result.json`, plus the matching `Fixture.lean` bytes. The module
hash is real; library and manifest pins are synthetic and do not establish a
checker installation or complete source closure. The repository evidence
copies are named `mocked-producer-request.json` and
`mocked-producer-result.json` to preserve this limit.

The compact evidence records the five baseline bypasses reproduced against
the unmodified pinned runner, their fixed outcomes and the final test counts.
All mutants recompute their embedded content IDs, so rejection is not merely
a stale fixture hash effect.

## Open gates

This change does not reconstruct a graph proposition or prove graph-rule
semantics. Original Goggles/H005 translation and full proposition comparison
remain their owner's responsibility. The proposed full synthesis subject
(source/interface/target terms, role maps, relation, context, assumptions,
effects and generation) is not representable by this narrower legacy receipt
alone. Therefore full U1 cross-owner compatibility remains open.

The original checker result has no exact command identity field. That part of
the proposed checker execution contract remains open. Content hashes are not
authentication. A fully self-consistent fabricated receipt can still satisfy
this wire contract; it must not become independent proof through this test.

Original Lean replay is still `BLOCKED_CANCELLED_DEPENDENCY_RESOLUTION`.
Original FORMAL aggregate still lacks its MIR Stage1 dependency. Neither
installation was restarted, no replacement prover was introduced, and there
is no rule admission, provider activation, merge or deployment claim.
