#!/usr/bin/env python3
"""Create private, new pilot credentials; never print their contents or deploy."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import secrets
from urllib.parse import urlencode, urlsplit


def initialize(output: Path, url: str) -> None:
    if not 0 < len(url) <= 2048 or not all(32 < ord(c) < 127 for c in url):
        raise ValueError("Invalid HTTPS origin")
    parsed = urlsplit(url)
    port = parsed.port
    if (
        parsed.scheme != "https" or not parsed.hostname
        or parsed.username is not None or parsed.password is not None
        or parsed.query or parsed.fragment
        or parsed.path not in ("", "/")
        or (port is not None and not 1 <= port <= 65535)
    ):
        raise ValueError("URL must be an HTTPS origin without credentials, path or query")
    # Refuse overwrite, including a symlink to another private directory.
    output = output.absolute()
    output.mkdir(mode=0o700, parents=False, exist_ok=False)
    os.chmod(output, 0o700)
    webhook_secret = secrets.token_urlsafe(48)
    inbox_token = secrets.token_urlsafe(48)
    service_secrets = {
        "WEBHOOK_SECRET": webhook_secret,
        "INBOX_TOKEN_SHA256": hashlib.sha256(inbox_token.encode()).hexdigest(),
    }
    registration = {
        "name": "msdk-ios-lab-inbox-bibek849",
        "description": "Read-only GitHub events for the MSDK iOS Lab contributor inbox.",
        "url": "https://github.com/bibek849/msdk-ios-lab",
        "public": "false",
        "request_oauth_on_install": "false",
        "webhook_active": "true",
        "webhook_url": url.rstrip("/") + "/github/webhook",
        "issues": "read",
        "pull_requests": "read",
        "events[]": ["issues", "issue_comment", "pull_request", "pull_request_review",
                      "pull_request_review_comment", "pull_request_review_thread"],
    }
    files = {
        "webhook-secret": webhook_secret + "\n",
        "inbox-token": inbox_token + "\n",
        "worker-secrets.json": json.dumps(service_secrets, indent=2) + "\n",
        "client.json": json.dumps({
            "url": url.rstrip("/"),
            "token_file": str(output / "inbox-token"),
            "contributor": "bibek849",
        }, indent=2) + "\n",
        "github-app-registration-url.txt": "https://github.com/settings/apps/new?"
        + urlencode(registration, doseq=True) + "\n",
    }
    for name, content in files.items():
        fd = os.open(output / name, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as target:
            target.write(content)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True,
                        help="New private directory; parent must already exist")
    parser.add_argument("--url", required=True, help="Pilot HTTPS origin")
    args = parser.parse_args()
    try:
        initialize(args.output, args.url)
    except (ValueError, OSError):
        parser.exit(1, "Cannot initialize pilot: check HTTPS origin and new private output path.\n")
    print("Created private pilot files in " + str(args.output.absolute()))
    print("No credentials printed, no GitHub App registered, no service deployed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
