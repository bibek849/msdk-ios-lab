# A reproducible test request

A pull request shares code. A handoff records the exact revision and one experiment the maintainer can review and reproduce. Contributors need Python 3.10+ and Git for the metadata tool; the experiment's own build requirements are separate.

## Prepare a handoff

Copy [the synthetic example](../experiments/example-synthetic.json), edit it for one question, and commit it with the code it describes. Run the appropriate software checks first and include their actual results in the PR. Then, from a clean checkout:

```sh
python3 tools/prepare_handoff.py \
  --experiment experiments/example-synthetic.json \
  --output artifacts/handoff
```

The tool writes three files:

| File | Purpose |
|---|---|
| `manifest.json` | Full source commit/tree identity, experiment blob and SHA-256, missing metadata and review state |
| `experiment.json` | Exact experiment bytes read from that Git commit |
| `SHA256SUMS` | SHA-256 for the two JSON files |

Attach these small files to the PR after reviewing their text. Include a permalink to the source commit and the relevant CI run. Do not commit generated handoffs: `artifacts/` is ignored. A new commit needs a new handoff directory. The tool refuses to overwrite an earlier handoff.

No build, test, shell instruction, device operation or network request is executed by this tool. It does not collect source archives, binaries, raw logs or untracked files. It runs only local Git queries and exports the committed experiment's text. Review that text for private data before committing or attaching it.

## Experiment schema v1

Every field below is required; unknown fields are rejected to keep the handoff small.

| Field | Meaning |
|---|---|
| `schema_version` | Integer `1` |
| `id` | Stable uppercase experiment identifier, 3–64 letters/digits/underscores/hyphens, starting with a letter |
| `kind` | `software_only` or `read_only_hardware`; executable command/flight requests are outside this format |
| `stage` | Roadmap `S0`–`S6`; read-only hardware requests are restricted to `S0`, `S2`, `S3`, `S4` |
| `question` | One falsifiable question |
| `build_commands` | 1–20 descriptive command strings, never automatically executed |
| `procedure` | 1–20 ordered instructions for the human reviewer/operator |
| `expected_outcomes` | Observable pass/fail criteria, including distinctions the result cannot establish |
| `stop_conditions` | When the operator must end the proposed experiment |
| `prerequisites` | Up to 20 records with `requirement`, `status` (`pending` or `documented`) and `evidence` (null for pending; text reference for documented) |
| `hardware` | Null for software-only work; the full tuple below for hardware work |
| `limits` | `repetitions` (integer 1–10) and `max_seconds_per_run` (integer 1–300); observation/runtime bounds after building |

The hardware tuple contains `phone_model`, `phone_os_build`, `controller`, `controller_firmware`, `aircraft`, `aircraft_firmware` and `cable`. Values are nonempty text or null when unknown. A hardware request must list its prerequisites. Keep serial numbers, accounts, signing credentials and exact locations out of the tuple.

Pending prerequisites or unknown hardware details produce `DRAFT`; complete metadata produces `READY_FOR_REVIEW`. A contributor marking a prerequisite `documented` is a claim for the maintainer to check, not approval. Every manifest explicitly records review and CI as `NOT_VERIFIED`, hardware approval as `NOT_GRANTED`, and test results as `NOT_RUN_BY_THIS_TOOL`.

The tool checks JSON structure, size, revision identity and output location. It cannot determine whether a procedure is safe, correct, within permissions or genuinely read-only. Source review and the [hardware stage gates](HARDWARE_TESTING.md) remain necessary even when a request passes validation. A checksum detects changed bytes; it is not a signature or evidence of a trusted author.

## Revision and evidence rules

The experiment must be a regular file tracked at HEAD. All tracked working-tree/index changes must be committed or restored first. Untracked files are excluded from export and are not a substitute for committed code. Output must be a new directory beneath this checkout's `artifacts/`; symlinks cannot redirect output outside it.

The maintainer checks out the full commit in a separate review checkout, examines build instructions/dependencies, and builds/signs locally when needed. The handoff carries no authority to run its commands. Record the resulting artifact hash, test conditions and observations using [the hardware-run template](templates/HARDWARE_RUN.md). SDK or private hardware evidence follows the repository's existing publication review; the contributor may receive an original synthetic reproduction where raw evidence cannot be shared.

Test the handoff tool independently of Swift or hardware:

```sh
python3 -m unittest discover -s tools/tests -v
```
