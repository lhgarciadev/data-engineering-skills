# Decorators and Context Managers

Both show up constantly in production pipeline code, and knowing how to *implement* them — not just use them — is what separates senior usage from copy-pasting `@retry`.

## Decorators for cross-cutting pipeline concerns

A decorator wraps a function to add behavior without touching its body. In data engineering the recurring uses are retry, timing, logging, and caching — exactly the cross-cutting concerns of a pipeline stage.

```python
import functools, time

def retry(attempts=3, wait=2):
    def decorator(func):
        @functools.wraps(func)          # preserves the wrapped function's name/docstring
        def wrapper(*args, **kwargs):
            for i in range(attempts):
                try:
                    return func(*args, **kwargs)
                except Exception:
                    if i == attempts - 1:
                        raise
                    time.sleep(wait * (2 ** i))   # exponential backoff
        return wrapper
    return decorator

@retry(attempts=5, wait=1)
def extract_from_api(url):
    ...
```

The senior details:
- `functools.wraps` — without it you lose the original function's `__name__`/`__doc__`, which breaks introspection, debugging, and some frameworks that key off function identity.
- Exponential backoff, not a fixed sleep — avoids hammering a struggling upstream.
- Three levels of nesting are required *because* the decorator itself takes arguments (`retry(attempts=5)` → returns `decorator` → returns `wrapper`).
- `*args, **kwargs` in `wrapper` are mandatory for the decorator to stay generic across any wrapped signature.

For calls to an external API specifically, also add jitter — see `external-api-integration.md` for why (a backoff without jitter can synchronize retries across many failed clients).

## Context managers for guaranteed cleanup

`with` guarantees resource cleanup (closing files/connections, committing or rolling back transactions) even when an exception is raised. Implement `__enter__`/`__exit__` directly, or more concisely with `@contextmanager`:

```python
from contextlib import contextmanager

@contextmanager
def db_connection(config):
    conn = open_connection(config)
    try:
        yield conn                # everything before yield is setup, after is teardown
        conn.commit()
    except Exception:
        conn.rollback()           # guaranteed cleanup on failure
        raise
    finally:
        conn.close()

with db_connection(cfg) as conn:
    conn.execute(query)
```

The pattern to internalize: `yield` marks the setup/teardown boundary, and `try/except/finally` guarantees rollback and closing regardless of outcome. This is the answer to "how do you make sure a connection doesn't hang if the job dies halfway through?"

## Common mistakes

| Mistake | Fix |
|---|---|
| Omitting `@functools.wraps` on a custom decorator | Add it — otherwise stack traces, `help()`, and introspection-based tooling see the wrapper's identity, not the original function's |
| Fixed-interval retry sleep | Use exponential backoff so a struggling dependency isn't hammered harder under load; for an external API specifically, add jitter too — see `external-api-integration.md` (backoff without jitter can still synchronize retries across many clients) |
| Closing a connection only in the "happy path" | Put cleanup in `finally` (or after `yield` in a `@contextmanager`), not just at the end of the try block |
| Swallowing the exception inside a context manager's `except` without `raise` | Re-raise after cleanup unless you specifically intend to suppress the error |
