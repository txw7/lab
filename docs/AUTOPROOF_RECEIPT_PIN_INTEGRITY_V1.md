# AutoProof receipt pin integrity V1

## Bounded repair

The Lab-owned `scripts/run_autoproof_formal_discharge_v1.lisp` judges binding
between an addressed theorem, a Research checker plan, and its returned checker
record. At baseline `3cdf93550ab81b8b120965287a0da4f18c71ea4d`, a reproduced
request omitted every theorem/source/toolchain pin from both sides. Equality
of missing values admitted it as `CHECKED` with `LEAN_CHECKED_THEOREM_V1`.

The repair requires nonblank theorem/module/toolchain and addressing strings,
64-character lowercase SHA-256 source/manifest digests, and explicitly supplied
local dependency maps with valid path/digest entries before existing equality
checks run. An empty dependency object remains valid. A missing map, JSON null,
false, arrays, malformed digests, and nested non-digest values are rejected.

`formal/json-lite.lisp` provides opt-in typed empty carriers. Default readers
retain their original behavior. Uninterned sentinels distinguish empty arrays
and false from empty objects without colliding with parsed JSON values. The
receipt runner opts in; its existing SMT wire decoder maps those sentinels to
the legacy Lisp values. Receipt judgment examines the undecoded JSON records.

Every returned judgment retains `theorem_status_effect=NONE`. These checks do
not execute Lean, authenticate a receipt, recompute a content-addressed object
identity, reconstruct dependency closure, or establish theorem correctness.
Research remains responsible for checker-record validation and promotion.
The synthetic positive test records are fixture data, never proof evidence.

## Focused gate

```sh
python3 scripts/check-autoproof-receipt-pins-v1.py
```

Requires Python 3 and SBCL on PATH, or `SBCL=/absolute/path/to/sbcl` (and its
normal `SBCL_HOME` when using an unpacked distribution). It covers valid empty
and nonempty local dependency maps; jointly missing/empty/null/malformed pins;
individual missing and mismatched values; malformed dependency-map types;
address and checker failures; unchanged no-obligation/unsupported outcomes;
default/typed JSON reading; nested values; and SMT wire-decoding parity.

The gate runs independently of the full FORMAL system. Its execution receipt
is `docs/evidence/AUTOPROOF_RECEIPT_PIN_INTEGRITY_V1.json`.

## Original backend ownership and unresolved load closure

`txw7/lab` owns `formal/`; the repository README explicitly identifies it as
the source imported from historical `FORMAL/`. The original ASDF definition is
`formal/formal.asd`, blob `0f1bf89830ac056d12eadeae4f949cf8d7ac88d5`, system
`formal`, package `mini-kernel`. Lab PR1 is pinned at
`abf3fd588d643b89a842fbd16f7d865057ac15c9`; this review branch originally starts
at PR4 `3cdf93550ab81b8b120965287a0da4f18c71ea4d`, three commits ahead of PR1.
Its full formal sources are unchanged from PR1. Lab main is a different cut,
`50b9430f0ef8c62caa0ef37d9cf54b942534a612`.

A fresh exact-source load materialized the original 44 Lisp components,
`formal.asd`, and five required/retained Lean data files, verifying all 50 Git
blob identities. Loading the system reaches the eager call to
`initialize-ingested-algorithm-registry` in `stage1-concept.lisp`, then fails on:

```text
/home/user0/MIR/pure_asm_and_or_write/xlisp0-orbit-stage1-hll-concept.lisp
```

That original external source is still unavailable in this execution
environment. It was not replaced, omitted, synthesized, or registered through
a fake backend. The full Lab aggregate and unchanged Goggles live FORMAL gate
remain blocked. An ASDF source-directory override alone cannot close them.
The Lab Lean toolchain pin is `leanprover/lean4:v4.29.1`; no Lean build or new
mathematical proof is claimed by this repair.

Work-order binding: orchestration PR13 at
`74afe01824c14824ccc30ac096e3e2ea131a66b2`,
`work/alignment/WORK_ORDER_GENERATIVE_GROWTH_V1.md`, GG06 original proof closure,
and the alignment P00/G02/P01 ownership/admission work. This bounded original
Lab-owner repair does not close GG06/P01, integrate diverged Goggles adapters,
or waive the original runtime/proof prerequisites.
