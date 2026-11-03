/** A notification transport only. It cannot execute code or call GitHub APIs. */
export interface Env {
  DB: D1Database;
  REPOSITORY: string;
  REPOSITORY_ID: string;
  CONTRIBUTOR_LOGIN: string;
  CONTRIBUTOR_ID: string;
  INSTALLATION_ID: string;
  PILOT_ENABLED: string;
  TRACKED_ISSUES?: string;
  TRACKED_PRS?: string;
  WEBHOOK_SECRET: string;
  INBOX_TOKEN_SHA256: string;
}

type ObjectValue = Record<string, unknown>;
type ItemType = 'issue' | 'pull_request';
interface EventDocument {
  delivery_id: string;
  event: string;
  action: string;
  kind: string;
  item_type: ItemType;
  number: number;
  url: string;
  actor: string | null;
  actor_id: number | null;
  title: string;
  body_excerpt: string;
  head_sha: string | null;
  occurred_at: string | null;
  received_at: string;
  untrusted: true;
}
interface Config {
  repository: string;
  repositoryId: number;
  recipientId: number;
  login: string;
  installationId: number;
  issues: Set<number>;
  pulls: Set<number>;
}
class HTTPError extends Error {
  constructor(readonly status: number, readonly code: string) { super(code); }
}
const encoder = new TextEncoder();
const MAX_WEBHOOK_BYTES = 256 * 1024;
const SUPPORTED = new Set([
  'issues', 'issue_comment', 'pull_request', 'pull_request_review',
  'pull_request_review_comment', 'pull_request_review_thread',
]);
const HARDWARE_MARKER = '<!-- msdk-hardware-feedback:v1 -->';
const MAINTAINER_ID = 77296559;

function object(value: unknown): ObjectValue {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? value as ObjectValue : {};
}
function positive(value: unknown): number | null {
  return typeof value === 'number' && Number.isSafeInteger(value) && value > 0 ? value : null;
}
function configuredId(value: string | undefined): number {
  const id = value && /^[1-9][0-9]*$/.test(value) ? positive(Number(value)) : null;
  if (id === null) throw new HTTPError(503, 'configuration_required');
  return id;
}
function tracked(value: string | undefined): Set<number> {
  if (!value) return new Set();
  const parts = value.split(',');
  if (parts.length > 100) throw new HTTPError(503, 'configuration_required');
  return new Set(parts.map(part => configuredId(part.trim())));
}
function configuration(env: Env): Config {
  if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(env.REPOSITORY ?? '') ||
      !/^[A-Za-z0-9-]{1,39}$/.test(env.CONTRIBUTOR_LOGIN ?? '') ||
      typeof env.WEBHOOK_SECRET !== 'string' || env.WEBHOOK_SECRET.length < 32 ||
      !/^[a-f0-9]{64}$/.test(env.INBOX_TOKEN_SHA256 ?? '')) {
    throw new HTTPError(503, 'configuration_required');
  }
  return {
    repository: env.REPOSITORY, repositoryId: configuredId(env.REPOSITORY_ID),
    recipientId: configuredId(env.CONTRIBUTOR_ID), login: env.CONTRIBUTOR_LOGIN,
    installationId: configuredId(env.INSTALLATION_ID),
    issues: tracked(env.TRACKED_ISSUES), pulls: tracked(env.TRACKED_PRS),
  };
}
function json(value: unknown, status = 200): Response {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff',
      ...(status === 503 ? { 'Retry-After': '60' } : {}),
    },
  });
}
async function bytes(request: Request, maximum: number): Promise<Uint8Array> {
  const declared = request.headers.get('content-length');
  if (declared && (!/^[0-9]+$/.test(declared) || Number(declared) > maximum)) {
    throw new HTTPError(413, 'payload_too_large');
  }
  const reader = request.body?.getReader();
  if (!reader) return new Uint8Array();
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const chunk = await reader.read();
      if (chunk.done) break;
      size += chunk.value.byteLength;
      if (size > maximum) {
        await reader.cancel();
        throw new HTTPError(413, 'payload_too_large');
      }
      chunks.push(chunk.value);
    }
  } finally { reader.releaseLock(); }
  const result = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { result.set(chunk, offset); offset += chunk.byteLength; }
  return result;
}
function parsed(data: Uint8Array): ObjectValue {
  try {
    const value: unknown = JSON.parse(new TextDecoder('utf-8', { fatal: true, ignoreBOM: false }).decode(data));
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error();
    return value as ObjectValue;
  } catch { throw new HTTPError(400, 'invalid_json'); }
}
function hex(data: ArrayBuffer): string {
  return Array.from(new Uint8Array(data), byte => byte.toString(16).padStart(2, '0')).join('');
}
function fromHex(value: string): Uint8Array {
  return Uint8Array.from(value.match(/.{2}/g) ?? [], pair => parseInt(pair, 16));
}
async function signature(request: Request, body: Uint8Array, env: Env): Promise<void> {
  const supplied = request.headers.get('x-hub-signature-256') ?? '';
  if (!/^sha256=[a-f0-9]{64}$/.test(supplied)) throw new HTTPError(401, 'invalid_signature');
  const key = await crypto.subtle.importKey(
    'raw', encoder.encode(env.WEBHOOK_SECRET), { name: 'HMAC', hash: 'SHA-256' }, false, ['verify'],
  );
  if (!await crypto.subtle.verify('HMAC', key, fromHex(supplied.slice(7)), body)) {
    throw new HTTPError(401, 'invalid_signature');
  }
}
async function authorize(request: Request, env: Env): Promise<void> {
  const bearer = request.headers.get('authorization') ?? '';
  if (!/^Bearer [!-~]{32,512}$/.test(bearer)) throw new HTTPError(401, 'unauthorized');
  const digest = await crypto.subtle.digest('SHA-256', encoder.encode(bearer.slice(7)));
  if (!crypto.subtle.timingSafeEqual(digest, fromHex(env.INBOX_TOKEN_SHA256))) {
    throw new HTTPError(401, 'unauthorized');
  }
}
function text(value: unknown, maximum: number): string {
  return typeof value === 'string' ? value.slice(0, maximum) : '';
}
function timestamp(value: unknown): string | null {
  if (typeof value !== 'string' || value.length > 40 || !/^\d{4}-\d\d-\d\dT/.test(value)) return null;
  const date = new Date(value);
  return Number.isFinite(date.getTime()) ? date.toISOString() : null;
}
function includesUser(value: unknown, user: number): boolean {
  return Array.isArray(value) && value.some(person => object(person).id === user);
}

async function webhook(request: Request, env: Env, config: Config): Promise<Response> {
  if (!(request.headers.get('content-type') ?? '').toLowerCase().startsWith('application/json')) {
    throw new HTTPError(415, 'json_required');
  }
  const data = await bytes(request, MAX_WEBHOOK_BYTES);
  await signature(request, data, env);
  const event = request.headers.get('x-github-event') ?? '';
  const delivery = request.headers.get('x-github-delivery') ?? '';
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(delivery) || !/^[a-z_]{1,64}$/.test(event)) {
    throw new HTTPError(400, 'invalid_delivery_headers');
  }
  const payload = parsed(data);
  // A GitHub App ping may have no repository/installation. It stores nothing.
  if (event === 'ping') return json({ status: 'ping' });
  const repository = object(payload.repository);
  if (repository.id !== config.repositoryId || repository.full_name !== config.repository ||
      repository.private !== false || object(payload.installation).id !== config.installationId) {
    throw new HTTPError(403, 'scope_mismatch');
  }
  if (!SUPPORTED.has(event)) return json({ status: 'ignored', reason: 'unsupported_event' }, 202);
  if (typeof payload.action !== 'string' || !/^[a-z_]{1,40}$/.test(payload.action)) {
    throw new HTTPError(400, 'invalid_action');
  }
  const entity = object(event === 'issues' || event === 'issue_comment' ? payload.issue : payload.pull_request);
  const type: ItemType = event.startsWith('pull_request') || entity.pull_request ? 'pull_request' : 'issue';
  const number = positive(entity.number);
  if (!number) throw new HTTPError(400, 'invalid_item');
  const manuallyTracked = (type === 'issue' ? config.issues : config.pulls).has(number);
  const currentlyRelated = includesUser(entity.assignees, config.recipientId) ||
    object(payload.assignee).id === config.recipientId ||
    (type === 'pull_request' && (
      object(entity.user).id === config.recipientId ||
      object(payload.requested_reviewer).id === config.recipientId ||
      includesUser(entity.requested_reviewers, config.recipientId)
    ));
  const retained = await env.DB.prepare(
    'SELECT 1 FROM tracked_items WHERE recipient_id = ? AND item_type = ? AND number = ?',
  ).bind(config.recipientId, type, number).first();
  if (!manuallyTracked && !currentlyRelated && !retained) return json({ status: 'ignored', reason: 'untracked_item' }, 202);

  // Include the routing header in the digest to detect conflicting redelivery.
  const digestInput = new Uint8Array(encoder.encode(event + '\n').length + data.length);
  digestInput.set(encoder.encode(event + '\n'));
  digestInput.set(data, encoder.encode(event + '\n').length);
  const digest = hex(await crypto.subtle.digest('SHA-256', digestInput));
  const existing = await env.DB.prepare('SELECT id, payload_sha256, recipient_id FROM events WHERE delivery_id = ?')
    .bind(delivery).first<{ id: number; payload_sha256: string; recipient_id: number }>();
  if (existing) {
    if (existing.payload_sha256 !== digest || existing.recipient_id !== config.recipientId) {
      throw new HTTPError(409, 'delivery_conflict');
    }
    return json({ status: 'accepted', duplicate: true, id: existing.id });
  }

  const comment = object(payload.comment);
  const review = object(payload.review);
  const sender = object(payload.sender);
  const content = event === 'issue_comment' || event === 'pull_request_review_comment' ? comment :
    event === 'pull_request_review' ? review : entity;
  const rawBody = typeof content.body === 'string' ? content.body : '';
  let kind: string = event;
  if (event === 'issue_comment' && rawBody.includes(HARDWARE_MARKER) &&
      object(comment.user).id === MAINTAINER_ID && sender.id === MAINTAINER_ID) kind = 'hardware_feedback';
  let url = `https://github.com/${config.repository}/${type === 'issue' ? 'issues' : 'pull'}/${number}`;
  const commentId = positive(comment.id);
  const reviewId = positive(review.id);
  if (commentId) url += event === 'issue_comment' ? `#issuecomment-${commentId}` : `#discussion_r${commentId}`;
  else if (event === 'pull_request_review' && reviewId) url += `#pullrequestreview-${reviewId}`;
  const head = object(entity.head).sha;
  const now = new Date().toISOString();
  const document: EventDocument = {
    delivery_id: delivery, event, action: payload.action, kind, item_type: type, number, url,
    actor: typeof sender.login === 'string' && /^[A-Za-z0-9][A-Za-z0-9-]{0,38}(\[bot\])?$/.test(sender.login) ? sender.login : null,
    actor_id: positive(sender.id), title: text(entity.title, 500), body_excerpt: text(rawBody, 4000),
    head_sha: typeof head === 'string' && /^[a-f0-9]{40}$/.test(head) ? head : null,
    occurred_at: timestamp(content.updated_at) ?? timestamp(content.submitted_at) ?? timestamp(entity.updated_at),
    received_at: now, untrusted: true,
  };
  await env.DB.batch([
    env.DB.prepare(`INSERT INTO events
      (delivery_id, payload_sha256, recipient_id, item_type, number, document, received_at)
      VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT(delivery_id) DO NOTHING`)
      .bind(delivery, digest, config.recipientId, type, number, JSON.stringify(document), now),
    env.DB.prepare(`INSERT INTO tracked_items (recipient_id, item_type, number)
      SELECT ?, ?, ? WHERE EXISTS (SELECT 1 FROM events
        WHERE delivery_id = ? AND payload_sha256 = ? AND recipient_id = ?)
      ON CONFLICT(recipient_id, item_type, number) DO NOTHING`)
      .bind(config.recipientId, type, number, delivery, digest, config.recipientId),
  ]);
  const stored = await env.DB.prepare('SELECT id, payload_sha256, recipient_id FROM events WHERE delivery_id = ?')
    .bind(delivery).first<{ id: number; payload_sha256: string; recipient_id: number }>();
  if (!stored) throw new HTTPError(503, 'storage_unavailable');
  if (stored.payload_sha256 !== digest || stored.recipient_id !== config.recipientId) {
    throw new HTTPError(409, 'delivery_conflict');
  }
  return json({ status: 'accepted', id: stored.id });
}

function integerQuery(value: string | null, fallback: number, min: number, max: number): number {
  if (value === null) return fallback;
  if (!/^[0-9]+$/.test(value)) throw new HTTPError(400, 'invalid_query');
  const result = Number(value);
  if (!Number.isSafeInteger(result) || result < min || result > max) throw new HTTPError(400, 'invalid_query');
  return result;
}
async function inbox(request: Request, env: Env, config: Config): Promise<Response> {
  await authorize(request, env);
  const url = new URL(request.url);
  if ([...url.searchParams.keys()].some(key => key !== 'after' && key !== 'limit') ||
      url.searchParams.getAll('after').length > 1 || url.searchParams.getAll('limit').length > 1) {
    throw new HTTPError(400, 'invalid_query');
  }
  const after = integerQuery(url.searchParams.get('after'), 0, 0, Number.MAX_SAFE_INTEGER);
  const limit = integerQuery(url.searchParams.get('limit'), 50, 1, 50);
  const result = await env.DB.prepare(`SELECT id, document FROM events
    WHERE recipient_id = ? AND acknowledged = 0 AND id > ? ORDER BY id LIMIT ?`)
    .bind(config.recipientId, after, limit + 1).all<{ id: number; document: string }>();
  // Bound response bytes independently of item count, including non-ASCII text.
  const events: unknown[] = [];
  let responseBytes = 256;
  for (const row of result.results.slice(0, limit)) {
    const event: unknown = { ...JSON.parse(row.document), id: row.id };
    const size = encoder.encode(JSON.stringify(event)).byteLength + 1;
    if (responseBytes + size > 256 * 1024) break;
    events.push(event);
    responseBytes += size;
  }
  return json({ schema: 1, contributor: config.login, events, has_more: result.results.length > events.length });
}
async function acknowledge(request: Request, env: Env, config: Config): Promise<Response> {
  await authorize(request, env);
  if (!(request.headers.get('content-type') ?? '').toLowerCase().startsWith('application/json')) {
    throw new HTTPError(415, 'json_required');
  }
  const payload = parsed(await bytes(request, 4096));
  if (Object.keys(payload).length !== 1 || !Array.isArray(payload.ids) || !payload.ids.length ||
      payload.ids.length > 50 || payload.ids.some(id => positive(id) === null)) {
    throw new HTTPError(400, 'invalid_ids');
  }
  const ids = [...new Set(payload.ids as number[])].sort((a, b) => a - b);
  const slots = ids.map(() => '(?)').join(',');
  // The conditional UPDATE checks the entire set in the same statement. A mix
  // of valid and foreign/missing IDs cannot partially acknowledge the inbox.
  const result = await env.DB.prepare(`WITH requested(id) AS (VALUES ${slots})
    UPDATE events SET acknowledged = 1
    WHERE recipient_id = ? AND id IN (SELECT id FROM requested) AND
      (SELECT COUNT(*) FROM events WHERE recipient_id = ? AND id IN (SELECT id FROM requested)) = ?
    RETURNING id`).bind(...ids, config.recipientId, config.recipientId, ids.length)
    .all<{ id: number }>();
  if (result.results.length !== ids.length) throw new HTTPError(400, 'unknown_ids');
  return json({ schema: 1, contributor: config.login, acknowledged: ids });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      const url = new URL(request.url);
      if (url.pathname === '/health' && request.method === 'GET') {
        return json({ service: 'msdk-agent-inbox', schema: 1, status: 'ok', mode: 'notification_only' });
      }
      const route = `${request.method} ${url.pathname}`;
      if (!['POST /github/webhook', 'GET /v1/inbox', 'POST /v1/ack'].includes(route)) {
        throw new HTTPError(404, 'not_found');
      }
      if (env.PILOT_ENABLED !== 'true') throw new HTTPError(503, 'pilot_disabled');
      const config = configuration(env);
      if (route !== 'GET /v1/inbox' && url.search) throw new HTTPError(400, 'invalid_query');
      if (route === 'POST /github/webhook') return await webhook(request, env, config);
      if (route === 'GET /v1/inbox') return await inbox(request, env, config);
      return await acknowledge(request, env, config);
    } catch (error) {
      if (error instanceof HTTPError) return json({ error: error.code }, error.status);
      // Do not echo payloads, credentials, SQL or platform exception details.
      return json({ error: 'storage_or_processing_unavailable' }, 503);
    }
  },
};
