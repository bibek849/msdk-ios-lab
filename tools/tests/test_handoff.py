import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
MODULE_SPEC = importlib.util.spec_from_file_location("handoff", ROOT / "tools/prepare_handoff.py")
handoff = importlib.util.module_from_spec(MODULE_SPEC)
MODULE_SPEC.loader.exec_module(handoff)
EXAMPLE = json.loads((ROOT / "experiments/example-synthetic.json").read_text())


class HandoffTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.repo = Path(self.temporary.name).resolve()
        self.git("init", "-q")
        self.git("config", "user.name", "Fixture Author")
        self.git("config", "user.email", "fixture@example.invalid")
        (self.repo / ".gitignore").write_text("artifacts/\n")
        (self.repo / "experiment.json").write_text(json.dumps(EXAMPLE))
        self.commit()

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.repo), *args],
                                       stderr=subprocess.STDOUT).decode().strip()

    def commit(self):
        self.git("add", ".")
        self.git("commit", "-qm", "Fixture")

    def export(self):
        return handoff.prepare(self.repo, "experiment.json", "artifacts/handoff")

    def test_export_pins_commit_and_checksums(self):
        output, manifest = self.export()
        self.assertEqual(manifest["source"]["commit"], self.git("rev-parse", "HEAD"))
        self.assertEqual(manifest["source"]["tree"], self.git("rev-parse", "HEAD^{tree}"))
        self.assertEqual(manifest["hardware_approval"], "NOT_GRANTED")
        self.assertEqual(manifest["ci_status"], "NOT_VERIFIED")
        self.assertEqual(manifest["request_readiness"], "READY_FOR_REVIEW")
        for line in (output / "SHA256SUMS").read_text().splitlines():
            digest, name = line.split("  ")
            self.assertEqual(digest, hashlib.sha256((output / name).read_bytes()).hexdigest())
        original_commit = manifest["source"]["commit"]
        (self.repo / "new.txt").write_text("new revision")
        self.commit()
        self.assertNotEqual(original_commit, self.git("rev-parse", "HEAD"))
        self.assertEqual(json.loads((output / "manifest.json").read_text())["source"]["commit"],
                         original_commit)

    def test_rejects_tracked_edits(self):
        (self.repo / "experiment.json").write_text("{}")
        with self.assertRaisesRegex(handoff.HandoffError, "Tracked changes"):
            self.export()

    def test_rejects_untracked_experiment(self):
        (self.repo / "untracked.json").write_text(json.dumps(EXAMPLE))
        with self.assertRaisesRegex(handoff.HandoffError, "tracked in HEAD"):
            handoff.prepare(self.repo, "untracked.json", "artifacts/handoff")

    def test_excludes_untracked_files_and_never_executes_commands(self):
        marker = self.repo / "must-not-exist"
        spec = copy.deepcopy(EXAMPLE)
        spec["build_commands"] = [f"touch {marker}"]
        (self.repo / "experiment.json").write_text(json.dumps(spec))
        self.commit()
        (self.repo / "private-untracked.txt").write_text("not exportable")
        output, _ = self.export()
        self.assertFalse(marker.exists())
        self.assertEqual({p.name for p in output.iterdir()},
                         {"manifest.json", "experiment.json", "SHA256SUMS"})

    def test_refuses_overwrite(self):
        output, _ = self.export()
        before = (output / "manifest.json").read_bytes()
        with self.assertRaisesRegex(handoff.HandoffError, "already exists"):
            self.export()
        self.assertEqual(before, (output / "manifest.json").read_bytes())

    def test_rejects_output_outside_artifacts(self):
        with self.assertRaisesRegex(handoff.HandoffError, "beneath"):
            handoff.prepare(self.repo, "experiment.json", "../escaped")

    def test_rejects_symlink_experiment(self):
        (self.repo / "alias.json").symlink_to("experiment.json")
        self.commit()
        with self.assertRaisesRegex(handoff.HandoffError, "symlink"):
            handoff.prepare(self.repo, "alias.json", "artifacts/handoff")

    def test_rejects_invalid_schema(self):
        for key, value in (("schema_version", 2), ("kind", "flight"),
                           ("procedure", []), ("limits", {"repetitions": True,
                                                        "max_seconds_per_run": 60})):
            with self.subTest(key=key):
                spec = copy.deepcopy(EXAMPLE)
                spec[key] = value
                with self.assertRaises(handoff.HandoffError):
                    handoff.validate(spec)

    def test_rejects_oversized_spec_and_non_utf8(self):
        for data in ((" " * (handoff.MAX_SPEC_BYTES + 1)).encode(),
                     json.dumps(EXAMPLE).encode("utf-16")):
            with self.subTest(size=len(data)):
                (self.repo / "experiment.json").write_bytes(data)
                self.commit()
                with self.assertRaises(handoff.HandoffError):
                    self.export()

    def test_pending_hardware_is_draft_not_approval(self):
        spec = copy.deepcopy(EXAMPLE)
        spec.update(kind="read_only_hardware", stage="S3",
                    hardware={field: None for field in handoff.HARDWARE_FIELDS},
                    prerequisites=[{"requirement": "Permitted accessory route",
                                    "status": "pending", "evidence": None}])
        (self.repo / "experiment.json").write_text(json.dumps(spec))
        self.commit()
        _, manifest = self.export()
        self.assertEqual(manifest["request_readiness"], "DRAFT")
        self.assertEqual(len(manifest["pending_metadata"]), 8)
        self.assertEqual(manifest["hardware_approval"], "NOT_GRANTED")

    def test_rejects_command_stage_hardware(self):
        spec = copy.deepcopy(EXAMPLE)
        spec.update(kind="read_only_hardware", stage="S5")
        with self.assertRaisesRegex(handoff.HandoffError, "read-only"):
            handoff.validate(spec)


if __name__ == "__main__":
    unittest.main()
