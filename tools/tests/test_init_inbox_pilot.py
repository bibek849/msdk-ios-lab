import hashlib
import importlib.util
import json
import os
from pathlib import Path
import stat
import tempfile
import unittest
from urllib.parse import parse_qs, urlsplit


spec = importlib.util.spec_from_file_location(
    "init_inbox_pilot", Path(__file__).resolve().parents[1] / "init_inbox_pilot.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PilotInitializationTests(unittest.TestCase):
    def test_private_identity_and_hash_without_extra_permissions(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "pilot"
            module.initialize(output, "https://pilot.example")
            token = (output / "inbox-token").read_text().strip()
            webhook = (output / "webhook-secret").read_text().strip()
            worker = json.loads((output / "worker-secrets.json").read_text())
            self.assertGreaterEqual(len(token), 32)
            self.assertNotEqual(token, webhook)
            self.assertEqual(worker["INBOX_TOKEN_SHA256"], hashlib.sha256(token.encode()).hexdigest())
            self.assertEqual(worker["WEBHOOK_SECRET"], webhook)
            config = json.loads((output / "client.json").read_text())
            self.assertEqual(config["token_file"], str(output / "inbox-token"))
            self.assertEqual(config["contributor"], "bibek849")
            registration = (output / "github-app-registration-url.txt").read_text().strip()
            query = parse_qs(urlsplit(registration).query)
            self.assertEqual(query["issues"], ["read"])
            self.assertEqual(query["pull_requests"], ["read"])
            self.assertEqual(query["public"], ["false"])
            self.assertNotIn("contents", query)
            self.assertNotIn(token, registration)
            self.assertNotIn(webhook, registration)
            if os.name == "posix":
                self.assertEqual(stat.S_IMODE(output.stat().st_mode), 0o700)
                for child in output.iterdir():
                    self.assertEqual(stat.S_IMODE(child.stat().st_mode), 0o600)

    def test_existing_directory_or_symlink_cannot_rotate_secrets(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "pilot"
            module.initialize(output, "https://pilot.example")
            original = (output / "inbox-token").read_text()
            with self.assertRaises(FileExistsError):
                module.initialize(output, "https://pilot.example")
            self.assertEqual((output / "inbox-token").read_text(), original)
            link = Path(temporary) / "link"
            link.symlink_to(output, target_is_directory=True)
            with self.assertRaises(FileExistsError):
                module.initialize(link, "https://pilot.example")

    def test_invalid_origins_write_nothing(self):
        with tempfile.TemporaryDirectory() as temporary:
            for url in ["http://pilot.example", "https://user:pass@pilot.example",
                        "https://pilot.example/path", "https://pilot.example?token=x",
                        "https://pilot.example#x", "https://pilot.example:0",
                        "https://pilot.example:99999", "https://pilot.example\n",
                        " https://pilot.example", "https://pilot.example:bad"]:
                output = Path(temporary) / "pilot"
                with self.assertRaises(ValueError):
                    module.initialize(output, url)
                self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
