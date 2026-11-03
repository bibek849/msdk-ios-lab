# ADR 0001: a small GitHub event inbox for one contributor

- Date: 2026-11-02
- Status: accepted for the first implementation; live qualification is recorded separately
- Scope: repository collaboration infrastructure, outside the iOS runtime
- Pilot: `bibek849` on `bibek849/msdk-ios-lab`

At the 2026-11-02 live checkpoint, the App is installed only on the pilot repository, the new D1 migration has passed, and the enabled Worker has delivered real GitHub assignment, comment, review and inline-review events to the authenticated Python client. Maintainer-authored synthetic hardware feedback was classified as feedback without establishing a physical result. Live exact acknowledgment and GitHub redelivery checks also passed. Actual Claude receipt is **NOT RUN** and is an optional contributor qualification, not a requirement for the maintainer or the CLI pilot. See [the deployment checkpoint](../AGENT_INBOX_DEPLOYMENT.md) and [test ledger](../TEST_RESULTS.md). This evidence does not change the notification-only scope of the decision.

## Problem

Contributors without the drone should receive a scoped assignment, code review and the owner's published hardware feedback through their own agent. GitHub repository access alone supplies neither reliable notification storage nor an always-running agent. A receiver must not convert arbitrary comment text into executable instructions or require the owner's AI credentials.

The first experiment needs one recipient and a small event set. Building a general agent scheduler, shared subscription service, real-time broker or multi-tenant platform would add work before the single-contributor loop is demonstrated.

## Decision

Use a **TypeScript Cloudflare Worker** with **D1** for signed GitHub App webhooks and a durable, authenticated notification inbox. Use a **Python standard-library client** for explicit fetch and acknowledgment. The contributor runs the client through their existing agent environment; the first Claude Code setup uses an explicitly scoped observation-only `/loop`.

The App subscribes to issue lifecycle/assignments, ordinary issue/PR comments, PR lifecycle, reviews, inline comments and review-thread changes. Permissions are read-only Issues, Pull requests and required Metadata for this repository. This phase does not ingest CI/Actions events. It does not require an App private key or outbound API token because the collector neither queries nor mutates GitHub.

Bind the pilot to the numeric repository, installation and contributor IDs, with login/name checks as applicable. Retain explicitly tracked item identities so cancellation and later feedback do not disappear merely because a task has been unassigned. Tracking means interest in notifications; it never authorizes work.

Keep two separate credentials: GitHub's webhook signing secret and a recipient bearer token whose SHA-256 digest is stored server-side. A local Python initializer creates private files and a reviewable GitHub registration URL without network access or deployment. Keep all AI provider credentials on the contributor's side. A valid webhook signature establishes origin, not authority to execute the payload. Every stored event is marked untrusted; URLs are constrained to the repository item.

D1 is the receipt store, not an in-memory queue. Persist before returning success. Unique delivery IDs and payload identity checks handle retries. Fetches do not acknowledge; exact explicit acknowledgments do. Bounded pages, excerpts and SQL capacity guards prevent this small pilot from growing without limit. Retained acknowledgments support retry deduplication; there is no automatic retention deletion in this version.

## Language and reuse rationale

The [engineering standard](../ENGINEERING_STANDARD.md) chooses Swift for necessary new iOS work and Python for tooling. TypeScript is justified here by the selected Workers runtime, its native Web APIs and D1 binding: it keeps deployment small, avoids a container/server process, and uses the host's Web Crypto signature verification. The Worker is deployment tooling, not an iOS transport, parser, decoder or command component. No Node/TypeScript package enters the Swift product.

Use platform HTTP, cryptography and managed SQL facilities rather than introducing a web framework, custom crypto or an external queue. Keep the existing Python ecosystem for the client. Pin the service's build/test tools and transitive versions in its package files and lockfile. No language is described as intrinsically faster; actual CPU and query usage must be observed against the free-plan limits.

## Alternatives considered

| Alternative | Decision |
|---|---|
| GitHub subscriptions and scheduled CLI snapshots alone | Still useful for fallback and reconciliation, but they do not provide this requested receiver and persistent delivery inbox |
| A Python server and SQLite on a VPS/container | Straightforward, but a reliable free always-available host with persistent disk would require a different operational setup; avoid managing a server for this pilot |
| Cloudflare KV | Do not use an eventually consistent key/value listing as this pilot's ordered, transactional receipt store; D1 fits exact IDs and acknowledgments |
| Separate queue plus worker/agent execution service | Defer until event volume or processing requires it; this receiver only validates, stores and serves bounded notifications |
| MCP/Claude Channels push adapter | A possible later client; first verify the provider-neutral CLI protocol and actual account workflow |
| Direct GitHub event to an AI API invocation | Defer; would introduce execution authority, credentials, provider billing and prompt-injection exposure into the collector |

## Consequences and limits

Cloudflare Free is sufficient in principle for a small pilot: no domain purchase or paid upgrade is selected. Shared account quotas and the 10 ms Worker CPU limit still apply; an account already on a paid plan has different billing. Inspect actual account settings and measure the deployed service. Keep deploy-specific database and installation IDs in ignored `wrangler.pilot.jsonc`, with the checked-in example disabled. [Deployment guide and primary pricing references](../AGENT_INBOX_DEPLOYMENT.md)

The initial caps are 1,000 pending events, 10,000 retained events and 10,000 tracked items. Full queues and database failures reject new work visibly. GitHub does not automatically redeliver failures, so the maintainer must inspect failures, redeliver after recovery and reconcile current GitHub state. Scheduled reconciliation, automatic retention, multi-contributor administration and background coding workers are not implemented by this decision.

No exactly-once or delivery-order guarantee is claimed. Receipt acknowledgment cannot prove that a model understood a message, and an agent crash before acknowledgment may repeat a summary. A contributor must consult current assignment, stage, scope and PR head before work. The App does not interpret old payloads as current authorization or accept private raw hardware evidence.

The owner remains responsible for source review, local signing, exact-artifact hardware tests, publication decisions and merges. Free event hosting does not make an AI subscription unlimited or authorize its use by a hosted service.

## Verification

Test raw-body signatures, wrong installation/repository/recipient, payload and queue bounds, duplicate/reordered delivery, exact/idempotent acknowledgment, restart persistence, disabled configuration and untrusted text handling. Test the Python client's schema/URL/token handling independently. Then perform the one-contributor live assignment, review, synthetic hardware-feedback, acknowledgment and cancellation sequence.

The [test ledger](../TEST_RESULTS.md) distinguishes implemented behavior, local synthetic checks, deployed GitHub delivery and a real Claude Code session. This ADR records design intent and does not itself establish that any of those checks passed.
