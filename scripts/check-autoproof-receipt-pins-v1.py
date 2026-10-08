#!/usr/bin/env python3
"""Exercise Lab receipt binding only; all checker records here are synthetic.

Run with SBCL on PATH, or set SBCL to its absolute binary path. This gate does
not run Lean, prove the fixture theorem, or validate content-addressed records.
"""

import copy
import json
import os
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "scripts/run_autoproof_formal_discharge_v1.lisp"


def fixture():
    source = "a" * 64
    manifest = "b" * 64
    address = {
        "schema": "ProgramGraphAddressBindingV1",
        "authority_ref": "fixture:authority",
        "source_revision": "fixture:revision",
        "source_graph_root": "fixture:root",
        "h001_graph_object_ref": "fixture:graph",
        "h001_bundle_ref": "fixture:bundle",
        "h002_address_ref": "fixture:address",
        "h002_containment_witness_ref": "fixture:containment",
        "mapping_witness_ref": "fixture:mapping",
        "target_occurrence_ref": "fixture:occurrence",
        "subject_snapshot_ref": "fixture:snapshot",
    }
    plan = {
        "schema": "ProofCheckPlanV1",
        "object_id": "sha256:" + "1" * 64,
        "goal_ref": "sha256:" + "2" * 64,
        "expected_theorem": "Fixture.example",
        "lean_module": "Fixture.lean",
        "target_source_sha256": source,
        "dependency_source_digests": {},
        "lean_version": "Lean (version 4.29.1)",
        "mathlib_revision": "3" * 40,
        "lake_manifest_sha256": manifest,
    }
    result = {
        "schema": "CheckerResultV1",
        "object_id": "sha256:" + "4" * 64,
        "plan_ref": plan["object_id"],
        "status": "CHECKED",
        "trusted": True,
        "process_status": 0,
        "exit_status": 0,
        "expected_theorem": plan["expected_theorem"],
        "module_path": plan["lean_module"],
        "source_sha256": source,
        "module_source_sha256": source,
        "dependency_source_digests": {},
        "lean_version": plan["lean_version"],
        "mathlib_revision": plan["mathlib_revision"],
        "lake_manifest_sha256": manifest,
    }
    payload = {
        "target_ref": plan["goal_ref"],
        "target_occurrence_ref": address["target_occurrence_ref"],
        "subject_snapshot_ref": address["subject_snapshot_ref"],
        "program_graph_address": address,
        "checker_plan_ref": plan["object_id"],
        "checker_result_ref": result["object_id"],
        "target_record": {
            "schema": "ProofObjectV1",
            "object_id": plan["goal_ref"],
            "object_type": "FormalLemma",
            "status": "UNPROVEN",
            "metadata": {
                "target_occurrence_ref": address["target_occurrence_ref"],
                "subject_snapshot_ref": address["subject_snapshot_ref"],
                "program_graph_address": copy.deepcopy(address),
                "expected_theorem": plan["expected_theorem"],
                "target_source_sha256": source,
            },
        },
        "checker_plan": plan,
        "checker_result": result,
    }
    return {
        "schema": "LSIPTheoremMathSearchResultV1",
        "candidate": {"carrier_ref": "fixture:candidate"},
        "formal_obligation": {
            "obligation_id": "fixture:obligation",
            "operation_id": "judge_lean_checker_receipt",
            "payload_row": payload,
        },
    }


def run_case(name, request, expected, directory):
    source = directory / "request.json"
    output = directory / "result.json"
    source.write_text(json.dumps(request), encoding="utf-8")
    process = subprocess.run(
        [os.environ.get("SBCL", "sbcl"), "--script", str(RUNNER), str(source), str(output)],
        capture_output=True, text=True, timeout=30,
    )
    assert process.returncode == 0, (name, process.stderr)
    row = json.loads(output.read_text())
    assert row["status"] == expected, (name, row)
    assert row["theorem_status_effect"] == "NONE", (name, row)
    if expected == "REJECTED":
        assert row["formal_judgment"] is None, (name, row)
        assert row["evidence"]["rejection_reason"], (name, row)
    if expected == "CHECKED":
        assert row["formal_judgment"]["kind"] == "LEAN_CHECKED_THEOREM_V1"
    print("PASS", name)


def cases():
    yield "complete-pins-empty-local-dependencies", fixture(), "CHECKED"
    row = fixture()
    payload = row["formal_obligation"]["payload_row"]
    for key in ("checker_plan", "checker_result"):
        payload[key]["dependency_source_digests"] = {"Dependency.lean": "c" * 64}
    yield "complete-pins-nonempty-local-dependencies", row, "CHECKED"

    groups = [
        [("metadata", "expected_theorem"), ("checker_plan", "expected_theorem"),
         ("checker_result", "expected_theorem")],
        [("metadata", "target_source_sha256"), ("checker_plan", "target_source_sha256"),
         ("checker_result", "source_sha256"), ("checker_result", "module_source_sha256")],
        [("checker_plan", "lean_module"), ("checker_result", "module_path")],
        [("checker_plan", "lean_version"), ("checker_result", "lean_version")],
        [("checker_plan", "mathlib_revision"), ("checker_result", "mathlib_revision")],
        [("checker_plan", "lake_manifest_sha256"), ("checker_result", "lake_manifest_sha256")],
    ]
    for group in groups:
        for variant in ("missing", "empty", "whitespace", "null", "number"):
            row = fixture()
            p = row["formal_obligation"]["payload_row"]
            for owner, field in group:
                record = p["target_record"]["metadata"] if owner == "metadata" else p[owner]
                if variant == "missing":
                    record.pop(field)
                else:
                    record[field] = {"empty": "", "whitespace": " \t ", "null": None, "number": 17}[variant]
            yield f"joint-{group[0][1]}-{variant}", row, "REJECTED"
        for owner, field in group:
            for variant in ("missing", "mismatch"):
                row = fixture()
                p = row["formal_obligation"]["payload_row"]
                record = p["target_record"]["metadata"] if owner == "metadata" else p[owner]
                if variant == "missing":
                    record.pop(field)
                else:
                    record[field] = "d" * 64 if "sha256" in field else "different"
                yield f"individual-{owner}-{field}-{variant}", row, "REJECTED"

    for variant in ("missing", "null", "false", "empty-array", "array", "nested-map",
                    "nested-array", "nested-false", "bad-digest", "bad-path", "wrong-type"):
        row = fixture()
        p = row["formal_obligation"]["payload_row"]
        for key in ("checker_plan", "checker_result"):
            if variant == "missing":
                p[key].pop("dependency_source_digests")
            else:
                p[key]["dependency_source_digests"] = {
                    "null": None, "false": False, "empty-array": [],
                    "array": ["D.lean", "c" * 64], "nested-map": {"D.lean": {}},
                    "nested-array": {"D.lean": []}, "nested-false": {"D.lean": False},
                    "bad-digest": {"D.lean": "not-a-digest"},
                    "bad-path": {"": "c" * 64}, "wrong-type": "not-a-map",
                }[variant]
        yield f"joint-dependency-map-{variant}", row, "REJECTED"
    row = fixture()
    row["formal_obligation"]["payload_row"]["checker_result"]["dependency_source_digests"] = {"D.lean": "c" * 64}
    yield "dependency-map-mismatch", row, "REJECTED"

    for field in fixture()["formal_obligation"]["payload_row"]["program_graph_address"]:
        if field == "schema":
            continue
        row = fixture()
        p = row["formal_obligation"]["payload_row"]
        p["program_graph_address"][field] = ""
        p["target_record"]["metadata"]["program_graph_address"][field] = ""
        if field in ("target_occurrence_ref", "subject_snapshot_ref"):
            p[field] = ""
            p["target_record"]["metadata"][field] = ""
        yield f"empty-address-{field}", row, "REJECTED"
    for field in ("target_occurrence_ref", "subject_snapshot_ref", "checker_plan_ref", "checker_result_ref"):
        row = fixture()
        row["formal_obligation"]["payload_row"][field] = "different"
        yield f"mismatched-{field}", row, "REJECTED"
    for field, value in (("trusted", False), ("process_status", 1), ("exit_status", 1), ("status", "FAILED")):
        row = fixture()
        row["formal_obligation"]["payload_row"]["checker_result"][field] = value
        yield f"failed-checker-{field}", row, "REJECTED"
    row = fixture()
    row["formal_obligation"] = None
    yield "no-formal-obligation-preserved", row, "NO_FORMAL_OBLIGATION"
    row = fixture()
    row["formal_obligation"]["operation_id"] = "unavailable_operation"
    yield "unsupported-operation-preserved", row, "CAPABILITY_MISSING"


def check_parser_and_smt_wire(directory):
    request_path = directory / "request.json"
    result_path = directory / "result.json"
    request_path.write_text(json.dumps(fixture()), encoding="utf-8")
    parser_path = directory / "typed.json"
    parser_path.write_text(json.dumps({
        "empty_object": {}, "empty_array": [], "false": False, "null": None,
        "map": {"D.lean": "c" * 64},
        "nested": {"values": [False, [], {}, None]},
        "literal": "JSON-EMPTY-ARRAY", "false_literal": "JSON-FALSE",
        "wire": [{"$keyword": "ITEMS"}, [], {"$keyword": "FLAG"}, False],
    }), encoding="utf-8")
    wrapper = directory / "parser-check.lisp"
    wrapper.write_text(f'''(with-open-file (stream {json.dumps(str(RUNNER))})
  (read-line stream) ; skip the executable script's shebang
  (load stream))
(let* ((path {json.dumps(str(parser_path))})
       (legacy (mini-kernel::read-json-file path))
       (typed (mini-kernel::read-json-file path :preserve-container-types t)))
  (assert (null (%json-get legacy "empty_object")))
  (assert (null (%json-get legacy "empty_array")))
  (assert (null (%json-get legacy "false")))
  (assert (eq :null (%json-get legacy "null")))
  (assert (null (%json-get typed "empty_object")))
  (assert (eq mini-kernel::*json-empty-array* (%json-get typed "empty_array")))
  (assert (eq mini-kernel::*json-false* (%json-get typed "false")))
  (assert (eq :null (%json-get typed "null")))
  (assert (equal (%json-get legacy "map") (%json-get typed "map")))
  (let ((values (%json-get (%json-get typed "nested") "values")))
    (assert (eq mini-kernel::*json-false* (first values)))
    (assert (eq mini-kernel::*json-empty-array* (second values)))
    (assert (null (third values)))
    (assert (eq :null (fourth values))))
  (assert (not (eq mini-kernel::*json-empty-array* (%json-get typed "literal"))))
  (assert (not (eq mini-kernel::*json-false* (%json-get typed "false_literal"))))
  (assert (equal (%wire-decode (%json-get typed "wire")) '(:items nil :flag nil)))
  (assert (equal (%wire-decode (%json-get legacy "wire"))
                 (%wire-decode (%json-get typed "wire"))))
  (assert (equal (%wire-decode (%json-get legacy "nested"))
                 (%wire-decode (%json-get typed "nested")))))
(format t "ParserDefaultTypedAndSmtWireGreen: 18 assertions~%")
''', encoding="utf-8")
    process = subprocess.run(
        [os.environ.get("SBCL", "sbcl"), "--script", str(wrapper), str(request_path), str(result_path)],
        capture_output=True, text=True, timeout=30,
    )
    assert process.returncode == 0, process.stderr
    assert "ParserDefaultTypedAndSmtWireGreen" in process.stdout, process.stdout
    print(process.stdout.strip())


def main():
    with tempfile.TemporaryDirectory(prefix="lab-receipt-pins-") as temp:
        count = 0
        for name, request, expected in cases():
            run_case(name, request, expected, Path(temp))
            count += 1
        check_parser_and_smt_wire(Path(temp))
    print(f"AutoProofReceiptPinsV1Green: {count} checks; synthetic receipt binding only")


if __name__ == "__main__":
    main()
