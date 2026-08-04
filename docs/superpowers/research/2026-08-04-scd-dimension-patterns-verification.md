# Research: surrogate keys, SCD Tipos 0-6, dimensiones/hechos de llegada tardía, conformed dimensions/bus matrix y patrones especiales de dimensión

**Fecha:** 2026-08-04
**Alcance:** verificación de 7 bloques de claims para el futuro reference file `scd-and-dimension-patterns.md` del skill `modeling-data-engineering` (spec: `docs/superpowers/specs/2026-08-04-modeling-skill-design.md` §2.2, R2): (1) surrogate keys — las tres razones de Kimball para usarlas en vez de la natural/business key; (2) SCD Tipos 0, 1, 2, 3; (3) **verificación con cuidado especial** de SCD Tipo 4 y Tipo 6 (el borrador afirma "Tipo 6 = híbrido 1+2+3", hay que confirmar si es terminología propia de Kimball Group o si viene de otra parte); (4) late-arriving dimensions (placeholder/inferred member); (5) **late-arriving facts** — el hueco específico que este research debe llenar, ya que `pipelines-architecture-data-engineering/references/idempotency-and-backfills.md` líneas 46-48 promete este patrón y el borrador de Leonardo solo cubre dimensiones de llegada tardía, no hechos; (6) conformed dimensions y el bus matrix de Kimball; (7) degenerate/junk/role-playing dimension y bridge table. Fuentes: **kimballgroup.com** (fetch directo de HTML y de un PDF oficial, con extracción de texto vía `pdftotext -layout` para evitar pérdida de contenido en el resumen automático de la herramienta de fetch), autoría verificada de cada pieza (Ralph Kimball como autor original en varios artículos, Margy Ross —presidenta de Kimball Group y coautora de *The Data Warehouse Toolkit*— en el Design Tip sobre Tipo 6). No se consultó el texto del libro *The Data Warehouse Toolkit* en sí (no disponible en este entorno) — donde el research se apoya en la formalización de 2013 (3ª edición del libro), se cita en su lugar el whitepaper y el Design Tip de Kimball Group que documentan esa misma formalización, ambos de acceso abierto.

---

## 1. Surrogate keys — las tres razones de Kimball

**VEREDICTO: las tres razones del borrador están confirmadas contra el artículo original de Ralph Kimball (1998) y contra el whitepaper oficial de Kimball Group (2013) — con un matiz de honestidad importante: el propio Kimball marca la razón de rendimiento (b) como una sospecha suya no demostrada, no como un hecho medido.**

Fuente primaria principal: Ralph Kimball, ["Surrogate Keys"](https://www.kimballgroup.com/1998/05/surrogate-keys/), Kimball Group, 2 de mayo de 1998 (fetch directo del HTML, extracción propia de texto).

### 1.1 Regla general

> "Every join between dimension tables and fact tables in a data warehouse environment should be based on surrogate keys, not natural keys."

### 1.2 Razón (a) — desacopla el warehouse de los cambios de clave del sistema origen, y permite integrar múltiples sistemas origen con distintos esquemas de ID

> "As the data warehouse manager, you need to keep your keys independent from the production keys. Production has different priorities from you."

Con una lista explícita de formas en que producción "pisa los dedos del pie" del warehouse, incluida esta — la cita exacta para el caso de fusión de sistemas de origen:

> "Your company has just made an acquisition, and you need to merge more than a million new customers into the master customer list. You will now need to extract from two production systems, but the newly acquired production system has nasty customer keys that don't look remotely like the others."

El whitepaper de 2013 confirma la misma razón, en lenguaje más formal:

> "This primary key cannot be the operational system's natural key because there will be multiple dimension rows for that natural key when changes are tracked over time. In addition, natural keys for a dimension may be created by more than one source system, and these natural keys may be incompatible or poorly administered."

Fuente: [Kimball Group, *Kimball Dimensional Modeling Techniques* (whitepaper, PDF)](https://www.kimballgroup.com/wp-content/uploads/2013/08/2013.09-Kimball-Dimensional-Modeling-Techniques11.pdf), sección "Dimension Surrogate Keys", p.7 (fetch directo del PDF, texto extraído con `pdftotext -layout` porque la herramienta de fetch estándar no logró leer el binario).

### 1.3 Razón (b) — joins de enteros son más rápidos: CONFIRMADA, pero con la propia honestidad de Kimball de que es una sospecha no probada

> "The final reason I can think of for surrogate keys is one that I strongly suspect but have never proven. Replacing big, ugly natural keys and composite keys with beautiful, tight integer surrogate keys is bound to improve join performance. The storage requirements are reduced, and the index lookups would seem to be simpler. I would be interested in hearing from anyone who has harvested a performance boost by replacing big ugly fat keys with anonymous integer keys."

Misma fuente (1998). **Este es un hallazgo importante para el skill**: Kimball no presenta esta razón como un hecho medido — literalmente dice "sospecho pero nunca lo he probado". El skill debe presentar esta razón con la misma honestidad (es una razón real y ampliamente aceptada, pero el propio Kimball la marcó como no verificada empíricamente por él en 1998), no como si Kimball la hubiera demostrado con benchmarks.

Complementariamente, sobre almacenamiento (relacionado pero no idéntico al argumento de velocidad):

> "You may be able to save substantial storage space with integer-valued surrogate keys... The beauty of a four-byte integer key is that it can represent more than 2 billion different values."

### 1.4 Razón (c) — habilita SCD Tipo 2 (múltiples filas versionadas por natural key): CONFIRMADA

> "Usually, when the data warehouse administrator encounters a changed description in a dimension record such as product or customer, the correct response is to issue a new dimension record. But to do this, the data warehouse must have a more general key structure. Hence the need for a surrogate key."

Misma fuente (1998). El whitepaper de 2013 lo reafirma en el mismo párrafo citado en 1.2: "there will be multiple dimension rows for that natural key when changes are tracked over time."

### 1.5 Nota adicional no pedida explícitamente pero relevante para el skill

El mismo artículo de 1998 ya anticipa el patrón de "unknown member"/inferred member (relevante para §4 y §5 de este research): describe la necesidad de una surrogate key especial para "the customer identification has not taken place yet" o "no customer is possible in this situation" — es decir, el mismo problema de placeholder que resuelven las secciones de late-arriving dimension/fact más abajo, ya está señalado por Kimball desde el artículo original de surrogate keys.

---

## 2. SCD Tipos 0, 1, 2 y 3

**VEREDICTO: los cuatro tipos están confirmados palabra por palabra contra el whitepaper oficial de Kimball Group.**

Fuente: [Kimball Group, *Kimball Dimensional Modeling Techniques* (whitepaper, PDF)](https://www.kimballgroup.com/wp-content/uploads/2013/08/2013.09-Kimball-Dimensional-Modeling-Techniques11.pdf), sección "Slowly Changing Dimension Techniques", pp. 11-12.

| Tipo | Cita textual exacta |
|---|---|
| **Tipo 0 — Retain Original** | "With slowly changing dimension type 0, the dimension attribute value never changes, so facts are always grouped by this original value. Type 0 is appropriate for any attribute labeled 'original,' such as a customer's original credit score or a durable identifier. It also applies to most attributes in a date dimension." |
| **Tipo 1 — Overwrite** | "With slowly changing dimension type 1, the old attribute value in the dimension row is overwritten with the new value; type 1 attributes always reflects the most recent assignment, and therefore this technique destroys history." |
| **Tipo 2 — Add New Row** | "Slowly changing dimension type 2 changes add a new row in the dimension with the updated attribute values. This requires generalizing the primary key of the dimension beyond the natural or durable key because there will potentially be multiple rows describing each member. When a new row is created for a dimension member, a new primary surrogate key is assigned and used as a foreign key in all fact tables from the moment of the update until a subsequent change creates a new dimension key and updated dimension row. A minimum of three additional columns should be added to the dimension row with type 2 changes: 1) row effective date or date/time stamp; 2) row expiration date or date/time stamp; and 3) current row indicator." |
| **Tipo 3 — Add New Attribute** | "Slowly changing dimension type 3 changes add a new attribute in the dimension to preserve the old attribute value; the new value overwrites the main attribute as in a type 1 change. This kind of type 3 change is sometimes called an alternate reality. A business user can group and filter fact data by either the current value or alternate reality. This slowly changing dimension technique is used relatively infrequently." |

**Confirmaciones directas de los detalles del borrador**:
- Tipo 2 = "cerrar fila actual con end-date/is_current flag, insertar fila nueva con nueva surrogate key" — **confirmado literalmente**: las tres columnas exactas son "row effective date", "row expiration date" y "current row indicator", más una "new primary surrogate key" para la fila nueva.
- Tipo 2 como "el caballo de batalla" — el whitepaper no usa esa expresión exacta ("workhorse"), pero sí lo trata como el mecanismo base sobre el cual se construyen los Tipos 4/5/6/7 (ver §3) — es una caracterización razonable del borrador, no una cita textual de Kimball.

**Matiz sobre Tipo 3 — "limitado a un solo cambio de historia"**: el whitepaper no usa la frase "limited to one change of history" verbatim. Lo que dice literalmente es que se añade **una** columna nueva para preservar el valor anterior ("add a new attribute... to preserve the old attribute value"). La limitación a "un solo cambio" es una inferencia directa y correcta de esa definición (una columna adicional = un valor previo, no un historial arbitrario), no una cita textual — el skill puede seguir afirmándolo, pero como interpretación de la mecánica descrita, no como cita de Kimball.

---

## 3. SCD Tipo 4 y Tipo 6 — verificación con cuidado especial

**VEREDICTO GENERAL: Tipo 4 está confirmado sin matices. Tipo 6 está confirmado como término propio y numerado oficialmente por Kimball Group — pero la afirmación del borrador necesita una corrección importante: Kimball Group NO se atribuye la autoría del término ni del mnemónico "1+2+3=6". Su propio Design Tip dice explícitamente que el nombre fue sugerido por "an HP engineer in 2000" — una persona externa y sin nombre, no Ralph Kimball ni Margy Ross. No se encontró ningún rastro, ni en fuentes de Kimball Group ni en ninguna otra fuente consultada, de que el origen se deba a alguien llamado "Bob Jarka"; esa atribución específica no se pudo confirmar en ninguna parte.**

### 3.1 Tipo 4 — mini-dimensión separada: CONFIRMADO

> "Slowly changing dimension type 4 is used when a group of attributes in a dimension rapidly changes and is split off to a mini-dimension. This situation is sometimes called a rapidly changing monster dimension. Frequently used attributes in multimillion-row dimension tables are mini-dimension design candidates, even if they don't frequently change. The type 4 mini-dimension requires its own unique primary key; the primary keys of both the base dimension and mini-dimension are captured in the associated fact tables."

Fuente: mismo whitepaper, p.12. Coincide exactamente con la descripción del borrador: mover el historial (de atributos que cambian rápido) a una tabla de mini-dimensión separada, referenciada aparte desde la fact table.

### 3.2 Tipo 6 — dónde vive el término, y quién dice qué

Hay **dos fuentes de Kimball Group** que tratan Tipo 6, con un contraste revelador entre ellas:

**(A) El whitepaper canónico (2013)** — define Tipo 6 sin ninguna historia de origen ni mnemónico:

> "Like type 5, slowly changing dimension type 6 also delivers both historical and current dimension attribute values. Type 6 builds on the type 2 technique by also embedding current type 1 versions of the same attributes in the dimension row so that fact rows can be filtered or grouped by either the type 2 attribute value in effect when the measurement occurred or the attribute's current value. In this case, the type 1 attribute is systematically overwritten on all rows associated with a particular durable key whenever the attribute is updated."

Fuente: mismo whitepaper, p.13.

**(B) Design Tip #152** (Kimball Group, febrero 2013, autora: **Margy Ross**, presidenta de Kimball Group y coautora de *The Data Warehouse Toolkit*) — sí incluye la historia de origen y el mnemónico, verificado verbatim mediante fetch directo del HTML:

> "Type 6 builds on the type 2 technique by also embedding current attributes in the dimension so that fact rows can be filtered or grouped by either the type 2 value in effect when the measurement occurred or the attribute's current value. **The type 6 moniker was suggested by an HP engineer in 2000 because it's a type 2 row with a type 3 column that's overwritten as a type 1; both 2 + 3 + 1 and 2 x 3 x 1 equal 6.**"

Fuente: [Kimball Group, "Design Tip #152 Slowly Changing Dimension Types 0, 4, 5, 6 and 7"](https://www.kimballgroup.com/2013/02/design-tip-152-slowly-changing-dimension-types-0-4-5-6-7/), autora Margy Ross (fetch directo, verificado por extracción de HTML propia, no solo por resumen automático).

El mismo Design Tip da contexto explícito sobre por qué estos tipos se numeraron formalmente hasta 2013:

> "The following type 5, 6, and 7 techniques are hybrids that combine the basics to support the common requirement to both accurately preserve historical attribute values, plus report historical facts according to current attribute values... [these correspond] to several techniques that have been described, but not precisely labeled in the past. Our hope is that more specific technique names will facilitate clearer communication between DW/BI team members."

### 3.3 Veredicto puntual sobre "Tipo 6 = híbrido 1+2+3"

- **El mnemónico "1+2+3=6" SÍ es un término/mnemónico que Kimball Group usa en su propio material publicado** (Design Tip #152, kimballgroup.com) — esto corrige cualquier duda de que fuera solo una síntesis de terceros. La cita textual usa la forma "2 + 3 + 1" (y también da la variante "2 × 3 × 1") en vez de "1 + 2 + 3", pero es aritméticamente la misma afirmación.
- **Corrección importante al borrador**: Kimball Group **no se atribuye haber acuñado el término**. Su propio texto dice explícitamente que "the type 6 moniker was **suggested by an HP engineer in 2000**" — es decir, según el propio Kimball Group, el nombre "Tipo 6" se originó fuera de Kimball Group, en la práctica de un ingeniero de HP (sin nombre, no identificado en ninguna fuente consultada), años antes de que Kimball Group lo formalizara y numerara oficialmente en la 3ª edición de *The Data Warehouse Toolkit* (2013). El borrador, si presenta "1+2+3=6" como si fuera una invención propia de Ralph Kimball, sería impreciso — lo correcto es decir que **Kimball Group adoptó, documentó y numeró oficialmente un término que, por su propio relato, ya circulaba en la práctica de la industria desde el año 2000**.
- **Sobre "Bob Jarka" como posible originador**: se buscó explícitamente este nombre en conexión con SCD Tipo 6, en varias variantes de búsqueda. **No se encontró ninguna fuente — ni de Kimball Group, ni de ningún blog, foro, o artículo técnico— que mencione a alguien llamado "Bob Jarka" en relación con este término.** La única atribución documentable, y viene directamente de Kimball Group, es "an HP engineer" sin nombre. Esta atribución específica queda marcada como **no confirmada / no encontrada** — no se debe usar ese nombre en el skill salvo que aparezca una fuente verificable adicional.
- **Sobre si el término está "contestado"**: no está contestado en el sentido de que exista desacuerdo sobre su definición — múltiples fuentes secundarias (IRI, Iteration Insights, foros de práctica) coinciden con la definición de Kimball Group. Lo que sí vale la pena notar es que el mnemónico y la historia de origen aparecen en un Design Tip (artículo de blog corto, tono informal) y **no** en el whitepaper de referencia más formal — es decir, es contenido real de Kimball Group, pero de un registro más anecdótico/informal que la definición técnica en sí, que si aparece igual en ambas fuentes.

### 3.4 Contexto adicional útil para el skill (no pedido explícitamente, pero clarifica el vecindario de Tipo 6)

Para evitar que el skill confunda Tipo 6 con Tipo 5 o Tipo 7 (ambos también híbridos, mencionados en la misma familia):

> Tipo 5: "The type 5 technique builds on the type 4 mini-dimension by embedding a 'current profile' mini-dimension key in the base dimension that's overwritten as a type 1 attribute. This approach [is] called type 5 because 4 + 1 equals 5..."

> Tipo 7: "With type 7, the fact table contains dual foreign keys for a given dimension: a surrogate key linked to the dimension table where type 2 attributes are tracked, plus the dimension's durable supernatural key linked to the current row in the type 2 dimension to present current attribute values. Type 7 delivers the same functionality as type 6, but it's accomplished via dual keys instead of physically overwriting the current attributes with type 6."

Fuente: mismo Design Tip #152 y whitepaper. Esto confirma que la familia de mnemónicos por suma ("4+1=5", "2+3+1=6") es un patrón real y consistente en el propio material de Kimball Group, no una invención aislada para el Tipo 6.

---

## 4. Late-arriving dimensions (dimensiones de llegada tardía)

**VEREDICTO: confirmado exactamente contra el whitepaper oficial de Kimball Group — placeholder row con naturales keys sin resolver, valores genéricos, actualización posterior vía overwrite Tipo 1.**

> "Sometimes the facts from an operational business process arrive minutes, hours, days, or weeks before the associated dimension context. For example, in a real-time data delivery situation, an inventory depletion row may arrive showing the natural key of a customer committing to purchase a particular product. In a real-time ETL system, this row must be posted to the BI layer, even if the identity of the customer or product cannot be immediately determined. In these cases, special dimension rows are created with the unresolved natural keys as attributes. Of course, these dimension rows must contain generic unknown values for most of the descriptive columns; presumably the proper dimensional context will follow from the source at a later time. **When this dimensional context is eventually supplied, the placeholder dimension rows are updated with type 1 overwrites.** Late arriving dimension data also occurs when retroactive changes are made to type 2 dimension attributes. In this case, a new row needs to be inserted in the dimension table, and then the associated fact rows must be restated."

Fuente: mismo whitepaper, sección "Late Arriving Dimensions", p.20.

**Nota terminológica**: el texto de Kimball Group aquí usa "special dimension rows" / "placeholder dimension rows", **no** la frase literal "inferred member". El término "inferred member" sí es terminología de Kimball ampliamente citada (aparece en el capítulo de subsistemas de ETL de *The Data Warehouse Toolkit*, 3ª edición, según múltiples fuentes secundarias consistentes — no verificado aquí verbatim contra el libro por no tener acceso a su texto), y es también el nombre que adoptó Microsoft para el mismo patrón en SSAS/SSIS ("Inferred Member"). El skill puede usar "inferred member"/"placeholder row" de forma intercambiable — son el mismo patrón — pero si cita textualmente a Kimball Group desde una fuente web abierta, la cita exacta usa "placeholder", no "inferred member".

**Confirmación adicional (Ralph Kimball, 2004) de que este mismo patrón tiene un segundo nombre en el vocabulario propio de Kimball** — ver §5.2 más abajo: Ralph Kimball llama a este mismo escenario, visto desde el lado del hecho en vez del lado de la dimensión, **"Early Arriving Facts"**.

---

## 5. Late-arriving facts (hechos de llegada tardía) — el hueco a llenar

**VEREDICTO: confirmado con una fuente primaria excelente — un Design Tip de Ralph Kimball mismo, dedicado exactamente a este problema, que además conecta explícitamente el patrón con la necesidad de buscar la fila de dimensión Tipo 2 vigente en la fecha de negocio histórica (no la fila vigente actual).**

Este es el bloque que llena el forward-pointer pendiente de `pipelines-architecture-data-engineering/references/idempotency-and-backfills.md` (líneas 46-48), que promete "late-arriving-fact patterns" sin que existiera aún el reference file que los cubriera. Dos fuentes de Kimball Group tratan esto — una es parte del whitepaper general, la otra es un Design Tip dedicado exclusivamente al problema.

### 5.1 Definición en el whitepaper oficial (2013)

> "A fact row is late arriving if the most current dimensional context for new fact rows does not match the incoming row. This happens when the fact row is delayed. In this case, the relevant dimensions must be searched to find the dimension keys that were effective when the late arriving measurement event occurred."

Fuente: [Kimball Group, *Kimball Dimensional Modeling Techniques* (whitepaper, PDF)](https://www.kimballgroup.com/wp-content/uploads/2013/08/2013.09-Kimball-Dimensional-Modeling-Techniques11.pdf), sección "Late Arriving Facts", p.17.

### 5.2 Tratamiento dedicado por Ralph Kimball — Design Tip #57 (2004): la conexión explícita con SCD Tipo 2

> "For several years, we have been aware of special modifications to these procedures to deal with **Late Arriving Facts, namely fact records that come into the warehouse very much delayed. This is a messy situation because we have to search back in history within the data warehouse to decide how to assign the right dimension keys that were in effect when the activity occurred at the right point in the past.**"

Fuente: Ralph Kimball, ["Kimball Design Tip #57: Early Arriving Facts"](http://www.kimballgroup.com/wp-content/uploads/2012/05/DT57EarlyArriving.pdf), Kimball Group, 2 de agosto de 2004 (fetch directo del PDF, `pdftotext -layout`).

**Esta es la cita que confirma exactamente lo que pide el punto 5 del research**: el propio Ralph Kimball, en su propio artículo, dice literalmente que un hecho de llegada tardía obliga a "buscar hacia atrás en la historia" para encontrar "las claves de dimensión que estaban vigentes cuando la actividad ocurrió, en el punto correcto del pasado" — es decir, exactamente el mecanismo de "buscar la fila de dimensión Tipo 2 vigente en la fecha de negocio del hecho, no la fila actual" que describe el borrador. La conexión con SCD Tipo 2 no es una inferencia del research — está en la cita misma: "the right dimension keys that were in effect" solo tiene sentido como concepto si la dimensión tiene múltiples versiones vigentes en distintas fechas, que es exactamente lo que Tipo 2 provee (effective date / expiration date / current row indicator, ver §2).

El mismo Design Tip #57 remite a un artículo previo de Kimball con más detalle ("Backward in Time", *Intelligent Enterprise*, 2000) — el enlace citado en el PDF (`www.intelligententerprise.com/000929/webhouse.jhtml`) ya no resuelve (el dominio dejó de existir), así que se marca como referencia histórica mencionada por Kimball, no como fuente verificada de forma independiente en este research.

### 5.3 Distinción de vocabulario importante que el skill debe hacer explícita: "late arriving fact" ≠ "early arriving fact"

Este Design Tip #57 es valioso porque, además de confirmar late-arriving facts, **aclara por qué el borrador no debe confundir esto con "late arriving dimension" (§4)** — son conceptos distintos y complementarios, y Ralph Kimball los nombra de forma explícita y simétrica en el mismo artículo:

> "If we have Late Arriving Facts, is it possible to have Early Arriving Facts? ... An early arriving fact takes place when the activity measurement arrives at the data warehouse without its full context."

Es decir, en el vocabulario propio de Kimball:
- **"Late arriving fact"** (Kimball Group, whitepaper p.17; Kimball, Design Tip #57) = el **hecho** llega tarde respecto a su fecha de negocio real; la dimensión ya tiene historial completo (Tipo 2) y hay que ubicar la versión correcta retroactivamente. **Este es el patrón que pide el punto 5 de este research y el que faltaba en el borrador de Leonardo.**
- **"Early arriving fact" / "late arriving dimension"** (mismo Design Tip #57; y whitepaper p.20, §4 de este research) = el **hecho** llega antes de que exista el contexto de dimensión; se resuelve con placeholder/inferred member y overwrite Tipo 1 posterior. Este es el único de los dos que el borrador de Leonardo ya cubría.

El propio Design Tip #57 confirma que el mecanismo de resolución de "early arriving facts" (visto del lado dimensión) es el mismo overwrite Tipo 1 descrito en §4:

> "Finally, if we believe that the Customer is new, we assign a new Customer surrogate key with a set of dummy attribute values in a new Customer dimension record. We then return to this dummy dimension record at a later time and make Type 1 (overwrite) changes to its attributes when we get more complete information on the new Customer."

**Acción para el skill**: el reference file debe presentar ambos patrones lado a lado, con esta distinción explícita de vocabulario (hecho tardío vs. dimensión tardía / hecho temprano), citando ambas fuentes — el whitepaper para la definición general y el Design Tip #57 de Ralph Kimball para el mecanismo detallado y la simetría conceptual.

---

## 6. Conformed dimensions y el bus matrix

**VEREDICTO: confirmado palabra por palabra contra el whitepaper oficial de Kimball Group, incluida la relación con "drill-across" y la estructura exacta filas=procesos de negocio / columnas=dimensiones.**

### 6.1 Conformed dimensions

> "Dimension tables conform when attributes in separate dimension tables have the same column names and domain contents. Information from separate fact tables can be combined in a single report by using conformed dimension attributes that are associated with each fact table. When a conformed attribute is used as the row header (that is, the grouping column in the SQL query), the results from the separate fact tables can be aligned on the same rows in a drill-across report. This is the essence of integration in an enterprise DW/BI system. Conformed dimensions, defined once in collaboration with the business's data governance representatives, are reused across fact tables; they deliver both analytic consistency and reduced future development costs because the wheel is not repeatedly re-created."

Fuente: [Kimball Group, *Kimball Dimensional Modeling Techniques* (whitepaper, PDF)](https://www.kimballgroup.com/wp-content/uploads/2013/08/2013.09-Kimball-Dimensional-Modeling-Techniques11.pdf), sección "Conformed Dimensions", p.10.

**Confirma exactamente** la afirmación del borrador: una dimensión compartida idénticamente entre varias fact tables habilita "drill-across" para comparar métricas de distintos procesos de negocio.

### 6.2 Enterprise Data Warehouse Bus Architecture / Bus Matrix

> "The enterprise data warehouse bus architecture provides an incremental approach to building the enterprise DW/BI system. This architecture decomposes the DW/BI planning process into manageable pieces by focusing on business processes, while delivering integration via standardized conformed dimensions that are reused across processes."

> "The enterprise data warehouse bus matrix is the essential tool for designing and communicating the enterprise data warehouse bus architecture. **The rows of the matrix are business processes and the columns are dimensions.** The shaded cells of the matrix indicate whether a dimension is associated with a given business process. The design team scans each row to test whether a candidate dimension is well-defined for the business process and also scans each column to see where a dimension should be conformed across multiple business processes."

Fuente: mismo whitepaper, secciones "Enterprise Data Warehouse Bus Architecture" y "Enterprise Data Warehouse Bus Matrix", p.10-11.

**Confirma exactamente** la estructura del borrador: filas = procesos de negocio, columnas = dimensiones conformadas, celdas sombreadas = qué dimensión aplica a qué proceso.

También, para precisión adicional (no pedido pero útil): Kimball Group define "drilling across" de forma separada y explícita, con el mecanismo técnico exacto:

> "Drilling across simply means making separate queries against two or more fact tables where the row headers of each query consist of identical conformed attributes. The answer sets from the two queries are aligned by performing a sort-merge operation on the common dimension attribute row headers."

---

## 7. Degenerate dimension, junk dimension, role-playing dimension, bridge table

**VEREDICTO: los cuatro términos están confirmados palabra por palabra contra el whitepaper oficial de Kimball Group, incluido el ejemplo textual exacto de bridge table con paciente/diagnósticos que pedía verificar el research.**

Fuente para los cuatro: mismo whitepaper, secciones respectivas, pp. 7, 9-10, 18.

### 7.1 Degenerate dimension

> "Sometimes a dimension is defined that has no content except for its primary key. For example, when an invoice has multiple line items, the line item fact rows inherit all the descriptive dimension foreign keys of the invoice, and the invoice is left with no unique content. But the invoice number remains a valid dimension key for fact tables at the line item level. This degenerate dimension is placed in the fact table with the explicit acknowledgment that there is no associated dimension table. Degenerate dimensions are most common with transaction and accumulating snapshot fact tables."

Confirma exactamente el ejemplo del borrador (número de orden/factura sin tabla de dimensión asociada, viviendo en la fact table).

### 7.2 Junk dimension

> "Transactional business processes typically produce a number of miscellaneous, low-cardinality flags and indicators. Rather than making separate dimensions for each flag and attribute, you can create a single junk dimension combining them together. This dimension, frequently labeled as a transaction profile dimension in a schema, does not need to be the Cartesian product of all the attributes' possible values, but should only contain the combination of values that actually occur in the source data."

Confirma exactamente: agrupar varios flags/indicadores de baja cardinalidad en una sola dimensión para evitar clutter de esquema.

### 7.3 Role-playing dimension

> "A single physical dimension can be referenced multiple times in a fact table, with each reference linking to a logically distinct role for the dimension. For instance, a fact table can have several dates, each of which is represented by a foreign key to the date dimension. It is essential that each foreign key refers to a separate view of the date dimension so that the references are independent. These separate dimension views (with unique attribute column names) are called roles."

Confirma el concepto exacto (una dimensión física, múltiples roles vía vistas separadas). **Matiz**: el whitepaper usa el ejemplo genérico de "several dates" sin nombrar explícitamente "order_date/ship_date/delivery_date" — ese trío específico es un ejemplo pedagógico estándar en la industria y consistente con lo que Kimball describe, pero no aparece con esos tres nombres exactos verbatim en esta fuente. El skill puede seguir usando ese ejemplo (es el caso de uso canónico de role-playing dimensions en la práctica), solo sin atribuir esos tres nombres literales a una cita de Kimball.

### 7.4 Bridge table (multivalued dimension)

> "In a classic dimensional schema, each dimension attached to a fact table has a single value consistent with the fact table's grain. But there are a number of situations in which a dimension is legitimately multivalued. For example, **a patient receiving a healthcare treatment may have multiple simultaneous diagnoses.** In these cases, the multivalued dimension must be attached to the fact table through a group dimension key to a bridge table with one row for each simultaneous diagnosis in a group."

**Esta es una confirmación exacta y literal** del ejemplo que pedía verificar el research (paciente con múltiples diagnósticos) — viene textualmente de Kimball Group, no es una analogía de terceros.

Adicionalmente, el whitepaper detalla un matiz relevante para el skill (relacionado con SCD Tipo 2, ver §2 y §5):

> "A multivalued bridge table may need to be based on a type 2 slowly changing dimension. For example, the bridge table that implements the many-to-many relationship between bank accounts and individual customers usually must be based on type 2 account and customer dimensions. In this case, to prevent incorrect linkages between accounts and customers, the bridge table must include effective and expiration date/time stamps, and the requesting application must constrain the bridge table to a specific moment in time to produce a consistent snapshot."

Este matiz conecta bridge tables con el mismo mecanismo de fechas de efectividad de Tipo 2 (§2) y con el problema de late-arriving facts (§5) — otra conexión real entre los bloques de este research, no forzada.

---

## Resumen de acciones para el contenido del skill

1. **Surrogate keys**: usar las tres razones citadas en §1, pero presentar la razón de rendimiento (b) con la misma honestidad epistémica de Kimball — es una sospecha razonable del propio Kimball, no un hecho que él mismo demostró.
2. **SCD 0-3**: citar literalmente contra el whitepaper (§2). Para Tipo 3, no afirmar "limited to one change of history" como cita textual — es una inferencia correcta de la definición, marcarla como tal.
3. **SCD Tipo 4**: confirmado sin matices, usar la cita de §3.1.
4. **SCD Tipo 6 — corrección obligatoria al borrador**: "1+2+3=6" SÍ es un mnemónico real de Kimball Group (Design Tip #152, Margy Ross), pero el propio Kimball Group dice que el nombre "fue sugerido por un ingeniero de HP en el año 2000" — no es una invención de Ralph Kimball. El skill debe decir "Kimball Group formalizó y numeró oficialmente en 2013 (3ª edición del libro) un término que, según su propio relato, ya circulaba en la práctica desde 2000" — nunca presentarlo como si Kimball lo hubiera acuñado. No usar el nombre "Bob Jarka" — no se encontró ninguna fuente que lo respalde; la única atribución verificable es "an HP engineer" sin nombre.
5. **Late-arriving dimensions**: confirmado con la cita de §4 — usar "placeholder"/"special dimension rows" como términos citables verbatim de Kimball Group; "inferred member" es terminología real pero de una fuente distinta (el libro, no el whitepaper web) y de Microsoft SSAS, no de esta página específica.
6. **Late-arriving facts — el hueco que cierra este research**: usar la cita de §5.1 (whitepaper) como definición general y la cita de §5.2 (Design Tip #57, Ralph Kimball, 2004) como el mecanismo detallado con conexión explícita a SCD Tipo 2. El skill debe presentar la distinción de vocabulario de §5.3 (late arriving fact ≠ early arriving fact/late arriving dimension) de forma explícita — es una distinción que el propio Kimball hace en el mismo artículo, no una invención de este research. Una vez implementado el reference file, actualizar `idempotency-and-backfills.md` líneas 46-48 de prosa plana a hyperlink real, como indica la spec §2.2.
7. **Conformed dimensions y bus matrix**: usar las citas de §6 tal cual — confirman exactamente filas=procesos/columnas=dimensiones y la relación con drill-across.
8. **Degenerate/junk/role-playing/bridge table**: usar las citas de §7 — el ejemplo de bridge table (paciente/diagnósticos) es una cita literal de Kimball Group, no una analogía de terceros, lo cual le da al skill una cita textual de alto valor.

**Nota de honestidad epistémica general**: dos huecos quedaron marcados explícitamente en este research — (a) el enlace que el propio Ralph Kimball cita en el Design Tip #57 hacia un artículo más detallado ("Backward in Time", *Intelligent Enterprise*, 2000) ya no resuelve (dominio desaparecido), así que ese tratamiento más profundo del mecanismo de late-arriving facts no se pudo verificar de forma independiente, solo se registra que Kimball lo menciona; (b) el término "inferred member" se confirma como terminología de Kimball ampliamente citada en fuentes secundarias consistentes entre sí (asociada al capítulo de subsistemas de ETL de *The Data Warehouse Toolkit*, 3ª edición), pero no se verificó verbatim contra el texto del libro mismo, que no está disponible en este entorno — la página web abierta de Kimball Group usa en su lugar "placeholder dimension rows". Ninguno de los dos huecos afecta los veredictos principales de este research.
