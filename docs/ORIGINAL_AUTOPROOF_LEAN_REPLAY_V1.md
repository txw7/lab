# Original AutoProof Lean replay V1

## Blocked execution checkpoint

This checkpoint preserves a replay driver for the original Research theorem
`RHMachine.mobiusS_mobiusZ` in `RHMachine/Mobius.lean`. Driver checkpoint
`e485633b7559a5d62f30f0ece28cea04ca394385` is published and byte-verified.
Python syntax compilation passes. The theorem checker, Lab judgment and stale
source negative were NOT RUN because original dependency resolution was
cancelled before readiness. Earlier synthetic receipt tests are not evidence
that this theorem ran.

The official Lean archive checksum was verified, and its actual executables
reported Lean 4.34.0 / Lake 5.0.0-src+293d5d0. The original Mathlib checkout
resolved to the required commit. Resolution then failed while cloning original
transitive dependency `leanprover-community/batteries` at
`f2effa3d803fda822b1f97b806c47cf2adfbcbc2`, with `Proxy CONNECT aborted`.
Polling the operation returned `automatic approval review was cancelled`.
No retry executed and no alternate download route was used. The project's
`lake-manifest.json` was not created; batteries and Cli were still absent.
The retained outer operation has no captured successful exit status.

This boundary is distinct from the missing original MIR Stage1 source. Neither
was replaced or bypassed. Exact source, toolchain, package-state and blocked
execution evidence is retained in
`docs/evidence/ORIGINAL_AUTOPROOF_LEAN_REPLAY_V1.json`.

Original source owner: `txw7/research` PR12 at
`e154f65e1976754718e4b3ef0726c388e67c7d97`. The theorem file has Git blob
`1cdecc8b5388f00449eeced903a46efbbe9779e2`. It states that for a complex `s`
with `s != 0`, the inverse Mobius coordinate recovers `s`. The exact original
module is checked, rather than replacing it with a simpler theorem.

The original project pins Lean `leanprover/lean4:v4.34.0` and Mathlib
`5ed2965256430c3649e86755f9576b54eca72435`. The official Linux archive is
`lean-4.34.0-linux.tar.zst` from the Lean4 `v4.34.0` release, with published
SHA-256 `caaa98356098c85dc0fcbbd28e1ec66f39eb6551829972b752ff20e1286b646b`.
Only an isolated task-local installation is used; no global settings change.

The replay driver verifies the original theorem, project settings, five
Research Python modules, and four Lab source blobs before use. It calls the
unchanged original `LeanChecker.capture_context`, `make_plan`, and `check`,
retains their actual content-addressed records, and passes the successful
checker result through the original Research Lab-request builder and Lab
judgment runner. The source file is never edited. A separately rehashed plan
with a wrong source digest must return `DEPENDENCY_MISMATCH`.

Example, after provisioning the original dependencies:

```sh
python3 scripts/replay-original-autoproof-lean-v1.py \
  --research-package /path/to/research/autoproof/src/autoproof \
  --lean-root /path/to/research/autoproof/lean \
  --output /path/to/new-receipt-directory
```

Lean/Lake must be on PATH; `SBCL` may name an absolute executable. The driver
does not install dependencies, modify original source, or promote a theorem.
The output directory must be new so previous receipts are preserved.

The address passed to Lab is explicitly an authored isolated replay fixture.
It does not certify a live ProgramGraph, source-to-graph translation, or a
production graph admission. Actual mathematical checking, exact source/result
binding, Lab judgment, and theorem-status promotion are distinct boundaries.
`theorem_status_effect` stays `NONE`; the original theorem target stays
`UNPROVEN` in the temporary store because promotion is not invoked.

The unresolved original MIR Stage1 source still blocks the full FORMAL/Lab
aggregate. This replay supplies no shim or replacement FORMAL backend, performs
no full RH build, and does not close global P00/G02/GG06/P01.

Work-order pin: orchestration PR13
`50bfccd17e186193c1da8ab9d574be8c6f9f9df5`,
`work/alignment/WORK_ORDER_GENERATIVE_GROWTH_V1.md`, GG06 original proof closure.
