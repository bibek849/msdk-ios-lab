#!/usr/bin/env python3
"""Connect a contributor's private inbox and print agent setup commands."""

import argparse
import getpass
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import stat
import subprocess
import sys

import agent_inbox as inbox


DEFAULT_HOME = Path.home() / ".config" / "msdk-ios-lab"
SOURCE = Path(__file__).resolve().parent
RUNTIME_FILES = ("agent_inbox.py", "agent_inbox_mcp.py")
INVITE_FIELDS = {"schema", "repository", "contributor", "contributor_id", "url"}


class OnboardingError(inbox.InboxError):
    """Locally defined diagnostics containing no external response text."""


def require(condition, message):
    if not condition:
        raise OnboardingError(message)


def read_invite(path):
    """Invitations contain no secret and may arrive as ordinary downloaded files."""
    descriptor = None
    try:
        descriptor = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
                             | getattr(os, "O_NONBLOCK", 0))
        metadata = os.fstat(descriptor)
        require(stat.S_ISREG(metadata.st_mode) and metadata.st_size <= 8192,
                      "Invitation must be a regular JSON file of at most 8 KiB")
        with os.fdopen(descriptor, "rb") as stream:
            descriptor = None
            raw = stream.read(8193)
        require(len(raw) <= 8192, "Invitation is too large")
    except OSError as error:
        raise inbox.InboxError("Cannot read invitation; use the maintainer's local invite.json") from error
    finally:
        if descriptor is not None:
            os.close(descriptor)
    return validate_invite(inbox.decode_json(raw, "Invitation"))


def validate_invite(value):
    require(isinstance(value, dict) and set(value) == INVITE_FIELDS,
                  "Invitation fields do not match schema 1")
    require(type(value["schema"]) is int and value["schema"] == 1
                  and value["repository"] == inbox.REPOSITORY,
                  "Invitation is not for MSDK iOS Lab schema 1")
    require(isinstance(value["contributor"], str) and re.fullmatch(
        r"[A-Za-z0-9][A-Za-z0-9-]{0,38}", value["contributor"])
        and inbox.positive_id(value["contributor_id"]), "Invalid invitation identity")
    result = dict(value)
    result["url"] = inbox.validate_base_url(value["url"])
    return result


def github_identity():
    executable = shutil.which("gh")
    require(executable is not None, "Install GitHub CLI, then run gh auth login")
    try:
        result = subprocess.run([executable, "api", "--hostname", "github.com", "user"],
                                capture_output=True, timeout=20, check=False)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise inbox.InboxError("GitHub identity check failed; check gh auth status") from error
    require(result.returncode == 0 and len(result.stdout) <= 65536,
                  "GitHub identity check failed; run gh auth login for your own account")
    value = inbox.decode_json(result.stdout, "GitHub identity")
    require(isinstance(value, dict) and isinstance(value.get("login"), str)
                  and inbox.positive_id(value.get("id")), "Invalid GitHub identity response")
    return value["login"], value["id"]


def verify_identity(invite):
    login, identifier = github_identity()
    require(login.lower() == invite["contributor"].lower()
                  and identifier == invite["contributor_id"],
                  "Signed-in GitHub account does not match this invitation")


def private_home(home):
    home = Path(home).expanduser().absolute()
    require(not home.exists() and not home.is_symlink(),
                  "Profile already exists; use doctor or choose a new --home")
    resolved = home.resolve()
    require(not any((parent / ".git").exists() for parent in (resolved, *resolved.parents)),
                  "Keep the private profile outside every Git checkout")
    return home


def write_private(path, data):
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "wb") as stream:
        stream.write(data)


def connect(invite, home, token):
    invite = validate_invite(invite)
    home = private_home(home)
    require(isinstance(token, str) and len(token) <= 512 and
                  re.fullmatch(r"[A-Za-z0-9._~+/-]{32,512}=*", token),
                  "Invalid inbox token; use the separately supplied credential")
    verify_identity(invite)
    # Validate remote identity before persisting a credential. Reading never acknowledges.
    page = inbox.fetch(invite["url"], invite["contributor"], token, limit=1)
    runtime = {}
    for name in RUNTIME_FILES:
        path = SOURCE / name
        require(path.is_file() and not path.is_symlink(), "Reviewed inbox runtime is missing")
        runtime[name] = path.read_bytes()
    home.parent.mkdir(parents=True, exist_ok=True)
    home.mkdir(mode=0o700, exist_ok=False)
    os.chmod(home, 0o700)
    (home / "runtime").mkdir(mode=0o700)
    write_private(home / "inbox-token", (token + "\n").encode("ascii"))
    config = {"url": invite["url"], "contributor": invite["contributor"],
              "token_file": str(home / "inbox-token")}
    write_private(home / "client.json", (json.dumps(config, indent=2) + "\n").encode())
    write_private(home / "invite.json", (json.dumps(invite, indent=2) + "\n").encode())
    hashes = {}
    for name, content in runtime.items():
        write_private(home / "runtime" / name, content)
        hashes[name] = hashlib.sha256(content).hexdigest()
    write_private(home / "runtime-sha256.json", (json.dumps(hashes, indent=2) + "\n").encode())
    return {"contributor": invite["contributor"], "connected": True,
            "pending": bool(page["events"]), "profile": str(home)}


def profile(home):
    home = Path(home).expanduser().absolute()
    invite = validate_invite(inbox.decode_json(
        inbox.read_private_file(home / "invite.json", 8192, "saved invitation"), "Saved invitation"))
    url, login, token = inbox.load_config(home / "client.json")
    require(url == invite["url"] and login == invite["contributor"],
                  "Profile configuration does not match its saved invitation")
    hashes = inbox.decode_json(inbox.read_private_file(
        home / "runtime-sha256.json", 8192, "runtime manifest"), "Runtime manifest")
    require(isinstance(hashes, dict) and set(hashes) == set(RUNTIME_FILES),
                  "Invalid installed runtime manifest")
    for name in RUNTIME_FILES:
        data = inbox.read_private_file(home / "runtime" / name, 128 * 1024, "installed inbox runtime")
        require(hashlib.sha256(data).hexdigest() == hashes[name],
                      "Installed runtime changed; review it before reconnecting in a new profile")
    return home, invite, url, login, token


def doctor(home):
    home, invite, url, login, token = profile(home)
    verify_identity(invite)
    page = inbox.fetch(url, login, token, limit=1)
    return {"status": "connected", "contributor": login, "repository": inbox.REPOSITORY,
            "pending": bool(page["events"]), "profile": str(home),
            "agent_registration": "not_checked", "hardware": "NOT_RUN"}


def instructions(home, agent=None):
    home, _invite, _url, _login, _token = profile(home)
    launch = [str(Path(sys.executable).resolve()), "-E", "-s",
              str(home / "runtime" / "agent_inbox_mcp.py"), "--config", str(home / "client.json")]
    commands = {
        "claude": ["claude", "mcp", "add", "--transport", "stdio", "--scope", "local",
                   "msdk-ios-lab", "--", *launch],
        "codex": ["codex", "mcp", "add", "msdk-ios-lab", "--", *launch],
    }
    return {name: shlex.join(command) for name, command in commands.items()
            if agent is None or name == agent}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    for name in ("connect", "doctor", "instructions"):
        sub = subparsers.add_parser(name)
        sub.add_argument("--home", type=Path, default=DEFAULT_HOME,
                         help="Private profile directory outside your checkout")
        if name != "doctor":
            sub.add_argument("--agent", choices=("claude", "codex"))
        if name == "connect":
            sub.add_argument("--invite", type=Path, required=True)
            sub.add_argument("--token-file", type=Path,
                             help="Read an existing owner-only credential file instead of hidden prompt")
    args = parser.parse_args(argv)
    try:
        if args.command == "connect":
            invitation = read_invite(args.invite)
            private_home(args.home)
            print("Connecting " + invitation["contributor"] + " to " + invitation["url"])
            print("Use only an invitation and token received directly from the maintainer.")
            if args.token_file:
                token = inbox.read_private_file(args.token_file, 1024, "inbox token file").decode("ascii").rstrip("\r\n")
            else:
                require(sys.stdin.isatty(), "Use an interactive terminal for the hidden token prompt, or --token-file")
                token = getpass.getpass("Inbox token (hidden): ")
            print(json.dumps(connect(invitation, args.home, token), sort_keys=True))
        if args.command in ("connect", "instructions"):
            print("Run ONE command below from your fork to register the reviewed inbox tools.")
            print("Review an existing msdk-ios-lab entry before replacing it. No agent settings were changed.")
            for name, command in instructions(args.home, args.agent).items():
                print(name + ":\n" + command)
            if args.agent in (None, "codex"):
                command = shlex.split(instructions(args.home, "codex")["codex"])
                separator = command.index("--")
                print("Desktop without the Codex CLI: add these fields in Settings > MCP servers:")
                print(json.dumps({"name": "msdk-ios-lab", "transport": "stdio",
                                  "command": command[separator + 1],
                                  "args": command[separator + 2:]}))
            print("Restart your agent; ask it to call inbox_status, then inbox_events. Fetch never acknowledges.")
            print("Follow docs/CONTRIBUTOR_QUICKSTART.md for one bounded task, PR and hardware feedback.")
        else:
            print(json.dumps(doctor(args.home), sort_keys=True))
        return 0
    except OnboardingError as error:
        print("Onboarding: " + str(error), file=sys.stderr)
        return 1
    except (inbox.InboxError, OSError, UnicodeError, EOFError):
        # No token, remote response or subprocess output belongs in diagnostic text.
        print("Onboarding failed. Check the invitation, your gh login, private profile permissions and inbox availability. Existing profiles are never overwritten; use doctor or a new --home.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
