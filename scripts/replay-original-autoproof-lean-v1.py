#!/usr/bin/env python3
"""Run one original Research Lean theorem through its checker and Lab judge.

No toolchain installation, dependency update, source editing, or theorem
promotion is performed by this script. All inputs must already be available.
The Lab address is an explicit isolated replay fixture, not a live graph claim.
"""

import argparse
import hashlib
import importlib
import json
import os
from pathlib import Path
import subprocess
import sys
import types


RESEARCH_COMMIT = "e154f65e1976754718e4b3ef0726c388e67c7d97"
LAB_COMMIT = "5ff6dd2fa44d5f5b7115be9ed02c9241d8971461"
MATHLIB_COMMIT = "5ed2965256430c3649e86755f9576b54eca72435"
MODULE = "RHMachine/Mobius.lean"
THEOREM = "RHMachine.mobiusS_mobiusZ"
PINNED_RESEARCH = {
    "canonical.py": "b2f9bd8311b9bd219d8f89c697654c56634cca98",
    "models.py": "22eb19b467daf05e41aa1077b1a47029a0436b77",
    "store.py": "319d566af4dd65f1c116445e18e64388da411ce2",
    "checker.py": "7d233cd3acd3b634f503b71f9efd1b559d91dbbb",
    "promote.py": "a08cff4cf56e66ab6137fe09fcdb4a808a44e8bc",
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def verify_blob(path, expected):
    data = path.read_bytes()
    actual = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
    if actual != expected:
        raise RuntimeError(f"original source mismatch: {path.name}: {actual} != {expected}")
    return {"git_blob": actual, "sha256": digest(data), "bytes": len(data)}


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--research-package", type=Path, required=True)
    parser.add_argument("--lean-root", type=Path, required=True)
    parser.add_argument("--lab-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        raise RuntimeError("output directory must be new; prior receipts are retained")
    output.mkdir(parents=True)
    lean_root = args.lean_root.resolve()
    source_pins = {name: verify_blob(args.research_package / name, expected)
                   for name, expected in PINNED_RESEARCH.items()}
    source_pins[MODULE] = verify_blob(lean_root / MODULE, "1cdecc8b5388f00449eeced903a46efbbe9779e2")
    source_pins["lean-toolchain"] = verify_blob(lean_root / "lean-toolchain", "12359f928f18e4a89ebd1444a0310b025931b17d")
    source_pins["lakefile.toml"] = verify_blob(lean_root / "lakefile.toml", "0babed56d9c584c0918af77fd70bf8d0da6746be")
    runner = args.lab_root.resolve() / "scripts/run_autoproof_formal_discharge_v1.lisp"
    source_pins["lab_runner"] = verify_blob(runner, "a298d08d8890479bf3e9914545e623bc97983e93")
    source_pins["lab_json_reader"] = verify_blob(args.lab_root / "formal/json-lite.lisp", "cfef1a1cdf71aea35cdb827c34bb39b64c218e89")
    source_pins["lab_package"] = verify_blob(args.lab_root / "formal/package.lisp", "db572d4abb9aedd2d8a0b3addaeb6fedc74e9e7a")
    source_pins["lab_asd"] = verify_blob(args.lab_root / "formal/formal.asd", "0f1bf89830ac056d12eadeae4f949cf8d7ac88d5")

    name = "_original_autoproof_lean_replay"
    package = types.ModuleType(name)
    package.__path__ = [str(args.research_package.resolve())]
    sys.modules[name] = package
    models = importlib.import_module(name + ".models")
    canonical = importlib.import_module(name + ".canonical")
    store = importlib.import_module(name + ".store").ObjectStore(output / "store")
    checker = importlib.import_module(name + ".checker").LeanChecker(lean_root)
    promote = importlib.import_module(name + ".promote")

    context = checker.capture_context(MODULE)
    if context["mathlib_revision"] != MATHLIB_COMMIT or "version 4.34.0" not in context["lean_version"]:
        raise RuntimeError("resolved environment differs from the original toolchain pins")
    if context["module_source_sha256"] != source_pins[MODULE]["sha256"]:
        raise RuntimeError("checker context differs from original theorem source")
    actual_mathlib = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=lean_root / ".lake/packages/mathlib",
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    if actual_mathlib != MATHLIB_COMMIT:
        raise RuntimeError("actual Mathlib checkout differs from the captured manifest")
    address = {
        "schema": "ProgramGraphAddressBindingV1",
        "authority_ref": "isolated-original-lean-replay-v1",
        "source_revision": RESEARCH_COMMIT,
        "source_graph_root": "fixture:original-lean-replay",
        "h001_graph_object_ref": "fixture:original-lean-replay:graph",
        "h001_bundle_ref": "fixture:original-lean-replay:bundle",
        "subject_snapshot_ref": "sha256:" + context["module_source_sha256"],
        "h002_address_ref": "fixture:original-lean-replay:address",
        "h002_containment_witness_ref": "fixture:original-lean-replay:containment",
        "mapping_witness_ref": "fixture:original-lean-replay:mapping",
        "target_occurrence_ref": "fixture:" + THEOREM,
    }
    theorem = models.proof_object(
        "FormalLemma", "For complex s != 0, mobiusS (mobiusZ s) = s",
        formal_language="lean4", status="UNPROVEN",
        metadata={
            "logical_id": "original-lean-replay:" + THEOREM,
            "expected_theorem": THEOREM,
            "target_source_sha256": context["module_source_sha256"],
            "checker_context": context,
            "target_occurrence_ref": address["target_occurrence_ref"],
            "subject_snapshot_ref": address["subject_snapshot_ref"],
            "program_graph_address": address,
        },
    )
    theorem_ref = store.put(theorem)
    plan = checker.make_plan(theorem_ref, MODULE, THEOREM)
    plan_ref = store.put(plan)
    write_json(output / "theorem-target.json", theorem)
    write_json(output / "checker-plan.json", plan)
    print("Invoking original LeanChecker.check on exact original Mobius.lean", flush=True)
    result = checker.check(plan)
    result_ref = store.put(result)
    write_json(output / "checker-result.json", result)
    if result["status"] != "CHECKED" or result["trusted"] is not True:
        raise RuntimeError(f"original Lean check did not pass: {result['status']}")
    request = promote.lab_judgment_request(store, theorem_ref, result_ref)
    write_json(output / "lab-request.json", request)
    process = subprocess.run(
        [os.environ.get("SBCL", "sbcl"), "--script", str(runner),
         str(output / "lab-request.json"), str(output / "lab-result.json")],
        capture_output=True, text=True, timeout=30,
    )
    (output / "lab.stdout").write_text(process.stdout)
    (output / "lab.stderr").write_text(process.stderr)
    if process.returncode != 0:
        raise RuntimeError("original Lab judgment runner failed")
    lab_result = json.loads((output / "lab-result.json").read_text())
    if lab_result["status"] != "CHECKED" or lab_result["theorem_status_effect"] != "NONE":
        raise RuntimeError("Lab did not admit the exact successful checker binding")
    judgment = lab_result["formal_judgment"]
    if judgment["checker_result_ref"] != result_ref or judgment["checker_plan_ref"] != plan_ref:
        raise RuntimeError("Lab judgment does not retain exact checker identities")
    if (judgment["target_ref"] != theorem_ref
            or judgment["subject_snapshot_ref"] != address["subject_snapshot_ref"]
            or judgment["target_occurrence_ref"] != address["target_occurrence_ref"]):
        raise RuntimeError("Lab judgment does not retain the exact source target")
    lab_result_ref = store.put(lab_result)

    # A mismatched source pin is rejected before theorem elaboration. The
    # original theorem file is never edited, including for this negative.
    stale_plan = dict(plan)
    stale_plan["target_source_sha256"] = "0" * 64
    stale_plan = canonical.with_object_id(stale_plan)
    store.put(stale_plan)
    stale_result = checker.check(stale_plan)
    store.put(stale_result)
    write_json(output / "stale-plan.json", stale_plan)
    write_json(output / "stale-result.json", stale_result)
    if stale_result["status"] != "DEPENDENCY_MISMATCH" or stale_result["trusted"] is not False:
        raise RuntimeError("stale source pin was not rejected")
    if stale_result["process_status"] is not None:
        raise RuntimeError("stale source receipt claims an elaboration process result")
    if digest((lean_root / MODULE).read_bytes()) != source_pins[MODULE]["sha256"]:
        raise RuntimeError("theorem source changed during replay")
    if store.get(theorem_ref)["status"] != "UNPROVEN":
        raise RuntimeError("replay unexpectedly promoted theorem state")
    receipt = {
        "schema": "OriginalAutoProofLeanReplayV1",
        "research_commit": RESEARCH_COMMIT, "lab_commit": LAB_COMMIT,
        "mathlib_commit": MATHLIB_COMMIT, "theorem": THEOREM,
        "source_pins": source_pins, "checker_context": context,
        "checker_plan_ref": plan_ref, "checker_result_ref": result_ref,
        "lab_judgment_ref": lab_result_ref,
        "checker_status": result["status"], "actual_lean_execution": True,
        "checker_process_status": result["process_status"],
        "lab_status": lab_result["status"], "theorem_status_effect": "NONE",
        "theorem_promotion_invoked": False,
        "stale_source_status": stale_result["status"],
        "store_objects_verified": store.verify(),
        "address_binding": "authored isolated replay fixture; no live ProgramGraph admission",
        "limits": ["one original theorem module", "no full RH build", "no MIR/FORMAL aggregate closure"],
    }
    write_json(output / "receipt.json", receipt)
    print(json.dumps(receipt, sort_keys=True), flush=True)


if __name__ == "__main__":
    main()
