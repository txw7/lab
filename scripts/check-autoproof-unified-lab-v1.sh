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
