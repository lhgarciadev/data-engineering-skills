# External API Integration: Consuming APIs for Ingestion

APIs are the most commonly underestimated ingestion source, because unlike a file in S3, there's a live, owned system on the other end — with quotas, latency, versions, and failures. The engineering here is in resilience and contract, not JSON parsing. Before any of it, though: whether to write this extractor by hand at all is a prior decision — see [production-patterns.md](production-patterns.md) for when a declarative EL library or a managed connector service is the better call.

## HTTP fundamentals: acting on status code classes, not just codes

You're assumed to know HTTP methods and the broad status families — 2xx success, 3xx redirect, 4xx client error, 5xx server error (RFC 9110). The trap that separates levels isn't knowing the codes, it's **acting differently by class**: a 4xx (401 auth, 403 forbidden, 404 not found, 422 invalid payload, 429 rate limit) is almost always a *permanent* error that retrying won't fix — except 401 after a token expires, and 429. A 5xx (500, 502, 503, 504) is usually *transient* and worth retrying. RFC 9110 itself is explicit that retrying with fresh credentials is valid for a 401 (§15.5.2), and that 404 doesn't imply permanence the way some engineers assume — that's what 410 Gone is for.

One citation worth getting exactly right: **422** is commonly attributed to WebDAV (RFC 4918 §11.2, "422 Unprocessable Entity") — that's its historical origin, but RFC 9110 formally absorbed it as a general-purpose HTTP status code in §15.5.21, renaming it **"422 Unprocessable Content."** Cite RFC 9110 as the current normative source, RFC 4918 as the historical origin — both names circulate in practice.

```python
import requests

resp = requests.get(url, timeout=(3.05, 30))   # (connect, read) - ALWAYS set a timeout
resp.raise_for_status()                          # turns 4xx/5xx into an exception
data = resp.json()
```

The #1 error in ingestion code is a request **without a timeout**. `requests`' own docs warn about this directly: "Failure to do so can cause your program to hang indefinitely." Without one, a hung server freezes your task indefinitely and blocks the whole DAG behind it — this is the first thing to check in a code review.

## Authentication

The first thing that breaks an ingestion in production. Schemes, in order of complexity:

- **API key** (in an `Authorization` or `X-API-Key` header) — simple; the key lives in a secrets manager, never in code.
- **Static bearer token** — same, but the token can rotate.
- **OAuth2 client credentials** (RFC 6749 §4.4, the machine-to-machine flow you'll use most) — exchange `client_id` and `client_secret` for a short-lived access token, use that token on calls.

```python
import time

class TokenManager:
    def __init__(self, client_id, secret, token_url, refresh_margin_seconds=60):
        self._id, self._secret, self._url = client_id, secret, token_url
        self._margin = refresh_margin_seconds
        self._token, self._expires_at = None, 0

    def token(self):
        if self._token is None or time.time() > self._expires_at - self._margin:
            resp = requests.post(self._url, data={
                "grant_type": "client_credentials",
                "client_id": self._id, "client_secret": self._secret,
            }, timeout=10)
            resp.raise_for_status()
            body = resp.json()
            self._token = body["access_token"]
            self._expires_at = time.time() + body["expires_in"]
        return self._token
```

The senior detail is a **proactive refresh**: renew the token before it expires, don't wait to react to a 401. A margin before expiry avoids the race condition of sending a request with a token that expires mid-flight — but don't treat any specific number as a documented standard. No major OAuth2 provider's docs (Auth0, Okta) prescribe a fixed margin, and real client libraries land in different places — Google's own `google-auth-library-python`, for instance, uses `REFRESH_THRESHOLD = timedelta(minutes=3, seconds=45)`, not 60 seconds. Pick a margin that fits your token's actual `expires_in`, and make it configurable rather than hardcoding a number as if it were spec.

And the usual: credentials live in a secrets manager with rotation, never hardcoded or committed — the same red flag as hardcoded credentials anywhere else in a pipeline.

## Pagination

No serious API hands you millions of rows in one response. Three models, and picking the wrong one breaks ingestion silently:

- **Offset/limit** (`?offset=200&limit=100`) — simple, but risky: if rows are inserted while you paginate, you can skip or duplicate records, and it gets slow at large offsets because the database scans and discards rows before the offset. This isn't just theoretical — Shopify's own engineering team benchmarked it: **6.5ms at offset 10 vs. 2,221ms at offset 100,000**, on the same query shape.
- **Cursor/keyset** (`?after=<last_id>`) — the API hands you an opaque pointer to "where to continue." Stable against inserts, efficient at any depth. The model to prefer whenever the API offers it.
- **Page token** (`?page_token=...`) — a cursor variant, common on Google APIs.
- **Link header** (`Link: <...>; rel="next"`, per **RFC 8288**, "Web Linking" — RFC 8288 obsoletes the older RFC 5988, so cite 8288) — the API returns the next-page URL in the `Link` response header; follow `rel="next"` until it's absent. This is GitHub's documented pagination pattern.

```python
def paginate(session, url, params):
    while url:
        resp = session.get(url, params=params, timeout=30)
        resp.raise_for_status()
        body = resp.json()
        yield from body["items"]                  # emit row by row, constant memory
        url = body.get("next_cursor_url")         # None when exhausted
        params = None                              # the cursor already carries state
```

Prefer cursor/keyset whenever the API offers it; with offset, assume you can lose or duplicate rows and compensate with idempotent deduplication downstream. Paginate through a generator so you never materialize the whole dataset in memory — the same generator pattern from [iterators-and-generators.md](iterators-and-generators.md).

## Rate limiting and resilience

The highest concentration of senior signal in this whole topic, because it's where "works on my laptop" dies in production.

**429 and `Retry-After`.** An API limiting you to N requests per window returns **429 Too Many Requests** (RFC 6585 — a separate spec from RFC 9110, not folded into it). It's often, but not guaranteed, accompanied by a `Retry-After` header (RFC 9110) telling you how long to wait. The rule: respect the server's `Retry-After` when it's present, instead of inventing your own wait.

**Exponential backoff with jitter.** On transient errors (5xx, timeouts, 429), retry with growing delay — 1s, 2s, 4s, 8s — plus a random jitter component. Jitter matters and gets asked about directly: without it, a thousand clients that failed at the same moment retry in lockstep, hammering the API right as it's recovering. This is documented directly by AWS's own engineering team: ["Exponential Backoff And Jitter"](https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/) (Marc Brooker, AWS Architecture Blog, 2015, updated 2023) — worth citing by name, though their concrete example is write contention on DynamoDB under optimistic concurrency control, not a generic retry storm; the mechanism generalizes to any retry-under-load scenario, which is exactly why AWS SDKs ship it as their default retry strategy.

```python
import time, random

TRANSIENT = {429, 500, 502, 503, 504}

def resilient_get(session, url, params=None, max_attempts=5):
    for attempt in range(max_attempts):
        try:
            resp = session.get(url, params=params, timeout=30)
            if resp.status_code in TRANSIENT:
                retry_after = resp.headers.get("Retry-After")
                wait = int(retry_after) if retry_after and retry_after.isdigit() else 2 ** attempt
                wait += random.uniform(0, 1)               # jitter
                if attempt == max_attempts - 1:
                    resp.raise_for_status()
                time.sleep(wait)
                continue
            resp.raise_for_status()                         # non-transient 4xx - fail now
            return resp
        except (requests.Timeout, requests.ConnectionError):
            if attempt == max_attempts - 1:
                raise
            time.sleep(2 ** attempt + random.uniform(0, 1))
```

**Circuit breaker.** After a run of consecutive failures (say, 20), stop hammering the API for a while instead of continuing to spend quota and time against something that's down — the standard circuit-breaker pattern (Fowler/Nygard). Naming it distinguishes someone who's operated ingestion at scale.

**Idempotency keys.** If a `POST` can be retried, send an idempotency key so the receiving server doesn't process the same request twice — the pattern Stripe's API documents directly for exactly this purpose.

Closing frame: assume every network call will eventually fail; the question isn't if, only when — and your code should treat that as the normal case, not the exceptional one. Backoff with jitter, respecting `Retry-After`, distinguishing transient from permanent, and a timeout, always.

## Incremental extraction: the watermark pattern, with a lookback margin

[production-patterns.md](production-patterns.md) already covers the watermark mechanism generally — persisting the last-seen value of a monotonic column and requesting only what's newer. Applied to APIs specifically, one refinement matters: don't request strictly `> watermark` — request `>= watermark - margin` (a few minutes earlier). Late-arriving data or clock skew between your system and the API's can otherwise leave gaps. The margin creates duplicates on purpose, deduplicated downstream with the `ROW_NUMBER` pattern from `sql-data-engineering`. Overlapping and deduplicating is safer than an exact cutoff that risks silently losing rows.

Two limits worth naming: incremental extraction captures changes, but many APIs don't expose deletions, so a periodic full-refresh reconciliation is still needed; and CDC/webhooks (see below) are the alternative to polling for watermarks in the first place.

## Concurrency for I/O-bound ingestion

Thousands of sequential API calls is unacceptably slow. Because ingestion is I/O-bound — the time is spent waiting on the network, not computing — this is exactly the case from [concurrency-and-the-gil.md](concurrency-and-the-gil.md) where threads or async help a lot and processes buy you nothing.

```python
import asyncio, aiohttp

async def fetch(session, url):
    async with session.get(url, timeout=aiohttp.ClientTimeout(total=30)) as resp:
        return await resp.json()

async def fetch_all(urls, limit=20):
    connector = aiohttp.TCPConnector(limit=limit)    # aiohttp's own concurrency cap
    async with aiohttp.ClientSession(connector=connector) as session:
        return await asyncio.gather(*(fetch(session, u) for u in urls))
```

Bound your concurrency — unlimited parallelism is as bad as none, because it saturates the API (cascading 429s) and your own memory. `aiohttp` documents `TCPConnector(limit=...)` as its own native way to cap concurrent connections; you'll also see `asyncio.Semaphore` used for the same purpose in real code — that's a general-purpose `asyncio` primitive from the standard library, not something `aiohttp` itself teaches, and it's useful when you need to bound concurrency around something other than a single `ClientSession` (a mixed set of calls, or rate-limiting logic that isn't purely connection-based). Either is valid; know which one you're actually reaching for and why. Reusing a single `Session`/`ClientSession` for connection pooling and keep-alive is the other cheap win worth calling out.

## Contract and observability

An external API changes without asking you. Validate the payload against a schema (Pydantic, `jsonschema`) at the ingestion boundary, so an upstream change fails loudly at one controlled point instead of silently corrupting tables three layers downstream. Land the raw payload as-is in a raw zone first, so you can reprocess if your parsing logic had a bug, and transform in a later layer — the same raw-then-transform split already used elsewhere in this pipeline.

Track metrics per run: rows ingested, latency, 429/5xx rate, quota consumed, watermark reached. Without this, a "successful" run that pulled 10 rows instead of the expected 10,000 looks identical to a real success. Tie alerts to those metrics and to SLAs.

## Push vs. pull: webhooks and bulk export

Polling — asking on a schedule — is simple but adds latency and wastes calls when nothing changed. **Webhooks** (the source calls you when something happens) give lower latency and less waste, but require exposing a receiver endpoint, handling the provider's own retries, deduplicating deliveries, and validating signatures. The deduplication requirement isn't optional: webhooks are typically **at-least-once** delivery. Stripe's own docs are explicit about this: "Webhook endpoints might occasionally receive the same event more than once... guard against duplicated event receipts by logging the event IDs." Design your receiver to be idempotent on the event ID from day one.

For large volumes, a third option often beats both: **bulk export** to a file (S3/GCS), usually cheaper and faster than paginating millions of rows over HTTP — several major APIs (Shopify's Bulk Operations, Salesforce's Bulk API among them) offer exactly this as the documented alternative to their paginated endpoints for large jobs.

Choose by pattern: polling for batch work that tolerates latency, webhooks/streaming for near-real-time, bulk export for moving a large dataset.
