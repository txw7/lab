#!/usr/bin/env python3
"""Exercise Lab receipt binding only; all checker records here are synthetic.

Run with SBCL on PATH, or set SBCL to its absolute binary path. This gate does
not run Lean, prove the fixture theorem, or validate content-addressed records.
"""

import copy
import hashlib
import importlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import types


ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "scripts/run_autoproof_formal_discharge_v1.lisp"


def content_id(record):
    # These fixtures contain only ASCII JSON values. This is the exact subset
    # of Research canonical.py (sorted compact UTF-8 JSON) exercised here.
    body = {key: value for key, value in record.items() if key != "object_id"}
    return "sha256:" + hashlib.sha256(json.dumps(
        body, ensure_ascii=False, allow_nan=False, sort_keys=True, separators=(",", ":")
    ).encode()).hexdigest()


def reseal(request):
    """Recompute every embedded identity without repairing deliberate bad links."""
    obligation = request.get("formal_obligation")
    if not isinstance(obligation, dict):
        return request
    p = obligation["payload_row"]
    target, plan, result = (p[key] for key in ("target_record", "checker_plan", "checker_result"))
    old_correlation = f"autoproof-lean-receipt:{p['target_ref']}:{p['checker_result_ref']}"
    for record, ref, successor, link in (
        (target, "target_ref", plan, "goal_ref"),
        (plan, "checker_plan_ref", result, "plan_ref"),
        (result, "checker_result_ref", None, None),
    ):
        old = record.get("object_id")
        record["object_id"] = content_id(record)
        if p.get(ref) == old:
            p[ref] = record["object_id"]
        if successor is not None and successor.get(link) == old:
            successor[link] = record["object_id"]
    assert all(record["object_id"] == content_id(record) for record in (target, plan, result))
    if obligation.get("obligation_id") == old_correlation:
        obligation["obligation_id"] = f"autoproof-lean-receipt:{p['target_ref']}:{p['checker_result_ref']}"
    return request


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
        "object_type": "ProofCheckPlan",
        "object_id": "sha256:" + "1" * 64,
        "goal_ref": "sha256:" + "2" * 64,
        "expected_theorem": "Fixture.example",
        "lean_module": "Fixture.lean",
        "target_source_sha256": source,
        "dependency_source_digests": {},
        "lean_version": "Lean (version 4.29.1)",
        "mathlib_revision": "3" * 40,
        "lake_manifest_sha256": manifest,
        "dependency_refs": [],
        "status": "CANDIDATE",
    }
    result = {
        "schema": "CheckerResultV1",
        "object_type": "CheckerResult",
        "checker": "lean4",
        "failure_class": None,
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
        "stdout_sha256": hashlib.sha256(b"").hexdigest(),
        "stderr_sha256": hashlib.sha256(b"").hexdigest(),
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
            "statement_canonical": "Fixture theorem (synthetic checker receipt)",
            "formal_language": "lean4",
            "dependencies": [],
            "domain_constraints": [],
            "provenance": {},
            "created_by": {},
            "evidence_refs": [],
            "metadata": {
                "logical_id": "fixture:theorem",
                "target_occurrence_ref": address["target_occurrence_ref"],
                "subject_snapshot_ref": address["subject_snapshot_ref"],
                "program_graph_address": copy.deepcopy(address),
                "expected_theorem": plan["expected_theorem"],
                "target_source_sha256": source,
                "checker_context": {
                    "module_path": plan["lean_module"],
                    "module_source_sha256": source,
                    "dependency_source_digests": {},
                    "lean_version": plan["lean_version"],
                    "mathlib_revision": plan["mathlib_revision"],
                    "lake_manifest_sha256": manifest,
                },
            },
        },
        "checker_plan": plan,
        "checker_result": result,
    }
    return reseal({
        "schema": "LSIPTheoremMathSearchResultV1",
        "status": "FORMAL_RECEIPT_SUBMITTED",
        "candidate": None,
        "formal_obligation": {
            "obligation_id": f"autoproof-lean-receipt:{payload['target_ref']}:{payload['checker_result_ref']}",
            "operation_id": "judge_lean_checker_receipt",
            "payload_row": payload,
        },
    })


def run_case(name, request, expected, directory):
    request = reseal(request)
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
        p = request["formal_obligation"]["payload_row"]
        assert row["formal_obligation_id"] == request["formal_obligation"]["obligation_id"]
        assert row["evidence"]["checker_context"] == p["target_record"]["metadata"]["checker_context"]
        assert row["evidence"]["expected_theorem"] == p["checker_plan"]["expected_theorem"]
        for field in ("stdout_sha256", "stderr_sha256"):
            assert row["evidence"][field] == p["checker_result"][field]
    print("PASS", name)
    return row


def cases():
    yield "complete-pins-empty-local-dependencies", fixture(), "CHECKED"
    row = fixture()
    payload = row["formal_obligation"]["payload_row"]
    for key in ("checker_plan", "checker_result"):
        payload[key]["dependency_source_digests"] = {"Dependency.lean": "c" * 64}
    payload["target_record"]["metadata"]["checker_context"]["dependency_source_digests"] = {"Dependency.lean": "c" * 64}
    yield "complete-pins-nonempty-local-dependencies", row, "CHECKED"

    row = fixture()
    p = row["formal_obligation"]["payload_row"]
    dependencies = {"A.lean": "c" * 64, "B.lean": "d" * 64}
    p["checker_plan"]["dependency_source_digests"] = dependencies
    p["checker_result"]["dependency_source_digests"] = dict(reversed(list(dependencies.items())))
    context = p["target_record"]["metadata"]["checker_context"]
    context["dependency_source_digests"] = copy.deepcopy(dependencies)
    p["target_record"]["metadata"]["checker_context"] = dict(reversed(list(context.items())))
    yield "context-and-dependency-json-order-independent", row, "CHECKED"

    row = fixture()
    row["formal_obligation"]["payload_row"]["target_record"]["metadata"]["optional_note"] = "extra metadata is allowed"
    yield "optional-unrelated-metadata-preserved", row, "CHECKED"

    for variant in ("missing", "null", "empty-object", "empty-array", "false"):
        row = fixture()
        metadata = row["formal_obligation"]["payload_row"]["target_record"]["metadata"]
        if variant == "missing":
            metadata.pop("checker_context")
        else:
            metadata["checker_context"] = {"null": None, "empty-object": {}, "empty-array": [], "false": False}[variant]
        yield f"target-context-{variant}", row, "REJECTED"
    context_fields = fixture()["formal_obligation"]["payload_row"]["target_record"]["metadata"]["checker_context"]
    for field in context_fields:
        for variant in ("missing", "null", "mismatch"):
            row = fixture()
            context = row["formal_obligation"]["payload_row"]["target_record"]["metadata"]["checker_context"]
            if variant == "missing":
                context.pop(field)
            elif variant == "null":
                context[field] = None
            else:
                context[field] = {"Other.lean": "e" * 64} if field == "dependency_source_digests" else "e" * 64
            yield f"target-context-{field}-{variant}", row, "REJECTED"
    row = fixture()
    row["formal_obligation"]["payload_row"]["target_record"]["metadata"]["checker_context"]["unowned_field"] = "extra"
    yield "target-context-extra-field", row, "REJECTED"
    for owner, field in (("checker_plan", "object_type"), ("checker_result", "object_type"), ("checker_result", "checker")):
        for variant in ("missing", "null", "wrong"):
            row = fixture()
            record = row["formal_obligation"]["payload_row"][owner]
            if variant == "missing":
                record.pop(field)
            else:
                record[field] = None if variant == "null" else "different"
            yield f"schema-{owner}-{field}-{variant}", row, "REJECTED"
    for variant in ("missing", "false", "failure", "empty-string"):
        row = fixture()
        result = row["formal_obligation"]["payload_row"]["checker_result"]
        if variant == "missing":
            result.pop("failure_class")
        else:
            result["failure_class"] = {"false": False, "failure": "lean_rejected", "empty-string": ""}[variant]
        yield f"successful-checker-failure-class-{variant}", row, "REJECTED"

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


def envelope_cases():
    for field, wrong in (("schema", "LSIPTheoremMathSearchResultV99"),
                         ("status", "FAILED"), ("candidate", {"carrier_ref": "other"})):
        for variant in ("missing", "wrong", "empty", "false"):
            request = fixture()
            if variant == "missing":
                request.pop(field)
            else:
                request[field] = {"wrong": wrong, "empty": "", "false": False}[variant]
            yield f"envelope-{field}-{variant}", request, "REJECTED"
    for value in (None, "", "different-request", "autoproof-lean-receipt:target:result"):
        request = fixture()
        request["formal_obligation"]["obligation_id"] = value
        yield f"correlation-{value!r}", request, "REJECTED"
    for spelling in ("JUDGE_LEAN_CHECKER_RECEIPT", "judge-lean-checker-receipt"):
        request = fixture()
        request["formal_obligation"]["operation_id"] = spelling
        yield f"noncanonical-operation-{spelling}", request, "REJECTED"
    for field in ("stdout_sha256", "stderr_sha256"):
        for variant in ("missing", "null", "invalid", "empty"):
            request = fixture()
            result = request["formal_obligation"]["payload_row"]["checker_result"]
            if variant == "missing":
                result.pop(field)
            else:
                result[field] = {"null": None, "invalid": "not-a-digest", "empty": ""}[variant]
            yield f"checker-output-{field}-{variant}", request, "REJECTED"
    request = fixture()
    request["formal_obligation"]["payload_row"]["target_record"]["metadata"]["literal_data"] = {
        "$symbol": "THIS-PACKAGE-DOES-NOT-EXIST:SENTINEL", "$package": "KEYWORD"}
    yield "receipt-symbol-markers-remain-data", request, "CHECKED"
    for name, marker in (
        ("symbol-array", {"$symbol": ["plain", "data"]}),
        ("symbol-object", {"$symbol": {"nested": "data"}}),
        ("keyword-object", {"$keyword": {"nested": "data"}}),
        ("reader-eval-string", '#.(error "must remain a string")'),
    ):
        request = fixture()
        request["formal_obligation"]["payload_row"]["target_record"]["metadata"]["literal_data"] = marker
        yield f"receipt-{name}-remains-data", request, "CHECKED"
    request = fixture()
    request["formal_obligation"]["operation_id"] = "unavailable_operation"
    request["formal_obligation"]["payload_row"]["$symbol"] = {"not": "a symbol"}
    yield "unknown-operation-does-not-decode-symbol-markers", request, "CAPABILITY_MISSING"


def check_raw_envelopes(directory):
    text = json.dumps(fixture())
    requests = {
        "duplicate-root-schema": text.replace('"schema":', '"schema":"ForeignV9","schema":', 1),
        "duplicate-obligation-id": text.replace('"obligation_id":', '"obligation_id":"foreign","obligation_id":', 1),
        "duplicate-result-status": text.replace('"status": "CHECKED"', '"status":"CHECKED","status":"FAILED"'),
        "trailing-object-comma": text[:-1] + ',}',
        "trailing-array-comma": text.replace('"dependencies": []', '"dependencies": ["x",]'),
        "leading-zero": text.replace('"process_status": 0', '"process_status": 00'),
        "raw-control-character": text.replace('"FormalLemma"', '"Formal\x01Lemma"'),
        "nested-over-limit": '{"extra":' + '[' * 65 + '0' + ']' * 65 + '}',
        "bytes-over-limit": '{"extra":"' + 'x' * 1048576 + '"}',
        "items-over-limit": '{"extra":[' + ','.join('0' for _ in range(4097)) + ']}',
        "malformed-root": '[]',
        "trailing-data": text + ' true',
        "duplicate-control-key": text[:-1] + ',"x\\b":1,"x\\b":2}',
        "unknown-schema-without-obligation": '{"schema":"UnknownV9"}',
    }
    for name, raw in requests.items():
        source, output = directory / "raw-request.json", directory / "raw-result.json"
        source.write_text(raw, encoding="utf-8")
        process = subprocess.run(
            [os.environ.get("SBCL", "sbcl"), "--script", str(RUNNER), str(source), str(output)],
            capture_output=True, text=True, timeout=30)
        assert process.returncode == 0, (name, process.stderr)
        result = json.loads(output.read_text())
        assert result["status"] == "REJECTED", (name, result)
        assert result["theorem_status_effect"] == "NONE", (name, result)
        assert result["formal_judgment"] is None, (name, result)
        assert result["evidence"]["rejection_reason"], (name, result)
        print("PASS", name)
    print(f"BoundedReceiptWireGreen: {len(requests)} raw envelope cases")


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


def check_original_research_producer(source_root, directory):
    """Run original model/store/request code with a MOCKED checker outcome.

    The input is research/autoproof/src/autoproof at the pinned PR12 commit.
    No Lean process is invoked, and no theorem is promoted.
    """
    root = Path(source_root)
    expected = {
        "canonical.py": "b2f9bd8311b9bd219d8f89c697654c56634cca98",
        "models.py": "22eb19b467daf05e41aa1077b1a47029a0436b77",
        "store.py": "319d566af4dd65f1c116445e18e64388da411ce2",
        "checker.py": "7d233cd3acd3b634f503b71f9efd1b559d91dbbb",
        "promote.py": "a08cff4cf56e66ab6137fe09fcdb4a808a44e8bc",
    }
    for filename, blob in expected.items():
        data = (root / filename).read_bytes()
        actual = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
        assert actual == blob, (filename, actual, blob)
    name = "_lab_original_research_fixture"
    package = types.ModuleType(name)
    package.__path__ = [str(root)]
    sys.modules[name] = package
    models = importlib.import_module(name + ".models")
    store_type = importlib.import_module(name + ".store").ObjectStore
    checker_type = importlib.import_module(name + ".checker").LeanChecker
    promote = importlib.import_module(name + ".promote")
    store = store_type(directory / "research-store")
    seed = fixture()["formal_obligation"]["payload_row"]
    metadata = copy.deepcopy(seed["target_record"]["metadata"])
    source = b"namespace Fixture\ntheorem example : True := by trivial\nend Fixture\n"
    digest = hashlib.sha256(source).hexdigest()
    metadata["target_source_sha256"] = digest
    metadata["checker_context"]["module_source_sha256"] = digest
    theorem = models.proof_object("FormalLemma", "Fixture.example", formal_language="lean4",
                                  status="UNPROVEN", metadata=metadata)
    theorem_ref = store.put(theorem)
    plan = models.proof_check_plan(theorem_ref, "Fixture.lean", "Fixture.example",
                                   checker_context=metadata["checker_context"])
    plan_ref = store.put(plan)
    # Calling the original formatter does not execute its checker. This is an
    # explicitly synthetic successful process outcome for protocol testing.
    result = checker_type(directory)._result(plan, "CHECKED", True, None, 0, "", "",
                                             source, metadata["checker_context"])
    result_ref = store.put(result)
    request = promote.lab_judgment_request(store, theorem_ref, result_ref)
    assert store.verify() == 3
    for record in (theorem, plan, result):
        assert content_id(record) == record["object_id"]
    run_case("original-research-model-store-request-mocked-checker", request, "CHECKED", directory)
    portable = os.environ.get("AUTOPROOF_PORTABLE_EVIDENCE_DIR")
    if portable:
        output = Path(portable)
        output.mkdir(parents=True, exist_ok=True)
        # These are the exact input and output bytes used by the real Lab
        # runner, with original Research producers and a MOCKED Lean outcome.
        (output / "portable-request.json").write_bytes((directory / "request.json").read_bytes())
        (output / "portable-result.json").write_bytes((directory / "result.json").read_bytes())
        (output / "Fixture.lean").write_bytes(source)
    mismatch = copy.deepcopy(request)
    target = mismatch["formal_obligation"]["payload_row"]["target_record"]
    target["metadata"]["checker_context"]["module_source_sha256"] = "f" * 64
    mismatch = reseal(mismatch)
    changed = mismatch["formal_obligation"]["payload_row"]
    for key in ("target_record", "checker_plan", "checker_result"):
        store.put(changed[key])
    try:
        promote.lab_judgment_request(store, changed["target_ref"], changed["checker_result_ref"])
    except ValueError as error:
        assert "pinned source context" in str(error), error
    else:
        raise AssertionError("original Research contract accepted changed target context")
    run_case("original-research-and-lab-rehashed-context-rejection", mismatch, "REJECTED", directory)
    print("OriginalResearchProducerCorrespondenceGreen: 5 source blobs verified, 2 boundary cases; MOCKED checker, no Lean execution")


def main():
    with tempfile.TemporaryDirectory(prefix="lab-receipt-pins-") as temp:
        count = 0
        for name, request, expected in (*cases(), *envelope_cases()):
            run_case(name, request, expected, Path(temp))
            count += 1
        check_parser_and_smt_wire(Path(temp))
        check_raw_envelopes(Path(temp))
        research_root = os.environ.get("AUTOPROOF_RESEARCH_ROOT")
        if research_root:
            check_original_research_producer(research_root, Path(temp))
        else:
            print("Original Research producer integration not run; set AUTOPROOF_RESEARCH_ROOT to the pinned source package")
    print(f"AutoProofReceiptPinsV1Green: {count} checks; synthetic receipt binding only")


if __name__ == "__main__":
    main()
