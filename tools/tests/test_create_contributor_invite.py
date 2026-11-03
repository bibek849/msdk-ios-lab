import hashlib
import importlib.util
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from urllib.parse import parse_qs, urlsplit


TOOLS = Path(__file__).resolve().parents[1]
with patch.object(sys, "path", [str(TOOLS), *sys.path]):
    spec = importlib.util.spec_from_file_location(
        "create_contributor_invite", TOOLS / "create_contributor_invite.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)


class ContributorInviteTests(unittest.TestCase):
    def arguments(self, output, **overrides):
        arguments = dict(output=output, login="contributor-one", github_id=12345,
                         url="https://msdk-inbox-one.example.workers.dev/",
                         worker_name="msdk-inbox-one", database_name="msdk-inbox-one-db")
        arguments.update(overrides)
        return arguments

    def test_public_invitation_excludes_all_private_credentials(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "invite"
            expected = module.create_invite(**self.arguments(output))
            invite = json.loads((output / "invite.json").read_text())
            self.assertEqual(invite, expected)
            self.assertEqual(invite, {
                "schema": 1, "repository": "bibek849/msdk-ios-lab",
                "contributor": "contributor-one", "contributor_id": 12345,
                "url": "https://msdk-inbox-one.example.workers.dev",
            })
            token = (output / "inbox-token").read_text().strip()
            webhook = (output / "webhook-secret").read_text().strip()
            secrets = json.loads((output / "worker-secrets.json").read_text())
            self.assertGreaterEqual(len(token), 32)
            self.assertNotEqual(token, webhook)
            self.assertEqual(secrets["WEBHOOK_SECRET"], webhook)
            self.assertEqual(secrets["INBOX_TOKEN_SHA256"], hashlib.sha256(token.encode()).hexdigest())
            public = (output / "invite.json").read_text()
            registration = (output / "github-app-registration-url.txt").read_text()
            for credential in [token, webhook, secrets["INBOX_TOKEN_SHA256"]]:
                self.assertNotIn(credential, public)
                self.assertNotIn(credential, registration)
            config = json.loads((output / "client.json").read_text())
            self.assertEqual(config["contributor"], invite["contributor"])
            self.assertEqual(config["url"], invite["url"])
            self.assertEqual(config["token_file"], str(output / "inbox-token"))

    def test_disabled_config_is_recipient_specific_and_uses_absolute_source_paths(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "invite"
            module.create_invite(**self.arguments(output))
            config = json.loads((output / "wrangler.contributor.jsonc").read_text())
            self.assertEqual(config["name"], "msdk-inbox-one")
            self.assertEqual(config["vars"]["CONTRIBUTOR_ID"], "12345")
            self.assertEqual(config["vars"]["CONTRIBUTOR_LOGIN"], "contributor-one")
            self.assertEqual(config["vars"]["REPOSITORY_ID"], "1443581816")
            self.assertEqual(config["vars"]["INSTALLATION_ID"], "0")
            self.assertEqual(config["vars"]["PILOT_ENABLED"], "false")
            self.assertEqual(config["vars"]["TRACKED_ISSUES"], "")
            self.assertEqual(config["vars"]["TRACKED_PRS"], "")
            self.assertEqual(len(config["d1_databases"]), 1)
            binding = config["d1_databases"][0]
            self.assertEqual(binding["binding"], "DB")
            self.assertEqual(binding["database_name"], "msdk-inbox-one-db")
            self.assertEqual(binding["database_id"], module.ZERO_DATABASE_ID)
            self.assertNotIn("account_id", config)
            for name in [config["main"], binding["migrations_dir"]]:
                self.assertTrue(Path(name).is_absolute())
                self.assertTrue(Path(name).exists())

    def test_config_with_observed_resource_ids_stays_disabled(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "invite"
            module.create_invite(**self.arguments(
                output, database_id="bc8e174e-210b-4730-bac2-719f07acf22d",
                installation_id=55555, app_name="msdk-lab-alice-12345"))
            config = json.loads((output / "wrangler.contributor.jsonc").read_text())
            self.assertEqual(config["vars"]["INSTALLATION_ID"], "55555")
            self.assertEqual(config["vars"]["PILOT_ENABLED"], "false")
            self.assertEqual(config["d1_databases"][0]["database_id"],
                             "bc8e174e-210b-4730-bac2-719f07acf22d")

    def test_registration_is_private_read_only_and_has_distinct_webhook(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "invite"
            module.create_invite(**self.arguments(output))
            query = parse_qs(urlsplit((output / "github-app-registration-url.txt").read_text()).query)
            self.assertEqual(query["name"], ["msdk-lab-inbox-12345"])
            self.assertEqual(query["public"], ["false"])
            self.assertEqual(query["request_oauth_on_install"], ["false"])
            self.assertEqual(query["issues"], ["read"])
            self.assertEqual(query["pull_requests"], ["read"])
            self.assertEqual(query["webhook_url"],
                             ["https://msdk-inbox-one.example.workers.dev/github/webhook"])
            self.assertEqual(set(query["events[]"]), set(module.EVENTS))
            self.assertNotIn("contents", query)
            self.assertNotIn("administration", query)
            self.assertNotIn("secret", query)

    @unittest.skipUnless(os.name == "posix", "POSIX private-file permissions")
    def test_bundle_is_private_even_with_permissive_umask(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "invite"
            previous = os.umask(0)
            try:
                module.create_invite(**self.arguments(output))
            finally:
                os.umask(previous)
            self.assertEqual(stat.S_IMODE(output.stat().st_mode), 0o700)
            for item in output.iterdir():
                self.assertEqual(stat.S_IMODE(item.stat().st_mode), 0o600)

    def test_existing_directory_or_symlink_cannot_replace_credentials(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "invite"
            module.create_invite(**self.arguments(output))
            original = {item.name: item.read_bytes() for item in output.iterdir()}
            with self.assertRaises(FileExistsError):
                module.create_invite(**self.arguments(output))
            link = Path(temporary) / "linked"
            link.symlink_to(output, target_is_directory=True)
            with self.assertRaises(FileExistsError):
                module.create_invite(**self.arguments(link))
            self.assertEqual({item.name: item.read_bytes() for item in output.iterdir()}, original)

    def test_invalid_inputs_and_existing_pilot_resources_write_nothing(self):
        cases = [
            {"login": "-someone"}, {"login": "someone-"}, {"login": "a--b"},
            {"login": "a" * 40}, {"login": "a\n"}, {"login": "a/b"},
            {"github_id": 0}, {"github_id": True}, {"github_id": module.MAX_SAFE_ID + 1},
            {"installation_id": -1}, {"installation_id": True},
            {"worker_name": "A"}, {"worker_name": "worker;cmd"},
            {"worker_name": "a" * 64}, {"database_name": "-a"},
            {"database_id": "not-a-uuid"}, {"database_id": 12},
            {"app_name": "a" * 35}, {"app_name": "a/b"},
            {"url": "http://example.com"}, {"url": "https://@example.com"},
            {"url": "https://:@example.com"}, {"url": "https://example.com/path"},
            {"url": "https://example.com?token=secret"}, {"url": "https://example.com#part"},
            {"url": "https://example.com:0"}, {"url": "https://example.com:99999"},
            {"url": "https://other.example.workers.dev"},
            {"url": "https://msdk-inbox-one.a.b.workers.dev"},
            {"worker_name": module.PILOT_WORKER, "url": "https://example.com"},
            {"database_name": module.PILOT_DATABASE},
            {"database_id": module.PILOT_DATABASE_ID},
            {"installation_id": module.PILOT_INSTALLATION_ID},
        ]
        with tempfile.TemporaryDirectory() as temporary:
            for index, overrides in enumerate(cases):
                with self.subTest(overrides=overrides):
                    output = Path(temporary) / str(index)
                    with self.assertRaises(ValueError):
                        module.create_invite(**self.arguments(output, **overrides))
                    self.assertFalse(output.exists())

    def test_independent_bundles_do_not_reuse_keys_or_change_template(self):
        template = module.SERVICE / "wrangler.jsonc"
        before = template.read_bytes()
        with tempfile.TemporaryDirectory() as temporary:
            first, second = Path(temporary) / "one", Path(temporary) / "two"
            module.create_invite(**self.arguments(first))
            module.create_invite(**self.arguments(
                second, login="second", github_id=98765,
                worker_name="msdk-inbox-two", database_name="msdk-inbox-two-db",
                url="https://msdk-inbox-two.example.workers.dev"))
            for name in ["inbox-token", "webhook-secret"]:
                self.assertNotEqual((first / name).read_text(), (second / name).read_text())
            self.assertEqual(before, template.read_bytes())

    def test_cli_stdout_never_contains_credential_material(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "invite"
            command = [sys.executable, str(TOOLS / "create_contributor_invite.py"),
                       "--login", "alice", "--github-id", "54321",
                       "--url", "https://msdk-inbox-cli.example.workers.dev",
                       "--worker-name", "msdk-inbox-cli", "--database-name", "msdk-inbox-cli-db",
                       "--output", str(output)]
            result = subprocess.run(command, capture_output=True, text=True, timeout=15)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("No service deployed", result.stdout)
            for name in ["inbox-token", "webhook-secret"]:
                self.assertNotIn((output / name).read_text().strip(), result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
