# Procedural Extensions: PL/SQL, T-SQL, PL/pgSQL, and MySQL Stored Routines

Everything else in this skill has been declarative — you describe the result set and let the engine's optimizer decide how to get there. Procedural extensions break that contract on purpose: Oracle's PL/SQL, SQL Server's T-SQL, PostgreSQL's PL/pgSQL, and MySQL's stored routines all let you write branching, looping, stateful code that lives and runs inside the database. That's a real capability, not a toy — but it's also where "I know SQL" quietly turns into "I wrote application code with worse tooling, no real test framework, and none of the composability a declarative query gives you for free." The senior default is: reach for a procedural block only when the logic genuinely cannot be expressed as a query — branching business rules that span multiple statements and need to persist intermediate decisions, side effects outside the row set (writing an audit trail, calling another object, reacting to something that isn't a set of rows), and admin/DBA scripting (maintenance jobs, metadata-driven schema changes, orchestration glue). If the task is "transform this row set," a window function, a CTE, or a `MERGE` almost always beats a hand-rolled loop — that's the rest of this skill. This file covers the remaining cases where a stored routine is the right tool, and the failure modes specific to each of the four dialects.

## Block structure and fundamentals

**Oracle PL/SQL** wraps everything in a block: `[DECLARE] BEGIN ... [EXCEPTION] END;`. `DECLARE` and `EXCEPTION` are both optional; `BEGIN`/`END` are not. `CREATE PROCEDURE` and `CREATE FUNCTION` are documented in Oracle's *SQL Language Reference*, not the *PL/SQL Language Reference* — a small but real filing distinction if you go looking for the syntax page. Two anchoring types are worth knowing cold: `%TYPE` ties a variable's type to a column or to an already-declared variable, and `%ROWTYPE` ties a variable to an entire row shape (table, view, or cursor). Neither inherits the underlying column's constraints or default value — they only borrow the datatype.

```sql
DECLARE
  v_name   employees.last_name%TYPE;
  v_row    employees%ROWTYPE;
BEGIN
  SELECT last_name INTO v_name FROM employees WHERE employee_id = 100;
  SELECT * INTO v_row FROM employees WHERE employee_id = 100;
END;
```

**SQL Server T-SQL** has `CREATE PROCEDURE` and `CREATE FUNCTION`, the latter in three distinct forms: scalar, inline table-valued, and multi-statement table-valued. `GO` is a batch separator recognized only by client tools — `sqlcmd`, SSMS — and the database engine never sees it; it exists specifically because `CREATE PROCEDURE` is documented as unable to share a batch with other statements, so `GO` is how the client tells the engine "this statement ends here."

```sql
CREATE PROCEDURE dbo.usp_give_raise
  @department_id INT,
  @pct DECIMAL(5,2)
AS
BEGIN
  UPDATE employees SET salary = salary * (1 + @pct / 100)
  WHERE department_id = @department_id;
END;
GO
```

T-SQL also gives you table variables (`DECLARE @t TABLE (...)`) alongside temp tables (`#t`). Table variables carry no distribution statistics, don't trigger recompiles, don't participate in transactional rollback, and use less locking and logging than a temp table — sounds like a strict upgrade, but Microsoft's own documentation stops short of recommending them universally: it advises testing case by case and preferring temp tables once row volumes get significant, precisely because the missing statistics that make table variables "cheap" also make the optimizer's row-count estimates unreliable at scale.

**PostgreSQL** added `CREATE PROCEDURE` in **PostgreSQL 11 (October 2018)** — a genuinely recent addition, not something that's "always been there" the way `CREATE FUNCTION` has. PL/pgSQL also borrows `%TYPE` and `%ROWTYPE` historically from PL/SQL, with the same anchoring behavior described above. Why Postgres needed a second, separate object at all is a transaction-control question, covered in full in the transactions section below.

**MySQL**'s `DELIMITER` command is a workaround specific to the `mysql` command-line client, not the server or wire protocol. The CLI treats `;` as end-of-statement by default, so without redefining the delimiter it would try to run each line of a multi-statement routine body separately instead of sending the whole `CREATE PROCEDURE` as one string. Drivers and APIs — JDBC, mysql-connector-python — send the full routine body directly and never need it.

```sql
DELIMITER $$

CREATE PROCEDURE get_employee(IN emp_id INT)
BEGIN
  SELECT * FROM employees WHERE employee_id = emp_id;
END$$

DELIMITER ;
```

MySQL procedure parameters can be declared `IN`, `OUT`, or `INOUT`; function parameters cannot — a MySQL function parameter is always input-only, full stop. And MySQL genuinely has no package concept: the MySQL Reference Manual's Chapter 27, "Stored Objects," enumerates procedures, functions, triggers, events, and views — packages are absent from that list entirely, not merely unmentioned in passing. `CREATE PACKAGE` exists only in MariaDB, a separate fork with its own documentation; it is not a MySQL feature under a different name.

## Cursors, and the RBAR anti-pattern

All four dialects support the same shape — `DECLARE` a cursor, `OPEN` it, `FETCH` rows in a loop, `CLOSE` it — and each has its own idiom for detecting "no more rows":

| Dialect | End-of-cursor mechanism |
|---|---|
| Oracle PL/SQL | `EXIT WHEN cursor_name%NOTFOUND;` |
| SQL Server T-SQL | `WHILE @@FETCH_STATUS = 0` — a **connection-global** variable, shared across every cursor open on that connection, not scoped to the one cursor you just fetched from |
| PostgreSQL PL/pgSQL | the special `FOUND` variable: `EXIT WHEN NOT FOUND;` |
| MySQL | `DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;`, then check the flag |

```sql
-- Oracle PL/SQL
DECLARE
  CURSOR emp_cur IS SELECT employee_id, salary FROM employees WHERE department_id = 10;
  v_id employees.employee_id%TYPE;
  v_sal employees.salary%TYPE;
BEGIN
  OPEN emp_cur;
  LOOP
    FETCH emp_cur INTO v_id, v_sal;
    EXIT WHEN emp_cur%NOTFOUND;
    UPDATE employees SET salary = v_sal * 1.1 WHERE employee_id = v_id;
  END LOOP;
  CLOSE emp_cur;
END;
```

```sql
-- MySQL: note the cursor is declared BEFORE the handler, in the same scope — order matters
DELIMITER $$
CREATE PROCEDURE raise_dept_salaries(IN dept_id INT)
BEGIN
  DECLARE done INT DEFAULT FALSE;
  DECLARE v_id INT;
  DECLARE v_sal DECIMAL(10,2);
  DECLARE emp_cur CURSOR FOR
    SELECT employee_id, salary FROM employees WHERE department_id = dept_id;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

  OPEN emp_cur;
  read_loop: LOOP
    FETCH emp_cur INTO v_id, v_sal;
    IF done THEN LEAVE read_loop; END IF;
    UPDATE employees SET salary = v_sal * 1.1 WHERE employee_id = v_id;
  END LOOP;
  CLOSE emp_cur;
END$$
DELIMITER ;
```

MySQL's cursors are also the most restricted of the four: read-only (no `WHERE CURRENT OF`), non-scrollable, with no real name of their own (the handler's `NOT FOUND` binding is what identifies "this cursor ran out"), and only one open per prepared statement — plus the ordering rule above, which is easy to get backwards the first time.

**RBAR — Row-By-Agonizing-Row** is the term for looping over a cursor to do what a set-based statement should do instead. It is **community terminology, not vendor vocabulary** — coined by Jeff Moden on the SQLServerCentral forum in 2005 — and it should be attributed that way, not presented as something Microsoft or Oracle wrote in a manual.

Official "avoid row-by-row" guidance is uneven across the four, and the honest answer differs by engine:

- **Oracle**: yes, officially — the Bulk SQL and Bulk Binding documentation states explicitly that bulk SQL minimizes the context-switch overhead between the PL/SQL and SQL engines, with a significant improvement starting around as few as 4 rows.
- **SQL Server**: yes, in the live cursor reference documentation — it notes the tempdb worktable overhead cursors carry and that a `WHILE` loop can replace a cursor in many cases. A stronger warning exists, but only in an archived Microsoft blog post, not in the current core reference.
- **MySQL**: partial — the manual warns "for a large result set, retrieving its rows through a cursor might be slow," but that's a narrower performance note, not a general "prefer set-based SQL" recommendation.
- **PostgreSQL**: **no official equivalent statement exists**. Avoiding row-by-row cursor loops on Postgres is community wisdom, not documented guidance — the same category this skill already applies to things like cold/warm-cache benchmarking pitfalls in the Spark skill or engine-specific gotchas elsewhere in this file. Don't attribute it to the PostgreSQL manual.

None of this means a cursor is always wrong. **SQL Server's own documentation describes scenarios where cursors are not just unavoidable but necessary**, and specifically recommends *firehose* cursors — fast-forward, read-only — for those cases. **PostgreSQL's documentation describes a genuine need for cursors** too: returning a large result set from a function via a `refcursor`, or paging through results without loading the entire set into memory at once. Oracle and MySQL both describe the cursor mechanism thoroughly but don't enumerate "when you actually need one" as explicitly as SQL Server and PostgreSQL do.

## Exception handling

**Oracle PL/SQL** catches with `EXCEPTION WHEN exception_name THEN ... WHEN OTHERS THEN ...`, and raises application errors with `RAISE_APPLICATION_ERROR(error_code, message)`, where `error_code` must fall between **-20000 and -20999**. The single most notable fact in this section: **PL/SQL is the only one of the four with a compiler-enforced warning** for a common mistake here. If a `WHEN OTHERS` handler doesn't end in `RAISE` or `RAISE_APPLICATION_ERROR`, PL/SQL emits `PLW-06009` when warnings are enabled. Oracle's own documentation states the rule directly: "Avoid unhandled exceptions... Make the last statement in the OTHERS exception handler either RAISE or RAISE_APPLICATION_ERROR."

**SQL Server T-SQL** got structured `TRY...CATCH` in **SQL Server 2005**, and `THROW` in **SQL Server 2012** — and `THROW` is now Microsoft's own documented recommendation over the older `RAISERROR`: the `RAISERROR` reference page itself states, "New applications should use THROW instead of RAISERROR." Inside a `CATCH` block you get `ERROR_MESSAGE()`, `ERROR_NUMBER()`, `ERROR_SEVERITY()`, `ERROR_STATE()`, `ERROR_PROCEDURE()`, and `ERROR_LINE()`. Critically, **catching an error does not automatically return it to the caller** — a `CATCH` block that logs and does nothing else swallows the error silently; propagating it back out requires a deliberate `THROW` (or `RAISERROR`) inside the `CATCH`.

```sql
BEGIN TRY
  UPDATE accounts SET balance = balance - 100 WHERE account_id = 1;
  UPDATE accounts SET balance = balance + 100 WHERE account_id = 2;
END TRY
BEGIN CATCH
  THROW;  -- re-raises the original error; omitting this swallows it
END CATCH;
```

**PostgreSQL PL/pgSQL** uses `EXCEPTION WHEN condition THEN`, and `RAISE` has exactly six levels: `DEBUG`, `LOG`, `INFO`, `NOTICE`, `WARNING`, `EXCEPTION` — and only `EXCEPTION` actually aborts the current transaction/block. `SQLSTATE` and `SQLERRM` are available inside a handler, with richer detail available via `GET STACKED DIAGNOSTICS`. There's also a documented performance cost specific to this dialect: PostgreSQL's own docs carry an explicit tip that an `EXCEPTION` block is significantly more expensive to enter and exit than a plain block — "don't use `EXCEPTION` without need."

**MySQL** declares handlers with `DECLARE ... HANDLER FOR`, in three flavors: `CONTINUE`, `EXIT`, and `UNDO`. The one that matters most: **`UNDO` is not actually implemented**. The current MySQL manual states this outright — "Not supported" — and this has been true identically across every manual version from 5.7 through 9.7. `SIGNAL`/`RESIGNAL` were added in **MySQL 5.5**.

None of the four make safe error handling automatic. Oracle requires the compiler-flagged `RAISE`/`RAISE_APPLICATION_ERROR`; SQL Server requires a deliberate re-throw inside `CATCH`; PostgreSQL requires choosing `EXCEPTION` deliberately (and paying for it) rather than a lower `RAISE` level; MySQL requires choosing `EXIT` or writing propagation logic yourself since `UNDO` doesn't exist. Oracle is the only one of the four backed by an actual compiler warning — the other three rely entirely on the developer remembering to do the right thing.

## Transactions inside a routine

**PostgreSQL draws the cleanest, most authoritative line of the four**, and it's the reason `PROCEDURE` exists there as a separate object from `FUNCTION` at all. Postgres's own documentation states it plainly: "While a function is called as part of a query or DML command, a procedure is called in isolation using the CALL command. A procedure can commit or roll back transactions during its execution ... A function cannot do that." The underlying reason is how each is invoked — a function is called as part of a query, while a procedure is called in isolation using `CALL` — so only the procedure form has a clean point to end and start a new transaction.

The other three dialects express the same underlying split, just without a dedicated object to enforce it:

- **Oracle**: a procedure can `COMMIT`/`ROLLBACK` freely. A **function** invoked from inside a SQL statement cannot — unless it's declared with `PRAGMA AUTONOMOUS_TRANSACTION`, which starts an independent transaction nested inside the caller's. The canonical use case is logging or audit-trail writes that must survive a rollback in the calling transaction:

```sql
CREATE OR REPLACE PROCEDURE log_audit_entry(p_message VARCHAR2) IS
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  INSERT INTO audit_log (message, logged_at) VALUES (p_message, SYSDATE);
  COMMIT;  -- commits independently of whatever the caller does next
END;
```

- **SQL Server**: procedures can `COMMIT`/`ROLLBACK`, but a `ROLLBACK` always unwinds all the way to the outermost `BEGIN TRANSACTION` — there's no partial rollback to an inner savepoint by default.
- **MySQL**: procedures can commit and roll back; **functions and triggers cannot**.

## Dynamic SQL

All four vendors document the parameterized/bind form as the explicit injection defense, in their own words:

**Oracle** — `EXECUTE IMMEDIATE ... USING bind_var`. Oracle's documentation states: "the most effective way to make your PL/SQL code invulnerable to SQL injection attacks is to use bind variables."

```sql
EXECUTE IMMEDIATE
  'UPDATE employees SET salary = salary * :1 WHERE department_id = :2'
  USING p_raise_factor, p_dept_id;
```

**SQL Server** — `sp_executesql @stmt, @params, @param1 = value1`, as opposed to plain `EXEC` over a concatenated string. Microsoft's documentation: "you should parameterize your queries when using sp_executesql."

```sql
EXEC sp_executesql
  N'UPDATE employees SET salary = salary * @factor WHERE department_id = @dept',
  N'@factor DECIMAL(5,2), @dept INT',
  @factor = @raise_factor, @dept = @department_id;
```

**PostgreSQL** — PL/pgSQL's `EXECUTE ... USING`, distinct from the top-level `EXECUTE` used for prepared statements outside a function body. Documentation: it is "much less prone to SQL-injection attacks since there is no need for quoting or escaping."

```sql
EXECUTE format('UPDATE employees SET salary = salary * $1 WHERE department_id = $2')
  USING p_raise_factor, p_dept_id;
```

**MySQL** — `PREPARE stmt FROM ...; EXECUTE stmt USING @var; DEALLOCATE PREPARE stmt;`. MySQL's own documentation lists "protection against SQL injection attacks" as an explicit benefit of this form.

```sql
SET @stmt = 'UPDATE employees SET salary = salary * ? WHERE department_id = ?';
PREPARE dyn_stmt FROM @stmt;
EXECUTE dyn_stmt USING @raise_factor, @dept_id;
DEALLOCATE PREPARE dyn_stmt;
```

## T-SQL parameter sniffing

This one is specific to SQL Server — none of the other three dialects has documented equivalent behavior. The mechanism: when a procedure or parameterized query is compiled, SQL Server builds and caches an execution plan based on the parameter values it saw *that first time*. If a later call passes very different values — a value that matches 2 rows vs. one that matches 2 million — the cached plan can be badly wrong for the new call, even though the query text is identical. Microsoft's current official term for this is **"parameter sensitivity"** (still commonly called "parameter sniffing," and the term itself is not wrong — it's just been formalized under the newer name).

Documented mitigations: `OPTION (RECOMPILE)` to force a fresh plan every call, `OPTIMIZE FOR (@param = value)` to pin the compiled plan to a representative value, `OPTIMIZE FOR UNKNOWN` to compile against generic statistics instead of the actual first-seen value, the database-scoped `DISABLE_PARAMETER_SNIFFING` option, and assigning parameters to local variables inside the procedure before using them. That last option has a real tradeoff: using a local variable defeats sniffing, but the optimizer then falls back to generic heuristic row-count estimates instead of using the actual runtime value — you trade "possibly wrong for some callers" for "consistently approximate for everyone."

The tell in production is a procedure that's fast for one caller and slow for another with no code change in between — that's parameter sensitivity, not a regression.

## Oracle packages

`CREATE PACKAGE` (the public spec — signatures only) and `CREATE PACKAGE BODY` (the private implementation) is a real, current Oracle feature with **no direct equivalent in any of the other three**. This isn't a naming difference — the other engines lack the underlying structure entirely: SQL Server and PostgreSQL schemas are pure namespaces, with no spec/body split at all — everything in a schema is equally visible, there's no "private implementation hidden behind a public interface" the way a package body is hidden behind a package spec. MySQL's `CREATE SCHEMA` is a plain synonym for `CREATE DATABASE` — an unrelated concept, not a lightweight package. Don't present any of these as a rough equivalent; the honest statement is that Oracle packages are a capability the other three simply don't have.

```sql
CREATE PACKAGE emp_pkg IS
  PROCEDURE give_raise(p_emp_id NUMBER, p_pct NUMBER);
  FUNCTION get_salary(p_emp_id NUMBER) RETURN NUMBER;
END emp_pkg;

CREATE PACKAGE BODY emp_pkg IS
  PROCEDURE give_raise(p_emp_id NUMBER, p_pct NUMBER) IS
  BEGIN
    UPDATE employees SET salary = salary * (1 + p_pct / 100) WHERE employee_id = p_emp_id;
  END;

  FUNCTION get_salary(p_emp_id NUMBER) RETURN NUMBER IS
    v_salary NUMBER;
  BEGIN
    SELECT salary INTO v_salary FROM employees WHERE employee_id = p_emp_id;
    RETURN v_salary;
  END;
END emp_pkg;
```

## The senior framing

The throughline of this entire skill has been declarative SQL — describe the result, let the engine figure out the plan. Procedural extensions are the escape hatch for the narrow slice of logic that genuinely can't be a query: branching business rules that span statements, admin and DBA scripting, side effects outside the row set. They are not a tool for row-by-row data transformation — that's RBAR, and reaching for a cursor loop where a set-based statement would do is almost always the wrong call, in any of the four dialects. The same discipline about not silently swallowing an error that this section applies at the database layer — Oracle's compiler warning, SQL Server's "propagate deliberately or it's gone," PostgreSQL's explicit `EXCEPTION` cost, MySQL's missing `UNDO` — has a direct counterpart one layer up, in application code; see [production-patterns.md](../../python-data-engineering/references/production-patterns.md) in the Python skill for the same principle expressed at the pipeline level.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Reaching for a cursor loop instead of a set-based rewrite | RBAR — row-by-row processing pays per-row overhead a single statement wouldn't; official guidance to avoid it exists for Oracle and SQL Server, is partial for MySQL, and doesn't exist at all for PostgreSQL (community wisdom there) | Rewrite as a single `UPDATE`/`MERGE`/window-function query; reserve cursors for the cases each vendor documents as genuinely needed (SQL Server firehose cursors, Postgres `refcursor` paging) |
| Oracle `WHEN OTHERS` with no `RAISE` or `RAISE_APPLICATION_ERROR` | Silently swallows every unanticipated exception — and PL/SQL is the only one of the four with a compiler warning (`PLW-06009`) for exactly this | End every `WHEN OTHERS` handler in `RAISE` or `RAISE_APPLICATION_ERROR` |
| Assuming a SQL Server `CATCH` block automatically returns the error to the caller | It doesn't — an empty or logging-only `CATCH` block hides the failure entirely | Explicitly `THROW` (or `RAISERROR`) inside `CATCH` to propagate |
| Assuming a PL/pgSQL `FUNCTION` can `COMMIT`/`ROLLBACK` | Only `PROCEDURE` can — Postgres's own docs state a function cannot, by design, since it's invoked as part of a query | Use `CREATE PROCEDURE` and `CALL` when the routine needs to control transactions |
| String-concatenated dynamic SQL instead of bound parameters | Classic SQL injection surface — all four vendors document the bind/parameterized form as the explicit defense | `EXECUTE IMMEDIATE ... USING` (Oracle), `sp_executesql` (SQL Server), `EXECUTE ... USING` (PL/pgSQL), `PREPARE ... EXECUTE ... USING` (MySQL) |
| Ignoring T-SQL parameter sniffing when a procedure is fast for one caller and slow for another | The cached plan was compiled against the first-seen parameter values and may be a poor fit for others | `OPTION (RECOMPILE)`, `OPTIMIZE FOR`, `OPTIMIZE FOR UNKNOWN`, `DISABLE_PARAMETER_SNIFFING`, or local variables (accepting generic estimates as the tradeoff) |
| Assuming MySQL has package-style code organization | MySQL's Chapter 27 "Stored Objects" lists procedures, functions, triggers, events, and views — no packages; `CREATE PACKAGE` is a MariaDB-only feature | Organize MySQL routines by naming convention or schema, not a package construct that doesn't exist |
