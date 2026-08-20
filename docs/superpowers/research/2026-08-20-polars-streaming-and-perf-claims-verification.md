# Research: verificando los claims de Polars sobre streaming, out-of-core y multiplicador de rendimiento

**Fecha:** 2026-08-20

**Alcance:** tres afirmaciones sobre Polars que hoy viven en `skills/python-data-engineering/references/memory-and-performance.md` (sección "Beyond pandas: PyArrow, Polars, DuckDB") y en `skills/spark-data-engineering/SKILL.md` (sección "Before tuning: does this workload need a cluster?"): (1) el multiplicador "3-11x faster than pandas"; (2) que `pl.scan_parquet(...)` + `.collect()` ejecuta con "streaming execution for data larger than RAM"; (3) que Polars y DuckDB "stream and spill out of core" en una sola máquina. Verificado contra **Polars 1.43.2** (última versión en PyPI al 2026-08-20, publicada 2026-08-01), leyendo el código fuente del sdist oficial `polars-1.43.2.tar.gz` (`src/polars/lazyframe/frame.py`, `src/polars/_utils/deprecation.py`), el código Rust en `pola-rs/polars@main` (`crates/polars-lazy/src/frame/mod.rs`, `crates/polars-config/src/{lib,engine,spill_path}.rs`, `crates/polars-python/src/lazyframe/general.rs`), el user guide oficial (`docs/source/user-guide/**` del propio repo y su versión publicada en docs.pola.rs), las release notes de `pola-rs/polars`, los PRs de deprecación/remoción, el issue de tracking del motor streaming, y la página de benchmarks de pola.rs. Para DuckDB se usó su documentación oficial (duckdb.org/docs).

---

## 1. Claim: "Commonly 3-11x faster than pandas on large data"

**Veredicto: no verificable contra fuente primaria — el número no existe en ninguna fuente primaria de Polars, y el rango además contradice lo que Polars sí publica.**

- **No hay respaldo textual en el repo de Polars.** Búsqueda de código sobre `pola-rs/polars` (GitHub code search) por la frase `"faster than pandas"` y por `"11x"`: **cero resultados** en todo el repositorio (código, docs, README, release notes). El `README.md` del proyecto no contiene ningún multiplicador; solo remite a "the [PDS-H benchmarks](https://www.pola.rs/benchmarks.html) results".
- **El benchmark oficial que sí existe da un número muy distinto.** La página oficial de benchmarks (https://pola.rs/posts/benchmarks/, fechada Sun, 1 Jun 2025) publica PDS-H (los 22 queries de TPC-H, con generación de datos y scripts modificados) sobre AWS `c7a.24xlarge` (96 vCPU, 192 GB RAM, Ubuntu 22.04 x86-64), comparando **Polars 1.30.0, DuckDB 1.3.0, PySpark 4.0.0, Dask 2025.5.1 y pandas 2.2.3**. En SF-10 (≈1 GB de CSV por unidad de scale factor), tomando `polars[streaming]-1.30.0` como baseline `1.0`, los factores de tiempo total son: DuckDB `1.5x`, Polars in-memory `2.5x`, Dask `11.8x`, PySpark `30.9x` y **pandas `94.0x`**. Es decir: en el propio benchmark de Polars, pandas es ~94 veces más lento en tiempo total, no 3-11x.
- **Y pandas ni siquiera llega a las escalas mayores.** Cita textual de la misma página: *"Pandas is only run in the SF-10 benchmark as it's single threaded execution and lack of query optimizer lead to 2 orders of magnitudes difference and OOM failures on higher scale factors."*
- **La copy de marketing de primera parte también dice otro número.** La home oficial (https://pola.rs/) afirma *"Compared to pandas, it can achieve more than 30x performance gains"*. Es fuente de primera parte, pero es copy de landing, no un benchmark reproducible: no nombra query set, versión, dataset ni hardware.
- **Descargo importante del propio Polars:** *"any results obtained using PDS are not comparable to published TPC-H Benchmark results, as the results obtained from using PDS do not comply with the TPC-H Benchmarks."* Cualquier cita de estos números debe llevar ese matiz.
- El post oficial https://pola.rs/posts/benchmark-energy-performance/ mide **energía**, no un multiplicador de velocidad ("Polars consumed approximately 8 times less energy than pandas" en tareas sintéticas; "about 63% of the energy required by pandas" en TPC-H) — no sirve como fuente del "3-11x".

Conclusión: el rango "3-11x" **no proviene de ninguna fuente primaria de Polars**. Es un número sin dueño: no está en las docs, ni en el repo, ni en los benchmarks publicados, y el único benchmark oficial que compara con pandas reporta un orden de magnitud distinto (~94x en tiempo total sobre PDS-H SF-10, y OOM de pandas más arriba).

**Acción:** eliminar el rango numérico y no reemplazarlo por otro inventado. Reemplazar *"Commonly 3-11x faster than pandas on large data"* por: *"Typically an order of magnitude faster than pandas on large data — Polars' own PDS-H benchmark (22 TPC-H-derived queries, SF-10, Polars 1.30.0 vs. pandas 2.2.3) puts pandas at ~94x the total runtime of Polars' streaming engine, and pandas OOMs at higher scale factors. Treat any specific multiplier as workload-dependent: the numbers come from a scan/filter/join/aggregate query set, not from arbitrary code."* Si se prefiere no citar cifras, la forma defendible mínima es *"typically an order of magnitude faster than pandas on large scan/filter/join/aggregate workloads"*, sin rango.

---

## 2. Claim: `.collect()` ejecuta en modo streaming / out-of-core

El texto actual dice que `pl.scan_parquet(...)` construye un query plan con *"projection/predicate pushdown, streaming execution for data larger than RAM"* que *"only executes on `.collect()`"*.

**Veredicto: incorrecto en la parte que importa. El pushdown sí es automático; el streaming es OPT-IN. `.collect()` pelado ejecuta en el motor in-memory.**

### 2.1 La forma vigente de la API (Polars 1.43.2)

Firma real de `LazyFrame.collect` en el sdist oficial de 1.43.2 (`src/polars/lazyframe/frame.py`, línea 2413):

```python
@deprecate_streaming_parameter()
@forward_old_opt_flags()
def collect(
    self,
    *,
    ...,
    engine: EngineType = "auto",
    background: bool = False,
    optimizations: QueryOptFlags = DEFAULT_QUERY_OPT_FLAGS,
    **_kwargs: Any,
) -> DataFrame | InProcessQuery:
```

El docstring del mismo archivo describe los valores aceptados de `engine`:

> * `"auto"`: use the engine set by `Config.set_engine_affinity` or the `POLARS_ENGINE_AFFINITY` environment variable, falling back to `"in-memory"` if unset (this default may change in a future release).
> * `"in-memory"`: use the in-memory engine, this is the default engine.
> * `"streaming"`: use the streaming engine, which processes queries in batches, reducing memory pressure and often outperforming the in-memory engine. This will soon become the default engine of Polars.
> * `"gpu"`: use the CUDA GPU engine (requires an Nvidia GPU and `cudf-polars`).
>
> If the selected engine cannot run the query, Polars falls back to the in-memory engine.

Los valores válidos están fijados en Rust (`crates/polars-config/src/engine.rs`): `auto`, `in-memory` (con alias legacy `cpu`), `streaming`, `gpu`. Pedir `"old-streaming"` devuelve el error `"the 'old-streaming' engine has been removed"`.

### 2.2 Qué hace exactamente `.collect()` sin argumentos — resuelto en el código, no en la prosa

- En Python, `collect()` con `engine="auto"` llama `_select_engine`, que devuelve `get_engine_affinity()` (`src/polars/lazyframe/frame.py` línea 188-189), y pasa ese valor a Rust: `wrap_df(ldf.collect(engine, callback))`.
- El default de la afinidad es `Auto`: `const DEFAULT_ENGINE_AFFINITY: Engine = Engine::Auto;` (`crates/polars-config/src/lib.rs` línea 39). Sin `POLARS_ENGINE_AFFINITY` ni `Config.set_engine_affinity(...)`, `engine` llega a Rust como `Auto`.
- En Rust, `LazyFrame::collect_with_engine` (`crates/polars-lazy/src/frame/mod.rs` línea 636) resuelve:

```rust
let engine = match engine {
    Engine::Streaming => Engine::Streaming,
    _ if std::env::var("POLARS_FORCE_STREAMING").as_deref() == Ok("1") => Engine::Streaming,
    Engine::Auto => Engine::InMemory,
    v => v,
};
```

  y el `LazyFrame::collect()` de Rust es literalmente `self.collect_with_engine(Engine::Auto)` (línea 742-743).

**`Engine::Auto => Engine::InMemory`. Un `.collect()` pelado ejecuta en el motor in-memory, no en streaming.** El único modo de conseguir streaming sin pasarlo en la llamada es global y explícito: `POLARS_ENGINE_AFFINITY=streaming`, `pl.Config.set_engine_affinity("streaming")`, o `POLARS_FORCE_STREAMING=1`.

Y la doc oficial lo dice en prosa, sin ambigüedad, en `docs/source/user-guide/lazy/execution.md`:

> With the default `collect` method Polars processes all of your data as one batch. This means that all the data has to fit into your available memory at the point of peak memory usage in your query.
>
> ### Execution on larger-than-memory data
>
> If your data requires more memory than you have available Polars **may** be able to process the data in batches using _streaming_ mode. To use streaming mode you simply pass the `engine="streaming"` argument to `collect`.

Nota: los sinks (`sink_parquet`, `sink_csv`, `sink_ipc`, `sink_ndjson`, ...) **también** llevan `engine: EngineType = "auto"` con la misma resolución a in-memory (docstring en `src/polars/lazyframe/frame.py` línea ~1368). La excepción es `LazyFrame.collect_batches`, cuyo `"auto"` cae a `"streaming"` — pero ese método está marcado **unstable** y su propio docstring advierte que *"This method is much slower than native sinks."*

### 2.3 Lo que el claim SÍ acierta: el pushdown es automático e independiente del motor

El pushdown no depende de `engine`. `docs/source/user-guide/lazy/optimizations.md` lista *Predicate pushdown* ("Applies filters as early as possible/ at scan level"), *Projection pushdown* ("Select only the columns that are needed at the scan level") y *Slice pushdown* como optimizaciones de la lazy API que corren una vez por query. `docs/source/user-guide/concepts/lazy-api.md` demuestra ambos con `scan_csv` + `collect()` pelado. Y `docs/source/user-guide/lazy/sources_sinks.md` confirma la ventaja adicional del `scan_*`: *"the Polars optimizer can push optimization into the readers. They can skip reading columns and rows that aren't required."*

Por lo tanto la frase del skill mezcla dos cosas de estatus distinto: **pushdown = automático; streaming/out-of-core = opt-in.**

### 2.4 `streaming=True`: deprecado, no removido (todavía)

El decorador que lo maneja, en `src/polars/_utils/deprecation.py` líneas 80-102 de 1.43.2:

```python
def deprecate_streaming_parameter() -> IdentityFunction:
    """Decorator to mark `streaming` argument as deprecated due to being renamed."""
    ...
            if "streaming" in kwargs:
                issue_deprecation_warning(
                    "the `streaming` parameter was deprecated in 1.25.0; use `engine` instead."
                )
                if kwargs["streaming"]:
                    kwargs["engine"] = "streaming"
                elif "engine" not in kwargs:
                    kwargs["engine"] = "in-memory"
                del kwargs["streaming"]
```

- **Deprecado desde 1.25.0**, con mensaje explícito en el propio código.
- En 1.43.2 **sigue funcionando**: emite `DeprecationWarning` y se traduce a `engine="streaming"` / `engine="in-memory"`. No es un `TypeError`.
- En `sink_parquet` y compañía el parámetro `streaming` es aún más muerto: su docstring dice *"Unused parameter, kept for backward compatibility. .. deprecated:: 1.30.0 Use the `engine` parameter instead."*
- Lo que **sí fue removido** es el *motor* streaming viejo (distinto del parámetro): PR [#23103](https://github.com/pola-rs/polars/pull/23103) "feat!: Remove old streaming engine", merged 2025-06-06, listado como breaking change en las release notes de **py-1.31.0** (publicada 2025-06-18): *"Remove old streaming engine (#23103)"*. Justificación en el cuerpo del PR: *"The old streaming engine was experimental, and deprecated for a while now. It started breaking more and more and becoming a maintenance issue, so we're now removing it."* El valor `"old-streaming"` del argumento `engine` había sido retirado antes, en PR [#21667](https://github.com/pola-rs/polars/pull/21667) (merged 2025-03-11).

### 2.5 Estado de madurez que declara la propia doc

- **No es default.** El docstring de `collect` en 1.43.2 dice del in-memory *"this is the default engine"*, y del streaming *"This will soon become the default engine of Polars"* — futuro, no presente.
- **No es "experimental" nominalmente en el path síncrono.** En 1.43.2, `collect(engine="streaming")` **no** emite ningún `issue_unstable_warning`. La única advertencia de inestabilidad que queda ligada a streaming en el código Python es en `collect_async` (`src/polars/lazyframe/frame.py` línea 2758: `issue_unstable_warning("streaming mode is considered unstable.")`). El "unstable" nominal hoy cubre `background=True`, `optimizations=`, `collect_batches` y `sink_batches`, no `collect(engine="streaming")`.
- **Pero la página del user guide sigue sin considerarse terminada.** El fuente de `docs/source/user-guide/concepts/streaming.md` abre con este comentario en el propio repo: `<!-- Not included in the docs "until we have something we are proud of". -->` (referenciando el PR #19087). La página sí está publicada y en el nav de `mkdocs.yml`, pero el comentario del autor sigue ahí.
- **Fallback silencioso a in-memory.** `docs/source/user-guide/concepts/streaming.md`: *"Polars can run many operations in a streaming manner. Some operations are inherently non-streaming, or are not implemented in a streaming manner (yet). In the latter case, Polars will fall back to the in-memory engine for those operations. A user doesn't have to know about this, but it can be interesting for debugging memory or performance issues."* Se inspecciona con `show_graph(plan_stage="physical", engine="streaming")`. El docstring de `collect` lo repite: *"If the selected engine cannot run the query, Polars falls back to the in-memory engine."* Consecuencia práctica: pedir `engine="streaming"` **no garantiza** ejecución en batches de toda la query.
- **Qué no soporta, según el issue de tracking oficial** [#20947](https://github.com/pola-rs/polars/issues/20947) ("Tracking issue for the new streaming engine", **open**, última actualización 2026-07-08). Su encabezado: *"From 1.31.1, Polars has a new streaming engine. In time, it will become the default engine, as it is usually faster and uses less memory. All queries that run on the in-memory engine should run on the streaming engine (please file a bug otherwise), but certain operations might not have a native streaming implementation yet (in which case they will transparently fall back to the in-memory engine)."* Ítems aún sin marcar al 2026-07-08: `AnonymousScan` como source; Anonymous Sink; `LazyFrame.group_by_dynamic` con columna `group_by` ordenada; `rolling_{sum,std,var,...}`; agregados `implode`, `median`/`quantile`, `str.join`; y en traducción de plan `.over(keys)` general, `.replace()`, `is_last_distinct`, `is_unique`, `is_duplicated`, `reshape`, `qcut`, `sample`, `pct_change`, `interpolate_by`, `ewm_*_by`, `fill_null(strategy=...)`, `search_sorted`, `random`, `rank`.

**Acción:** reescribir la bullet de Polars en `memory-and-performance.md` separando pushdown (automático) de streaming (opt-in). Fraseo propuesto: *"**Polars**: a DataFrame library with a **lazy API** — `pl.scan_parquet(...)` builds a query plan (predicate, projection and slice pushdown into the reader) that only executes on `.collect()`, similar in spirit to Spark's lazy DAGs. Pushdown is automatic, but out-of-core execution is not: a bare `.collect()` runs the in-memory engine and materializes everything at peak, which the user guide states outright ('With the default `collect` method Polars processes all of your data as one batch'). Batched, larger-than-memory execution is opt-in via `.collect(engine="streaming")` (or a `sink_*` with the same argument) — and even then Polars silently falls back to the in-memory engine for operations without a streaming implementation, so verify with `show_graph(plan_stage="physical", engine="streaming")`. The older `collect(streaming=True)` spelling was deprecated in Polars 1.25.0 and still works with a DeprecationWarning; the separate legacy streaming *engine* was removed in 1.31.0."* Añadir además una fila a la tabla "Common mistakes": *"Assuming a bare `.collect()` on a `pl.scan_*` streams out of core"* → *"It doesn't — pass `engine="streaming"` (Polars 1.25.0+) or use a `sink_*`; check the physical plan to confirm the query actually streams"*.

---

## 3. Claim: Polars y DuckDB procesan datasets más grandes que la RAM en una sola máquina

El texto de `spark-data-engineering/SKILL.md` dice: *"Polars' lazy `scan_*` API and DuckDB both stream and spill out of core, so one machine handles datasets well past its own memory."*

**Veredicto: parcialmente correcto — la dirección es correcta, pero agrupa dos motores con garantías muy distintas, y atribuye a Polars un spilling que hoy es opt-in y explícitamente inestable.**

### 3.1 Polars: streaming ≠ spilling

Hay que distinguir dos mecanismos:

- **Streaming (procesamiento en batches).** Documentado y real, pero opt-in (ver §2). La doc de features de Polars lo enuncia así (`docs/source/index.md`): *"**Out of Core**: The streaming API allows you to process your results without requiring all your data to be in memory at the same time."* Y en la sección Philosophy del mismo archivo: *"Handles datasets much larger than your available RAM."* La home (https://pola.rs/) lo repite: *"Want to process large data sets that are bigger than your memory? Our streaming API allows you to process your results efficiently, eliminating the need to keep all data in memory."* Nótese que todas estas afirmaciones son sobre la **streaming API**, no sobre el default.
- **Spilling a disco (out-of-core propiamente dicho).** Es mucho más nuevo y mucho más limitado. PR [#27998](https://github.com/pola-rs/polars/pull/27998) "feat: Add naive out-of-core spilling to Polars", merged 2026-06-22, listado en las release notes de **py-1.42.0** (2026-06-24). Cuerpo del PR, textual: *"This PR adds naive out-of-core capabilities to Polars. Note: this is all very early work and still highly unstable, likely with bugs and performance issues. To enable it, specify `POLARS_OOC_MEMORY_BUDGET_MB` to set a memory budget in MB. Note that not everything is included in this (e.g. we still rely on `mmap` in places which isn't tracked in this). Also note that not everything *can* be spilled to disk, so Polars can still go over this amount, even ignoring the previous effect."*
  - Confirmado en `crates/polars-config/src/lib.rs`: `POLARS_OOC_MEMORY_BUDGET_MB` con `DEFAULT_OOC_MEMORY_BUDGET_MB: u64 = u64::MAX` (líneas 78-79) — es decir, **sin budget efectivo por defecto, no hay spilling**. Config relacionada: `POLARS_OOC_MEMORY_BUDGET_FRACTION` (default `0.8`), `POLARS_OOC_SPILL_MIN_BYTES` (default 64 KB), `POLARS_OOC_SPILL_FORMAT` (solo `ipc`), `POLARS_OOC_SPILL_COMPRESSION_LEVEL` (default 0). El directorio de spill lo fija `crates/polars-config/src/spill_path.rs` (`/var/tmp/polars-{USER}/spill` en Linux, "always real disk, never tmpfs").
  - **Qué operadores todavía NO son out-of-core.** El issue de tracking oficial [#20947](https://github.com/pola-rs/polars/issues/20947) tiene una sección "Out-of-core" con, al 2026-07-08: `[x]` Multiplexers (#26774), `[ ]` **Group-by**, `[ ]` **Equi-join**, `[ ]` **Sort**. Los tres operadores bloqueantes clásicos siguen sin spilling.

Es decir: para Polars, un `group_by`/`join`/`sort` cuyo estado no cabe en RAM **no** se resuelve hoy con spilling a disco, ni con streaming ni sin él. El streaming reduce la presión de memoria del pipeline (sources, proyecciones, filtros, slices, concat), no elimina el requisito de que el estado del operador bloqueante quepa en memoria.

### 3.2 DuckDB: sí soporta out-of-core para los operadores bloqueantes, con caveat

Fuente: DuckDB docs oficiales, "Tuning Workloads" (https://duckdb.org/docs/current/guides/performance/how_to_tune_workloads), sección de larger-than-memory workloads.

- Los operadores bloqueantes que enumera son `GROUP BY`, `JOIN`, `ORDER BY` y `OVER (PARTITION BY ... ORDER BY ...)`, y la doc afirma: *"DuckDB supports larger-than-memory processing for all of these operators."*
- Ubicación del spill: *"DuckDB creates the `database_file_name.tmp` temporary directory (in persistent mode) or the `.tmp` directory (in in-memory mode)"*, configurable con la opción `temp_directory`.
- **Caveat explícito:** *"If multiple blocking operators appear in the same query, DuckDB may still throw an out-of-memory exception due to the complex interplay of these operators."* La misma página anota además que ciertas funciones de agregación que usan ordenamiento internamente no soportan offload a disco y pueden provocar OOM en datasets grandes.
- No verificado contra fuente primaria en esta ronda: el valor y comportamiento exacto de `max_temp_directory_size` (la página consultada no lo menciona; probablemente vive en la página de configuración/pragmas).

### 3.3 Consecuencia para el texto de la skill de Spark

El párrafo actual es defendible en su conclusión ("la línea no es 'fits in RAM'") pero es demasiado generoso con Polars y borra la diferencia entre los dos motores. Hoy, en una sola máquina:

- **DuckDB** es el que realmente hace out-of-core para group-by/join/sort/window, by default, con un caveat documentado sobre varios operadores bloqueantes en la misma query.
- **Polars** hace *streaming en batches* (opt-in vía `engine="streaming"` o `sink_*`), lo cual ya permite datasets mayores que la RAM en pipelines dominados por scan/filter/proyección, pero su spilling a disco es de 1.42.0, opt-in vía env var, declarado *"very early work and still highly unstable"* por sus autores, y todavía no cubre group-by, equi-join ni sort.

**Acción:** reemplazar la frase *"Polars' lazy `scan_*` API and DuckDB both stream and spill out of core, so one machine handles datasets well past its own memory"* por una que distinga los dos motores y su estatus. Fraseo propuesto: *"The line is not 'fits in RAM'. DuckDB runs its blocking operators — `GROUP BY`, `JOIN`, `ORDER BY`, windowing — out of core by spilling to a temp directory, so one machine handles datasets well past its own memory (its docs warn that several blocking operators in one query can still OOM). Polars gets there differently: `scan_*` plus `.collect(engine="streaming")` (or a `sink_*`) processes the query in batches rather than materializing everything, which covers scan/filter/projection-heavy pipelines past RAM — but streaming is opt-in, not what a bare `.collect()` does, and as of Polars 1.43 its disk spilling is opt-in (`POLARS_OOC_MEMORY_BUDGET_MB`, added 1.42.0), described by its authors as early and unstable, and does not yet cover group-by, equi-join or sort. So: a single-node engine handles larger-than-RAM work, but you have to ask for it, and for a huge blocking aggregation or join DuckDB is the safer single-node bet today."*

---

## Resumen de acciones

| # | Claim | Veredicto | Corrección |
|---|---|---|---|
| 1 | "Commonly 3-11x faster than pandas on large data" | No verificable contra fuente primaria | Quitar el rango; usar "typically an order of magnitude faster on large scan/filter/join/aggregate workloads", citando PDS-H SF-10 (pandas ≈94x el tiempo total de Polars streaming, Polars 1.30.0 vs pandas 2.2.3) si se quiere un número |
| 2 | `.collect()` ejecuta streaming para data > RAM | Incorrecto (el pushdown sí es automático; el streaming no) | Separar pushdown (automático) de streaming (opt-in vía `engine="streaming"`); mencionar el fallback silencioso a in-memory; `streaming=True` deprecado en 1.25.0 (aún funciona con warning), motor streaming viejo removido en 1.31.0 |
| 3 | Polars y DuckDB "stream and spill out of core" | Parcialmente correcto | Distinguir: DuckDB spillea group-by/join/sort/window por default; Polars hace streaming en batches opt-in y su spilling (1.42.0, `POLARS_OOC_MEMORY_BUDGET_MB`) es opt-in, "highly unstable" según sus autores, y no cubre group-by/equi-join/sort |

**Claims a re-chequear si esto se lee meses después:** el default de `engine` en `collect` (el propio docstring dice *"this default may change in a future release"* y el streaming *"will soon become the default engine"*); los ítems `[ ]` de la sección Out-of-core del issue #20947 (Group-by, Equi-join, Sort), que pueden cerrarse en cualquier release; y `max_temp_directory_size` de DuckDB, no verificado en esta ronda.
