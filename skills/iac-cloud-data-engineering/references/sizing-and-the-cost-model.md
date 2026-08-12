# Sizing and the Cost Model

This file states no price, no service limit, no quota, no instance type and no node size. That is a sourcing decision, not squeamishness. An amount is the fastest-rotting claim in this domain — rates move, free tiers move, regions differ — and a document carrying one is wrong on a schedule nobody controls. What survives is the **shape** of the charge: which meter turns, what turns it, and in what unit. So billing units appear here in full and verbatim, because the unit *is* the shape; amounts never do. Where a source prints a unit next to a figure, the unit is quoted and the figure is elided as `[…]`, the same convention as the verification behind this file. Everything below was verified 2026-08-08.

[`choosing-a-managed-service.md`](choosing-a-managed-service.md) establishes that the product name never answers the billing question — the meter does. This file is the other half of that: given the meter, what does it do to you, and what do you size against.

## The shapes, in the units vendors actually print

- **Capacity held per unit of time.** You buy a quantity of compute and pay for how long you hold it, whether or not it does work. Google sells this as "Capacity pricing (per slot-hour)", where you "pay for query processing capacity, measured in slots (virtual CPUs) over time". Amazon sells Redshift Serverless this way — you are "billed according to the capacity used in a given duration, in RPU hours on a per-second basis" — and Athena's capacity reservations the same way, in DPU-hours, with the telling verb that capacity is "held for you as long as you need it". Snowflake's version bills credits against warehouse uptime: "Snowflake credits are used to pay for the processing time used by each virtual warehouse", and "Warehouses are only billed for credit usage while running."
- **Per query, measured in bytes scanned.** Not per query. AWS's own term for Athena's default is `per-query billing, based on data scanned`, and the full phrase is the whole point: two queries are not two units of cost. BigQuery's default is the same family under a different name — "On-demand pricing (per TiB)", where "you pay for the data scanned by your queries."
- **Per request.** Object stores meter operations separately from the bytes they touch. Azure prints the unit as `Per transaction`; Amazon states that "You pay for requests made against your S3 buckets and objects", with cost varying "based on the request type".
- **Stored volume per unit of time.** Azure's meter for Blob Storage data storage is `Per GB / per month`. Read both halves: a rate against a quantity, charged again every period. It is the only meter on this list that turns while nobody is working.
- **Egress.** Charged per GB against the volume that leaves. [`statefulness-and-the-one-way-door.md`](statefulness-and-the-one-way-door.md) owns this one — the documented in-free / out-metered asymmetry, the arithmetic that makes it lock-in, and the attribution that reading carries. What matters here is only that it is a *separate* meter from storage and from requests, so a design that reduces one can raise another.

That is five shapes, and the list is deliberately short. Almost every surprising invoice line in a data platform is one of them wearing a product name you did not recognise.

**The private network path is the worked example of that sentence.** Reaching a managed store privately is not a setting, it is a billed resource composing shapes already on that list, and it has a product name per provider — checked 2026-08-12, because this area renames. AWS **PrivateLink** (an `interface VPC endpoint`), **Azure Private Link** (a `private endpoint`) and Google Cloud **Private Service Connect** (an `endpoint`) each carry an hourly meter plus a meter per volume processed. The details that are shape and not amount: AWS charges the hour **per Availability Zone** rather than per endpoint, so the meter follows your topology and not your traffic, and it charges "irrespective of the state of its association with the service" — an endpoint left attached to nothing keeps billing, which is the orphaned line item this file exists to catch. Azure splits the processed-data meter by direction, `Inbound Data Processed` and `Outbound Data Processed`, and bills the *write* to a storage account as outbound. Not every private path bills by the hour: AWS's gateway endpoint carries "no additional charge", and a Private Service Connect interface carries no hourly charge. [`identity-network-and-encryption.md`](identity-network-and-encryption.md) decides whether you want the private path; this is what wanting it costs in shape.

## "Hour" in the unit name is not the billing granularity

The most common misreading of the capacity shape is that a unit ending in `-hour` means you are billed by the hour. You are not, in any of the products verified here. Google documents that BigQuery slot capacity "is billed per second with a `[…]` minimum duration by default". Snowflake documents that "credits are billed per-second, with a `[…]` minimum". Amazon documents Redshift Serverless capacity "in RPU hours on a per-second basis, with a `[…]` minimum charge".

So the unit's denominator and the meter's granularity are independent facts, and you need all of them:

- The **denominator** (`slot-hour`, `RPU-hour`, `DPU-hour`, credits per hour of warehouse size) is how the rate is quoted.
- The **granularity** is how finely the clock is read — per second, in every case above.
- The **minimum** is a floor charged each time the clock starts. Its existence is a shape; its duration is an amount, so it is elided here and you must read it on your provider's page.

The minimum is not decoration. Snowflake states that "Suspending and then resuming a warehouse within `[…]` results in multiple charges because the `[…]` minimum starts over each time a warehouse is resumed." That single sentence is why the popular tuning advice in the last section of this file is wrong as stated. And the minimum is not universal even within one product: Google documents an opt-in mode, fluid scaling, set at the reservation level, giving "per-second billing with no minimum duration" — so "capacity always bills with a minimum" is a claim you cannot make about BigQuery.

## "Serverless" names who operates it, not what meters it

The generalisation that ruins cost forecasts: *serverless means you pay per request.* It is false as a rule, and Redshift Serverless is the counterexample in the product's own documentation. An RPU is a unit of capacity — Amazon writes that the service "measures data warehouse capacity in Redshift Processing Units (RPUs)" — and the billing is capacity multiplied by duration. The word "query" appears in that documentation only to say when the clock runs, never as the unit of charge.

BigQuery makes the same point from the other side: Google defines the term by what you do not do — "You don't need to provision individual instances or virtual machines" — and then describes two different pricing models underneath it. The label is stable across both. The meter is not.

Athena is the product closest to the popular story, and even there AWS's phrasing is `per-query billing, based on data scanned`, sold alongside capacity reservations that AWS also calls serverless. The rule to carry: **the label tells you who runs the infrastructure; it predicts nothing about your invoice.** Read the unit, product by product, every time.

## Three workload shapes

`Throughput shape` is one of the six axes in [`choosing-a-managed-service.md`](choosing-a-managed-service.md), and it is a fact about your workload rather than about any product. For cost purposes it takes three values, named here and reused by [`platform-archetypes.md`](platform-archetypes.md):

- **Steady.** Load sits near its peak for most of the operating window, and the volume is forecastable a period ahead. Scheduled batch pipelines and always-on ingest live here.
- **Spiky.** Bursts separated by idle, where the peak sits far above the mean but arrives on a trigger you know or can detect. Batch loads on a schedule, period-end closes, event-driven reprocessing.
- **Exploratory.** Humans issuing ad-hoc queries. What distinguishes it is not its time profile but its *generator*: neither the arrival time nor the cost of a single unit of work is predictable, because both are set by analyst behaviour rather than by your data volume or your schedule.

Steady and spiky describe *when* load arrives. Exploratory describes *who decides* — which is why it belongs on the same list even though it is not the same kind of category, and why it behaves worst against exactly one of the cost shapes.

| Workload shape | On capacity held per unit of time | On per-query bytes scanned | On per-request |
|---|---|---|---|
| **Steady** | The natural fit. You are paying for capacity you are genuinely using, and a standing unit is the shape with a knob on it | Workable but wasteful: you re-pay the scan of the same corpus on every run, for work whose volume you already knew | Predictable — the request count comes from your own schedule |
| **Spiky** | You fund the peak through every idle window, unless auto-suspend or an idle timeout is set *and* the idle windows outlast the billing minimum | Strong fit: idle costs nothing, and the bill tracks the work | Strong fit, same reason |
| **Exploratory** | Bounded by construction. The bill has a ceiling you chose, and contention shows up as queuing rather than as spend | **The cell that explodes.** No ceiling, and the driver is invisible at the moment of the decision | Uncommon shape for analytical access |

### The cell that explodes

Exploratory work on a bytes-scanned meter is where budgets break, and the mechanism is worth stating precisely because "our warehouse got expensive" is usually diagnosed as a data-volume problem when it is a behaviour problem. The cost is set by what each query touches, and nothing in a notebook or a BI tool puts that in front of the person pressing run. The corpus can be flat across a reporting period while the bill climbs sharply, because the variable that moved was how people queried it rather than how much of it there is.

Two facts from Google's own pricing documentation defuse the most expensive misconceptions here:

- **`LIMIT` does not reduce the charge.** "When you run a query, you're charged according to the data processed in the columns you select, even if you set an explicit `LIMIT` on the results." This is the single most common and most costly wrong mental model of this meter — the belief that asking for few rows means scanning few bytes.
- **Errors and cache hits are not charged.** "You aren't charged for queries that return an error or for queries that retrieve results from the cache." Worth knowing before you build a retry policy or a caching layer that defeats the vendor's.

The structural fix is not a lecture about `SELECT *`. It is to give exploratory work a shape with a ceiling — a capacity reservation, a dedicated warehouse, or a bounded serving copy — and leave the bytes-scanned meter to workloads whose scan volume you can predict.

## `SELECT *` is an architecture decision, not a style preference

On a bytes-scanned meter, the physical layout of the data is the cost-control lever, and query hygiene stops being tidiness. The chain is documented end to end by the vendors themselves, not inferred here.

**Columns.** BigQuery "uses a columnar data structure", and "You're charged according to the total data processed in the columns you select". Selecting every column is therefore a decision about the bill taken in a text editor.

**Compression.** AWS states the mechanism for Athena in one sentence: "Querying compressed data is faster and also cheaper because you pay for the number of bytes scanned before decompression." Compression is charged before it is undone, so it reduces the metered quantity directly.

**Columnar format.** AWS lists the effect: with Parquet or ORC, "Only the columns needed for the query are loaded" and "Files can contain metadata that allow the engine to skip loading unneeded data."

**Partitioning and clustering.** Google's recommendation is unhedged: "Partitioning and clustering your tables can help reduce the amount of data processed by queries. As a best practice, use partitioning and clustering whenever possible." AWS explains the mechanism for Athena: partition keys "act as virtual columns", and "When you filter on partition key columns, only data from matching partitions is read."

Both counter-indications travel with the recommendation, because neither lever is monotonic and AWS documents both:

- **Over-partitioning fragments the dataset.** "Having too many partition keys can result in fragmented datasets with too many files and files that are too small." The advice is not "partition as finely as possible."
- **Columnar formats punish small files.** "For small files, the overhead of the columnar file format outweighs the benefits."

Where this lands in the rest of the suite: partition pruning, predicate and projection pushdown, and the cost driver per engine are [`query-optimization-and-production.md`](../../sql-data-engineering/references/query-optimization-and-production.md); the watermark and incremental-extraction patterns that keep a recurring job's scan bounded to new data are [`engineering-query-patterns.md`](../../sql-data-engineering/references/engineering-query-patterns.md); the layering that decides how many stored, separately metered copies of the corpus exist at all is [`modern-lakehouse-modeling.md`](../../modeling-data-engineering/references/modern-lakehouse-modeling.md). This skill's contribution is only the reframing: on this meter those are budget controls, and they belong in the design review rather than in a tuning ticket filed later.

## Size from the bottleneck resource, not from the data volume

"The dataset is large" implies nothing about a machine. Sizing starts by asking which resource saturates first, because that is the only one worth buying more of:

- **Memory.** The job holds more in a single process than the process has. This is the case with the richest treatment elsewhere: [`spark-data-engineering`](../../spark-data-engineering/SKILL.md) owns it, and [`memory-management.md`](../../spark-data-engineering/references/memory-management.md) covers the executor and driver split specifically. A job that collects a large result to the driver is not fixed by a bigger cluster, and buying one hides the defect behind an invoice.
- **Network.** Shuffle volume, or a read path crossing a region boundary. The cross-region case is a cost decision before it is a latency one, and [`statefulness-and-the-one-way-door.md`](statefulness-and-the-one-way-door.md) has the argument.
- **IO and scan bandwidth.** The job is reading more bytes than it needs. On a bytes-scanned meter this bottleneck and the cost meter are the same quantity, which is why the previous section is a sizing section as much as a cost one.
- **Concurrency.** The limiter is how many things run at once, not how fast any one of them runs. AWS states this directly for Athena capacity: "The number of DPUs that you hold influences the number of queries that you can run concurrently." A workload queuing behind a concurrency ceiling looks exactly like a slow workload from the outside, and buying faster nodes does nothing for it.

Diagnose before you size. Each of those has a different remedy, and not all of them are answered by buying a bigger thing.

## Provision for the peak, or don't — but know which failure you bought

Provisioning is a choice between two failure modes, and they are not equally visible.

- **Over-provisioning fails as steady, invisible waste.** Nothing breaks. No alert fires. Nobody files a ticket. The cost appears on an invoice line that looks the same as it did last period, which is exactly why it outlives the people who set it.
- **Under-provisioning fails as visible queuing.** Jobs run late, dashboards are stale, someone complains, and the complaint arrives with a name attached.

Teams over-provision because the second failure has an owner and the first does not. Naming that asymmetry out loud is most of the fix: assign the invoice line to the same person who owns the latency, and the two failures start being compared on the same terms.

The lever on the capacity shape is the idle timeout, and its vendor-documented form is auto-suspend. Snowflake's framing: "Auto-suspend ensures that you don't leave a warehouse running (and consuming credits) when there are no incoming queries. Similarly, auto-resume ensures that the warehouse starts up again as soon as it is needed." Redshift Serverless expresses the same idea in its billing: "When no queries are running, you aren't billed for compute capacity."

**And the lever is not monotonic — this is the part that gets left out.** Because the billing minimum restarts on every resume, an aggressive auto-suspend against an intermittent workload can produce *more* charges, not fewer: Snowflake's documentation says so in the sentence quoted earlier. The idle timeout must therefore be set against the actual gaps in your arrival pattern, not driven to its floor. And Snowflake records a second limit on the lever: "Auto-suspend only occurs when the minimum number of clusters is running and there is no activity for the specified period of time" — in a multi-cluster warehouse it does not act cluster by cluster.

The remaining cost of suspending is cold start. Warm-capacity features buy that latency back by reintroducing a standing charge, which moves the workload toward the provisioned shape you thought you had left. That trade is legitimate; making it without noticing is not.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Reading a `-hour` unit as hourly billing | Google, Snowflake and Amazon all document per-second granularity on capacity units quoted per hour, each with a minimum charged at start | Separate three facts — the rate's denominator, the meter's granularity, and the minimum — and read all three |
| "Serverless, so we pay per request" | Redshift Serverless bills capacity multiplied by duration in RPU hours; Google defines the word by what you do not provision, under two different pricing models | Ignore the label, name the meter, and re-read it per product |
| Saying "per query" for a bytes-scanned meter | AWS's own term is `per-query billing, based on data scanned`; dropping the second half implies query *count* predicts the bill, and it does not | Use the full phrase, and forecast from scan volume rather than from query volume |
| Adding `LIMIT` to make a query cheaper | Google states you are charged for data processed in the columns you select "even if you set an explicit `LIMIT` on the results" | Reduce columns and prune partitions; row limits are a display concern, not a cost one |
| Putting exploratory work on a bytes-scanned meter | The driver is analyst behaviour, is unbounded, and is invisible to the person issuing the query | Give exploratory access a shape with a ceiling; reserve the scan meter for workloads whose volume you can predict |
| Driving auto-suspend to its lowest setting | The billing minimum restarts on each resume, so suspending inside that window multiplies charges rather than saving them — Snowflake documents this explicitly | Set the idle timeout against your real arrival gaps, and check whether a multi-cluster configuration changes when it fires |
| Partitioning ever more finely to cut scan cost | AWS documents the reversal: too many partition keys fragment the dataset into too many small files, and columnar formats are worst on small files | Partition on the columns queries actually filter on, and check file sizes after |
| Sizing from the size of the dataset | Volume names no bottleneck; memory, network, scan bandwidth and concurrency each saturate differently and not all respond to a bigger node | Identify the saturating resource first, then size that one |
| Treating over-provisioning as the safe error | It fails silently and indefinitely, while under-provisioning fails loudly and therefore gets fixed | Give the invoice line and the latency the same owner so both failures are visible to the same person |
