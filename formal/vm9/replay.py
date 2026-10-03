#!/usr/bin/env python3
"""Byte binding/orchestration only. Proof judgments belong to pinned lab kernels."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
LAB_PIN = "50b9430f0ef8c62caa0ef37d9cf54b942534a612"
EXPECTED_BINDING_SHA256 = '99c9c2a14fa7df3fb13e85d7ebd7ea6635f5bf4f680a38f6541e55bcf9b089b5'
EXPECTED_OWNER_MANIFEST_SHA256 = '0603af8ed10b929156a9013bcee803874e96906ce4ccfc4c9414ef1074e73204'
EXPECTED_MODULES = {'load-lab.lisp': 'ada41ac925768cdf7a6d2a510cf0c9c70c4454a7640a59e1e12f791caadc76d3', 'integration.lisp': 'a971f729a27073e2ff7aeb19209b3fa11faba1d69a30b7924324dac9154c1a30', 'phase-model.lisp': 'b3ecd7d820342f96b53c76396cb3dbfc2c848170c42aa139e566016e762f2971', 'run.lisp': '99da757dd63a7c022b6337f34b4ec11a4cca3293f7a46d7ecf775c3caef40498', 'phase-model.json': '64ed7f28ee3a53754c073dab6df8fe050608380181a89a9635642cd85af131ae', 'domain-obligations.json': '3a54b92dd3fb869dcdf6d0e3da2f9d9f9fb75ecb20131cdebc7c48c4ab468052'}
EXTERNAL_TCB = ["rustc-8925ea358-source-to-mir", "kani-0.68-transformation-and-rust-model",
                "cbmc-6.11-cadical-result", "host-process-filesystem-integrity",
                "vm9-external-replay-checker-v1"]


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_json(path: Path):
    def no_duplicates(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"duplicate JSON key: {key}")
            result[key] = value
        return result
    return json.loads(path.read_bytes(), object_pairs_hook=no_duplicates)


def bounded_file(root: Path, name: str) -> Path:
    rel = Path(name)
    if rel.is_absolute() or not rel.parts or ".." in rel.parts:
        raise ValueError(f"unsafe relative path: {name}")
    path = root / rel
    if not path.resolve().is_relative_to(root.resolve()) or not path.is_file():
        raise ValueError(f"missing or escaped input: {name}")
    return path


def verify_owner(root: Path, manifest: dict):
    if manifest["commit"] != LAB_PIN or manifest["repository"] != "txw7/lab":
        raise ValueError("wrong lab source pin")
    for entry in manifest["files"]:
        raw = bounded_file(root, entry["path"]).read_bytes()
        blob = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
        if blob != entry["git_blob_sha"] or sha(raw) != entry["sha256"]:
            raise ValueError(f"lab source mismatch: {entry['path']}")


def verify_inputs(binding_path: Path, roots: dict[str, Path], expected: str):
    if sha(binding_path.read_bytes()) != expected:
        raise ValueError("binding digest mismatch")
    binding = read_json(binding_path)
    if binding["schema"] != "vm9-lab-input-binding.v1":
        raise ValueError("unsupported binding schema")
    if binding["authority"] != "abstract-phase-model-only":
        raise ValueError("unproved authority escalation")
    if binding["external_tcb"] != EXTERNAL_TCB:
        raise ValueError("external assumption laundering")
    for entry in binding["files"]:
        if entry["root"] not in roots:
            raise ValueError(f"missing input root: {entry['root']}")
        raw = bounded_file(roots[entry["root"]], entry["path"]).read_bytes()
        if sha(raw) != entry["sha256"]:
            raise ValueError(f"stale input: {entry['root']}:{entry['path']}")
        if entry["role"] == "legacy-kani-candidate":
            candidate = read_json(bounded_file(roots[entry["root"]], entry["path"]))
            if candidate["claim"]["external_tcb"] != EXTERNAL_TCB:
                raise ValueError("legacy TCB mismatch")
            if candidate["claim"]["source_revision"] != binding["runtime_revision"]:
                raise ValueError("legacy source identity mismatch")
        if entry["role"] == "partial-source-refinement-receipt":
            receipt = read_json(bounded_file(roots[entry["root"]], entry["path"]))
            if (receipt["schema"] != "vm9.partial-source-refinement-receipt.v1"
                    or receipt["status"] != "ACCEPTED_PARTIAL_CONDITIONAL_NOT_FORMAL_CLOSURE"
                    or receipt["primary_target"] != "9VM"
                    or receipt["open_obligations_prevent_closure"] is not True):
                raise ValueError("external receipt authority mismatch")
            for nested in receipt["files"]:
                raw = bounded_file(roots[entry["root"]], nested["path"]).read_bytes()
                if sha(raw) != nested["sha256"]:
                    raise ValueError(f"stale external artifact: {nested['path']}")
        if entry["role"] == "legacy-pins":
            pins = read_json(bounded_file(roots[entry["root"]], entry["path"]))
            for group, prefix in (("source_files", "proof-source"), ("evidence_files", "")):
                for nested in pins[group]:
                    raw = bounded_file(roots[entry["root"]], str(Path(prefix) / nested["path"])).read_bytes()
                    if sha(raw) != nested["sha256"]:
                        raise ValueError(f"stale legacy artifact: {nested['path']}")
    return binding


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sbcl", required=True, type=Path)
    parser.add_argument("--sbcl-home", required=True, type=Path)
    parser.add_argument("--lab-root", required=True, type=Path,
                        help="root containing exact formal/*.lisp sources")
    parser.add_argument("--input-root", action="append", default=[], metavar="NAME=PATH")
    parser.add_argument("--bindings", type=Path, default=HERE / "bindings.json")
    parser.add_argument("--owner-manifest", type=Path, default=HERE / "owner-manifest.json")
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args(argv)
    roots = {}
    for item in args.input_root:
        name, path = item.split("=", 1)
        if name in roots:
            raise ValueError("duplicate input root")
        roots[name] = Path(path)
    if sha(args.owner_manifest.read_bytes()) != EXPECTED_OWNER_MANIFEST_SHA256:
        raise ValueError("owner manifest digest mismatch")
    def verify_modules():
        for name, digest in EXPECTED_MODULES.items():
            if sha((HERE / name).read_bytes()) != digest:
                raise ValueError(f"integration module mismatch: {name}")
    verify_modules()
    owners = read_json(args.owner_manifest)
    verify_owner(args.lab_root, owners)
    binding = verify_inputs(args.bindings, roots, EXPECTED_BINDING_SHA256)
    args.out.mkdir(parents=True, exist_ok=True)
    env = {key: os.environ[key] for key in ("PATH", "HOME", "LANG", "LC_ALL") if key in os.environ}
    env.update(SBCL_HOME=str(args.sbcl_home.resolve()),
               VM9_LAB_FORMAL_ROOT=str((args.lab_root / "formal").resolve()) + "/",
               VM9_SOURCE_REF=f"txw7/egress-runtime@{binding['runtime_revision']}",
               VM9_EVIDENCE_REF=binding["legacy_candidate_ref"],
               VM9_BINDING_SHA256=EXPECTED_BINDING_SHA256,
               VM9_ENVELOPE=str((args.out / "envelope.sexp").resolve()))
    commands = []
    for mode in ("produce", "restore"):
        verify_modules()
        verify_owner(args.lab_root, owners)
        verify_inputs(args.bindings, roots, EXPECTED_BINDING_SHA256)
        env["VM9_MODE"] = mode
        command = [str(args.sbcl.resolve()), "--noinform", "--script", str(HERE / "run.lisp")]
        result = subprocess.run(command, env=env, capture_output=True, timeout=180)
        log = result.stdout + result.stderr
        (args.out / f"{mode}.log").write_bytes(log)
        if result.returncode or b"VM9 LAB PHASE MODEL ACCEPTED: 2 native, 2 reference, 13 residual OPEN" not in log:
            raise RuntimeError(f"lab {mode} failed; inspect {mode}.log")
        verify_modules()
        verify_owner(args.lab_root, owners)
        verify_inputs(args.bindings, roots, EXPECTED_BINDING_SHA256)
        commands.append({"mode": mode, "returncode": result.returncode, "log_sha256": sha(log)})
    receipt = {"schema": "vm9-lab-native-replay.v1", "lab_revision": LAB_PIN,
               "binding_sha256": EXPECTED_BINDING_SHA256,
               "abstract_projection_digests": binding["abstract_projection_digests"],
               "full_vm9_subject_digest": None,
               "state_transition_trace_correspondence": "open",
               "integration_modules_sha256": EXPECTED_MODULES,
               "authority": "abstract-phase-model-only", "native_phase_model_certificates": 2,
               "reference_phase_model_certificates": 2, "fresh_process_replays": 2,
               "abstract_model_claims": ["phase-budget(0,9)",
                    "forall c,r:Nat, phase-budget(c,succ r) -> phase-budget(succ c,r)"],
               "residual_obligations_open": 13, "full_vm9_refinement": "open",
               "external_proof_replayed_by_this_command": False,
               "legacy_external_tcb": EXTERNAL_TCB,
               "lab_tcb": ["pinned lab pi0 Nat/Eq bootstrap and native checker",
                           "pinned lab reference checker (agreement is not metatheory)",
                           "SBCL/runtime/host and SHA256 byte-binding runner"],
               "sbcl_binary_sha256": sha(args.sbcl.read_bytes()),
               "envelope_sha256": sha((args.out / "envelope.sexp").read_bytes()),
               "runs": commands}
    (args.out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps(receipt, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, RuntimeError, OSError, KeyError) as error:
        print(f"REJECTED: {error}", file=sys.stderr)
        raise SystemExit(1)
