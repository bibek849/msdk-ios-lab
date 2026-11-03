# Invite a contributor and close the hardware feedback loop

Contributors follow [one quickstart](CONTRIBUTOR_QUICKSTART.md). The maintainer supplies an invitation, assigns one issue, reviews the PR and returns feedback. No maintainer Claude/Codex subscription is required. The project pays for no contributor AI calls.

## Admit one person

Review their [contributor request](https://github.com/bibek849/msdk-ios-lab/issues/new?template=contributor.yml), choose an original software task at an open roadmap gate, and have them comment on its issue before assigning it. Confirm their actual GitHub numeric identity using their handle:

```sh
gh api users/CONTRIBUTOR --jq '{login,id}'
```

Replace placeholders before running commands. Record the canonical login and numeric ID in the private provisioning record. Agree on a private credential-delivery channel; do not put the token in the public request. No contributor is given maintainer GitHub, Cloudflare, signing or hardware credentials.

## Prepare an isolated inbox

For this small first cohort, reuse the tested single-recipient receiver with **one new Worker, D1 database and private GitHub App per contributor**. Each App delivers to that person's Worker, installed only on this repository. This avoids modifying the existing `bibek849` inbox or introducing untested multi-recipient routing. It is a bounded pilot design, not a self-service multi-tenant platform.

The [D1 Free account limit](https://developers.cloudflare.com/d1/platform/limits/) is ten databases, shared with other projects; check current usage before creating any. The existing owner pilot consumes one. Stop onboarding at available Free capacity rather than upgrading, reusing another person's inbox or promising unlimited enrollment. A shared App/router is a separate future change with migration and isolation tests.

Choose unused resource names and a new private bundle directory whose parent already exists. From a reviewed upstream checkout:

```sh
python3 tools/create_contributor_invite.py \
  --login CONTRIBUTOR --github-id NUMERIC_ID \
  --url https://NEW-WORKER.ACCOUNT.workers.dev \
  --worker-name NEW-WORKER --database-name NEW-DATABASE \
  --output /PRIVATE/NEW-BUNDLE
```

This command is **local preparation only**. It creates:

| File | Recipient and purpose |
|---|---|
| `invite.json` | Contributor configuration, containing no secret |
| `inbox-token` | Contributor's private fetch/ack credential; send separately |
| `webhook-secret`, `worker-secrets.json` | Maintainer only; a new signing secret and inbox-token hash |
| `wrangler.contributor.jsonc` | Maintainer only; disabled new deployment with absolute source paths |
| `client.json` | Maintainer's private test configuration |
| `github-app-registration-url.txt` | Prefilled new private App registration; secret entered separately |

The preparer refuses overwrite and the known owner-pilot resource identities. It cannot prove an arbitrary new name is unused remotely: verify account, Workers Free plan, resource ownership and available quota before publication. It never deploys, changes billing or contacts the contributor. Run it from the stable checkout you will deploy; keep that checkout until provisioning completes.

## Activate only the new resources

Use the existing [deployment guide](AGENT_INBOX_DEPLOYMENT.md) for authentication, signatures and recovery, substituting **only the new bundle's** `wrangler.contributor.jsonc`, names and identities. Do not use `wrangler.pilot.jsonc` or the owner pilot's secrets for a new person.

1. Verify the intended Cloudflare account and Workers Free plan. Before creating resources, pin `account_id` in the new config to that verified account. Create `NEW-DATABASE` using this config, record its returned UUID in the same config, and apply the existing migration only to this new database.
2. Deploy the new Worker with `PILOT_ENABLED=false`; install secrets from the new bundle. All commands below select the new config explicitly.
3. Open the generated registration URL. Verify Issues/Pull requests/Metadata read-only permissions, the six event families and HTTPS verification. Enter this bundle's signing secret privately. Install only on `bibek849/msdk-ios-lab` and record its own installation ID.
4. Set that installation ID and `PILOT_ENABLED=true` in the new config; deploy again. Verify an authenticated fetch with the new bundle's `client.json`.
5. Share only `invite.json` and the separate inbox token through the agreed channel. The contributor runs the quickstart, confirms `doctor` and asks their agent for `inbox_status`.

With the pinned Wrangler installed in `services/agent-inbox`:

```sh
node_modules/.bin/wrangler d1 create NEW-DATABASE --config /PRIVATE/NEW-BUNDLE/wrangler.contributor.jsonc
node_modules/.bin/wrangler d1 migrations apply NEW-DATABASE --remote --config /PRIVATE/NEW-BUNDLE/wrangler.contributor.jsonc
node_modules/.bin/wrangler deploy --config /PRIVATE/NEW-BUNDLE/wrangler.contributor.jsonc
node_modules/.bin/wrangler secret bulk /PRIVATE/NEW-BUNDLE/worker-secrets.json --config /PRIVATE/NEW-BUNDLE/wrangler.contributor.jsonc
# After App installation and reviewed config update:
node_modules/.bin/wrangler deploy --config /PRIVATE/NEW-BUNDLE/wrangler.contributor.jsonc
```

There is one human App registration/installation step per person. No OAuth callback service, additional billing product or AI-hosted worker is introduced. Future simplification must retain per-person revocation and isolate existing inboxes.

## Assign, review, test, respond

Assign the contributor's human account and set one current status label. Include a completed [task brief](templates/AGENT_TASK.md), allowed files, acceptance checks and one question. Assign **after activation** so the assignment produces an event. If assigned earlier, record its ID in that inbox's `TRACKED_ISSUES`, redeploy and re-read current GitHub state; the service does not backfill history.

The contributor authorizes their own agent for that scope. The agent works in their fork and prepares a reviewed PR. No upstream write access is needed. The inbox routes the contributor's authored PR automatically; feedback belongs on that PR or the tracked issue. The connector supplies tools, not an always-on scheduler or an automatic coding grant.

For hardware-dependent changes, require a clean committed experiment and the existing [handoff](HANDOFF_FORMAT.md). Review the code and CI before adding the exact SHA to the local hardware queue. Build/sign and operate the hardware locally. Do not run unreviewed contribution commands from an inbox message.

Copy [TEST_FEEDBACK.md](templates/TEST_FEEDBACK.md), preserve `<!-- msdk-hardware-feedback:v1 -->`, and complete the tested SHA, artifact/run identity, outcome and one next action. Publish only material cleared for sharing. Post the reviewed file as `bibek849` on the linked issue/PR:

```sh
gh issue comment ISSUE_NUMBER --repo bibek849/msdk-ios-lab --body-file /PRIVATE/REVIEWED-FEEDBACK.md
# Or, for the contributor's PR:
gh pr comment PR_NUMBER --repo bibek849/msdk-ios-lab --body-file /PRIVATE/REVIEWED-FEEDBACK.md
```

The marker is recognized only when the webhook's author and sender match the configured maintainer identity. It identifies feedback, not a hardware pass. Use PASS, FAIL, BLOCKED, INCOMPLETE or NOT RUN honestly; synthetic delivery tests must explicitly say SYNTHETIC and hardware NOT RUN. A new PR revision needs a new handoff before retesting.

## Stop and revoke

Closing, blocking or unassigning a task changes work authority but does not revoke its notification history. For withdrawal, set **that contributor's** `PILOT_ENABLED=false` and redeploy its explicit config; both fetch/ack and webhook ingestion then fail closed. Suspend its own App installation if it is no longer needed. Preserve the existing owner pilot. Rotate a compromised token privately before re-enabling; notify the contributor through the agreed channel. Cancelling a local agent schedule alone does not revoke the server credential.

Use `doctor` for connection failures and App Recent Deliveries for missed webhooks. GitHub does not automatically retry failed webhook deliveries. The existing [recovery guide](AGENT_INBOX_DEPLOYMENT.md) covers controlled redelivery, queue caps and retained records. Record each new contributor's delivery/agent qualification separately; the owner's CLI pilot does not establish every contributor's agent runtime.
