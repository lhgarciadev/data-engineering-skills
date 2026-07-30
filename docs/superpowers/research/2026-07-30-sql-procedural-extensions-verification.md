# Research: extensiones procedurales (PL/SQL, T-SQL, PL/pgSQL, MySQL) para `dataeng-sql`

**Fecha:** 2026-07-30
**Alcance:** el equipo confirmó uso real de stored procedures en Oracle (PL/SQL) y SQL Server (T-SQL); se agrega también PostgreSQL (PL/pgSQL) y MySQL por costo marginal bajo y para evitar la asimetría de cubrir SQL declarativo en los 4 pero procedural solo en 2. Mismo nivel de profundidad que `dataeng-python`/`dataeng-sql`/`dataeng-spark`: de lo fundamental a la señal senior. 4 investigaciones en paralelo, exclusivamente contra documentación oficial: docs.oracle.com (PL/SQL Language Reference, SQL Language Reference), learn.microsoft.com (vía el MCP oficial de Microsoft Learn), postgresql.org/docs, dev.mysql.com/doc/refman. Sin fuentes secundarias, salvo donde se marca explícitamente terminología de comunidad (RBAR).

---

## 1. Fundamentos — estructura de bloque, variables, parámetros

**Oracle PL/SQL** — bloque `[DECLARE] BEGIN ... [EXCEPTION] END;` (DECLARE y EXCEPTION opcionales, BEGIN/END obligatorio). `CREATE PROCEDURE`/`CREATE FUNCTION` viven en el *SQL Language Reference*, no en el PL/SQL Language Reference. `%TYPE` ancla el tipo de una variable a una columna u otra variable ya declarada; `%ROWTYPE` ancla a una fila completa (tabla, vista o cursor) — ninguno hereda constraints ni default values de la columna. Ambos vigentes en la doc 23ai actual.

**SQL Server T-SQL** — `CREATE PROCEDURE`/`CREATE FUNCTION` (esta última en 3 formas: scalar, inline table-valued, multi-statement table-valued). `GO` es un comando del **cliente** (sqlcmd/SSMS) que nunca ve el motor — existe porque `CREATE PROCEDURE` está documentado explícitamente como no combinable con otras sentencias en el mismo batch. Table variables vs. temp tables: las table variables no tienen distribution statistics, no disparan recompiles, no participan del rollback transaccional, y usan menos locking/logging — pero la propia doc de Microsoft recomienda **probar caso por caso** y preferir temp tables cuando el volumen de filas es significativo.

**PostgreSQL** (verificación más crítica del research) — `CREATE PROCEDURE` se agregó en **PostgreSQL 11 (oct. 2018)**. La distinción central, cita textual de la doc oficial: *"A procedure can commit or roll back transactions during its execution ... A function cannot do that."* Es decir, la razón de ser de `PROCEDURE` como objeto separado de `FUNCTION` es exactamente control transaccional (ver §3 abajo). `%TYPE`/`%ROWTYPE` también existen en PL/pgSQL, prestados históricamente de PL/SQL.

**MySQL** — `DELIMITER` es una solución del **cliente `mysql` CLI**, no del protocolo/servidor: el cliente interpreta `;` como fin de sentencia por defecto, así que hay que redefinirlo temporalmente para pasarle al servidor el cuerpo completo de la rutina como un solo string. No aplica cuando un driver/API (JDBC, mysql-connector-python) envía el cuerpo directamente. Diferencia de parámetros: `proc_parameter` admite `IN`/`OUT`/`INOUT`; `func_parameter` no — los parámetros de función son siempre de entrada. **Packages: ausencia real confirmada**, no "no verificable" — el capítulo 27 "Stored Objects" del manual de MySQL enumera procedure/function/trigger/event/view sin mencionar packages en ningún punto; `CREATE PACKAGE` existe solo en MariaDB (fork distinto, documentación separada), no en MySQL.

## 2. Control de flujo, cursores, y el anti-patrón RBAR

Patrón cursor DECLARE/OPEN/FETCH/CLOSE confirmado en los 4, cada uno con su propio mecanismo de "no more rows":

| Dialecto | Condición de fin |
|---|---|
| PL/SQL | `EXIT WHEN cursor_name%NOTFOUND;` |
| T-SQL | `WHILE @@FETCH_STATUS = 0` (variable global de conexión, compartida entre todos los cursores abiertos) |
| PL/pgSQL | variable especial `FOUND`: `EXIT WHEN NOT FOUND;` |
| MySQL | `DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;` + chequeo de la bandera |

**Restricciones de cursores en MySQL** (más limitado que los otros 3): solo lectura (no `WHERE CURRENT OF`), no scrollable, sin nombre real (el handler statement actúa como ID), un solo cursor abierto por prepared statement, y — regla de orden de declaración poco intuitiva — los cursores deben declararse *antes* que los handlers en el mismo scope. La propia doc de MySQL además advierte: "for a large result set, retrieving its rows through a cursor might be slow."

**RBAR (Row-By-Agonizing-Row)** — término de comunidad (Jeff Moden, foro SQLServerCentral, 2005), **no** vocabulario de ningún vendor — así debe atribuirse en el skill. Guía oficial "evitar fila-por-fila" varía por motor:
- **Oracle**: sí, oficial — la doc de "Bulk SQL and Bulk Binding" dice explícitamente que el bulk SQL minimiza el overhead de context-switching entre PL/SQL y SQL, con mejora significativa desde ~4 filas.
- **SQL Server**: sí, en la referencia viva de cursors (menciona overhead de tempdb worktables y que un `WHILE` puede reemplazar un cursor); una advertencia más fuerte solo existe en un blog archivado de Microsoft (no en la referencia core).
- **MySQL**: parcial — solo la advertencia de performance citada arriba, no una recomendación general "preferir set-based".
- **PostgreSQL**: **sin guía oficial equivalente** — es sabiduría de comunidad para Postgres, igual que el pitfall de cold/warm cache en Spark. No atribuir a la doc oficial.

**Cuándo un cursor SÍ es la herramienta correcta**: SQL Server documenta explícitamente que "hay escenarios donde los cursores no solo son inevitables, son necesarios" (recomienda cursores *firehose*: fast-forward, read-only). PostgreSQL documenta la necesidad genuina de cursores para devolver result sets grandes desde una función (`refcursor`) o paginar sin cargar todo en memoria. Oracle/MySQL describen el mecanismo pero no enumeran tan explícitamente cuándo es necesario vs. anti-patrón.

## 3. Manejo de excepciones

- **Oracle PL/SQL**: `EXCEPTION WHEN ex THEN ... WHEN OTHERS THEN ...`; `RAISE_APPLICATION_ERROR(error_code, message)` con `error_code` en **-20000 a -20999**. **Único motor con advertencia de compilador explícita**: si `WHEN OTHERS` no termina en `RAISE` o `RAISE_APPLICATION_ERROR`, PL/SQL emite el warning `PLW-06009` (con warnings habilitados) — la doc oficial lo dice literalmente: "Avoid unhandled exceptions... Make the last statement in the OTHERS exception handler either RAISE or RAISE_APPLICATION_ERROR."
- **SQL Server T-SQL**: `TRY...CATCH` desde **SQL Server 2005**; `THROW` desde **SQL Server 2012** — la propia página de referencia de `RAISERROR` dice: "New applications should use THROW instead of RAISERROR." `THROW` es la recomendación vigente. Funciones disponibles en el `CATCH`: `ERROR_MESSAGE()`, `ERROR_NUMBER()`, `ERROR_SEVERITY()`, `ERROR_STATE()`, `ERROR_PROCEDURE()`, `ERROR_LINE()`. La doc también aclara: los errores atrapados en `CATCH` **no** se devuelven automáticamente a la aplicación llamadora — hay que propagarlos deliberadamente.
- **PostgreSQL PL/pgSQL**: `EXCEPTION WHEN condition THEN`; niveles de `RAISE` exactos: `DEBUG, LOG, INFO, NOTICE, WARNING, EXCEPTION` (solo `EXCEPTION` aborta). `SQLSTATE`/`SQLERRM` disponibles dentro del handler; detalle enriquecido vía `GET STACKED DIAGNOSTICS`. La doc trae un **Tip** de performance explícito: un bloque con `EXCEPTION` es significativamente más caro de entrar/salir que uno sin — "don't use EXCEPTION without need."
- **MySQL**: `DECLARE ... HANDLER FOR` con 3 tipos — `CONTINUE`, `EXIT`, `UNDO`. **`UNDO` no está implementado** — la doc actual lo dice literalmente "Not supported" (idéntico en manuales 5.7 a 9.7). `SIGNAL`/`RESIGNAL` (verificado vía worklog de ingeniería `WL#2110`, no la página de doc versionada — las URLs versionadas de MySQL redirigen silenciosamente a la versión actual y no sirven como evidencia de fecha) confirmado agregado en **MySQL 5.5**.

**Síntesis cross-cutting**: ninguno de los 4 motores hace el manejo seguro de errores automático — cada uno exige un acto deliberado (RAISE/RAISE_APPLICATION_ERROR, THROW, re-signal, o código de propagación) para no tragarse un error en silencio. Oracle es el único respaldado por una advertencia de compilador.

## 4. Transacciones, SQL dinámico, performance, packages

**Transacciones dentro de una rutina**: patrón compartido entre los 4 — una *procedure* puede hacer COMMIT/ROLLBACK, una *function* generalmente no (Oracle: función invocada desde SQL no puede, salvo `PRAGMA AUTONOMOUS_TRANSACTION`, usado para logging/auditoría que sobrevive un rollback del caller; SQL Server: sí, pero el rollback siempre deshace hasta el `BEGIN TRANSACTION` más externo; **PostgreSQL: la razón de ser de `PROCEDURE` como objeto separado**, ver §1; MySQL: procedures sí, functions/triggers no).

**SQL dinámico** — los 4 vendors recomiendan explícitamente la forma parametrizada/bind para evitar injection, con cita textual propia:
- Oracle: `EXECUTE IMMEDIATE ... USING bind_var` — "the most effective way to make your PL/SQL code invulnerable to SQL injection attacks is to use bind variables."
- SQL Server: `sp_executesql @stmt, @params, @param1=value1` — "you should parameterize your queries when using sp_executesql."
- PostgreSQL: `EXECUTE command-string USING expr` (distinto del `EXECUTE` top-level de prepared statements) — "much less prone to SQL-injection attacks since there is no need for quoting or escaping."
- MySQL: `PREPARE stmt FROM ...; EXECUTE stmt USING @var;` — doc propia lista "protection against SQL injection attacks" como beneficio explícito.

**Parameter sniffing (T-SQL)** — terminología oficial actual: "parameter sensitivity" (alias común "parameter sniffing"). El plan se compila/cachea según los valores de parámetro vistos en ese momento, lo cual puede ser subóptimo después. Mitigaciones documentadas: `OPTION (RECOMPILE)`, `OPTIMIZE FOR (<param>=<value>)`, `OPTIMIZE FOR UNKNOWN`, `DISABLE_PARAMETER_SNIFFING`, variables locales (con el trade-off de que el optimizer cae a estimaciones heurísticas genéricas en vez de sniffear el valor real).

**Packages de Oracle** — `CREATE PACKAGE`/`CREATE PACKAGE BODY` (spec pública + body privado) es una feature real y vigente, **sin equivalente directo en ninguno de los otros 3**: en SQL Server y Postgres los schemas son solo namespaces (sin split spec/body); en Postgres el análogo más cercano es una extensión (`CREATE EXTENSION`), que es una unidad de empaquetado/instalación/versión, no una interfaz pública/privada; en MySQL `CREATE SCHEMA` es literalmente sinónimo de `CREATE DATABASE` — un concepto no relacionado.

---

## Resumen de acciones para `procedural-extensions.md`

Todo lo anterior queda **confirmado contra documentación oficial**, sin necesidad de correcciones — construir el archivo directamente sobre esta base. Puntos a destacar como contenido "senior":
1. RBAR y cuándo un cursor es la herramienta correcta vs. anti-patrón — el insight central del archivo.
2. La distinción function-vs-procedure de Postgres para control transaccional — la razón más nítida y mejor verificada de todo el research, generalizable al patrón que Oracle/MySQL aplican a sus propias funciones/triggers.
3. Parameter sniffing como el gotcha de performance más específico de T-SQL, sin concepto equivalente documentado en los otros 3.
4. Packages de Oracle como concepto genuinamente sin par — no forzar una equivalencia con schemas/extensions.
5. Cross-link a `dataeng-python/references/production-patterns.md` para la discusión de manejo de errores (mismo principio — no tragarse errores en silencio — expresado de forma distinta en cada capa).

**Nota de honestidad epistémica**: RBAR y la falta de guía oficial "evitar cursores" en PostgreSQL son sabiduría de comunidad/de motor específico, no vocabulario universal de vendor — presentarlos así, mismo criterio que "Catalyst" en Spark o el pitfall de cold/warm cache.
