#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v sbcl >/dev/null
command -v lake >/dev/null
command -v cargo >/dev/null
command -v python3 >/dev/null

sbcl --noinform --disable-debugger \
  --eval "(require :asdf)" \
  --eval "(asdf:load-asd \"$ROOT/formal/formal.asd\")" \
  --eval "(asdf:load-asd \"$ROOT/formal/math/formal-math.asd\")" \
  --eval "(asdf:load-asd \"$ROOT/theorem-workbench/theorem-workbench.asd\")" \
  --eval "(asdf:load-asd \"$ROOT/rh-workbench/rh-workbench.asd\")" \
  --eval "(asdf:load-system \"formal\")" \
  --load "$ROOT/formal/backend-protocol-tests.lisp" \
  --load "$ROOT/formal/theorem-ir-tests.lisp" \
  --load "$ROOT/formal/theorem-proof-tests.lisp" \
  --load "$ROOT/formal/search-protocol-tests.lisp" \
  --load "$ROOT/formal/lsip-preparation-tests.lisp" \
  --eval "(assert (mini-kernel-backend-protocol-tests:run-tests))" \
  --eval "(assert (mini-kernel-theorem-ir-tests:run-tests))" \
  --eval "(assert (mini-kernel-theorem-proof-tests:run-tests))" \
  --eval "(assert (mini-kernel-search-protocol-tests:run-tests))" \
  --eval "(assert (mini-kernel-lsip-preparation-tests:run-tests))" \
  --eval "(asdf:load-system \"formal-math/tests\")" \
  --eval "(asdf:load-system \"theorem-workbench/tests\")" \
  --eval "(asdf:load-system \"rh-workbench/tests\")" \
  --eval "(assert (lab.math:run-formal-math-tests))" \
  --eval "(assert (lab.theorem-workbench:run-theorem-workbench-tests))" \
  --eval "(assert (lab.rh-workbench:run-rh-workbench-tests))" \
  --eval "(quit)"


TMP_AUTOPROOF="$(mktemp -d)"
trap 'rm -rf "$TMP_AUTOPROOF"' EXIT
cat >"$TMP_AUTOPROOF/search.json" <<'JSON'
{
  "schema": "LSIPTheoremMathSearchResultV1",
  "status": "CANDIDATE_GENERATED",
  "candidate": {
    "carrier_ref": "candidate:lab-smoke"
  },
  "formal_obligation": null
}
JSON

sbcl --script "$ROOT/scripts/run_autoproof_formal_discharge_v1.lisp"   "$TMP_AUTOPROOF/search.json"   "$TMP_AUTOPROOF/formal.json"

python3 - "$TMP_AUTOPROOF/formal.json" <<'PY'
import json
import pathlib
import sys
row = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert row["schema"] == "LabFormalDischargeResultV1"
assert row["status"] == "NO_FORMAL_OBLIGATION"
assert row["theorem_status_effect"] == "NONE"
PY

python3 - "$TMP_AUTOPROOF/request.json" "$TMP_AUTOPROOF/rejected-request.json" <<'PY'
import json
import pathlib
import sys

target_ref = "sha256:" + "1" * 64
plan_ref = "sha256:" + "2" * 64
result_ref = "sha256:" + "3" * 64
digest = "a" * 64
target = {
    "schema": "ProofObjectV1",
    "object_type": "FormalLemma",
    "object_id": target_ref,
    "status": "UNPROVEN",
    "metadata": {
        "expected_theorem": "Fixture.theorem",
        "target_source_sha256": digest,
        "target_occurrence_ref": "occurrence:fixture",
        "subject_snapshot_ref": "snapshot:fixture",
        "program_graph_address": {
            "schema": "ProgramGraphAddressBindingV1",
            "authority_ref": "program-graph:fixture-authority",
            "source_revision": "sha256:fixture-revision",
            "source_graph_root": "sha256:fixture-graph-root",
            "h001_graph_object_ref": "h001:fixture-object",
            "h001_bundle_ref": "h001:fixture-bundle",
            "subject_snapshot_ref": "snapshot:fixture",
            "h002_address_ref": "h002:fixture-address",
            "h002_containment_witness_ref": "h002:fixture-containment",
            "mapping_witness_ref": "h002:fixture-mapping",
            "target_occurrence_ref": "occurrence:fixture",
        },
    },
}
plan = {
    "schema": "ProofCheckPlanV1",
    "object_id": plan_ref,
    "goal_ref": target_ref,
    "expected_theorem": "Fixture.theorem",
    "lean_module": "Fixture.lean",
    "target_source_sha256": digest,
    "dependency_source_digests": {},
    "lean_version": "Lean fixture",
    "mathlib_revision": "mathlib-fixture",
    "lake_manifest_sha256": "b" * 64,
}
result = {
    "schema": "CheckerResultV1",
    "object_id": result_ref,
    "status": "CHECKED",
    "trusted": True,
    "process_status": 0,
    "exit_status": 0,
    "plan_ref": plan_ref,
    "expected_theorem": "Fixture.theorem",
    "module_path": "Fixture.lean",
    "source_sha256": digest,
    "module_source_sha256": digest,
    "dependency_source_digests": {},
    "lean_version": "Lean fixture",
    "mathlib_revision": "mathlib-fixture",
    "lake_manifest_sha256": "b" * 64,
}
payload = {
    "target_ref": target_ref,
    "target_occurrence_ref": "occurrence:fixture",
    "subject_snapshot_ref": "snapshot:fixture",
    "program_graph_address": target["metadata"]["program_graph_address"],
    "checker_plan_ref": plan_ref,
    "checker_result_ref": result_ref,
    "target_record": target,
    "checker_plan": plan,
    "checker_result": result,
}
request = {
    "schema": "LSIPTheoremMathSearchResultV1",
    "status": "FORMAL_RECEIPT_SUBMITTED",
    "formal_obligation": {
        "obligation_id": "fixture-obligation",
        "operation_id": "judge_lean_checker_receipt",
        "payload_row": payload,
    },
}
pathlib.Path(sys.argv[1]).write_text(json.dumps(request), encoding="utf-8")
payload["target_occurrence_ref"] = "occurrence:wrong"
pathlib.Path(sys.argv[2]).write_text(json.dumps(request), encoding="utf-8")
PY

sbcl --script "$ROOT/scripts/run_autoproof_formal_discharge_v1.lisp" \
  "$TMP_AUTOPROOF/request.json" "$TMP_AUTOPROOF/judgment.json"
sbcl --script "$ROOT/scripts/run_autoproof_formal_discharge_v1.lisp" \
  "$TMP_AUTOPROOF/rejected-request.json" "$TMP_AUTOPROOF/rejected-judgment.json"
python3 - "$TMP_AUTOPROOF/judgment.json" "$TMP_AUTOPROOF/rejected-judgment.json" <<'PY'
import json
import pathlib
import sys
accepted = json.loads(pathlib.Path(sys.argv[1]).read_text())
rejected = json.loads(pathlib.Path(sys.argv[2]).read_text())
assert accepted["status"] == "CHECKED"
assert accepted["theorem_status_effect"] == "NONE"
assert accepted["formal_judgment"]["kind"] == "LEAN_CHECKED_THEOREM_V1"
assert accepted["formal_judgment"]["target_occurrence_ref"] == "occurrence:fixture"
address = accepted["formal_judgment"]["program_graph_address"]
assert address["schema"] == "ProgramGraphAddressBindingV1"
assert address["h001_graph_object_ref"] == "h001:fixture-object"
assert address["h002_address_ref"] == "h002:fixture-address"
assert accepted["formal_judgment"]["checker_result_ref"] == "sha256:" + "3" * 64
assert rejected["status"] == "REJECTED"
assert rejected["theorem_status_effect"] == "NONE"
PY

rm -rf "$TMP_AUTOPROOF"
trap - EXIT

(
  cd "$ROOT/formal"
  lake build
)

(
  cd "$ROOT/sim-lab"
  cargo test
)
