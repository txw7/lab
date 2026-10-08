# AutoProof receipt correspondence V1

## Checkpoint scope

This bounded follow-on to Lab PR4 commit
`850a0d564199b3acb36221b0cb21332b15466784` aligns the original Lab receipt judge
with the original Research producer's target-context contract. The full new
gate and exact-source producer experiment are being recorded separately; this
checkpoint alone is not a completed proof or integration receipt.

The source authority is `txw7/research` PR12 commit
`e154f65e1976754718e4b3ef0726c388e67c7d97`, which contains merged PR70:

- `autoproof/src/autoproof/promote.py::_verify_target_context` compares the
  theorem's complete `metadata.checker_context` against its plan. Both
  `lab_judgment_request` and theorem promotion invoke that comparison.
- `autoproof/schemas/proof_check_plan_v1.json` requires
  `object_type=ProofCheckPlan`.
- `autoproof/schemas/checker_result_v1.json` requires
  `object_type=CheckerResult` and `checker=lean4`.
- `autoproof/src/autoproof/checker.py::LeanChecker._result` emits null
  `failure_class` for its successful Lean outcome.

Lab previously compared some duplicated metadata fields but ignored the
theorem's complete pinned checker context. Recomputing all embedded content
hashes did not prevent admission of a stale/different source context, another
checker kind, incorrect record object types, or an explicit failure class as
`LEAN_CHECKED_THEOREM_V1`.

The runner now enforces those original context/record contracts. Dependency
maps and context fields compare independently of JSON member order. It still
does not authenticate a result or create a new hashing authority. Research
retains content-addressed store validation and theorem promotion.

Generic proof metadata is extensible; `checker_context` is not mandatory for
every `ProofObjectV1`. It is required for this successful addressed Lean
judgment because the original `lab_judgment_request` requires it. Unrelated
metadata remains allowed. No-obligation and unsupported-operation handling
does not require a checker context.

The focused gate uses synthetic receipt data. The optional original-producer
exercise loads five hash-verified Research source files, uses its actual model,
object store, result formatter and Lab request builder, and supplies a MOCKED
successful checker-process outcome. No Lean process is invoked and no theorem
is promoted. Hash recomputation is not authentication or mathematical proof.

Run `python3 scripts/check-autoproof-receipt-pins-v1.py`; set
`AUTOPROOF_RESEARCH_ROOT` to the pinned `autoproof/src/autoproof` directory to
also run the original-producer correspondence exercise. `SBCL` can name an
absolute SBCL executable. Omission of the optional source is reported as
not run, rather than silently counted as passed.

Original FORMAL remains blocked by the unresolved historical source
`/home/user0/MIR/pure_asm_and_or_write/xlisp0-orbit-stage1-hll-concept.lisp`.
No shim, replacement backend, dependency removal, actual Lean execution,
Goggles modification, live provider activation, merge or deployment occurs.

Work-order binding: orchestration PR13
`71416c751aac38da5efab3dde7cb7434482ebb93`, unchanged
`work/alignment/WORK_ORDER_GENERATIVE_GROWTH_V1.md`, GG06 exact
source/proposition/checker coverage. This change does not close GG06 or P01.
