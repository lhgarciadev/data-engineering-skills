# OOP for Pipelines

The goal isn't inheritance theory — it's abstractions that make pipeline code testable, extensible, and easy to reason about.

## Abstract base classes and polymorphism

The canonical pattern is a common interface for sources or sinks:

```python
from abc import ABC, abstractmethod

class DataSource(ABC):
    @abstractmethod
    def read(self): ...

class S3Source(DataSource):
    def __init__(self, bucket, prefix):
        self.bucket, self.prefix = bucket, prefix
    def read(self):
        ...

class JDBCSource(DataSource):
    def read(self):
        ...

def run_pipeline(source: DataSource, sink):
    for batch in source.read():
        sink.write(transform(batch))
```

`run_pipeline` neither knows nor cares which source it's reading from — that's polymorphism, and it's what makes the pipeline extensible without touching the orchestrator.

## Composition over inheritance, and dependency injection

Prefer composing behavior (injecting an object) over deep inheritance hierarchies. Pass the source/sink/config as arguments instead of constructing them inside the pipeline — that's what makes them mockable in tests. This is the real reason for the structure above: **testability**, not elegance for its own sake.

## dataclasses for config and records

For objects that just carry data (config, a record, an event), use `@dataclass` instead of hand-writing `__init__`. `frozen=True` makes instances immutable — hashable and safe to share across threads/processes:

```python
from dataclasses import dataclass

@dataclass(frozen=True)
class PipelineConfig:
    source: str
    sink: str
    batch_size: int = 10_000
```

`dataclass` is for shaping data you already trust. For data crossing a trust boundary — an inbound API payload, a config file, anything external — use Pydantic instead, since it validates on construction rather than just holding fields. See [data-validation.md](data-validation.md) for the Pydantic/Pandera split.

## Common mistakes

| Mistake | Fix |
|---|---|
| Constructing the source/sink *inside* the function that uses them | Inject them as parameters so tests can pass a fake/mock |
| Deep inheritance chains for source variants (`S3CsvSource(S3Source(Source))`) | Compose instead — a source that takes a format-parser object beats a subclass per format |
| Hand-writing `__init__`/`__eq__`/`__repr__` for a plain config/record object | Use `@dataclass` (or `@dataclass(frozen=True)` if it should be immutable) |
| Using `@dataclass` for data from an untrusted boundary (API response, uploaded file) | Use Pydantic there — it validates, `dataclass` doesn't |
