import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location("replay", Path(__file__).with_name("replay.py"))
replay = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(replay)

class BindingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.data = self.root / "data.txt"
        self.data.write_text("original")
        self.binding = {"schema": "vm9-lab-input-binding.v1", "authority": "abstract-phase-model-only",
                        "external_tcb": replay.EXTERNAL_TCB.copy(),
                        "files": [{"root": "evidence", "path": "data.txt", "role": "advisory",
                                   "sha256": replay.sha(self.data.read_bytes())}]}
        self.path = self.root / "binding.json"

    def tearDown(self):
        self.temp.cleanup()

    def write(self):
        self.path.write_text(json.dumps(self.binding))
        return replay.sha(self.path.read_bytes())

    def verify(self, digest):
        return replay.verify_inputs(self.path, {"evidence": self.root}, digest)

    def test_exact_bytes(self):
        self.verify(self.write())

    def test_mismatched_binding(self):
        self.write()
        with self.assertRaisesRegex(ValueError, "binding digest"):
            self.verify("0" * 64)

    def test_stale_input(self):
        digest = self.write()
        self.data.write_text("edited")
        with self.assertRaisesRegex(ValueError, "stale input"):
            self.verify(digest)

    def test_unproved(self):
        self.binding["authority"] = "proved"
        with self.assertRaisesRegex(ValueError, "authority"):
            self.verify(self.write())

    def test_assumption_erasure(self):
        self.binding["external_tcb"].pop()
        with self.assertRaisesRegex(ValueError, "assumption"):
            self.verify(self.write())

    def test_path_traversal(self):
        self.binding["files"][0]["path"] = "../outside.txt"
        with self.assertRaisesRegex(ValueError, "unsafe"):
            self.verify(self.write())

    def test_absolute_path(self):
        self.binding["files"][0]["path"] = str(self.data)
        with self.assertRaisesRegex(ValueError, "unsafe"):
            self.verify(self.write())

    def test_missing_root(self):
        self.binding["files"][0]["root"] = "new"
        with self.assertRaisesRegex(ValueError, "missing input root"):
            self.verify(self.write())

    def test_duplicate_json_fields(self):
        self.path.write_text('{"schema":"a","schema":"b"}')
        with self.assertRaisesRegex(ValueError, "duplicate JSON"):
            replay.read_json(self.path)

    def test_owner_blob_mismatch(self):
        raw = self.data.read_bytes()
        manifest = {"repository": "txw7/lab", "commit": replay.LAB_PIN,
                    "files": [{"path": "data.txt", "git_blob_sha": "0" * 40,
                               "sha256": replay.sha(raw)}]}
        with self.assertRaisesRegex(ValueError, "lab source mismatch"):
            replay.verify_owner(self.root, manifest)

    def test_wrong_owner_pin(self):
        with self.assertRaisesRegex(ValueError, "wrong lab source pin"):
            replay.verify_owner(self.root, {"repository": "txw7/lab", "commit": "latest"})

if __name__ == "__main__":
    unittest.main()
