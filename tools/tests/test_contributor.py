import contextlib
import copy
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shlex
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


TOOLS = Path(__file__).resolve().parents[1]
inbox_spec = importlib.util.spec_from_file_location("contributor_test_inbox", TOOLS / "agent_inbox.py")
inbox = importlib.util.module_from_spec(inbox_spec)
inbox_spec.loader.exec_module(inbox)
spec = importlib.util.spec_from_file_location("contributor_test_module", TOOLS / "contributor.py")
contributor = importlib.util.module_from_spec(spec)
with mock.patch.dict(sys.modules, {"agent_inbox": inbox}):
    spec.loader.exec_module(contributor)

TOKEN = "synthetic-contributor-token-never-real-123456789"
INVITE = {
    "schema": 1,
    "repository": "bibek849/msdk-ios-lab",
    "contributor": "fixture-contributor",
    "contributor_id": 12345,
    "url": "https://fixture.example",
}
PAGE = {"schema": 1, "contributor": "fixture-contributor", "events": [], "has_more": False}


class ContributorTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.home = self.root / "private profile with spaces"
        self.source = self.root / "reviewed runtime"
        self.source.mkdir()
        for name in contributor.RUNTIME_FILES:
            (self.source / name).write_text("# reviewed synthetic runtime: " + name + "\n")
        self.invite = copy.deepcopy(INVITE)
        self.invite_path = self.root / "invite.json"
        self.invite_path.write_text(json.dumps(self.invite))
        self.token_path = self.root / "private-token"
        self.token_path.write_text(TOKEN + "\n")
        self.token_path.chmod(0o600)
        self.source_patch = mock.patch.object(contributor, "SOURCE", self.source)
        self.source_patch.start()
        self.addCleanup(self.source_patch.stop)
        self.identity = mock.patch.object(contributor, "github_identity", return_value=(
            self.invite["contributor"], self.invite["contributor_id"]))
        self.identity_mock = self.identity.start()
        self.addCleanup(self.identity.stop)
        # Exercise the real client's schema/identity validation, without any network.
        self.transport = mock.patch.object(inbox, "request_json", return_value=copy.deepcopy(PAGE))
        self.transport_mock = self.transport.start()
        self.addCleanup(self.transport.stop)

    def connect(self):
        return contributor.connect(self.invite, self.home, TOKEN)

    def snapshot(self):
        return {str(path.relative_to(self.home)): path.read_bytes()
                for path in self.home.rglob("*") if path.is_file()}

    def test_invitation_canonical_origin_and_no_input_mutation(self):
        self.invite["url"] += "/"
        result = contributor.validate_invite(self.invite)
        self.assertEqual(result["url"], INVITE["url"])
        self.assertTrue(self.invite["url"].endswith("/"))
        self.assertEqual(contributor.read_invite(self.invite_path), INVITE)

    def test_invitation_rejects_wrong_scope_schema_and_identity(self):
        cases = [
            {"unexpected": "field"}, {"repository": "someone/else"},
            {"schema": True}, {"schema": 2}, {"contributor_id": True},
            {"contributor_id": 0}, {"contributor_id": "12345"},
            {"contributor": "--shell-option"}, {"contributor": "a/b"},
        ]
        for changes in cases:
            with self.subTest(changes=changes):
                value = {**INVITE, **changes}
                with self.assertRaises(inbox.InboxError):
                    contributor.validate_invite(value)
        missing = dict(INVITE)
        del missing["contributor_id"]
        with self.assertRaises(inbox.InboxError):
            contributor.validate_invite(missing)

    def test_invitation_rejects_insecure_or_non_origin_urls(self):
        for url in ["http://fixture.example", "https://fixture.example/path",
                    "https://fixture.example?token=ignored", "https://fixture.example#fragment",
                    "https://name:secret@fixture.example", "https://@fixture.example",
                    "https://:@fixture.example", "https://fixture.example:0",
                    "https://fixture.example:99999", "https://fixture.example\n"]:
            with self.subTest(url=url), self.assertRaises(inbox.InboxError):
                contributor.validate_invite({**INVITE, "url": url})

    def test_invitation_rejects_duplicate_json_oversize_and_symlink(self):
        raw = json.dumps(INVITE)
        self.invite_path.write_text(raw[:-1] + ', "schema": 1}')
        with self.assertRaises(inbox.InboxError):
            contributor.read_invite(self.invite_path)
        self.invite_path.write_text(" " * 8193)
        with self.assertRaises(inbox.InboxError):
            contributor.read_invite(self.invite_path)
        if hasattr(os, "O_NOFOLLOW"):
            link = self.root / "invitation-link"
            link.symlink_to(self.invite_path)
            with self.assertRaises(inbox.InboxError):
                contributor.read_invite(link)

    def test_connect_requires_both_github_login_and_numeric_identity_before_write(self):
        for identity in [("someone-else", 12345), ("fixture-contributor", 67890)]:
            with self.subTest(identity=identity):
                self.identity_mock.return_value = identity
                with self.assertRaises(inbox.InboxError):
                    self.connect()
                self.assertFalse(self.home.exists())
                self.transport_mock.assert_not_called()

    def test_github_login_matching_is_case_insensitive(self):
        self.identity_mock.return_value = ("FIXTURE-CONTRIBUTOR", 12345)
        self.assertTrue(self.connect()["connected"])

    def test_wrong_remote_inbox_identity_leaves_no_profile(self):
        self.transport_mock.return_value = {**PAGE, "contributor": "someone-else"}
        with self.assertRaises(inbox.InboxError):
            self.connect()
        self.assertFalse(self.home.exists())

    def test_invalid_token_and_network_failure_leave_no_profile(self):
        with self.assertRaises(inbox.InboxError):
            contributor.connect(self.invite, self.home, "short")
        self.identity_mock.assert_not_called()
        self.transport_mock.assert_not_called()
        self.transport_mock.side_effect = inbox.InboxError("Synthetic network failure")
        with self.assertRaises(inbox.InboxError):
            self.connect()
        self.assertFalse(self.home.exists())

    def test_missing_reviewed_runtime_leaves_no_profile(self):
        (self.source / contributor.RUNTIME_FILES[-1]).unlink()
        with self.assertRaises(inbox.InboxError):
            self.connect()
        self.assertFalse(self.home.exists())

    def test_profile_modes_and_runtime_are_independent_of_checkout_changes(self):
        original = {name: (self.source / name).read_bytes() for name in contributor.RUNTIME_FILES}
        result = self.connect()
        self.assertEqual(result["contributor"], INVITE["contributor"])
        self.assertFalse(result["pending"])
        self.assertNotIn(TOKEN, json.dumps(result))
        self.transport_mock.assert_called_once_with(
            INVITE["url"], TOKEN, "/v1/inbox?after=0&limit=1")
        hashes = json.loads((self.home / "runtime-sha256.json").read_text())
        for name, content in original.items():
            self.assertEqual(hashes[name], hashlib.sha256(content).hexdigest())
            (self.source / name).write_text("# later unreviewed branch content\n")
            self.assertEqual((self.home / "runtime" / name).read_bytes(), content)
        self.assertEqual(contributor.profile(self.home)[3], INVITE["contributor"])
        if os.name == "posix":
            self.assertEqual(stat.S_IMODE(self.home.stat().st_mode), 0o700)
            self.assertEqual(stat.S_IMODE((self.home / "runtime").stat().st_mode), 0o700)
            for path in self.home.rglob("*"):
                if path.is_file():
                    self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600, path)

    def test_existing_profile_and_symlink_are_never_overwritten(self):
        self.connect()
        original = self.snapshot()
        self.transport_mock.reset_mock()
        with self.assertRaises(inbox.InboxError):
            self.connect()
        self.assertEqual(self.snapshot(), original)
        self.transport_mock.assert_not_called()
        link = self.root / "profile-link"
        link.symlink_to(self.home, target_is_directory=True)
        with self.assertRaises(inbox.InboxError):
            contributor.connect(self.invite, link, TOKEN)
        self.assertEqual(self.snapshot(), original)

    def test_profile_inside_git_directory_or_worktree_is_refused(self):
        for index, git_is_file in enumerate([False, True]):
            checkout = self.root / ("checkout-" + str(index))
            checkout.mkdir()
            marker = checkout / ".git"
            if git_is_file:
                marker.write_text("gitdir: /fixture/worktree-metadata\n")
            else:
                marker.mkdir()
            target = checkout / "nested" / "private"
            with self.subTest(git_is_file=git_is_file), self.assertRaises(inbox.InboxError):
                contributor.connect(self.invite, target, TOKEN)
            self.assertFalse(target.exists())
        self.identity_mock.assert_not_called()
        self.transport_mock.assert_not_called()

    def test_agent_commands_quote_paths_with_spaces_and_contain_no_token(self):
        self.connect()
        before = self.snapshot()
        self.transport_mock.reset_mock()
        commands = contributor.instructions(self.home)
        self.assertEqual(set(commands), {"claude", "codex"})
        for agent, text in commands.items():
            words = shlex.split(text)
            self.assertEqual(words[0:3], [agent, "mcp", "add"])
            launch = words[words.index("--") + 1:]
            self.assertEqual(launch, [str(Path(sys.executable).resolve()), "-E", "-s",
                str(self.home / "runtime" / "agent_inbox_mcp.py"), "--config",
                str(self.home / "client.json")])
            self.assertNotIn(TOKEN, text)
            self.assertNotIn("inbox-token", text)
        self.assertEqual(set(contributor.instructions(self.home, "claude")), {"claude"})
        self.assertEqual(set(contributor.instructions(self.home, "codex")), {"codex"})
        self.assertEqual(self.snapshot(), before)
        self.transport_mock.assert_not_called()

    def test_doctor_is_read_only_does_not_ack_or_register_an_agent(self):
        self.connect()
        before = self.snapshot()
        self.transport_mock.reset_mock()
        with mock.patch.object(inbox, "acknowledge") as ack, \
                mock.patch.object(contributor.subprocess, "run") as command:
            result = contributor.doctor(self.home)
        self.assertEqual(result["status"], "connected")
        self.assertEqual(result["agent_registration"], "not_checked")
        self.assertEqual(result["hardware"], "NOT_RUN")
        self.assertNotIn(TOKEN, json.dumps(result))
        self.assertEqual(self.snapshot(), before)
        self.transport_mock.assert_called_once_with(
            INVITE["url"], TOKEN, "/v1/inbox?after=0&limit=1")
        ack.assert_not_called()
        command.assert_not_called()

    def test_doctor_rejects_modified_runtime_before_any_network(self):
        self.connect()
        (self.home / "runtime" / contributor.RUNTIME_FILES[0]).write_text("# unexpected modification\n")
        self.identity_mock.reset_mock()
        self.transport_mock.reset_mock()
        with self.assertRaises(inbox.InboxError):
            contributor.doctor(self.home)
        self.identity_mock.assert_not_called()
        self.transport_mock.assert_not_called()

    def test_saved_invitation_and_config_cannot_disagree(self):
        self.connect()
        config_path = self.home / "client.json"
        config = json.loads(config_path.read_text())
        config["contributor"] = "someone-else"
        config_path.write_text(json.dumps(config))
        self.transport_mock.reset_mock()
        with self.assertRaises(inbox.InboxError):
            contributor.doctor(self.home)
        self.transport_mock.assert_not_called()

    def test_cli_token_file_setup_does_not_print_credentials_or_register(self):
        output, errors = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors), \
                mock.patch.object(contributor.getpass, "getpass") as prompt, \
                mock.patch.object(contributor.subprocess, "run") as command:
            code = contributor.main(["connect", "--invite", str(self.invite_path),
                                     "--home", str(self.home), "--token-file", str(self.token_path),
                                     "--agent", "codex"])
        self.assertEqual(code, 0)
        self.assertNotIn(TOKEN, output.getvalue() + errors.getvalue())
        self.assertIn("codex mcp add", output.getvalue())
        self.assertNotIn("claude mcp add", output.getvalue())
        prompt.assert_not_called()
        command.assert_not_called()

    def test_cli_remote_error_does_not_leak_token_or_server_text(self):
        self.transport_mock.side_effect = inbox.InboxError("synthetic secret server text " + TOKEN)
        output, errors = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
            code = contributor.main(["connect", "--invite", str(self.invite_path),
                                     "--home", str(self.home), "--token-file", str(self.token_path)])
        self.assertEqual(code, 1)
        self.assertFalse(self.home.exists())
        self.assertNotIn(TOKEN, output.getvalue() + errors.getvalue())
        self.assertNotIn("synthetic secret server text", errors.getvalue())

    def test_github_identity_uses_only_the_fixed_read_command(self):
        self.identity.stop()
        response = subprocess.CompletedProcess([], 0,
            stdout=b'{"login":"fixture-contributor","id":12345}', stderr=b"")
        with mock.patch.object(contributor.shutil, "which", return_value="/fixture/gh"), \
                mock.patch.object(contributor.subprocess, "run", return_value=response) as run:
            self.assertEqual(contributor.github_identity(), ("fixture-contributor", 12345))
        run.assert_called_once_with(["/fixture/gh", "api", "--hostname", "github.com", "user"],
                                    capture_output=True, timeout=20, check=False)


if __name__ == "__main__":
    unittest.main()
