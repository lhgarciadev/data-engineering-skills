# Data Validation: Pydantic vs Pandera vs Great Expectations

These three get reached for interchangeably by people who haven't hit the difference yet — they validate different things, at different points in a pipeline.

## The split

- **Pydantic** validates individual records/objects: one API payload, one config file, one row treated as a Python object. It's a record-at-a-time boundary check, not built for a dataframe as a whole.
- **Pandera** validates the dataframe itself: schema, dtypes, cross-column constraints, statistical constraints (value ranges, uniqueness, nullability) — and the same schema definition works across pandas, Polars, Dask, and PySpark. This is the standard choice for "validate this dataframe mid-pipeline."
- **Great Expectations** is a heavier, org-wide data-quality and documentation platform (expectation suites, data docs, validation checkpoints across many datasets/teams). Usually overkill for validating a single pipeline's output — reach for it when the requirement is organization-wide data quality governance, not a single job's correctness.

**Rule of thumb**: Pydantic at ingestion boundaries (validate the payload/record as it enters your system), Pandera inside the pipeline (validate the dataframe after transformation, before it's written downstream).

```python
from pydantic import BaseModel

class IncomingEvent(BaseModel):     # validates one record at the boundary
    id: str
    ts: int
    amount: float

import pandera.pandas as pa
from pandera.pandas import DataFrameSchema, Column, Check

schema = DataFrameSchema({          # validates the whole dataframe mid-pipeline
    "id": Column(str, unique=True),
    "amount": Column(float, Check.ge(0)),
})
schema.validate(df)
```

## Common mistakes

| Mistake | Fix |
|---|---|
| Using Pydantic to validate an entire dataframe row-by-row in a loop | Use Pandera against the dataframe directly — faster and expresses cross-column/statistical checks Pydantic can't |
| Reaching for Great Expectations to validate one pipeline's output | Use Pandera unless there's an actual org-wide data-quality governance requirement |
| Skipping validation at the ingestion boundary because "the pipeline will catch bad data downstream" | Validate at the boundary with Pydantic — catching malformed input early gives a clear, localized error instead of a confusing downstream failure |
