#!/usr/bin/env python3
"""Read and explicitly acknowledge a contributor inbox; never execute event text."""

import argparse
from datetime import datetime
from http.client import HTTPException
import json
import os
from pathlib import Path
import re
import stat
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlsplit
from urllib.request import HTTPRedirectHandler, ProxyHandler, Request, build_opener


REPOSITORY = "bibek849/msdk-ios-lab"
MAX_RESPONSE_BYTES = 512 * 1024
MAX_SAFE_ID = 9_007_199_254_740_991
TIMEOUT_SECONDS = 15
EVENT_FIELDS = {
    "id", "delivery_id", "event", "action", "kind", "item_type", "number",
    "url", "actor", "actor_id", "title", "body_excerpt", "head_sha",
    "occurred_at", "received_at", "untrusted",
}
EVENT_NAMES = {
    "issues", "issue_comment", "pull_request", "pull_request_review",
    "pull_request_review_comment", "pull_request_review_thread",
}


class InboxError(ValueError):
    """An error whose message is safe to show without credentials or response text."""


def require(condition, message):
    if not condition:
        raise InboxError(message)


def positive_id(value):
    return type(value) is int and 1 <= value <= MAX_SAFE_ID


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate JSON key")
        result[key] = value
    return result


def _reject_constant(_value):
    raise ValueError("Nonfinite JSON number")


def decode_json(raw, description):
    try:
        return json.loads(raw.decode("utf-8"), object_pairs_hook=_unique_object,
                          parse_constant=_reject_constant)
    except (UnicodeError, ValueError, RecursionError) as error:
        raise InboxError(f"{description} is not valid UTF-8 JSON") from error


def read_private_file(path, maximum, description):
    """Open a regular owner-only file without following its final symlink."""
    descriptor = None
    try:
        flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0)
        descriptor = os.open(path, flags)
        metadata = os.fstat(descriptor)
        require(stat.S_ISREG(metadata.st_mode), f"{description} must be a regular file")
        if os.name == "posix":
            require(metadata.st_uid == os.getuid(), f"{description} must be owned by you")
            require(metadata.st_mode & 0o077 == 0,
                    f"{description} must have owner-only permissions (chmod 600)")
        require(metadata.st_size <= maximum, f"{description} is too large")
        with os.fdopen(descriptor, "rb") as stream:
            descriptor = None
            raw = stream.read(maximum + 1)
        require(len(raw) <= maximum, f"{description} is too large")
        return raw
    except OSError as error:
        raise InboxError(f"Cannot read {description}; use a private regular file, not a symlink") from error
    finally:
        if descriptor is not None:
            os.close(descriptor)


def validate_base_url(value, allow_local_http=False):
    require(isinstance(value, str) and 0 < len(value) <= 2048 and
            all(32 < ord(character) < 127 for character in value), "Invalid inbox URL")
    try:
        parsed = urlsplit(value)
        port = parsed.port
    except ValueError as error:
        raise InboxError("Invalid inbox URL") from error
    require(parsed.hostname and parsed.username is None and parsed.password is None and
            not parsed.query and not parsed.fragment and parsed.path in ("", "/"),
            "Inbox URL must be an origin without credentials, path, query or fragment")
    require(port is None or 1 <= port <= 65535, "Invalid inbox URL port")
    is_loopback = parsed.hostname in {"127.0.0.1", "localhost", "::1"}
    require(parsed.scheme == "https" or
            (allow_local_http and parsed.scheme == "http" and is_loopback),
            "Inbox URL requires HTTPS; explicit local HTTP is limited to loopback")
    return f"{parsed.scheme}://{parsed.netloc}"


def load_config(path, allow_local_http=False):
    path = Path(path).expanduser().absolute()
    config = decode_json(read_private_file(path, 8192, "client configuration"),
                         "Client configuration")
    require(isinstance(config, dict) and set(config) == {"url", "token_file", "contributor"},
            "Configuration requires exactly url, token_file and contributor")
    base_url = validate_base_url(config["url"], allow_local_http)
    contributor = config["contributor"]
    require(isinstance(contributor, str) and
            re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9-]{0,38}", contributor),
            "Invalid contributor login in configuration")
    require(isinstance(config["token_file"], str) and 0 < len(config["token_file"]) <= 4096,
            "Configuration requires a token file path")
    token_path = Path(config["token_file"]).expanduser()
    if not token_path.is_absolute():
        token_path = path.parent / token_path
    try:
        token = read_private_file(token_path, 1024, "inbox token file").decode("ascii").rstrip("\r\n")
    except UnicodeError as error:
        raise InboxError("Invalid inbox token file") from error
    require(len(token) <= 512 and re.fullmatch(r"[A-Za-z0-9._~+/-]{32,512}=*", token),
            "Inbox token must be a single 32–512 character bearer token")
    return base_url, contributor, token


class NoRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def request_json(base_url, token, path, payload=None):
    headers = {"Accept": "application/json", "Authorization": "Bearer " + token,
               "User-Agent": "msdk-ios-lab-inbox/1"}
    data = None
    if payload is not None:
        data = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        headers["Content-Type"] = "application/json"
    request = Request(base_url + path, data=data, headers=headers,
                      method="POST" if payload is not None else "GET")
    # Do not forward the inbox credential through environment-configured proxies
    # or follow a redirect to another origin. TLS uses urllib's verified default.
    opener = build_opener(ProxyHandler({}), NoRedirects())
    try:
        with opener.open(request, timeout=TIMEOUT_SECONDS) as response:
            require(response.status == 200, "Unexpected inbox HTTP status")
            require(response.headers.get_content_type() == "application/json",
                    "Inbox response must be application/json")
            length = response.headers.get("Content-Length")
            if length is not None:
                require(re.fullmatch(r"[0-9]{1,7}", length) and int(length) <= MAX_RESPONSE_BYTES,
                        "Inbox response is too large or has invalid length")
            raw = response.read(MAX_RESPONSE_BYTES + 1)
    except HTTPError as error:
        code = error.code
        error.close()
        if 300 <= code < 400:
            raise InboxError("Inbox redirects are refused; verify the configured origin") from error
        raise InboxError(f"Inbox request failed (HTTP {code}); no automatic retry") from error
    except (URLError, OSError, TimeoutError, HTTPException) as error:
        raise InboxError("Inbox network/TLS request failed; no automatic retry") from error
    require(len(raw) <= MAX_RESPONSE_BYTES, "Inbox response exceeds 512 KiB")
    return decode_json(raw, "Inbox response")


def _text(value, maximum, nullable=False):
    return (nullable and value is None) or (isinstance(value, str) and len(value) <= maximum)


def _timestamp(value, nullable=False):
    if nullable and value is None:
        return True
    if not _text(value, 40) or not value:
        return False
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).tzinfo is not None
    except ValueError:
        return False


def validate_event(event, after):
    require(isinstance(event, dict) and set(event) == EVENT_FIELDS,
            "Inbox event fields do not match schema 1")
    require(positive_id(event["id"]) and event["id"] > after and positive_id(event["number"]),
            "Inbox event has an invalid identifier or order")
    require(event["untrusted"] is True, "Inbox events must be marked untrusted")
    require(isinstance(event["event"], str) and event["event"] in EVENT_NAMES and
            event["item_type"] in ("issue", "pull_request"),
            "Inbox event has an unsupported type")
    for name in ("action", "kind"):
        require(isinstance(event[name], str) and re.fullmatch(r"[a-z_]{1,64}", event[name]),
                "Inbox event has an invalid action or kind")
    require(isinstance(event["delivery_id"], str) and
            re.fullmatch(r"[A-Za-z0-9_-]{1,128}", event["delivery_id"]),
            "Inbox event has an invalid delivery ID")
    require(_text(event["title"], 500) and _text(event["body_excerpt"], 4000),
            "Inbox event text exceeds the schema limits")
    require(event["actor"] is None or (isinstance(event["actor"], str) and
            re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9-]{0,63}(?:\[bot\])?", event["actor"])),
            "Inbox event has an invalid actor")
    require(event["actor_id"] is None or positive_id(event["actor_id"]),
            "Inbox event has an invalid actor ID")
    require(event["head_sha"] is None or (isinstance(event["head_sha"], str) and
            re.fullmatch(r"[0-9a-f]{40}", event["head_sha"])),
            "Inbox event has an invalid source revision")
    require(_timestamp(event["occurred_at"], nullable=True) and _timestamp(event["received_at"]),
            "Inbox event has an invalid timestamp")
    path_type = "issues" if event["item_type"] == "issue" else "pull"
    canonical = f"https://github.com/{REPOSITORY}/{path_type}/{event['number']}"
    require(isinstance(event["url"], str) and re.fullmatch(
        re.escape(canonical) + r"(?:#(?:issuecomment-\d+|discussion_r\d+|pullrequestreview-\d+))?",
        event["url"]), "Inbox event URL is outside the expected repository item")


def fetch(base_url, contributor, token, after=0, limit=50):
    require(type(after) is int and 0 <= after < MAX_SAFE_ID, "after must be a nonnegative ID")
    require(type(limit) is int and 1 <= limit <= 50, "limit must be between 1 and 50")
    result = request_json(base_url, token, "/v1/inbox?" + urlencode({"after": after, "limit": limit}))
    require(isinstance(result, dict) and set(result) == {"schema", "contributor", "events", "has_more"},
            "Inbox response fields do not match schema 1")
    require(type(result["schema"]) is int and result["schema"] == 1 and
            result["contributor"] == contributor, "Inbox schema or contributor does not match configuration")
    require(type(result["has_more"]) is bool and isinstance(result["events"], list) and
            len(result["events"]) <= limit, "Inbox page exceeds its limit or is malformed")
    previous_id = after
    for event in result["events"]:
        validate_event(event, previous_id)
        previous_id = event["id"]
    require(not result["has_more"] or result["events"], "Inbox pagination is incomplete")
    return result


def acknowledge(base_url, contributor, token, ids):
    require(isinstance(ids, list) and 1 <= len(ids) <= 50 and all(positive_id(item) for item in ids),
            "ack requires 1–50 positive event IDs")
    ids = sorted(set(ids))
    result = request_json(base_url, token, "/v1/ack", {"ids": ids})
    require(isinstance(result, dict) and set(result) == {"schema", "contributor", "acknowledged"},
            "Acknowledgment response fields do not match schema 1")
    require(type(result["schema"]) is int and result["schema"] == 1 and
            result["contributor"] == contributor and result["acknowledged"] == ids and
            all(positive_id(item) for item in result["acknowledged"]),
            "Acknowledgment response does not match the requested contributor and IDs")
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True, help="Owner-only local JSON configuration")
    parser.add_argument("--allow-local-http", action="store_true", help="Permit HTTP only for loopback testing")
    subparsers = parser.add_subparsers(dest="command", required=True)
    fetch_parser = subparsers.add_parser("fetch", help="Read pending events without acknowledging them")
    fetch_parser.add_argument("--after", type=int, default=0)
    fetch_parser.add_argument("--limit", type=int, default=50)
    ack_parser = subparsers.add_parser("ack", help="Acknowledge only IDs already processed; never completes a task")
    ack_parser.add_argument("ids", nargs="+", type=int)
    args = parser.parse_args(argv)
    try:
        base_url, contributor, token = load_config(args.config, args.allow_local_http)
        if args.command == "fetch":
            result = fetch(base_url, contributor, token, args.after, args.limit)
        else:
            result = acknowledge(base_url, contributor, token, args.ids)
        print(json.dumps(result, ensure_ascii=True, sort_keys=True))
        return 0
    except InboxError as error:
        print("inbox: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
