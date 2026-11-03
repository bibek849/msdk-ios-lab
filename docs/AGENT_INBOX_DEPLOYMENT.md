# Deploy the one-contributor event inbox

The pilot targets **`bibek849`** and the public **`bibek849/msdk-ios-lab`** repository. A GitHub App sends signed notifications to a Cloudflare Worker; D1 retains them until the contributor explicitly acknowledges receipt. The [Python client](../tools/agent_inbox.py) supplies the same interface to Claude Code and other agents.

This is a notification service. It does not run submitted code, call an AI provider, write to GitHub, merge changes or operate hardware. Follow the [Claude Code pilot](CLAUDE_CODE_PILOT.md) for the contributor's observation loop and live acceptance run. Deployment and App registration are separate from implementation; consult [TEST_RESULTS.md](TEST_RESULTS.md) for what has actually been exercised. Do not treat the commands below as evidence that a service is active.

**Verified setup checkpoint, 2026-11-02:** the GitHub App `msdk-ios-lab-inbox-bibek849` is registered as App ID `5588168`, with installation `178014955` restricted to `bibek849/msdk-ios-lab`. Its Issues, Pull requests and Metadata permissions are read-only, with the six event families below. The new pilot D1 database has had its remote migration applied successfully. The Worker deployment and live GitHub delivery are not yet qualified at this checkpoint; actual Claude scheduling/receipt and account entitlement remain pending. Use the test ledger for later results rather than inferring readiness from the registration.

## Free hosting and implementation choice

Use **Cloudflare Workers Free + D1**, with the generated `workers.dev` HTTPS hostname. No purchased domain, paid queue, R2 bucket or paid plan is required for this pilot. Verify the account is on Workers Free before creating resources; do not upgrade billing or change existing services as part of these steps. Cloudflare advertises free Workers signup without a credit card. [Workers product page](https://www.cloudflare.com/products/workers/)

Current allowances checked **2026-11-02**: Workers has 100,000 requests/day and 10 ms CPU per invocation. D1 includes 5 million rows read/day, 100,000 rows written/day and 5 GB/account, with a 500 MB limit per free database. These quotas are shared with other work in the account. Quota exhaustion causes request/query failures on Free; it is not a guarantee of uninterrupted delivery. Paid-plan overages have separate billing. [Workers limits](https://developers.cloudflare.com/workers/platform/limits/), [D1 pricing](https://developers.cloudflare.com/d1/platform/pricing/), [D1 limits](https://developers.cloudflare.com/d1/platform/limits/)

One five-minute polling client makes about 288 inbox requests/day before extra pages or acknowledgments. This is a sizing example, not a measurement. Keep requests and SQL queries bounded and indexed; record actual Cloudflare CPU and database usage during the pilot. The hosting target is no additional charge within Workers Free, not an unlimited-service promise. The contributor's Claude entitlement and usage allowance must be checked separately; free event hosting does not pay for model execution.

The collector uses TypeScript because it runs in the Workers runtime; the client keeps the project's Python tooling. This adds no runtime or dependency to the Swift/iOS library. The [architecture decision](decisions/0001-agent-inbox.md) records the scope and tradeoffs.

## Local preparation

Use a supported Node.js release satisfying the package's engine requirement, Python 3.10+, and the existing GitHub CLI login. Wrangler is a project dependency with its version and transitive dependencies committed in the lockfile. Cloudflare supports Current, Active and Maintenance Node.js releases; check the current OS requirements if local `workerd` cannot start. [Wrangler installation](https://developers.cloudflare.com/workers/wrangler/install-and-update/)

From the repository root:

```sh
cd services/agent-inbox
npm ci
npm run check
npm test
npm run build
npm run db:local
```

`build` is a deployment dry run, not a cloud deployment. `db:local` applies the migration only to local D1. The tests use synthetic credentials/events and isolated local storage. Use `npm run dev` for local HTTP checks after creating a private `.dev.vars` with test-only secrets and a local configuration containing a nonzero synthetic installation ID and `PILOT_ENABLED="true"`. Keep the checked-in defaults disabled. Production credentials do not belong in local fixtures.

Local bindings and state are separate from production. Preserve explicit `--local` for local migrations, and keep `.wrangler/`, `.dev.vars`, credentials and exported databases out of Git. [Local development](https://developers.cloudflare.com/workers/local-development/), [D1 local state](https://developers.cloudflare.com/d1/best-practices/local-development/)

## Create only the pilot resources

Run the following from `services/agent-inbox`. Authenticate into the intended Cloudflare account and confirm its plan in the dashboard:

```sh
npx wrangler login
npx wrangler whoami
npx wrangler d1 create msdk-ios-lab-inbox-pilot
```

The final command returns the **new** database ID. If this pilot's database was already created, verify its recorded identity and reuse that exact pilot resource; do not create another or select an unrelated database with a similar name. The Worker name is `msdk-ios-lab-inbox`; the D1 binding is `DB`. If either name already exists without a matching pilot record, inspect ownership and stop before overwriting it. Do not reuse another project's database, change DNS, or migrate an existing resource.

Copy the disabled example to a local deployment file, which is ignored by Git:

```sh
cp wrangler.jsonc wrangler.pilot.jsonc
```

Do this only when `wrangler.pilot.jsonc` does not already exist; otherwise review and preserve the existing pilot configuration. Put the verified new database ID in `wrangler.pilot.jsonc` at `d1_databases[0].database_id`, replacing the zero placeholder. All remote commands below explicitly select this deployment file. Keep checked-in `wrangler.jsonc` disabled and free of account-specific deployment changes.

Keep these starting variables:

| Variable | Pilot value / purpose |
|---|---|
| `REPOSITORY` | `bibek849/msdk-ios-lab` |
| `REPOSITORY_ID` | `1443581816`; numeric repository identity must match |
| `CONTRIBUTOR_LOGIN` | `bibek849` |
| `CONTRIBUTOR_ID` | `77296559`; numeric recipient identity must match |
| `INSTALLATION_ID` | `0` until the actual GitHub App installation is known |
| `PILOT_ENABLED` | `false` until configuration and registration are complete |
| `TRACKED_ISSUES` / `TRACKED_PRS` | Empty, or comma-separated numeric IDs of explicitly opted-in items |

The table describes the disabled template, not a request to reset an installed pilot. For the registered installation above, the private `wrangler.pilot.jsonc` uses `INSTALLATION_ID="178014955"` while the committed example remains `0`/disabled. The configuration checks installation, repository and recipient identity rather than trusting display text. Existing assignments do not generate retrospective events: explicitly track the pilot issue/PR if they predate installation, then reconcile their current state. Up to 100 explicit IDs per configuration list are accepted. Do not repurpose one recipient's credential for a different contributor.

Review the migration before applying it. After verifying that `wrangler.pilot.jsonc` points to the newly created pilot database:

```sh
npx wrangler d1 migrations apply msdk-ios-lab-inbox-pilot --remote --config wrangler.pilot.jsonc
npx wrangler deploy --config wrangler.pilot.jsonc
```

This first deployment is deliberately disabled. Record the returned HTTPS Worker URL privately for setup; `/health` is public, while the webhook and inbox return 503 when disabled or incompletely configured. A healthy HTTP process is not proof that GitHub delivery works.

## Provision two distinct secrets

Use [the pilot initializer](../tools/init_inbox_pilot.py) to generate an independent webhook secret and contributor token, the server-side token digest, client configuration and a GitHub App registration URL. It creates a **new** directory with mode 700 and files with mode 600, refuses an existing output directory, and prints no credential values. It performs no deployment, network call, GitHub registration or installation.

The parent directory must already exist and be owner-controlled. Replace `/private/path/msdk-inbox` with a new location outside the checkout and replace the URL with the intended pilot HTTPS origin. Run from `services/agent-inbox`:

```sh
python3 ../../tools/init_inbox_pilot.py \
  --output /private/path/msdk-inbox \
  --url https://YOUR-WORKER.YOUR-SUBDOMAIN.workers.dev

npx wrangler secret bulk /private/path/msdk-inbox/worker-secrets.json --config wrangler.pilot.jsonc
```

The generated files are `webhook-secret`, `inbox-token`, `worker-secrets.json`, `client.json` and `github-app-registration-url.txt`. Treat the directory as private; do not commit, upload or print its credential-bearing files. Do not put credentials in command arguments, prompts, screenshots or issue bodies. If initialization fails after creating the directory, inspect it locally; do not reuse a partially provisioned token set or overwrite it blindly.

The bulk upload provisions the raw `WEBHOOK_SECRET` and only the inbox token's SHA-256 digest as `INBOX_TOKEN_SHA256`. The raw inbox token stays on the contributor's machine. The webhook secret must also be entered in GitHub's App settings. The collector requires **no GitHub App private key, installation token, OAuth client secret, Claude credential or OpenAI API key** because it makes no outbound GitHub or AI calls. GitHub may offer or prompt for App private-key generation during setup; this collector does not need that key.

## Register and install the GitHub App

Open the registration URL saved in `github-app-registration-url.txt` while signed into the owner's GitHub account. It pre-fills the name, homepage, webhook URL, read-only permissions and six event families below; it does not submit the form. The webhook secret cannot be supplied through the registration URL and must be entered from the private `webhook-secret` file in the settings UI. Review every permission before creating the App, keep SSL verification enabled, and adjust the name if that name is unavailable. [GitHub's registration URL parameters](https://docs.github.com/en/apps/sharing-github-apps/registering-a-github-app-using-url-parameters)

Alternatively, open **Settings → Developer settings → GitHub Apps → New GitHub App** manually, use this repository as the homepage and `https://YOUR-WORKER.YOUR-SUBDOMAIN.workers.dev/github/webhook` as the webhook URL, then configure the same settings.

Grant only these repository permissions:

- **Issues: read-only**.
- **Pull requests: read-only**.
- **Metadata: read-only**, as required by GitHub.

Subscribe to six event families: **Issues**, **Issue comment**, **Pull request**, **Pull request review**, **Pull request review comment**, and **Pull request review thread**. No Contents, Actions or Checks access is required for this pilot; it does not consume CI events yet. No write or administration permission is needed. Choose installation only on the owner's account, then install it on **only `msdk-ios-lab`**. Do not authorize another repository. [GitHub App registration](https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app), [App webhook permissions](https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/using-webhooks-with-github-apps)

Record the installation ID from the installed App's settings URL or the authenticated installation record. Put that positive numeric ID in `INSTALLATION_ID`. Registration/installation pings may fail while the pilot is disabled; they are setup observations, not a passed event test.

After checking the new database binding, both secrets, exact installation ID and the explicit pilot task scope, set `PILOT_ENABLED` to `true` in the service's deployment configuration and redeploy:

```sh
npx wrangler deploy --config wrangler.pilot.jsonc
```

Use GitHub App **Advanced → Recent Deliveries** to inspect and, where needed, redeliver a setup ping. Then run the assignment, review and synthetic feedback sequence in the [pilot acceptance guide](CLAUDE_CODE_PILOT.md). The GitHub App and the contributor inbox credential serve separate roles; contributors do not need to install this App on their own accounts to read an authorized inbox.

## Client and API behavior

The initializer's `client.json` already contains `url`, `token_file` and `contributor` with the expected private token path. Verify the deployed HTTPS origin, then run this from the repository root before enabling Claude's observation loop:

```sh
python3 tools/agent_inbox.py --config /private/path/msdk-inbox/client.json fetch --limit 20
```

If no initializer was used, create the private configuration as documented in [CLAUDE_CODE_PILOT.md](CLAUDE_CODE_PILOT.md). Only use the raw inbox token in its private token file; the server-side digest cannot authenticate the client.

| Endpoint | Authentication and behavior |
|---|---|
| `GET /health` | Public process health only; it cannot establish delivery or task readiness |
| `POST /github/webhook` | Raw-body GitHub HMAC-SHA256, installation/repository checks and bounded payload; routed events persist before accepted receipt. Signed pings store nothing; unsupported or unrelated items may be ignored with 202 |
| `GET /v1/inbox?after=0&limit=20` | Contributor bearer token; pending events only, maximum page size 50 and 256 KiB response; no acknowledgment on read |
| `POST /v1/ack` | Same bearer token; JSON `{"ids":[101,102]}` acknowledges only those existing recipient IDs, at most 50 per request |

Acknowledgment is idempotent receipt bookkeeping. It neither completes the GitHub task nor grants execution/hardware authority. Events are explicitly untrusted data. The contributor must read current GitHub assignment, labels, scope and PR head through their own GitHub connection before proposing work; an old event cannot override current state.

Hardware feedback uses the ordinary issue/PR comment path. A comment containing `<!-- msdk-hardware-feedback:v1 -->` is classified as `hardware_feedback` only when both its author and event sender match the fixed initial maintainer ID, `77296559`. This class does not certify the body, a hardware outcome or publication permission. Only publication-approved material belongs in public comments; mark synthetic delivery tests **SYNTHETIC — hardware NOT RUN**.

## Recovery, retention and stopping

- A retried delivery with the same ID and body/event identity is deduplicated, including after acknowledgment. A reused ID with different content conflicts; investigate rather than changing its identity to bypass the check.
- D1 commits accepted records before the receiver reports success. Pending events survive a Worker or client restart. Delivery is not exactly once: clients can summarize twice if they crash after display and before acknowledgment, and webhook arrival order is not authoritative task order.
- The pilot caps the inbox at **1,000 pending events**, **10,000 retained events** and **10,000 tracked items**. Payloads are capped at 256 KiB, titles at 500 characters and stored body excerpts at 4,000 characters. Full source context remains on GitHub. Capacity/database failures return an error instead of silently dropping an accepted new event.
- GitHub does not automatically retry failed webhook deliveries. Monitor App Recent Deliveries, investigate errors, restore capacity/configuration, and explicitly redeliver failed deliveries. The receiver returns 503 with `Retry-After: 60` for unavailable operation; that header does not make GitHub retry. [GitHub failure handling](https://docs.github.com/en/webhooks/using-webhooks/handling-failed-webhook-deliveries)
- Acknowledging events frees pending capacity but retains their rows for deduplication. There is **no automated retention purge or scheduled GitHub reconciliation** in this pilot. Before reaching the retained cap, export/back up the pilot database and review a retention extension or deliberate archival procedure. Deleting event rows also deletes their deduplication record, so replay protection would end for those IDs. Do not silently purge unacknowledged work or rely on indefinite capacity.
- After an outage or missing delivery, use GitHub as the authority: reconcile the tracked issue/PR's current assignment, closure/blocked state, review comments and revision. This manual check is required because the collector stores notifications and does not reconstruct missed events. Record any gap in the pilot report.
- To pause receipt and consumption, set `PILOT_ENABLED=false` in `wrangler.pilot.jsonc` and redeploy with that same `--config`, disable the App webhook if appropriate, and cancel the contributor's loop. Changing state in an old webhook payload does not stop a locally authorized coding session; communicate cancellation through the current task and contributor controls.
- To revoke an inbox credential, replace `INBOX_TOKEN_SHA256` and distribute a new private token only to the opted-in recipient. Rotate the webhook secret in both Cloudflare and GitHub as one controlled change; reconcile the delivery gap. Export or delete only this project's new resources when intentionally retiring the pilot.

Record the exact source revision, Worker deployment/version, database migration, App/installation identity, tested issue/PR and observed results without credential values. Keep local integration results, live GitHub delivery and actual Claude scheduling as separate evidence.
