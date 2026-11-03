#!/usr/bin/env python3
"""Prepare one isolated contributor inbox locally; never deploy or print secrets.

Each bundle is for a NEW Worker, D1 database and private GitHub App. The existing
owner pilot is not reused, and invite.json alone does not provision anything.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
from urllib.parse import urlencode, urlsplit
from uuid import UUID

from agent_inbox import MAX_SAFE_ID, REPOSITORY, validate_base_url


ROOT = Path(__file__).resolve().parents[1]
SERVICE = ROOT / "services" / "agent-inbox"
ZERO_DATABASE_ID = "00000000-0000-0000-0000-000000000000"
PILOT_WORKER = "msdk-ios-lab-inbox"
PILOT_DATABASE = "msdk-ios-lab-inbox-pilot"
PILOT_DATABASE_ID = "b2787a9c-8e4f-4c13-b354-71c6a335d85e"
PILOT_INSTALLATION_ID = 178014955
EVENTS = ["issues", "issue_comment", "pull_request", "pull_request_review",
          "pull_request_review_comment", "pull_request_review_thread"]


def _identifier(value, description, allow_zero=False):
    minimum = 0 if allow_zero else 1
    if type(value) is not int or not minimum <= value <= MAX_SAFE_ID:
        raise ValueError(f"Invalid {description}")


def _resource_name(value, maximum, description):
    if (not isinstance(value, str) or not 1 <= len(value) <= maximum or
            not re.fullmatch(r"[a-z0-9](?:[a-z0-9-]*[a-z0-9])?", value)):
        raise ValueError(f"Invalid {description}; use lowercase letters, digits and hyphens")


def create_invite(output, login, github_id, url, worker_name, database_name,
                  database_id=ZERO_DATABASE_ID, installation_id=0, app_name=None):
    """Write a new private bundle after validating every supplied identity."""
    if (not isinstance(login, str) or not 1 <= len(login) <= 39 or
            not re.fullmatch(r"[A-Za-z0-9](?:[A-Za-z0-9]|-(?=[A-Za-z0-9]))*", login)):
        raise ValueError("Invalid GitHub contributor login")
    _identifier(github_id, "GitHub contributor ID")
    _identifier(installation_id, "GitHub installation ID", allow_zero=True)
    _resource_name(worker_name, 63, "Worker name")
    _resource_name(database_name, 63, "database name")
    app_name = app_name if app_name is not None else f"msdk-lab-inbox-{github_id}"
    _resource_name(app_name, 34, "GitHub App name")
    url = validate_base_url(url)
    host = urlsplit(url).hostname
    if host.endswith(".workers.dev"):
        labels = host.split(".")
        if len(labels) != 4 or labels[0] != worker_name:
            raise ValueError("workers.dev origin must match the new Worker name")
    if not isinstance(database_id, str):
        raise ValueError("Invalid database UUID")
    try:
        if str(UUID(database_id)) != database_id:
            raise ValueError("Invalid database UUID")
    except (ValueError, AttributeError) as error:
        raise ValueError("Invalid database UUID") from error
    if (worker_name == PILOT_WORKER or database_name == PILOT_DATABASE or
            database_id == PILOT_DATABASE_ID or installation_id == PILOT_INSTALLATION_ID or
            host == "msdk-ios-lab-inbox.onrampyadav.workers.dev"):
        raise ValueError("This preparer cannot reuse the existing owner's pilot resources")

    config = json.loads((SERVICE / "wrangler.jsonc").read_text(encoding="utf-8"))
    config["$schema"] = str(SERVICE / "node_modules" / "wrangler" / "config-schema.json")
    config["name"] = worker_name
    config["main"] = str(SERVICE / "src" / "index.ts")
    config["vars"] = {
        "REPOSITORY": REPOSITORY,
        "REPOSITORY_ID": "1443581816",
        "CONTRIBUTOR_LOGIN": login,
        "CONTRIBUTOR_ID": str(github_id),
        "INSTALLATION_ID": str(installation_id),
        "PILOT_ENABLED": "false",
        "TRACKED_ISSUES": "",
        "TRACKED_PRS": "",
    }
    config["d1_databases"] = [{
        "binding": "DB", "database_name": database_name,
        "database_id": database_id, "migrations_dir": str(SERVICE / "migrations"),
    }]
    config.pop("account_id", None)

    output = Path(output).expanduser().absolute()
    # Creating only a new directory prevents replacing or rotating an existing
    # person's credentials, including through a final-component symlink.
    output.mkdir(mode=0o700, parents=False, exist_ok=False)
    os.chmod(output, 0o700)
    inbox_token = secrets.token_urlsafe(48)
    webhook_secret = secrets.token_urlsafe(48)
    invite = {"schema": 1, "repository": REPOSITORY, "contributor": login,
              "contributor_id": github_id, "url": url}
    registration = {
        "name": app_name,
        "description": "Read-only GitHub events for one MSDK iOS Lab contributor.",
        "url": f"https://github.com/{REPOSITORY}",
        "public": "false", "request_oauth_on_install": "false",
        "webhook_active": "true", "webhook_url": url + "/github/webhook",
        "issues": "read", "pull_requests": "read", "events[]": EVENTS,
    }
    files = {
        "invite.json": json.dumps(invite, indent=2) + "\n",
        "inbox-token": inbox_token + "\n",
        "webhook-secret": webhook_secret + "\n",
        "worker-secrets.json": json.dumps({
            "WEBHOOK_SECRET": webhook_secret,
            "INBOX_TOKEN_SHA256": hashlib.sha256(inbox_token.encode()).hexdigest(),
        }, indent=2) + "\n",
        "client.json": json.dumps({"url": url, "contributor": login,
                                   "token_file": str(output / "inbox-token")}, indent=2) + "\n",
        "wrangler.contributor.jsonc": json.dumps(config, indent=2) + "\n",
        "github-app-registration-url.txt": "https://github.com/settings/apps/new?"
        + urlencode(registration, doseq=True) + "\n",
    }
    for name, content in files.items():
        descriptor = os.open(output / name, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as target:
            target.write(content)
    return invite


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--login", required=True, help="Verified contributor GitHub login")
    parser.add_argument("--github-id", required=True, type=int,
                        help="Verified numeric contributor ID, not the maintainer ID")
    parser.add_argument("--url", required=True, help="New inbox HTTPS origin")
    parser.add_argument("--worker-name", required=True, help="New, unused Worker name")
    parser.add_argument("--database-name", required=True, help="New, unused D1 name")
    parser.add_argument("--database-id", default=ZERO_DATABASE_ID,
                        help="New database UUID; defaults to an unconfigured placeholder")
    parser.add_argument("--installation-id", default=0, type=int,
                        help="New App installation ID; defaults to unconfigured 0")
    parser.add_argument("--app-name", help="New globally unique App name, at most 34 characters")
    parser.add_argument("--output", required=True, type=Path,
                        help="New private directory; parent must already exist")
    args = parser.parse_args()
    try:
        create_invite(**vars(args))
    except (ValueError, OSError, KeyError, TypeError):
        parser.exit(1, "Cannot prepare invite: verify identities, HTTPS origin, new resource names "
                    "and a new private output directory. Existing files were not replaced.\n")
    print("Prepared private onboarding bundle in " + str(args.output.expanduser().absolute()))
    print("No service deployed, App registered, contributor contacted or billing changed.")
    print("Deploy and verify the new inbox before sharing invite.json; send inbox-token separately ")
    print("through a private channel. Never share the other bundle files with contributors.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
