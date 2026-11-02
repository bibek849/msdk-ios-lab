#!/usr/bin/env python3
"""Export a committed experiment as metadata. Never execute its instructions."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys


MAX_SPEC_BYTES = 32_768
HARDWARE_FIELDS = {
    "phone_model", "phone_os_build", "controller", "controller_firmware",
    "aircraft", "aircraft_firmware", "cable",
}


class HandoffError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise HandoffError(message)


def text(value, name):
    require(isinstance(value, str) and 0 < len(value.strip()) <= 2_000,
            f"{name} must be nonempty text of at most 2000 characters")


def text_list(value, name):
    require(isinstance(value, list) and 1 <= len(value) <= 20,
            f"{name} must contain 1–20 text items")
    for item in value:
        text(item, name)


def validate(spec):
    """Check structure, not truth, safety, permission, or test success."""
    fields = {
        "schema_version", "id", "kind", "stage", "question", "build_commands",
        "procedure", "expected_outcomes", "stop_conditions", "prerequisites",
        "hardware", "limits",
    }
    require(isinstance(spec, dict) and set(spec) == fields,
            "Experiment must contain exactly the documented schema fields")
    require(type(spec["schema_version"]) is int and spec["schema_version"] == 1,
            "Unsupported schema_version")
    require(isinstance(spec["id"], str) and
            re.fullmatch(r"[A-Z][A-Z0-9_-]{2,63}", spec["id"]), "Invalid experiment id")
    require(spec["kind"] in ("software_only", "read_only_hardware"),
            "Only software_only and read_only_hardware requests are supported")
    require(spec["stage"] in ("S0", "S1", "S2", "S3", "S4", "S5", "S6"),
            "Invalid roadmap stage")
    if spec["kind"] == "read_only_hardware":
        require(spec["stage"] in ("S0", "S2", "S3", "S4"),
                "Hardware requests are limited to read-only S0/S2/S3/S4 work")
    text(spec["question"], "question")
    for name in ("build_commands", "procedure", "expected_outcomes", "stop_conditions"):
        text_list(spec[name], name)
    limits = spec["limits"]
    require(isinstance(limits, dict) and set(limits) == {"repetitions", "max_seconds_per_run"},
            "limits requires repetitions and max_seconds_per_run")
    require(type(limits["repetitions"]) is int and 1 <= limits["repetitions"] <= 10,
            "repetitions must be 1–10")
    require(type(limits["max_seconds_per_run"]) is int and
            1 <= limits["max_seconds_per_run"] <= 300,
            "max_seconds_per_run must be 1–300")
    prerequisites = spec["prerequisites"]
    require(isinstance(prerequisites, list) and len(prerequisites) <= 20,
            "prerequisites must be a list of at most 20 records")
    pending = []
    for item in prerequisites:
        require(isinstance(item, dict) and set(item) == {"requirement", "status", "evidence"},
                "Each prerequisite requires requirement, status and evidence")
        text(item["requirement"], "prerequisite requirement")
        require(item["status"] in ("pending", "documented"), "Invalid prerequisite status")
        if item["status"] == "documented":
            text(item["evidence"], "documented prerequisite evidence")
        else:
            require(item["evidence"] is None, "Pending prerequisite evidence must be null")
            pending.append("Prerequisite: " + item["requirement"])
    hardware = spec["hardware"]
    if spec["kind"] == "software_only":
        require(hardware is None, "software_only requests must set hardware to null")
    else:
        require(prerequisites, "Hardware requests must state their prerequisites")
        require(isinstance(hardware, dict) and set(hardware) == HARDWARE_FIELDS,
                "Hardware requests require the documented hardware tuple")
        for name in sorted(HARDWARE_FIELDS):
            if hardware[name] is None:
                pending.append("Hardware detail: " + name)
            else:
                text(hardware[name], name)
    return pending


def git(repo, *args):
    result = subprocess.run(["git", "-C", str(repo), *args],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    require(result.returncode == 0, "Git check failed: " + " ".join(args))
    return result.stdout


def json_bytes(value):
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def prepare(repo, experiment, output):
    repo = Path(repo).resolve()
    require(git(repo, "rev-parse", "--show-toplevel").decode().strip() == str(repo),
            "Run this tool from its repository checkout")
    require(not git(repo, "status", "--porcelain", "--untracked-files=no"),
            "Tracked changes must be committed or restored before preparing a handoff")
    commit = git(repo, "rev-parse", "HEAD").decode().strip()
    tree = git(repo, "rev-parse", "HEAD^{tree}").decode().strip()
    requested = Path(experiment)
    requested = requested if requested.is_absolute() else repo / requested
    require(not requested.is_symlink(), "Experiment may not be a symlink")
    requested = requested.resolve()
    require(requested.is_relative_to(repo), "Experiment must be inside the repository")
    relative = requested.relative_to(repo).as_posix()
    entry = git(repo, "ls-tree", commit, "--", relative).decode().strip()
    require(entry.startswith(("100644 blob ", "100755 blob ")),
            "Experiment must be a regular file tracked in HEAD")
    blob = entry.split()[2]
    raw = git(repo, "show", f"{commit}:{relative}")
    require(len(raw) <= MAX_SPEC_BYTES, "Experiment exceeds 32 KiB")
    try:
        spec = json.loads(raw.decode("utf-8"))
    except (ValueError, UnicodeError) as error:
        raise HandoffError("Experiment is not valid UTF-8 JSON") from error
    pending = validate(spec)
    destination = Path(output)
    destination = destination if destination.is_absolute() else repo / destination
    artifacts = repo / "artifacts"
    require(artifacts.resolve() == artifacts, "artifacts may not resolve through a symlink")
    resolved = destination.resolve()
    require(resolved.is_relative_to(artifacts) and resolved != artifacts,
            "Output must be a new directory beneath this checkout's artifacts directory")
    require(not destination.is_symlink() and not destination.exists(), "Output already exists")
    # Resolve nested symlinks before writing; output must stay beneath artifacts.
    destination = resolved
    manifest = {
        "schema_version": 1,
        "source": {"commit": commit, "tree": tree},
        "experiment": {"path": relative, "git_blob": blob,
                       "sha256": hashlib.sha256(raw).hexdigest()},
        "request_readiness": "DRAFT" if pending else "READY_FOR_REVIEW",
        "pending_metadata": pending,
        "review_status": "NOT_VERIFIED",
        "ci_status": "NOT_VERIFIED",
        "hardware_approval": "NOT_GRANTED",
        "test_result": "NOT_RUN_BY_THIS_TOOL",
        "contents": "Metadata only; no source archive, binary, logs or credentials collected",
    }
    outputs = {"manifest.json": json_bytes(manifest), "experiment.json": raw}
    sums = "".join(f"{hashlib.sha256(data).hexdigest()}  {name}\n"
                   for name, data in sorted(outputs.items()))
    outputs["SHA256SUMS"] = sums.encode("ascii")
    destination.mkdir(parents=True, exist_ok=False)
    for name, data in outputs.items():
        with (destination / name).open("xb") as handle:
            handle.write(data)
    return destination, manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--experiment", required=True, help="Committed experiment JSON")
    parser.add_argument("--output", required=True, help="New directory under artifacts/")
    args = parser.parse_args()
    try:
        destination, manifest = prepare(Path(__file__).resolve().parents[1],
                                        args.experiment, args.output)
    except (HandoffError, OSError) as error:
        print(f"Handoff rejected: {error}", file=sys.stderr)
        return 1
    print(f"Prepared {destination} at commit {manifest['source']['commit']}")
    print(f"{manifest['request_readiness']}; no commands executed or hardware approval granted")
    return 0


if __name__ == "__main__":
    sys.exit(main())
