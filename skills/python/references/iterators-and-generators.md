# Iterators and Generators

This is the single most important concept for data engineering in Python: everything else in this skill (streaming pipelines, chunked processing, memory-bounded jobs) is built on it.

## The iterator protocol

An **iterable** is any object with `__iter__()` that returns an **iterator**; an iterator has `__next__()`, which produces the next value or raises `StopIteration`. `for` is sugar over this protocol. Understanding it is what lets you build custom lazy data sources instead of always materializing lists.

## Generators: lazy by construction

A function with `yield` doesn't run its body when called — it returns a generator object. Each `next()` runs the body until the next `yield`, returns that value, and freezes local state (variables, position) until the following call. This is lazy evaluation: you process one element at a time without materializing the whole collection.

```python
def read_lines(path):
    with open(path) as f:
        for line in f:            # the file object is itself a line generator
            yield line.strip()

# Process a 50 GB file with constant memory:
for line in read_lines("huge.csv"):
    process(line)
```

## Chaining generators into a pipeline

The real payoff is chaining generators so nothing materializes until the final consumer pulls a value — conceptually, this is how Spark's lazy DAG execution thinks about a job.

```python
def parse(lines):
    for l in lines:
        yield l.split(",")

def keep_valid(rows):
    for r in rows:
        if len(r) == 3:
            yield r

pipeline = keep_valid(parse(read_lines("data.csv")))
# Nothing has been read yet. Data only flows, row by row, once you iterate `pipeline`.
```

`itertools.islice` lets you take a bounded slice without forcing the rest of the generator to run:

```python
from itertools import islice
first_100 = islice(pipeline, 100)
```

## What actually distinguishes senior usage

Don't just say "uses less memory." The precise claims are:

1. Generators enable streaming pipelines with constant memory.
2. **A generator is consumed exactly once.** If you need to iterate twice, either materialize it (`list(gen)`) or rebuild the generator — that's a deliberate design decision, not an accident. Calling `len()` on a generator, or passing it to something that iterates it twice, silently breaks the second pass.
3. `yield from` delegates to a sub-generator so you can compose without nested loops.

A common interview probe is "convert this list-returning function into one with constant memory" — the trap is recognizing where laziness breaks the logic (e.g., a later `len()` call forces full materialization anyway, so laziness bought nothing).

## itertools toolkit

`islice`, `chain`, `groupby`, `tee`, `count`, `takewhile` are the standard toolkit for working with lazy iterators; their signatures have been stable across recent Python versions (3.12/3.13/3.14), so reach for them instead of hand-rolling the equivalent loop.

| Function | Use for |
|---|---|
| `islice(it, n)` | Take `n` items without materializing the rest |
| `chain(it1, it2, ...)` | Treat several iterables as one, lazily |
| `groupby(it, key)` | Group **consecutive** equal keys — sort first if you need full grouping |
| `tee(it, n)` | Split one iterator into `n` independent ones (each still consumed once) |
| `count(start)` | Infinite counter, useful with `takewhile`/`islice` |
| `takewhile(pred, it)` | Stop consuming as soon as `pred` is false |

## Comprehensions vs generator expressions

List/dict/set comprehensions aren't just syntactic sugar — they're faster than an equivalent `for` + `.append()` loop because the loop runs in C. But when the dataset doesn't fit in memory, use a **generator expression** (parentheses instead of brackets), which is lazy:

```python
squares_list = [x * x for x in range(10_000_000)]   # materializes everything now
squares_gen  = (x * x for x in range(10_000_000))   # lazy, constant memory
```

## Common mistakes

| Mistake | Fix |
|---|---|
| Iterating a generator twice expecting the same results | Materialize once (`list(...)`) if you need multiple passes, or recreate the generator |
| Calling `len()` on a generator | Generators have no length; materialize first if you truly need the count, or track a counter while iterating |
| Using `groupby` without sorting by the same key first | `groupby` only groups consecutive runs — sort by `key` beforehand or you'll get many single-element groups |
| Building a list comprehension over an unbounded/huge source | Use a generator expression or a `yield`-based generator instead |
