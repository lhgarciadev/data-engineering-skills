# Especificación de Diseño: Skill `project-structure-data-engineering`
## Novena skill de dominio de la suite `data-engineering-skills` (entregada fuera del roadmap original de 8 el 2026-08-02, incorporada a él ese mismo día — ver Estado de la spec de la suite)

**Fecha:** 2026-08-02
**Responsable:** Leonardo H. García Díaz
**Estado:** Implementado y shippeado (2026-08-02) — ver `docs/superpowers/plans/2026-08-02-project-structure-skill-implementation.md` para el registro de ejecución. **Cierre adicional (2026-08-02):** se agregó una sección nueva a `package-layout.md`, "Where the orchestrator's DAG file lives" — hallazgo confirmado en ambos repos auditados (Repo A y Repo B, §3): ambos ubican los archivos de DAG de Airflow en una carpeta `airflow/dags/` de nivel superior, hermana del paquete del job, y ambos lo sincronizan vía un parámetro `dags_directory` de su pipeline CI/CD — verificado por grep sobre las copias locales de ambos repos en esta misma sesión. Contenido agregado deja explícito que el nombre de esa carpeta es una convención de repo/CI, no un requisito del propio Airflow (que lee de su `dags_folder` configurado, `airflow.cfg`/`AIRFLOW__CORE__DAGS_FOLDER`, por defecto `$AIRFLOW_HOME/dags`). Cross-link liviano agregado en `pipelines-architecture-data-engineering/references/orchestrator-selection-and-topology.md` (sección "Deployment topology") distinguiendo esa sección (componentes de infraestructura) de esta nueva (dónde vive el archivo fuente del DAG en el repo). `SKILL.md` actualizado con una fila de quick reference y una de common mistakes. Verificado: conteo de headers, balance de code fences, todos los reference files enlazados, y re-escaneo de confidencialidad en todo el repo — limpio.

**Cierre adicional (2026-08-03):** revisión de una estructura de proyecto propuesta por un colega senior del usuario, evaluada y contrastada contra el contenido ya shippeado de esta skill. Cambios aplicados a `package-layout.md`: `schemas/` agregado como capa opcional del diagrama de cuatro capas (`source_schema.py`/`target_schema.py`, el lado en-código de un contrato de datos — cross-link a `data-contracts.md`); sección de tests ampliada con el split `unit/`+`integration/` sobre el mirror 1:1 ya existente, justificando cuándo vale la pena (`transform/` es lógica pura → `unit/`; `extract/`/`load/` cruzan una frontera real de I/O → `integration/`); fila nueva en la tabla de errores comunes sobre un directorio de nivel superior `utils/`/`addons/` — el hallazgo es que el nombre genérico del directorio es el defecto, no el contenido, incluso si los archivos adentro (`connectors.py`, `logger.py`) están bien nombrados individualmente. `SKILL.md` actualizado con una fila de quick reference (`schemas/`) y la fila correspondiente de errores comunes. `data-contracts.md` recibió un puntero concreto al patrón `schemas/`. No se tocó el conteo de la suite ni el roadmap — es una mejora de contenido dentro de una skill ya entregada, no una skill nueva.

---

## 1. Contexto y objetivo

Origen: Leonardo recibió de un colega dos repos reales y privados de un producto de datos en producción, como ejemplo de estructura de paquete Python para ingesta y exposición de datos, más la recomendación de seguir FastAPI "Bigger Applications" para la parte de exposición, y de revisar las skills de `python-development` del repo `wshobson/agents` (uv, packaging, code style) como referencia adicional. Los dos repos se auditaron en detalle (ver §3) — uno resultó ser un scaffold generado por una herramienta interna de scaffolding, sin lógica de negocio real; el otro es código real en producción, con un incidente documentado y un bug activo conocido.

**Nota de confidencialidad:** ambos repos son privados y propiedad de un tercero. Ni el nombre de la empresa, ni los nombres de los repos, ni nombres de rama, ni el alias del colega que los compartió, ni ningún otro identificador interno se registran en este documento ni en ningún artefacto de esta suite — solo se documentan, ya anonimizados, los patrones estructurales genéricos observados.

Ningún skill existente de la suite cubre hoy "cómo estructuro un paquete nuevo de ingesta/transformación o de exposición de datos, de la carpeta al empaquetado": `python-data-engineering` cubre código a nivel de función/clase (OOP, decoradores, testing, idempotencia) pero no layout de repo ni empaquetado; `pipelines-architecture-data-engineering` cubre la decisión arquitectónica de servir datos vía API (`serving-pipeline-output.md`) pero no cómo estructurar el paquete que la implementa. Esta skill llena ese hueco.

Es una adición fuera del roadmap original de 8 dominios de `docs/superpowers/specs/2026-07-28-suite-skills-ingenieria-datos-design.md` — análoga al caso de "APIs" que se evaluó y descartó en la ronda de `pipelines-architecture-data-engineering` (ver esa spec, §2.1), pero con una diferencia decisiva: ahí no había caso de uso real confirmado; acá sí lo hay — un colega del equipo de Leonardo, en un contexto de producción real, comparte esta necesidad y dos ejemplos reales auditables.

## 2. Alcance y fronteras

- **Cubre**: layout de un paquete Python de ingesta/transformación (capas `config`/`extract`/`transform`/`load`, tests en espejo 1:1), empaquetado (Poetry vs. `uv`, `pyproject.toml`, fijar la versión de Python al runtime de destino), y el archivo de contrato de datos como artefacto versionado junto al código.
- **No cubre — frontera con otra skill o decisión ya tomada**:
  - **Implementación de API** (FastAPI en profundidad, REST vs. GraphQL vs. gRPC, versionado de endpoints, seguridad) — **fuera de alcance de la suite, confirmado de nuevo el 2026-08-02**: sin caso de uso real todavía (ver `pipelines-architecture-data-engineering`, spec §2.1, para el criterio original — "uso real confirmado", no especulativo). Esta skill solo referencia FastAPI "Bigger Applications" como puntero de una frase, igual que ya hace `serving-pipeline-output.md`. Si en el futuro aparece un caso de uso real, ese contenido se evalúa contra el mismo criterio — no antes.
  - **La decisión arquitectónica** de servir datos vía API vs. warehouse vs. export — ya cubierta en `pipelines-architecture-data-engineering/references/serving-pipeline-output.md`; no se duplica acá, solo cross-link.
  - **Hosting/infraestructura del paquete** (Terraform, contenedores) — pointer hacia `iac-cloud-data-engineering` (futura). Incluye explícitamente el patrón de "registro de jobs" visto en los repos auditados (un solo `locals` map en Terraform en vez de un módulo por job) — se documenta en detalle cuando esa skill se escriba.
  - **Testing e idempotencia a nivel de código** (fixtures, mocks, `hypothesis`) — ya cubierto en `python-data-engineering/references/production-patterns.md`; cross-link en vez de duplicar.
  - **Modelado de esquemas/dimensional** — `modeling-data-engineering` (futura).

## 3. Fuentes

- Dos repos reales y **privados**, propiedad de un tercero, compartidos por un colega del equipo de Leonardo únicamente como referencia de lectura — no se registra en este documento, ni en ningún otro artefacto de esta suite, ningún nombre de empresa, nombre de repo, nombre de rama, alias de persona, ID de cuenta cloud, URL interna, ni dato de negocio real. Solo se documentan, ya anonimizados, los patrones estructurales genéricos observados; identificados abajo de forma no identificable como Repo A y Repo B únicamente para diferenciarlos dentro de este documento.
  - **Repo A** — scaffold generado por una herramienta interna de scaffolding, sin lógica de negocio real; útil solo como ejemplo de estructura de repo/monorepo (Nx + Glue + Airflow + Terraform + un pipeline CI/CD).
  - **Repo B** — código real en producción, con capas `config`/`extract`/`transform`/`load`, un incidente de producción documentado (parseo de fechas) y un bug activo conocido (mismatch camelCase/snake_case en mapeo de columnas, enmascarado por un mock que reemplaza la función exacta donde vive el riesgo).
- FastAPI, "Bigger Applications - Multiple Files" — referenciado como puntero únicamente (ver §2), no como fuente de contenido extenso.
- `wshobson/agents` (MIT), `plugins/python-development/skills/` — validado por listado directo del repo (`python-project-structure`, `python-packaging`, `uv-package-manager`, `python-code-style`, entre otras): revisado como insumo adicional con atribución, sin adopción literal — mismo tratamiento que en las skills anteriores de la suite.

## 4. Estructura de archivos

```
skills/project-structure-data-engineering/
  SKILL.md
  references/
    package-layout.md
    packaging-and-tooling.md
    data-contracts.md
```

Mismo formato que el resto de la suite: overview, when to use, tabla de quick reference y tabla de common mistakes en `SKILL.md`; un archivo de reference por tema pesado.

### 4.1 `package-layout.md`

Estructura por capas para un paquete de ingesta/transformación: `config/` (identidad del job/paquete, parámetros), `extract/` (contrato con la fuente), `transform/` (única lógica de negocio real), `load/` (o un loader reutilizable con factory por formato/versión, cuando el mismo paquete escribe a más de un formato/destino) — y `tests/` en espejo 1:1 de esa estructura.

Incluye dos patrones observados y verificados en el Repo B auditado (§3), presentados de forma genérica/anonimizada, sin nombres ni lógica de negocio real:
- **Job delgado sobre librería compartida**: la lógica genérica de ETL (reutilizable entre muchos paquetes) se versiona aparte; el paquete del job solo aporta identidad + transformaciones propias.
- **Strategy para paridad local/nube**: dos implementaciones intercambiables del mismo contrato (ej. catálogo real de producción vs. catálogo local para desarrollo), elegidas una sola vez en el entrypoint según el entorno.

### 4.2 `packaging-and-tooling.md`

Poetry vs. `uv` (elegir uno, no mezclar), estructura de `pyproject.toml`, fijar la versión de Python a la versión exacta del runtime de destino (ej. el runtime de Glue/Lambda), dependencias privadas/compartidas vía git+tag. Complementado con `python-project-structure`, `python-packaging` y `uv-package-manager` de `wshobson/agents` (§3), con atribución.

### 4.3 `data-contracts.md`

El contrato de datos como artefacto YAML mínimo versionado junto al código (identificador de servicio, dominio/subdominio, consumidores, inputs/outputs esperados) — vale la pena aunque arranque casi vacío; evita que esta información viva solo en un wiki externo desincronizado.

### 4.4 Sección de exposición (dentro de `package-layout.md`, no un reference file propio)

Un párrafo, no una sección extensa, al cierre de `package-layout.md`: cuando el paquete expone datos vía API, seguir el patrón de routers-por-dominio + dependency injection de FastAPI "Bigger Applications", con cross-link a `pipelines-architecture-data-engineering/references/serving-pipeline-output.md` para la decisión de si conviene construir la API en primer lugar. Nota explícita de alcance: implementación de API fuera de alcance de la suite (ver §2). `SKILL.md` solo referencia esta sección desde su tabla de quick reference, sin repetir el contenido.

### 4.5 Common mistakes (tabla en `SKILL.md`)

- Cobertura de tests mal alcanzada en repos con más de un paquete (`[tool.coverage.run] source` apuntando a un solo paquete) — visto repetido en ambos repos auditados, indicio de defecto sistemático de plantilla, no error puntual.
- Mockear la función exacta donde vive el riesgo real (ej. una función de alineación de schema) — los tests pasan en verde mientras el bug vive en producción.
- Mismatch silencioso de convención de nombres (camelCase del origen vs. snake_case del schema final) en un mapeo que descarta en silencio columnas no declaradas.

## 5. Fuera de alcance (de esta fase)

- Implementación de API (ver §2) — sin caso de uso real confirmado, revisado 2026-08-02.
- Patrón de registro de jobs en Terraform — pointer hacia `iac-cloud-data-engineering` (futura), sin contenido hoy.
- Modelado de esquemas/dimensional — `modeling-data-engineering` (futura).

## 6. Próximos pasos

Transición a `superpowers:writing-plans` para el plan de implementación: redacción completa de `SKILL.md` + los 3 reference files, contenido final en inglés (convención ya fijada en la spec de la suite §3) con los repos fuente anonimizados, siguiendo el mismo proceso de validación liviana de discoverability y la autorevisión `writing-great-skills` ya usados en las skills anteriores.

Al cerrar, actualizar el Estado de la spec de la suite (`2026-07-28-suite-skills-ingenieria-datos-design.md`) para reflejar esta adición fuera del roadmap original de 8 dominios.
