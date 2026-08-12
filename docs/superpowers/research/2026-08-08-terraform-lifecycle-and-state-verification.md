# Research: Terraform `lifecycle` — `prevent_destroy`, `create_before_destroy` y datos sensibles en el state

**Fecha:** 2026-08-08
**Alcance:** verificación de 5 claims del Paso 1 del plan de implementación de la skill `iac-cloud`. Fuentes primarias: documentación oficial de HashiCorp Terraform, rama de documentación **sin selector de versión** (la sección "Language" de `developer.hashicorp.com` no expone versionado por URL). Páginas consultadas en la fecha indicada:

- `https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle` — título de página: "lifecycle reference".
- `https://developer.hashicorp.com/terraform/language/manage-sensitive-data` — título de página: "Manage sensitive data in your configuration". **La URL histórica `https://developer.hashicorp.com/terraform/language/state/sensitive-data` (la "sensitive data in state page" que nombra el plan) ya no existe como página propia: responde 200 tras redirección a `manage-sensitive-data`** (verificado con `curl -w '%{url_effective}'`; ambas URLs devuelven exactamente el mismo cuerpo — mismo tamaño y mismo `md5sum`, `b38ef3832ab5eaf42ae2a07ca7cc6859`).
- `https://developer.hashicorp.com/terraform/language/block/resource` — título de página: "resource block reference". Consultada porque redacta `prevent_destroy` con palabras distintas a la página `lifecycle`, y esa divergencia importa (ver claim 1).
- `https://developer.hashicorp.com/terraform/language/state/remove` — "Remove a resource from state". Consultada porque es la página a la que la propia doc de `prevent_destroy` remite como salida.
- `https://developer.hashicorp.com/terraform/plugin/best-practices/sensitive-state` — "Handling sensitive values in state". Consultada porque es la única página que habla de atributos de **recurso** marcados como sensibles a nivel de schema del provider, que es exactamente lo que pide el claim 4.
- `https://developer.hashicorp.com/terraform/tutorials/state/resource-lifecycle` — "Manage resource lifecycle" (tutorial, no referencia). Consultada porque es la única página oficial que enuncia de forma explícita la relación entre `prevent_destroy` y un **reemplazo**, y porque muestra el texto literal del error.

**Identificadores de versión disponibles en las páginas capturadas** (no hay número de versión de doc): la página `lifecycle` documenta la regla `action_trigger` y el bloque `removed { lifecycle { destroy = false } }`, y la página `manage-sensitive-data` enuncia requisitos hasta "Use Terraform 1.11 or later to use a write-only argument on a managed resource". El HTML capturado incluye un banner de "HashiConf 2025". El tutorial `resource-lifecycle` es visiblemente más antiguo que las páginas de referencia (su salida de `terraform init` muestra un provider `hashicorp/aws` de la serie 3.x); esto se marca donde corresponde.

**Nota de método**: el fetcher basado en LLM (`WebFetch`) **sí funcionó** contra `developer.hashicorp.com` — no hubo 403 — y se usó para el primer pase sobre la página `lifecycle`. Aun así, para poder citar verbatim y dejar auditable cada cita, todas las páginas se volvieron a descargar con `curl -sSL -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"` y se convirtieron a texto plano con un script Python que elimina `script`/`style`/`svg`/`nav`/`head`, elimina comentarios, convierte solo etiquetas de bloque en saltos de línea y descarta las etiquetas inline sin insertar saltos (para no partir las oraciones a mitad de un `<code>`). `WebSearch` se usó únicamente para localizar URLs candidatas, nunca como fuente de citas. Los textos crudos quedaron en `un directorio scratchpad local de la sesión` con prefijo `tf-lifecycle-`; cada cita de este documento es grepeable ahí. Nota de captura: el proceso de extracción deja como última línea un artefacto `stdin is not a tty` en cada `.txt`; no forma parte del contenido de las páginas.

**Restricción aplicada**: no se reproduce ninguna cifra de precio, límite de servicio, cuota, tipo de instancia ni tamaño de nodo. Los fragmentos de configuración de ejemplo del tutorial que contienen tipos de instancia se omiten deliberadamente de las citas.

---

## 1. `prevent_destroy = true` produce un error en tiempo de PLAN cuando el recurso sería destruido

**VEREDICTO: SUPPORTED**, verbatim — con una salvedad de terminología que la propia documentación introduce al describir el mismo argumento con dos redacciones distintas en dos páginas distintas.

La página de referencia de `lifecycle` lo enuncia explícitamente sobre el *plan*:

> "When prevent_destroy is set to true, Terraform rejects plans that would destroy the infrastructure object associated with the resource and returns an error. The argument must be present in the configuration. This rule doesn't prevent Terraform from destroying a resource if you remove its configuration. Refer to Remove a resource from state for instructions on how to remove a resource from state without destroying the actual resource."

Fuente: `https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle`, sección "prevent_destroy", verbatim.

El texto literal del error, tal como lo muestra la documentación oficial, confirma que la condición evaluada es el **plan**, no el resultado del apply:

> "│ Error: Instance cannot be destroyed
> │
> │ on main.tf line 31:
> │ 31: resource "aws_instance" "example" {
> │
> │ Resource aws_instance.example has lifecycle.prevent_destroy set, but the
> │ plan calls for this resource to be destroyed. To avoid this error and
> │ continue with the plan, either disable lifecycle.prevent_destroy or reduce
> │ the scope of the plan using the -target flag."

Fuente: `https://developer.hashicorp.com/terraform/tutorials/state/resource-lifecycle`, sección "Prevent resource deletion", verbatim. Obsérvese la frase clave: *"the plan calls for this resource to be destroyed"* — la condición es lo que el plan propone, y el remedio sugerido (`-target`) es un remedio de alcance de plan.

### 1.1 El hedge de terminología que hay que registrar

La página `resource block reference` describe el mismo argumento **sin** la palabra "plans" en una de sus dos menciones:

> "prevent_destroy: Terraform rejects operations to destroy the resource and returns an error. This rule doesn't prevent Terraform from destroying the resource if you remove the resource configuration. For instructions on how to remove a resource from state without destroying the actual resource, refer to Remove a resource from state."

Fuente: `https://developer.hashicorp.com/terraform/language/block/resource`, tabla/lista de reglas de `lifecycle`, verbatim.

Y, unas líneas más abajo, la misma página vuelve a la formulación de plan:

> "The prevent_destroy argument instructs Terraform to reject plans to destroy the resource."

Fuente: `https://developer.hashicorp.com/terraform/language/block/resource`, sección "prevent_destroy", verbatim.

**Cómo debe redactarlo el skill**: dos de las tres formulaciones oficiales dicen explícitamente "plans"/"plan", y el texto del error dice "the plan calls for this resource to be destroyed". La afirmación "falla en tiempo de plan" está sostenida. Lo que el skill **no** debe hacer es decir "falla al ejecutar `terraform plan`" como si fuera exclusivo de ese comando: el error se produce en cualquier operación que genere un plan con esa destrucción, incluido `terraform destroy` (que es justamente el comando con el que la documentación lo demuestra) y `terraform apply`.

---

## 2. ¿Bloquea también un REEMPLAZO (destroy-and-recreate forzado por un cambio de atributo), o solo un destroy explícito?

**VEREDICTO: SUPPORTED (con la simplificación popular CORRECTED)** — sí, también bloquea el reemplazo; lo que queda CORRECTED es la lectura popular "te impide destruir el warehouse", que es incompleta y **activamente engañosa** (ver §2.3: el modo de fallo dominante en producción no es un destroy pedido, sino un plan que revienta entero por un cambio de atributo que fuerza recreación). Pero **la página de referencia nunca usa la palabra "replacement" en la definición operativa**: lo dice de forma oblicua, y la afirmación explícita solo aparece en una página de tutorial. Esta es la claim que el brief marcó como delicada, así que se documenta el camino de evidencia completo, incluida la parte que es oblicua.

### 2.1 Lo que dice la página de referencia (oblicuo, dos veces)

La definición operativa habla de "the infrastructure object associated with the resource", no de "destroy" como comando ni de "replacement" como acción:

> "When prevent_destroy is set to true, Terraform rejects plans that would destroy the infrastructure object associated with the resource and returns an error."

Fuente: `https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle`, verbatim.

El párrafo de uso recomendado sí introduce la palabra "replacing", y además admite explícitamente la consecuencia incómoda:

> "Use this rule as protection against accidentally replacing objects that may be costly to reproduce, such as database instances, storage, or other stateful resources. Enabling prevent_destroy, however, makes certain configuration changes impossible to apply and prevents the terraform destroy command from operating once such objects are created. Use prevent_destroy sparingly."

Fuente: `https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle`, verbatim.

Este párrafo es la evidencia más fuerte de la página de referencia, y hay que leerlo con cuidado: (a) el propósito declarado es protección contra **"accidentally replacing"**, no solo contra destruir; (b) la contrapartida declarada, *"makes certain configuration changes impossible to apply"*, solo tiene sentido si el bloqueo alcanza al reemplazo — un cambio de configuración que fuerza un nuevo recurso deja de poder aplicarse. La página nunca escribe la frase "prevent_destroy blocks replacements", pero ambas mitades del párrafo describen exactamente ese comportamiento.

### 2.2 La afirmación explícita, que solo existe en el tutorial

> "The prevent_destroy attribute is useful in situations where a change to an attribute would force a replacement and create downtime."

Fuente: `https://developer.hashicorp.com/terraform/tutorials/state/resource-lifecycle`, sección "Prevent resource deletion", verbatim.

Y el mecanismo por el cual esto ocurre queda visible en el propio vocabulario de planes de Terraform, que trata el reemplazo como una destrucción más una creación. La misma página de referencia describe ese comportamiento por defecto:

> "Terraform performs the following operations when you apply a configuration:
> [...]
> Destroys and re-creates resources whose arguments have changed but that Terraform cannot update in-place because of remote API limitations."

Fuente: `https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle`, sección introductoria, verbatim.

Es decir: un reemplazo **es** un plan que contiene una destrucción del objeto de infraestructura, y `prevent_destroy` rechaza "plans that would destroy the infrastructure object". El símbolo que Terraform imprime para ese caso, según el propio tutorial, es:

> "Resource actions are indicated with the following symbols:
> ~ update in-place
> +/- create replacement and then destroy"

Fuente: `https://developer.hashicorp.com/terraform/tutorials/state/resource-lifecycle`, verbatim (salida de `terraform apply` con `create_before_destroy` activo).

### 2.3 El hedge, y en qué se equivoca la simplificación popular

Registro explícito de las limitaciones de esta verificación:

- La **página de referencia** (`meta-arguments/lifecycle`) **no afirma literalmente** que `prevent_destroy` bloquee reemplazos. Lo implica de dos maneras ("accidentally replacing", "makes certain configuration changes impossible to apply") pero no lo enuncia.
- La afirmación literal proviene de una página de **tutorial**, no de referencia, y ese tutorial es visiblemente más antiguo que las páginas de referencia (muestra un provider AWS de la serie 3.x en su salida de `terraform init`).
- No se encontró en la documentación oficial ninguna página que diga lo contrario ni que exceptúe el reemplazo.

**La simplificación popular — "te impide destruir el warehouse" — es incompleta y operativamente engañosa.** Lo que la documentación describe no es un candado sobre `terraform destroy`; es un rechazo de *cualquier plan* que destruya el objeto, lo que incluye el caso mucho más frecuente y mucho menos esperado: alguien cambia un atributo que fuerza recreación y **el plan entero falla**, sin haber pedido destruir nada. Ese es el escenario que la doc reconoce cuando dice "makes certain configuration changes impossible to apply" y por el que cierra con "Use prevent_destroy sparingly".

**Cómo debe redactarlo el skill**: `prevent_destroy` no es "un seguro contra `terraform destroy`". Es un rechazo de todo plan que destruya el objeto, y su efecto práctico dominante es que **un cambio de atributo que fuerce recreación deja de poder aplicarse** — la protección y el bloqueo son la misma cosa vista desde dos lados. Si el skill enseña `prevent_destroy` como "candado anti-destroy", enseña mal la mitad que más duele en producción. Y debe citar la advertencia de la propia doc: *"Use prevent_destroy sparingly."*

---

## 3. Qué lo evade: ¿quitar el bloque de recurso de la configuración sigue produciendo error?

**VEREDICTO: CORRECTED** — respecto a la lectura protectora que la mayoría asume. La respuesta documentada es **no**: quitar el bloque no produce error, y Terraform destruye la infraestructura real.

La página de referencia lo dice dos veces, en dos secciones distintas, y la segunda explica el porqué mecánico:

> "The argument must be present in the configuration. This rule doesn't prevent Terraform from destroying a resource if you remove its configuration."

Fuente: `https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle`, sección "prevent_destroy", verbatim.

> "Except for create_before_destroy, Terraform does not explicitly record a resource's lifecycle rule to state. As a result, Terraform destroys the actual infrastructure during an apply operation if you remove the resource's configuration, even if prevent_destroy is enabled. Refer to Remove a resource from state for instructions on how to remove a resource from state without destroying the actual resource."

Fuente: `https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle`, sección "State", verbatim. Esta es la cita más importante de todo el documento para el skill: da la **razón** — la regla `lifecycle` no vive en el state, vive solo en la configuración, así que borrar la configuración borra la protección junto con ella. `create_before_destroy` es la única excepción que sí se persiste al state.

La misma limitación, reafirmada en la página del bloque `resource`:

> "This rule doesn't prevent Terraform from destroying the resource if you remove the resource configuration."

Fuente: `https://developer.hashicorp.com/terraform/language/block/resource`, verbatim.

Y en el tutorial, con una formulación que añade el caso de comentar el bloque:

> "Enabling prevent_destroy, however, does not prevent Terraform from destroying the resource if you comment out or remove the configuration."

Fuente: `https://developer.hashicorp.com/terraform/tutorials/state/resource-lifecycle`, verbatim.

### 3.1 La salida documentada cuando lo que se quiere es dejar de gestionar sin destruir

La doc no deja el hueco abierto: remite a un mecanismo concreto.

> "To remove a resource from Terraform state without destroying it, replace the resource block with a removed block and then apply the change using the standard Terraform workflow. When you remove a resource from state, Terraform no longer manages that infrastructure's lifecycle."

> "Add a lifecycle block to the removed block and set the destroy argument to false. Setting destroy to true removes the resource from state and destroys it."

> "Alternatively, you can use the terraform state rm command to remove a resource from state, but we recommend using the removed block instead. This is because the removed block lets you preview the results of the operation, which makes it a safer way to remove resources."

Fuente: `https://developer.hashicorp.com/terraform/language/state/remove`, verbatim.

**Cómo debe redactarlo el skill**: `prevent_destroy` protege contra el borrado accidental **mientras el bloque siga en la configuración**. No es un control de gobierno: cualquiera que borre o comente el bloque de recurso desactiva la protección en el mismo commit que dispara la destrucción, y un `terraform apply` la ejecuta. El skill debe decir explícitamente que esta regla no sustituye controles fuera de Terraform (revisión de PR sobre los archivos de infraestructura, protección de borrado del propio proveedor, permisos). Y para "dejar de gestionar sin destruir", la ruta documentada es el bloque `removed` con `lifecycle { destroy = false }`, preferido sobre `terraform state rm` por la propia doc porque permite previsualizar.

---

## 4. El state de Terraform puede contener valores sensibles en texto plano, incluidos los de recursos con atributos marcados como sensibles

**VEREDICTO: SUPPORTED**, verbatim, en las dos mitades del claim y desde dos páginas distintas.

### 4.1 El state contiene valores sensibles, y en local es texto plano

> "Terraform state and plan files contain detailed information about your infrastructure, including resource attributes and metadata that can contain sensitive values, such as initial database passwords or API tokens."

Fuente: `https://developer.hashicorp.com/terraform/language/manage-sensitive-data`, sección "Background", verbatim.

> "If you are developing with Terraform locally, Terraform stores your state in a plaintext file, which includes any secret values you defined in your configuration. Treat your state file as sensitive data by excluding it from Git workflows and following our recommendations to secure your state file."

Fuente: `https://developer.hashicorp.com/terraform/language/manage-sensitive-data`, verbatim.

### 4.2 Marcar como sensible NO lo saca del state

Esta es la mitad del claim que más se malinterpreta, y la doc la aborda de frente:

> "Terraform stores values with the sensitive argument in both state and plan files, and anyone who can access those files can access your sensitive values. Additionally, if you use the terraform output CLI command with the -json or -raw flags, Terraform displays sensitive variables and outputs in plain text."

Fuente: `https://developer.hashicorp.com/terraform/language/manage-sensitive-data`, sección "Hide sensitive variables and outputs", verbatim.

Y para el caso específico de **atributos de recurso** marcados como sensibles en el schema del provider (que es literalmente lo que dice el claim, y que la página de lenguaje no cubre porque `sensitive` allí es un argumento de `variable`/`output`):

> "When working with a field that contains information likely to be considered sensitive, it is best to enable the sensitive flag on the schema of that field using the SDK the provider is written in. For example, the Sensitive flag in Plugin Framework or the Sensitive flag in SDKv2. This will prevent the field's values from showing up in CLI output and in HCP Terraform. It will not encrypt or obscure the value in the state, however."

Fuente: `https://developer.hashicorp.com/terraform/plugin/best-practices/sensitive-state`, sección "Using Sensitive Flag functionality", verbatim. La última oración — *"It will not encrypt or obscure the value in the state, however"* — es la confirmación exacta de la segunda mitad del claim.

### 4.3 El matiz que el skill debe conservar: qué sí saca valores del state

La doc no se limita a advertir; nombra el mecanismo que sí evita la persistencia, y ese mecanismo **no** es `sensitive`:

> "Ephemeral values are available at the run time of an operation, but Terraform omits them from state and plan files. Because Terraform does not store ephemeral values, you must capture any generated values you want to preserve in another resource or output in your configuration."

Fuente: `https://developer.hashicorp.com/terraform/language/manage-sensitive-data`, sección "Omit values from state and plan files", verbatim.

> "Write-only arguments let you securely pass temporary values to Terraform's managed resources during an operation without persisting those values to state or plan files. Each provider defines any available write-only arguments on their managed resources."

Fuente: `https://developer.hashicorp.com/terraform/language/manage-sensitive-data`, sección "Use write-only arguments", verbatim.

Y las recomendaciones de protección del state, citadas como forma (sin cifras):

> "If you store sensitive values in a state file, we recommend implementing additional security measures to keep your state safe:
> Store your state remotely
> Encrypt your state at rest
> Use access controls to limit who has access to your state
> Use audit logs to track state access over time"

Fuente: `https://developer.hashicorp.com/terraform/language/manage-sensitive-data`, sección "State security best practices", verbatim.

**Cómo debe redactarlo el skill**: `sensitive = true` es una regla de **redacción de salida** (CLI y UI de HCP Terraform), no de almacenamiento. El valor sigue en el state y en el plan en claro. Quien quiera que un secreto no toque el state necesita `ephemeral` o un *write-only argument*, no `sensitive`. Y el state en sí se trata como material sensible: remoto, cifrado en reposo, con control de acceso y auditoría — fuera de Git.

---

## 5. `create_before_destroy` — qué dicen los docs que hace, y por qué es la herramienta equivocada para un recurso de datos con estado

**VEREDICTO: CORRECTED** — el claim tiene dos mitades y solo una está en la fuente. Se desglosa explícitamente porque el plan asumía que la doc respalda ambas.

### 5.1 Lo que hace — **SUPPORTED**, verbatim

> "By default, when Terraform must change a resource argument that cannot be updated in-place due to remote API limitations, Terraform destroys the existing object and then create a new replacement object with the new configured arguments. Use the create_before_destroy rule to instruct Terraform to create a replacement resource before destroying the current resource."

Fuente: `https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle`, sección "create_before_destroy", verbatim. (La oración conserva el error de concordancia del original: *"then create a new replacement object"*.)

Advertencia de opt-in, en la misma sección:

> "This is an opt-in behavior because many remote object types have unique name requirements or other constraints that must be accommodated for both a new and an old object to exist concurrently. Some resource types offer special options to append a random suffix onto each object name to avoid collisions, for example. Terraform CLI cannot automatically activate such features, so you must understand the constraints for each resource type before using create_before_destroy with it."

Fuente: `https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle`, verbatim.

Propagación a dependencias, que la doc marca como no reversible:

> "Terraform propagates and applies create_before_destroy behavior to all resource dependencies. For example:
> create_before_destroy is enabled on resource A but not on resource B.
> Because resource A is dependent on resource B, Terraform enables create_before_destroy for resource B implicitly by default and stores it to the state file.
> As a result, you cannot override create_before_destroy to false on resource B because that would imply dependency cycles in the graph."

Fuente: `https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle`, verbatim.

Y la interacción con provisioners de destrucción:

> "When the resource contains a provisioner that runs during the destroy operation, setting create_before_destroy to true also prevents the provisioner from running."

Fuente: `https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle`, verbatim.

La formulación equivalente en la página del bloque `resource`:

> "create_before_destroy: Terraform creates a replacement resource before destroying the current resource."

Fuente: `https://developer.hashicorp.com/terraform/language/block/resource`, verbatim.

### 5.2 "Es la herramienta equivocada para un recurso de datos con estado" — **UNSUPPORTED como afirmación con fuente**

**La documentación oficial de Terraform nunca dice esto.** No se encontró en ninguna de las seis páginas consultadas una afirmación de que `create_before_destroy` sea inadecuado para bases de datos, warehouses, buckets o cualquier recurso que contenga datos. Esta parte del claim es **razonamiento propio del repo**, no material citable, y el skill debe presentarla como tal.

Lo que la doc **sí** dice, y que es lo que el skill puede usar como base sourced:

1. `create_before_destroy` **no evita la destrucción**; solo cambia el orden. La cita de 5.1 es inequívoca: *"create a replacement resource before destroying the current resource"* — el objeto original se destruye igual. El símbolo de plan que la propia doc muestra para ese caso es `+/- create replacement and then destroy` (`https://developer.hashicorp.com/terraform/tutorials/state/resource-lifecycle`, verbatim).
2. La doc exige que **ambos objetos coexistan**: *"must be accommodated for both a new and an old object to exist concurrently"*. Para un recurso con datos esto significa que existirán dos copias de la infraestructura, y la doc no dice nada sobre qué pasa con los datos de la que se destruye.
3. La doc advierte que el usuario debe entender las restricciones **por tipo de recurso** antes de usarlo: *"you must understand the constraints for each resource type before using create_before_destroy with it"*. Esa oración es el gancho legítimo para el consejo del repo, sin fingir que la doc emitió el juicio.
4. La doc trata a los recursos con estado como el caso de uso de la regla **contraria**: el párrafo de `prevent_destroy` es el que nombra *"database instances, storage, or other stateful resources"*, no el de `create_before_destroy`.
5. El tutorial oficial presenta `create_before_destroy` como remedio de **downtime**, no de pérdida de datos: *"For changes that may cause downtime but must happen, use the create_before_destroy attribute to create your new resource before destroying the old resource."* (`https://developer.hashicorp.com/terraform/tutorials/state/resource-lifecycle`, verbatim). Y en ese mismo tutorial, `create_before_destroy` se añade **sustituyendo** a `prevent_destroy` en el bloque `lifecycle` — es decir, la doc oficial las presenta como respuestas a problemas distintos, no como complementos.

**Cómo debe redactarlo el skill**: la parte citable es "`create_before_destroy` reordena, no cancela: el objeto viejo se destruye de todas formas, y ambos deben poder coexistir". El paso de ahí a "por eso no sirve para proteger un warehouse: los datos del objeto viejo no viajan al nuevo" es una inferencia del repo — correcta en la mecánica descrita, pero **no atribuible a HashiCorp**. El skill debe enunciarla en voz propia y no colgarle una cita de la doc que no existe.

---

## Resumen de veredictos

| # | Claim | Veredicto |
|---|---|---|
| 1 | `prevent_destroy = true` produce error en tiempo de plan cuando el recurso sería destruido | **SUPPORTED** — verbatim ("rejects plans that would destroy…"; error: "the plan calls for this resource to be destroyed"). Hedge: la página del bloque `resource` dice "rejects operations to destroy" en una mención y "reject plans" en otra; no es exclusivo del comando `plan` |
| 2 | ¿Bloquea también un **reemplazo**, o solo un destroy explícito? | **SUPPORTED (con la simplificación popular CORRECTED)** — sí bloquea reemplazos. Pero la página de **referencia nunca usa la palabra "replacement"**: lo dice oblicuamente ("accidentally replacing", "makes certain configuration changes impossible to apply"); la afirmación explícita solo está en un **tutorial** más antiguo. La simplificación "te impide destruir" es incompleta y engañosa |
| 3 | ¿Quitar el bloque de recurso de la configuración sigue produciendo error? | **CORRECTED** — **no**. La doc lo dice cuatro veces en tres páginas: sin configuración no hay protección, porque la regla `lifecycle` no se persiste al state (única excepción: `create_before_destroy`). Ruta documentada para no destruir: bloque `removed` con `lifecycle { destroy = false }` |
| 4 | El state puede contener valores sensibles en claro, incluso con atributos marcados como sensibles | **SUPPORTED** — verbatim en ambas mitades: "Terraform stores values with the sensitive argument in both state and plan files"; y para atributos de recurso, "It will not encrypt or obscure the value in the state, however". Lo que sí los omite es `ephemeral` / write-only arguments, no `sensitive` |
| 5 | `create_before_destroy`: qué hace, y por qué es la herramienta equivocada para un recurso de datos con estado | **CORRECTED** (desglose): 5.1 "qué hace" **SUPPORTED** verbatim. 5.2 "es la herramienta equivocada para datos con estado" **UNSUPPORTED como afirmación con fuente** — la doc nunca lo dice; es inferencia propia del repo y debe marcarse como tal |

## Implicación para el skill

- **No enseñar `prevent_destroy` como "candado anti-`terraform destroy`".** Su efecto dominante en producción es el otro: un cambio de atributo que fuerza recreación hace fallar el plan completo. La propia doc lo admite ("makes certain configuration changes impossible to apply") y cierra con "Use prevent_destroy sparingly" — esa advertencia debe aparecer en el skill.
- **Al citar el bloqueo de reemplazos, ser honesto sobre la procedencia.** La página de referencia lo implica; la afirmación literal viene de un tutorial. Si el skill quiere una cita de referencia, la correcta es "rejects plans that would destroy the infrastructure object associated with the resource" combinada con la definición de reemplazo de la misma página ("Destroys and re-creates resources whose arguments have changed but that Terraform cannot update in-place").
- **Decir explícitamente que `prevent_destroy` no es un control de gobierno.** Borrar o comentar el bloque lo desactiva en el mismo cambio que dispara la destrucción, porque la regla no vive en el state. El skill debe emparejarlo con controles externos (revisión del cambio de infraestructura, protección de borrado del propio proveedor, permisos) y con el bloque `removed` para el caso "dejar de gestionar sin destruir".
- **Corregir la ecuación `sensitive` = "protegido".** `sensitive` redacta salida; no cambia lo que se escribe al state ni al plan. Para que un secreto no toque el state el mecanismo documentado es `ephemeral` o un write-only argument. El state se trata como material sensible: remoto, cifrado en reposo, acceso controlado, auditado, fuera de Git.
- **`create_before_destroy` no cancela la destrucción, la reordena** — y exige coexistencia de ambos objetos. El skill puede citar eso. El argumento "por eso no protege datos" debe ir en voz del repo, sin cita atribuida a HashiCorp.
- **Fragilidad de fuente a vigilar**: la "sensitive data in state page" que nombraba el plan ya no existe como página independiente (redirige a `manage-sensitive-data`); cualquier enlace del skill debe apuntar a la URL nueva. La afirmación explícita del claim 2 depende de una página de tutorial que podría reescribirse o retirarse; conviene que el skill no dependa de ella como única base.
