# Research: Deriva de licencia en Terraform, existencia y compatibilidad de OpenTofu, y si Pulumi / AWS CDK caen en la misma categoría conceptual

**Fecha:** 2026-08-08
**Alcance:** verificación de los 3 claims del Paso 7 del plan de implementación de la skill de IaC/cloud. El objetivo operativo de este pase es decidir **cómo debe nombrar la skill a la herramienta** a lo largo de todo el documento.

**Documentos, páginas y versiones consultadas (todas recuperadas el 2026-08-08):**

| Fuente | URL | Versión / fecha de la fuente |
|---|---|---|
| Terraform `LICENSE` (rama `main`) | `https://raw.githubusercontent.com/hashicorp/terraform/main/LICENSE` | último commit al archivo: `f3658552ea`, 2026-03-17 |
| Terraform `LICENSE` (tag de release) | `https://raw.githubusercontent.com/hashicorp/terraform/v1.15.8/LICENSE` | **v1.15.8**, publicado 2026-07-08 (release más reciente según la API de GitHub) — byte-idéntico al de `main` |
| Terraform `README.md` | `https://raw.githubusercontent.com/hashicorp/terraform/main/README.md` | rama `main` |
| Terraform `main.go` (cabecera SPDX) | `https://raw.githubusercontent.com/hashicorp/terraform/main/main.go` | rama `main` |
| Historial del `LICENSE` de Terraform | `https://api.github.com/repos/hashicorp/terraform/commits?path=LICENSE` | commits `4eba7c0596` (2026-03-11) y `f3658552ea` (2026-03-17) |
| Metadatos de licencia del repo (GitHub) | `https://api.github.com/repos/hashicorp/terraform` | consulta 2026-08-08 |
| Anuncio oficial de HashiCorp en su foro | `https://discuss.hashicorp.com/t/hashicorp-projects-changing-license-to-business-source-license-v1-1/57106.json` | post original de `melissa`, 2023-08-10T20:15:45Z |
| Blog de anuncio de HashiCorp | `https://www.hashicorp.com/en/blog/hashicorp-adopts-business-source-license` | Armon Dadgar, 2023-08-10 (ver Nota de método) |
| Página "Open Source and HashiCorp" | `https://www.hashicorp.com/en/about/open-source` | consulta 2026-08-08 (ver Nota de método) |
| OSI — The Open Source Definition | `https://opensource.org/osd` | "Last modified on February 16, 2024" |
| OSI — OSI Approved Licenses | `https://opensource.org/licenses` | consulta 2026-08-08 |
| OSI — Common reasons for rejection of licenses | `https://opensource.org/licenses/common-reasons-for-rejection-of-licenses` | "This page was last modified on: March 12, 2024" |
| OSI — FAQ | `https://opensource.org/faq` | consulta 2026-08-08 |
| OpenTofu `LICENSE` | `https://raw.githubusercontent.com/opentofu/opentofu/main/LICENSE` | rama `main` |
| OpenTofu `README.md` y `cmd/tofu/main.go` | `https://raw.githubusercontent.com/opentofu/opentofu/main/...` | rama `main` |
| Metadatos de licencia del repo OpenTofu | `https://api.github.com/repos/opentofu/opentofu` | consulta 2026-08-08 |
| OpenTofu — home | `https://opentofu.org/` | banner "OpenTofu 1.12.0 is released" |
| OpenTofu — FAQ | `https://opentofu.org/faq/` | consulta 2026-08-08 |
| OpenTofu — Getting started | `https://opentofu.org/docs/intro/` | docs v1.12.x |
| OpenTofu — Migrating from Terraform / Migration Guide | `https://opentofu.org/docs/intro/migration/`, `.../migration-guide/` | docs v1.12.x |
| OpenTofu — v1.x Compatibility Promises | `https://opentofu.org/docs/language/v1-compatibility-promises/` | docs v1.12.x |
| OpenTofu — What's new in 1.12 | `https://opentofu.org/docs/intro/whats-new/` | docs v1.12.x |
| OpenTofu — State and Plan Encryption | `https://opentofu.org/docs/language/state/encryption/` | docs v1.12.x |
| OpenTofu release más reciente | `https://api.github.com/repos/opentofu/opentofu/releases/latest` | **v1.12.5**, publicado 2026-07-21 |
| Linux Foundation — press release | `https://www.linuxfoundation.org/press/announcing-opentofu` | 20 de septiembre de 2023 |
| Pulumi — State and Backends | `https://www.pulumi.com/docs/iac/concepts/state-and-backends/` | consulta 2026-08-08 |
| Pulumi — How Pulumi works | `https://www.pulumi.com/docs/iac/concepts/how-pulumi-works/` | consulta 2026-08-08 |
| Pulumi — `pulumi preview` | `https://www.pulumi.com/docs/iac/cli/commands/pulumi_preview/` | consulta 2026-08-08 |
| Pulumi — resource option `protect` | `https://www.pulumi.com/docs/iac/concepts/options/protect/` | consulta 2026-08-08 |
| AWS CDK v2 Developer Guide — home, stacks, resources, deploy, synth, `cdk diff` | `https://docs.aws.amazon.com/cdk/v2/guide/...` | CDK **v2** Developer Guide |
| AWS CloudFormation User Guide — `DeletionPolicy`, change sets | `https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/...` | consulta 2026-08-08 |

---

## Nota de método

**Lo que funcionó.** `curl -A "Mozilla/5.0 ..."` funcionó sin problema contra `raw.githubusercontent.com`, `api.github.com`, `discuss.hashicorp.com`, `opensource.org`, `opentofu.org`, `www.linuxfoundation.org`, `www.pulumi.com` y `docs.aws.amazon.com`. Todo el HTML se convirtió a texto plano con un extractor propio (`scratchpad/extract.py`) y se guardó junto al HTML original.

**Lo que falló y cómo se rodeó.**

1. `www.hashicorp.com` e `ir.hashicorp.com` están detrás de un **Vercel Security Checkpoint** que devuelve **HTTP 429** con el cuerpo `Vercel Security Checkpoint / We're verifying your browser` a *cualquier* petición de `curl`, con cualquier User-Agent, con y sin `Referer`, con y sin cookie jar, y también a través del proxy de texto `r.jina.ai` (que reporta literalmente `Warning: Target URL returned error 429: Too Many Requests`). Es decir: **el workaround habitual de este repo (curl con UA de navegador) no sirve aquí; el bloqueo es inverso al caso de `debezium.io`**.
2. `web.archive.org` es **inalcanzable desde este sandbox** (`OpenSSL SSL_connect: Connection reset by peer` y después timeouts de 25 s sobre el 443). No hubo forma de usar la Wayback Machine como espejo.
3. La única herramienta que sí atravesó el checkpoint fue **WebFetch** (el fetcher basado en LLM). Su salida es texto procesado por un modelo, no HTML crudo. Por eso, **todas las citas de `hashicorp.com` en este documento se marcan explícitamente como "vía WebFetch" y se guardaron literalmente** en `scratchpad/raw/iac-hashicorp-webfetch-outputs.txt` con una nota de procedencia. No se han elevado a la categoría de "verbatim auditable" al mismo nivel que las demás.
4. La FAQ de licenciamiento (`https://www.hashicorp.com/en/license-faq`) **no pudo obtenerse con sus respuestas**: WebFetch devolvió únicamente el índice de preguntas y `ANSWER NOT PRESENT` para cada respuesta solicitada (el contenido está en acordeones renderizados en cliente). Las preguntas cuya existencia sí quedó confirmada son Q8, Q12, Q19, Q23 y Q24.
5. Para no depender de una fuente inaccesible, la caracterización de HashiCorp se ancló además en **dos fuentes que sí se descargaron crudas**: (a) el post oficial de anuncio en `discuss.hashicorp.com` (obtenido como JSON de Discourse, texto íntegro) y (b) el propio archivo `LICENSE` y las cabeceras SPDX del repositorio de Terraform.

**Regla que se respetó a rajatabla:** donde HashiCorp y la OSI usan vocabularios distintos, **se citan por separado y no se fusionan**. Ninguna frase de este documento atribuye a la OSI una calificación que la OSI no haya escrito, ni a HashiCorp una que HashiCorp no haya escrito.

---

## 1. Licencia actual de Terraform y si sigue siendo open source bajo la definición de la OSI

**VEREDICTO: CORRECTED**

La deriva está **confirmada y es doble**: (a) Terraform ya no está bajo una licencia open source aprobada por la OSI, y (b) la simplificación popular corregida —"Terraform está bajo la BUSL de HashiCorp"— **también está desactualizada**: desde marzo de 2026 el Licensor nombrado en el archivo es IBM, no HashiCorp.

### 1.1 El identificador de licencia, verbatim, desde el archivo `LICENSE` de hoy

**Fecha de comprobación: 2026-08-08.** Versión consultada: rama `main` y tag `v1.15.8` (el release más reciente, publicado 2026-07-08); **ambos archivos son byte-idénticos**.

> ```
> License text copyright (c) 2020 MariaDB Corporation Ab, All Rights Reserved.
> "Business Source License" is a trademark of MariaDB Corporation Ab.
>
> Parameters
>
> Licensor:             International Business Machines Corporation (IBM)
> Licensed Work:        Terraform Version 1.6.0 or later. The Licensed Work is (c) 2024
>                       IBM Corp.
> ```

Fuente: `https://raw.githubusercontent.com/hashicorp/terraform/main/LICENSE`, verbatim.

Y el bloque de términos del mismo archivo, que nombra la versión exacta de la licencia:

> ```
> Notice
>
> Business Source License 1.1
>
> Terms
>
> The Licensor hereby grants you the right to copy, modify, create derivative
> works, redistribute, and make non-production use of the Licensed Work. The
> Licensor may make an Additional Use Grant, above, permitting limited production use.
> ```

Fuente: `https://raw.githubusercontent.com/hashicorp/terraform/main/LICENSE`, verbatim.

Los parámetros de conversión y la cláusula de uso adicional, verbatim:

> ```
> Additional Use Grant: You may make production use of the Licensed Work, provided
>                       Your use does not include offering the Licensed Work to third
>                       parties on a hosted or embedded basis in order to compete with
>                       IBM Corp.'s paid version(s) of the Licensed Work.
> ...
> Change Date:          Four years from the date the Licensed Work is published.
> Change License:       MPL 2.0
> ```

Fuente: `https://raw.githubusercontent.com/hashicorp/terraform/main/LICENSE`, verbatim.

El identificador SPDX aparece en las cabeceras del código:

> ```go
> // Copyright IBM Corp. 2014, 2026
> // SPDX-License-Identifier: BUSL-1.1
> ```

Fuente: `https://raw.githubusercontent.com/hashicorp/terraform/main/main.go`, verbatim.

Y el README lo declara explícitamente:

> ```
> ## License
>
> [Business Source License 1.1](https://github.com/hashicorp/terraform/blob/main/LICENSE)
> ```

Fuente: `https://raw.githubusercontent.com/hashicorp/terraform/main/README.md`, verbatim.

### 1.2 La deriva dentro de la deriva: el Licensor cambió de HashiCorp a IBM en 2026-03-11

El commit `4eba7c0596` (2026-03-11T06:35:44Z, mensaje `Update LICENSE`) contiene este diff, verbatim de la API de GitHub:

> ```diff
> -Licensor:             HashiCorp, Inc.
> +Licensor:             International Business Machines Corporation (IBM)
>  Licensed Work:        Terraform Version 1.6.0 or later. The Licensed Work is (c) 2024
> -                      HashiCorp, Inc.
> +                      IBM Corp.
> ```

Fuente: `https://api.github.com/repos/hashicorp/terraform/commits/4eba7c0596`, campo `files[0].patch`, verbatim.

**Esto importa para la skill**: cualquier material que diga "la BUSL de HashiCorp" está describiendo un estado anterior a marzo de 2026. La licencia sigue siendo BUSL-1.1; el titular ya no es el que la mayoría de fuentes secundarias nombra.

### 1.3 Cómo lo caracteriza HashiCorp (su propio vocabulario)

El anuncio oficial en el foro de HashiCorp, **descargado crudo** (JSON de Discourse), post de `melissa` del 2023-08-10:

> "Today, HashiCorp has announced a transition in license from the Mozilla Public License v2.0 (MPL 2.0) to the Business Source License v1.1 (BSL or BUSL) for future releases of all products and several libraries. HashiCorp APIs, SDKs, and almost all other libraries will remain MPL 2.0 HashiCorp is committed to continuing to develop our popular community products in the open with broad access and permissions for re-use."

Fuente: `https://discuss.hashicorp.com/t/hashicorp-projects-changing-license-to-business-source-license-v1-1/57106`, post #1, verbatim (extraído del campo `cooked` del JSON).

El mismo post lista el repositorio afectado:

> "https://github.com/hashicorp/terraform - re-licensed to BSL"

Fuente: ídem, verbatim.

**El término que HashiCorp usa para su propia licencia es "source-available", no "open source".** Las siguientes citas provienen de `hashicorp.com` **vía WebFetch** (ver Nota de método, punto 3 — no fue posible descargarlas crudas):

> "This commitment continues today, with all HashiCorp projects accessible through a source-available license that allows broad copying, modification, and redistribution, while helping support a vibrant community and partner ecosystem."

> "We offer our products through a free, source-available license because we believe that enabling practitioners to innovate in infrastructure helps create broad ecosystems, and allows organizations to more easily solve integration problems."

Fuente: `https://www.hashicorp.com/en/about/open-source`, vía WebFetch, 2026-08-08.

Y del blog de anuncio, también vía WebFetch, HashiCorp describe la BSL 1.1 como:

> "a source-available license that allows copying, modification, redistribution, non-commercial use, and commercial use under specific conditions"

Fuente: `https://www.hashicorp.com/en/blog/hashicorp-adopts-business-source-license`, vía WebFetch, 2026-08-08.

**HEDGE REGISTRADO — cuidado con esta frase.** HashiCorp **no** dice "esto ya no es open source". Dice "source-available". Al mismo tiempo, la propia página institucional sigue usando "open source" para describir su historia y su ecosistema ("they chose an open source model, which evolved over time..."). Es decir: HashiCorp usa **ambos vocabularios en la misma página**, "source-available" para la licencia actual y "open source" para el modelo histórico y el ecosistema. La skill **no debe citar a HashiCorp diciendo que Terraform no es open source**, porque no lo dice; debe citar que HashiCorp lo llama "source-available".

### 1.4 Cómo lo caracteriza la OSI (autoridad distinta, vocabulario distinto)

La OSI es la autoridad separada sobre qué significa "open source". Su definición operativa:

> "Open source licenses are licenses that comply with the Open Source Definition – in brief, they allow software to be freely used, modified, and shared. To be approved by the Open Source Initiative (also known as the OSI) a license must go through the Open Source Initiative's license review process."

Fuente: `https://opensource.org/licenses`, verbatim.

**BUSL-1.1 no aparece en la lista de licencias aprobadas por la OSI.** La búsqueda sobre el listado completo (926 líneas de texto extraído) devuelve una única coincidencia con la cadena "BSL": el identificador SPDX `BSL-1.0`, que es la **Boost Software License**, no la Business Source License. `MPL-2.0` sí aparece en la lista, categorizada como "Popular / Strong Community".

Fuente: `https://opensource.org/licenses`, listado completo, consultado 2026-08-08.

Y la OSI nombra explícitamente a la BUSL como caso de rechazo:

> "Conditional licensing . Licenses with variable outcomes like BUSL that delay availability of full software freedom won't be approved because we cannot be sure that they meet the OSD for all use cases at all times. Licenses like the Sun Industry Standards Source License (SISSL) that apply different OSI-approved licenses depending on conditions have been approved in the past."

Fuente: `https://opensource.org/licenses/common-reasons-for-rejection-of-licenses`, sección "Common reasons for rejection of licenses" (página modificada por última vez el 2024-03-12), verbatim.

El criterio de la Open Source Definition que el Additional Use Grant de Terraform pone en tensión:

> "6. No Discrimination Against Fields of Endeavor
>
> The license must not restrict anyone from making use of the program in a specific field of endeavor. For example, it may not restrict the program from being used in a business, or from being used for genetic research."

Fuente: `https://opensource.org/osd` (última modificación 2024-02-16), verbatim.

Y la postura de la OSI sobre el etiquetado:

> "Can I call my program "Open Source" even if I don't use an approved license?
>
> Please don't do that. If you call it "Open Source" without using an approved license, you will confuse people. This is not merely a theoretical concern — we have seen this confusion happen in the past, and it's part of the reason we have a formal license approval process."

> "Is <SOME LICENSE> an Open Source license, even if it is not listed on your web site?
>
> In general, no. We run all licenses through an approval process to provide an accepted standard on which licenses are Open Source, and we list the approved ones . Be dubious of claimed Open Source-ness for licenses that haven't gone through the process."

Fuente: `https://opensource.org/faq`, verbatim.

**HEDGE REGISTRADO — el matiz exacto.** La OSI dice que licencias "like BUSL" **no serán aprobadas** ("won't be approved") y que **no puede estar segura** de que cumplan la OSD en todos los casos ("we cannot be sure that they meet the OSD for all use cases at all times"). Eso es más matizado que "la OSI declaró que la BUSL no es open source". La formulación defendible, y la única que la skill puede sostener con estas fuentes, es: **BUSL-1.1 no es una licencia aprobada por la OSI, y la OSI ha declarado que licencias de ese tipo no se aprobarán.**

### 1.5 Corroboración independiente: el detector de licencias de GitHub

| Repositorio | `license.spdx_id` según la API de GitHub |
|---|---|
| `hashicorp/terraform` | `NOASSERTION` (`key: other`, `name: Other`) |
| `opentofu/opentofu` | `MPL-2.0` (`name: Mozilla Public License 2.0`) |

Fuente: `https://api.github.com/repos/hashicorp/terraform` y `https://api.github.com/repos/opentofu/opentofu`, consultados 2026-08-08.

### 1.6 Qué queda CORREGIDO, exactamente

| Simplificación popular | Lo que dicen las fuentes |
|---|---|
| "Terraform es open source" | Falso desde la v1.6.0. La `Licensed Work` es "Terraform Version 1.6.0 or later" bajo BUSL-1.1. |
| "Terraform está bajo la BUSL de HashiCorp" | Desactualizado desde 2026-03-11: el `Licensor` nombrado es "International Business Machines Corporation (IBM)". |
| "HashiCorp admitió que ya no es open source" | HashiCorp no dice eso. Dice "source-available". Es la OSI, autoridad distinta, la que no aprueba la BUSL. |
| "La BUSL nunca se vuelve libre" | El propio archivo fija `Change License: MPL 2.0` y `Change Date: Four years from the date the Licensed Work is published`. |
| "Todo HashiCorp pasó a BUSL" | El anuncio oficial dice "HashiCorp APIs, SDKs, and almost all other libraries will remain MPL 2.0". |

---

## 2. OpenTofu existe como fork y cuál es su claim de compatibilidad con Terraform

**VEREDICTO: SUPPORTED**, con tres hedges que la skill debe conservar (frontera de versión del state file, alcance del término "drop-in replacement", y divergencia futura admitida por el propio proyecto).

### 2.1 Que es un fork, en sus propias palabras

> "Why was OpenTofu created? OpenTofu is a Terraform fork, created as an initiative of Gruntwork, Spacelift, Harness, Env0, Scalr, and others, in response to HashiCorp's switch from an open-source license to the BUSL."

Fuente: `https://opentofu.org/faq/`, verbatim.

Y en la documentación técnica, hablando de las promesas de compatibilidad heredadas:

> "The original commitments had been made for OpenTofu's predecessor, adopted by our project as part of the fork, and represented a snapshot of platforms that were in wide use at the time their version of this document was drafted."

Fuente: `https://opentofu.org/docs/language/v1-compatibility-promises/`, verbatim.

### 2.2 Su licencia

El archivo `LICENSE` del repositorio, verbatim, empieza así:

> ```
> Copyright (c) The OpenTofu Authors
> Copyright (c) 2014 HashiCorp, Inc.
>
> Mozilla Public License, version 2.0
> ```

Fuente: `https://raw.githubusercontent.com/opentofu/opentofu/main/LICENSE`, verbatim.

Las cabeceras SPDX del código:

> ```go
> // Copyright (c) The OpenTofu Authors
> // SPDX-License-Identifier: MPL-2.0
> // Copyright (c) 2023 HashiCorp, Inc.
> // SPDX-License-Identifier: MPL-2.0
> ```

Fuente: `https://raw.githubusercontent.com/opentofu/opentofu/main/cmd/tofu/main.go`, verbatim.

Y el README:

> ```
> ## License
>
> [Mozilla Public License v2.0](https://github.com/opentofu/opentofu/blob/main/LICENSE)
> ```

Fuente: `https://raw.githubusercontent.com/opentofu/opentofu/main/README.md`, verbatim.

**Nota:** MPL-2.0 **sí** está en la lista de licencias aprobadas por la OSI (ver §1.4). Esta es la asimetría que la skill puede afirmar sin ambigüedad: la licencia de OpenTofu está aprobada por la OSI; la de Terraform, no.

### 2.3 Su gobernanza (Linux Foundation)

Del comunicado de prensa de la Linux Foundation, del 20 de septiembre de 2023:

> "BILBAO, SPAIN – September 20, 2023 – Today, the Linux Foundation announced the formation of OpenTofu , an open source alternative to Terraform's widely used infrastructure as code provisioning tool. Previously named OpenTF , OpenTofu is an open and community-driven response to Terraform's recently announced license change from a Mozilla Public License v2.0 (MPLv2) to a Business Source License v1.1, providing everyone with a reliable, open source alternative under a neutral governance model."

Fuente: `https://www.linuxfoundation.org/press/announcing-opentofu`, verbatim.

> "While Terraform has been instrumental in simplifying infrastructure management in cloud environments, recent licensing changes have raised concerns within the open source community. OpenTofu is an open source successor to the MPLv2-licensed Terraform that will be community-driven, impartial, layered and modular, and backward-compatible."

Fuente: ídem, verbatim.

El propio sitio de OpenTofu confirma la custodia en su pie de página, verbatim:

> "Copyright © OpenTofu a Series of LF Projects, LLC and its contributors."

Fuente: `https://opentofu.org/` (y todas las páginas de `opentofu.org/docs/`), verbatim.

Y el gobierno técnico, del FAQ:

> "How are new features, bug fixes, and other development decisions made in OpenTofu? The core team with its technical lead determine the most important features and bug fixes to work on, while the steering committee makes decisions on big changes. All those decisions are guided by community feedback and public discussion."

Fuente: `https://opentofu.org/faq/`, verbatim.

### 2.4 Cómo redacta exactamente su claim de compatibilidad — y dónde están los hedges

**Hedge 1 — "drop-in replacement" es la formulación de marketing de la portada, sin frontera de versión declarada ahí:**

> "OpenTofu is a reliable, flexible, community-driven infrastructure as code tool under the Linux Foundation's stewardship. It serves as a drop-in replacement for Terraform , preserving your existing workflows and configurations."

Fuente: `https://opentofu.org/`, sección hero, verbatim.

**Hedge 2 — la documentación técnica es notablemente más cauta que la portada:**

> "OpenTofu aims to maintain compatibility with Terraform configurations. While most Terraform code will work without modification, we recommend following our migration guide to ensure a smooth transition."

Fuente: `https://opentofu.org/docs/intro/migration/`, sección "Before you begin", verbatim.

Nótese la degradación del lenguaje: la portada dice *"serves as a drop-in replacement"*; los docs dicen *"aims to maintain compatibility"* y *"most Terraform code will work without modification"*. **La skill debe usar la formulación de los docs, no la de la portada.**

**Hedge 3 — LA FRONTERA DE VERSIÓN, que es el dato duro y el que suele omitirse:**

> "Will OpenTofu work with my existing state file? OpenTofu will work with existing state files up to those created with Terraform versions 1.5.x."

Fuente: `https://opentofu.org/faq/`, verbatim.

Esta es la única frontera de versión explícita que el proyecto publica. Es coherente con el punto de bifurcación: Terraform v1.6.0 es exactamente la primera versión BUSL (`Licensed Work: Terraform Version 1.6.0 or later`, §1.1). **Es decir: el fork es "drop-in" respecto a Terraform hasta la 1.5.x; a partir de ahí no hay promesa alguna de compatibilidad de estado.**

El procedimiento de migración documentado, verbatim, confirma que la compatibilidad se *verifica*, no se *asume*:

> "Step 4: Verify your configuration
>
> Run a plan to ensure OpenTofu can read your state and configuration:
>
> `tofu plan`
>
> Expected result : You should see "No changes" or the same plan output you would see with Terraform.
>
> If you see unexpected changes:
>
> Do not apply the changes
>
> Investigate the differences
>
> Consider rolling back (see below)"

Fuente: `https://opentofu.org/docs/intro/migration/migration-guide/`, verbatim.

Y sobre la vuelta atrás, verbatim:

> "Rolling back to Terraform
>
> If you encounter issues during migration, you can safely roll back:
>
> Stop using OpenTofu immediately
>
> Restore from your backups (if any state changes were made)"

Fuente: ídem, verbatim.

### 2.5 Divergencia de funcionalidades: lo que los docs sí dicen y lo que no

**Lo que el proyecto dice explícitamente sobre divergencia futura:**

> "Will OpenTofu be compatible with future Terraform releases? The community will decide what features OpenTofu will have. Some long-awaited Terraform features will be publicly available soon. If you're missing a feature in OpenTofu that's available in Terraform, feel free to create an issue."

Fuente: `https://opentofu.org/faq/`, verbatim.

Esta respuesta es una **no-promesa**: OpenTofu declina comprometerse a paridad con releases futuros de Terraform y reconoce que puede faltar funcionalidad que Terraform sí tiene. En el mismo FAQ, en la sección dirigida a empresas, sí se enuncia una aspiración:

> "This risk is minimized by giving OpenTofu to the Linux Foundation, and OpenTofu's aim of maintaining feature parity with Terraform for future releases reduces the technical risks."

Fuente: `https://opentofu.org/faq/`, verbatim. **"aim of maintaining feature parity" es una aspiración declarada, no una garantía.**

**Funcionalidades que OpenTofu documenta y que constituyen divergencia propia.** OpenTofu documenta cifrado de estado y de plan, algo que su propio changelog atribuye al proyecto:

> "OpenTofu supports encrypting state and plan files at rest, both for local storage and when using a backend. In addition, you can also use encryption with the terraform_remote_state data source."

Fuente: `https://opentofu.org/docs/language/state/encryption/`, verbatim.

Y en la portada, sobre iteración de providers introducida en v1.9:

> "Provider Iteration with for_each — v1.9 — Dynamically generate provider configurations with for_each, eliminating repetitive code and improving maintainability."

Fuente: `https://opentofu.org/`, verbatim.

Del release actual (v1.12), varias capacidades de ciclo de vida relevantes para la skill:

> "Dynamic prevent_destroy : The prevent_destroy argument in a resource's lifecycle block can now refer to other symbols within the same module, such as input variables."

> "New destroy lifecycle meta-argument: The new destroy = false lifecycle option for managed resources allows removing an object from the state without first destroying the remote object."

Fuente: `https://opentofu.org/docs/intro/whats-new/`, verbatim.

**HEDGE REGISTRADO:** ninguna de estas páginas afirma *"Terraform no tiene esto"*. Documentan lo que OpenTofu tiene. La skill **no debe escribir "OpenTofu tiene X y Terraform no"** apoyándose en estas fuentes — no lo dicen. Lo que sí puede afirmar, con cita, es que **el propio proyecto no promete paridad con releases futuros de Terraform** y que **la única frontera de compatibilidad de estado publicada es Terraform 1.5.x**.

### 2.6 Versiones vigentes en la fecha de comprobación

- Terraform: **v1.15.8**, publicado 2026-07-08.
- OpenTofu: **v1.12.5**, publicado 2026-07-21; la documentación del sitio corresponde a la serie v1.12.x.

Ambos números están **muy por encima** de la frontera 1.5.x. Los dos linajes llevan divergiendo desde el punto de fork.

---

## 3. Si Pulumi y AWS CDK pertenecen a la misma categoría que Terraform / OpenTofu para los fines del consejo de la skill

**VEREDICTO: CORRECTED**

El consejo de la skill es **mayoritariamente independiente de la herramienta, pero no del todo**. Tres de los cuatro conceptos núcleo generalizan limpiamente a Pulumi y a CDK; **el cuarto — "el state file es un artefacto que tú posees, versionas, bloqueas, cifras y puedes corromper" — NO generaliza a CDK**, y generaliza a Pulumi sólo con una traducción de vocabulario. Esa es exactamente la línea divisoria.

### 3.1 Modelo declarativo de estado deseado

**Pulumi — sí, y lo dice con esas palabras:**

> "Now, let's make a change to one of resources and run pulumi up again. Since Pulumi operates on a desired state model, it will use the last deployed state to compute the minimal set of changes needed to update your deployed infrastructure."

Fuente: `https://www.pulumi.com/docs/iac/concepts/how-pulumi-works/`, verbatim.

> "Explicit control : Pulumi treats your program as the source of truth for desired state."

Fuente: `https://www.pulumi.com/docs/iac/concepts/state-and-backends/`, verbatim.

**HEDGE IMPORTANTE sobre Pulumi:** el programa se *ejecuta* en un lenguaje de propósito general; lo declarativo es el grafo de recursos que resulta, no el código. Los docs son explícitos:

> "When the first aws.s3.bucket object is constructed, the language host sends a resource registration request to the deployment engine and then continues executing the program. This is subtle, but important: When the call to new aws.s3.bucket returns, it does not mean that the actual S3 bucket has been created in AWS , it just means the language host has expressed that this bucket is part of the desired state of your infrastructure."

Fuente: `https://www.pulumi.com/docs/iac/concepts/how-pulumi-works/`, verbatim.

**AWS CDK — sí, pero por delegación: el modelo declarativo vive en CloudFormation, no en CDK:**

> "The AWS Cloud Development Kit (AWS CDK) is an open-source software development framework for defining cloud infrastructure in code and provisioning it through AWS CloudFormation."

Fuente: `https://docs.aws.amazon.com/cdk/v2/guide/home.html`, verbatim.

> "Before you can deploy an AWS Cloud Development Kit (AWS CDK) stack, it must first be synthesized. Stack synthesis is the process of producing an AWS CloudFormation template and deployment artifacts from a CDK stack. The template and artifacts are known as the cloud assembly . The cloud assembly is what gets deployed to provision your resources on AWS."

Fuente: `https://docs.aws.amazon.com/cdk/v2/guide/configure-synth.html`, verbatim.

> "The AWS CDK utilizes the AWS CloudFormation service to perform deployments. Before you deploy, you synthesize your CDK stacks. This creates a CloudFormation template and deployment artifacts for each CDK stack in your app. ... During deployment, assets are uploaded to the bootstrapped resources and the CloudFormation template is submitted to CloudFormation to provision your AWS resources."

Fuente: `https://docs.aws.amazon.com/cdk/v2/guide/deploy.html`, verbatim.

### 3.2 State file / backend de estado — AQUÍ ESTÁ LA DIFERENCIA QUE DECIDE TODO

**Pulumi — sí tiene state file y backend, con vocabulario propio ("state", "backend", "checkpoint"):**

> "Pulumi stores metadata about your infrastructure so that it can manage your cloud resources. This metadata is called state . Each stack has its own state, and state is how Pulumi knows when and how to create, read, delete, or update cloud resources."

Fuente: `https://www.pulumi.com/docs/iac/concepts/state-and-backends/`, verbatim.

> "Pulumi stores state in a backend of your choosing. A backend is an API and storage endpoint used by the CLI to coordinate updates, and read and write stack state whenever appropriate. Backend options include Pulumi Cloud, an easy-to-use, secure, and reliable hosted application with policies and safeguards to facilitate team collaboration, in addition to simple object storage in AWS S3, Microsoft Azure Blob Storage, Google Cloud Storage, any AWS S3 compatible server such as Minio or Ceph, or a local filesystem."

Fuente: ídem, verbatim.

> "Checkpoints
>
> Pulumi state is usually stored in a transactional snapshot called a checkpoint . Pulumi records checkpoints early and often as it executes so that Pulumi can operate reliably, similar to how database transactions work. The basic functions of state allow Pulumi to diff your program's goal state against the last known update, recover from failure, and destroy resources accurately to clean up afterwards. The checkpoint format augments this with additional failure recovery capabilities in the face of partial failure."

Fuente: ídem, sección "Checkpoints", verbatim.

Y sobre secretos en el estado, que es el mismo problema que en Terraform:

> "Pulumi state does not include your cloud credentials. Credentials are kept local to your client — wherever the CLI runs — even when using the managed Pulumi Cloud backend. Pulumi does store configuration and secrets, but encrypts those secrets using your chosen encryption provider."

Fuente: ídem, verbatim.

**AWS CDK — NO. El "estado" es el stack de CloudFormation, un recurso gestionado del lado del servicio:**

> "An AWS CDK stack is the smallest single unit of deployment. It represents a collection of AWS resources that you define using CDK constructs. When you deploy CDK apps, the resources within a CDK stack are deployed together as an AWS CloudFormation stack."

Fuente: `https://docs.aws.amazon.com/cdk/v2/guide/stacks.html`, verbatim.

> "Resources are what you configure to use AWS services in your applications. Resources are a feature of AWS CloudFormation. By configuring resources and their properties in a AWS CloudFormation template, you can deploy to AWS CloudFormation to provision your resources. With the AWS Cloud Development Kit (AWS CDK), you can configure resources through constructs. You then deploy your CDK app, which involves synthesizing a AWS CloudFormation template and deploying to AWS CloudFormation to provision your resources."

Fuente: `https://docs.aws.amazon.com/cdk/v2/guide/resources.html`, verbatim.

**Esta es la diferencia estructural.** En Terraform/OpenTofu y en Pulumi, el estado es un artefacto que **el usuario aloja** (fichero local, bucket, backend gestionado) y por tanto puede perder, corromper, filtrar o dejar sin bloqueo. En CDK **no existe tal artefacto**: la fuente de verdad es el stack de CloudFormation, del lado del servicio, y AWS se encarga de su durabilidad, su consistencia y su bloqueo. **Todo consejo de la skill que trate el estado como "un fichero tuyo que debes proteger" es, literalmente, inaplicable a CDK.**

### 3.3 Paso de plan / preview

**Pulumi — sí, `pulumi preview`, y la descripción del comando es casi una definición de "plan":**

> "This command displays a preview of the updates to an existing stack whose state is represented by an existing state file. The new desired state is computed by running a Pulumi program, and extracting all resource allocations from its resulting object graph. These allocations are then compared against the existing state to determine what operations must take place to achieve the desired state. No changes to the stack will actually take place."

Fuente: `https://www.pulumi.com/docs/iac/cli/commands/pulumi_preview/`, verbatim.

Con opción de fallo duro ante cambios inesperados, útil para CI:

> "--expect-no-changes Return an error if any changes are proposed by this preview"

Fuente: ídem, verbatim.

**AWS CDK — sí, `cdk diff`, apoyado en change sets de CloudFormation:**

> "This command is typically used to compare differences between the current state of stacks in your local CDK app against deployed stacks. However, you can also compare a deployed stack with any local AWS CloudFormation template."

Fuente: `https://docs.aws.amazon.com/cdk/v2/guide/ref-cli-cmd-diff.html`, verbatim.

> "auto – Default. Creates an AWS CloudFormation change set to display accurate replacement information. If the change set can't be created (for example, due to missing permissions), falls back to a template-only diff. Uses the deploy role."

> "template – Compares CloudFormation templates directly. Faster, but less accurate. Any change detected to properties that require resource replacement is displayed as a resource replacement, even if the change is purely cosmetic. Uses the lookup role."

Fuente: ídem, verbatim.

Y el mecanismo subyacente de CloudFormation:

> "When you need to update a stack, understanding how your changes will affect running resources before you implement them can help you update stacks with confidence. Change sets allow you to preview how proposed changes to a stack might impact your running resources, including the impact on resource properties and attributes. Whether your changes will delete or replace any critical resources, CloudFormation makes the changes to your stack only when you decide to execute the change set, allowing you to decide whether to proceed with your proposed changes"

Fuente: `https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-cfn-updating-stacks-changesets.html`, verbatim.

**HEDGE REGISTRADO:** el preview de CDK **no es siempre exacto**. Los propios docs distinguen `change-set` ("Use this when you need guaranteed accuracy") de `template` ("Faster, but less accurate"). El consejo "haz plan y revísalo antes de aplicar" generaliza; **el consejo "el plan te dice exactamente lo que va a pasar" no generaliza sin el matiz de qué modo de diff estás usando.**

### 3.4 Protección contra destrucción / retención

**Pulumi — opción de recurso `protect`, y es un mecanismo de rechazo duro:**

> "The protect resource option marks a resource as protected. A protected resource cannot be deleted directly, and it will be an error to do a Pulumi deployment which tries to delete a protected resource for any reason."

Fuente: `https://www.pulumi.com/docs/iac/concepts/options/protect/`, verbatim.

> "Applies to custom and component resources. The protect resource option applies to both custom resources and component resources . It is defined on the base resource-options type in every Pulumi SDK. Setting protect: true on a component propagates protect: true to every child custom resource. The engine refuses to delete any protected resource in the subtree until the flag is removed (or the resource is unprotected with pulumi state unprotect )."

Fuente: ídem, verbatim.

> "Child resources inherit the protect option from their parent resource . When a parent resource has protect: true , all of its children are also protected by default. To allow a specific child resource to be deleted independently of its protected parent, explicitly set protect: false on that child."

Fuente: ídem, verbatim.

Y existe un escape explícito, que la skill debe conocer porque es exactamente el tipo de flag que la gente añade en CI y luego lamenta:

> "--ignore-protect Ignore the protect resource option for this operation, previewing the deletion or replacement of protected resources instead of failing"

Fuente: `https://www.pulumi.com/docs/iac/cli/commands/pulumi_preview/`, verbatim.

**AWS CDK — política de eliminación / retención, y aquí hay una divergencia de defaults entre CDK y CloudFormation que hay que registrar:**

> "Removal policies
>
> Resources that maintain persistent data, such as databases, Amazon S3 buckets, and Amazon ECR registries, have a removal policy . The removal policy indicates whether to delete persistent objects when the AWS CDK stack that contains them is destroyed. The values specifying the removal policy are available through the RemovalPolicy enumeration in the AWS CDK core module."

Fuente: `https://docs.aws.amazon.com/cdk/v2/guide/resources.html`, sección "Removal policies", verbatim.

> "RemovalPolicy.RETAIN
>
> Keep the contents of the resource when destroying the stack (default). The resource is orphaned from the stack and must be deleted manually. If you attempt to re-deploy the stack while the resource still exists, you will receive an error message due to a name conflict."

> "RemovalPolicy.DESTROY
>
> The resource will be destroyed along with the stack."

Fuente: ídem, verbatim.

Debajo, en CloudFormation, el default es **el contrario**:

> "With the DeletionPolicy attribute you can preserve, and in some cases, backup a resource when its stack is deleted. You specify a DeletionPolicy attribute for each resource that you want to control. If a resource has no DeletionPolicy attribute, CloudFormation deletes the resource by default."

Fuente: `https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-attribute-deletionpolicy.html`, verbatim.

> "To keep a resource when its stack is deleted, specify Retain for that resource. You can use Retain for any resource."

> "If you want to modify resources outside of CloudFormation, use a Retain deletion policy and then delete the stack. Otherwise, your resources might get out of sync with your CloudFormation template and cause stack errors."

Fuente: ídem, verbatim.

**HEDGE REGISTRADO — y es un hedge peligroso.** Los docs de CDK dicen que `RETAIN` es "(default)" **en el contexto de recursos que almacenan datos persistentes y cuyo construct L2 lo fija así**; los docs de CloudFormation dicen que, sin atributo, **"CloudFormation deletes the resource by default"**. No son contradictorios (el default de CDK lo pone el construct, no el motor), pero **la skill no debe escribir "en CDK los datos se retienen por defecto" a secas** — depende del construct. La formulación segura: *"la retención es un atributo por recurso; verifica el default del construct concreto, no lo asumas."*

Y una advertencia operativa que la skill debería recoger porque contradice la intuición:

> "AWS CloudFormation does not remove Amazon S3 buckets that contain files even if their removal policy is set to DESTROY . Attempting to do so is an AWS CloudFormation error. To have the AWS CDK delete all files from the bucket before destroying it, set the bucket's autoDeleteObjects property to true ."

Fuente: `https://docs.aws.amazon.com/cdk/v2/guide/resources.html`, verbatim.

### 3.5 Tabla de correspondencia conceptual

| Concepto que la skill enseña | Terraform / OpenTofu | Pulumi | AWS CDK |
|---|---|---|---|
| Modelo declarativo de estado deseado | Sí (HCL) | Sí — "Pulumi operates on a desired state model", desde un programa imperativo que *expresa* el grafo | Sí, **delegado**: sintetiza a plantilla CloudFormation |
| Artefacto de estado que el usuario aloja | **Sí** — state file + backend | **Sí** — "state" en un "backend" elegido; snapshot = "checkpoint" | **NO** — el estado es el stack de CloudFormation, del lado del servicio |
| Paso de plan/preview antes de aplicar | Sí | Sí — `pulumi preview` (`--expect-no-changes` para CI) | Sí — `cdk diff`, con modos `change-set` (exacto) / `template` (menos exacto) |
| Protección contra destrucción / retención | Sí | Sí — resource option `protect` (con escape `--ignore-protect`) | Sí — `RemovalPolicy` (CDK) sobre `DeletionPolicy` (CloudFormation) |
| Cifrado / secretos en el estado | Sí | Sí — "Pulumi does store configuration and secrets, but encrypts those secrets using your chosen encryption provider" | **No aplica del mismo modo** — no hay fichero de estado propio que cifrar |

### 3.6 Conclusión explícita: qué es independiente de la herramienta y qué NO

**SÍ es independiente de la herramienta (la skill lo dice una vez y no lo vuelve a litigar):**

1. **El modelo declarativo de estado deseado.** Las tres familias comparan un estado deseado contra un estado conocido y calculan el delta mínimo. Todo el razonamiento sobre idempotencia, deriva de configuración y "no toques la consola" vale igual en las tres.
2. **La disciplina de plan-antes-de-apply.** `terraform plan` / `tofu plan`, `pulumi preview`, `cdk diff`. El consejo "revisa el plan, falla el pipeline ante cambios no esperados, no apliques a ciegas" vale igual en las tres, incluido el gate de CI (`--expect-no-changes` en Pulumi tiene equivalente directo).
3. **La existencia de un mecanismo de protección contra destrucción, y la obligación de activarlo explícitamente en recursos con datos.** `prevent_destroy`, `protect`, `RemovalPolicy`/`DeletionPolicy`. El consejo generaliza; el nombre y el default no.

**NO es independiente de la herramienta (la skill debe decirlo explícitamente donde toque):**

1. **Toda la gestión del state file como artefacto propio**: backend remoto, bloqueo de estado, versionado del bucket de estado, cifrado en reposo del estado, recuperación tras un state corrupto, `state rm` / `import` como operaciones de fontanería. **Vale para Terraform/OpenTofu y, con traducción de vocabulario, para Pulumi. NO vale para CDK**, donde ese artefacto no existe y la durabilidad del estado es responsabilidad de CloudFormation.
2. **Los defaults de retención.** Divergen entre CDK y CloudFormation, y divergen entre herramientas. La skill no puede enunciar un default universal.
3. **La exactitud del preview.** En CDK depende del modo de diff (`change-set` vs `template`). No se puede afirmar "el plan es exacto" de forma universal.
4. **La discusión de licencia.** Es específica de Terraform frente a OpenTofu, y no tiene análogo en Pulumi ni en CDK (CDK se autodescribe como "open-source software development framework" en sus propios docs).

---

## Resumen de veredictos

| # | Claim | Veredicto |
|---|---|---|
| 1 | Licencia actual de Terraform y si sigue siendo open source bajo la OSI | **CORRECTED** — Deriva confirmada y doble. `LICENSE` en `main` y en el tag `v1.15.8` (idénticos, comprobados el **2026-08-08**): **Business Source License 1.1**, SPDX `BUSL-1.1`, `Licensed Work: Terraform Version 1.6.0 or later`, `Change License: MPL 2.0`, `Change Date: Four years`. Segunda corrección: el `Licensor` **ya no es HashiCorp sino IBM** desde el commit `4eba7c0596` del 2026-03-11. HashiCorp lo llama **"source-available"** (nunca "no open source"); la OSI, autoridad separada, **no incluye BUSL-1.1 en su lista de licencias aprobadas** y dice que licencias "like BUSL" **"won't be approved"**. Los dos vocabularios se mantienen separados en este documento. |
| 2 | OpenTofu existe como fork y su claim de compatibilidad | **SUPPORTED** — "OpenTofu is a Terraform fork" (FAQ, verbatim); licencia **MPL 2.0** (SPDX `MPL-2.0`, sí aprobada por la OSI); gobernanza **Linux Foundation** ("a Series of LF Projects, LLC", comunicado del 2023-09-20). Tres hedges preservados: (a) la portada dice **"drop-in replacement"** pero los docs dicen **"aims to maintain compatibility"** / **"most Terraform code will work without modification"**; (b) la única frontera de versión publicada es **"OpenTofu will work with existing state files up to those created with Terraform versions 1.5.x"** — justo por debajo de la primera versión BUSL; (c) el proyecto **declina prometer paridad futura** ("The community will decide what features OpenTofu will have"), sólo declara "aim of maintaining feature parity". Versiones vigentes: Terraform v1.15.8 (2026-07-08), OpenTofu v1.12.5 (2026-07-21) — ambos muy por encima de la frontera. |
| 3 | Pulumi y AWS CDK, ¿misma categoría? ¿El consejo es independiente de la herramienta? | **CORRECTED** — Sólo **parcialmente** independiente. Generalizan: modelo de estado deseado, paso de plan/preview, y la existencia de un mecanismo de protección contra destrucción. **NO generaliza el state file como artefacto propio del usuario**: Pulumi sí lo tiene ("state" en un "backend", snapshot = "checkpoint"), **CDK no lo tiene en absoluto** — su estado es el stack de CloudFormation, del lado del servicio. Tampoco generalizan los defaults de retención (CDK documenta `RETAIN` como default para constructs con datos; CloudFormation documenta que sin `DeletionPolicy` **borra** por defecto) ni la exactitud del preview (`cdk diff` en modo `template` es "less accurate"). |

---

## Implicación para el skill

### Decisión de nombrado (concreta y accionable)

**1. La skill nombra la herramienta como `Terraform/OpenTofu` — con barra, sin espacios — y lo hace UNA sola vez de forma explicada, al inicio, en un bloque corto.** Ese bloque dice, con las citas de §1.1, §2.1 y §2.2:

- Terraform está bajo **BUSL-1.1** desde la v1.6.0; el `Licensor` es **IBM** desde marzo de 2026; **la BUSL no es una licencia aprobada por la OSI** (dato verificable: no está en `opensource.org/licenses`).
- HashiCorp la llama **"source-available"** — la skill usa esa palabra, no "no open source", cuando atribuye la caracterización a HashiCorp.
- OpenTofu es un **fork** bajo **MPL 2.0** (sí aprobada por la OSI) bajo la **Linux Foundation**.
- La sintaxis HCL, el modelo de estado, el flujo `init/plan/apply` y los meta-argumentos de `lifecycle` son **comunes a ambos**; cambia el binario (`terraform` vs `tofu`) y la licencia.

**2. Tras ese bloque, la skill NO vuelve a litigar la cuestión.** Todos los ejemplos de código posteriores se escriben en HCL y se etiquetan como válidos para `Terraform/OpenTofu`. Los comandos se escriben como `terraform plan` / `tofu plan` **sólo la primera vez** que aparecen; después basta con `plan`, `apply`, `destroy` en prosa, o `terraform <cmd>` con una nota al pie única de que `tofu <cmd>` es equivalente. **Prohibido**: repetir el disclaimer de licencia en cada sección; escribir "Terraform (o OpenTofu, que es un fork open source...)" más de una vez.

**3. Prohibiciones de redacción derivadas de las fuentes:**
- **No** escribir "Terraform es open source". Es falso desde la v1.6.0.
- **No** escribir "la BUSL de HashiCorp" sin más. Desde 2026-03-11 el `Licensor` es IBM. Si se necesita brevedad: "BUSL-1.1".
- **No** escribir "HashiCorp reconoció que ya no es open source". No lo dice. Dice "source-available".
- **No** escribir "la OSI declaró que la BUSL no es open source". Lo que la OSI escribió es que licencias "like BUSL" **"won't be approved"** y que no puede estar segura de que cumplan la OSD en todos los casos. La formulación sostenible es: **"BUSL-1.1 no es una licencia aprobada por la OSI"**.
- **No** escribir "OpenTofu es un reemplazo drop-in de Terraform" a secas. Esa es la frase de la portada. Los docs dicen "aims to maintain compatibility" y **la única frontera publicada es Terraform 1.5.x para el state file**. Si la skill menciona la compatibilidad, **debe** incluir esa frontera.
- **No** escribir "OpenTofu tiene cifrado de estado y Terraform no". Ninguna fuente primaria consultada hace esa comparación. Se puede decir que OpenTofu **documenta** cifrado de estado y plan.

### Decisión sobre Pulumi y AWS CDK

**4. La skill declara UNA sola vez, en el mismo bloque inicial, que el consejo es independiente de la herramienta en tres ejes y NO lo es en un cuarto:**

*Redacción propuesta para el skill, **no es una cita**: los dos bloques siguientes son texto redactado por esta verificación a partir de las fuentes citadas en §3, no una transcripción de ninguna página. Las citas verbatim de Pulumi, AWS CDK y CloudFormation que lo sustentan están en esa sección, cada una con su URL.*

> Independiente: estado deseado declarativo, plan/preview antes de aplicar, protección explícita contra destrucción en recursos con datos. Equivalentes: `terraform plan` ≈ `pulumi preview` ≈ `cdk diff`; `prevent_destroy` ≈ `protect` ≈ `RemovalPolicy`/`DeletionPolicy`.
>
> **NO independiente:** todo lo relativo al **state file como artefacto que tú alojas** — backend remoto, bloqueo, versionado, cifrado en reposo, recuperación de un estado corrupto, `state rm`/`import`. Aplica a Terraform/OpenTofu y, con otro vocabulario, a Pulumi ("state"/"backend"/"checkpoint"). **No aplica a AWS CDK**, donde ese artefacto no existe: la fuente de verdad es el stack de CloudFormation y su durabilidad la gestiona AWS.

**5. Consecuencia estructural para el índice de la skill:** la sección de **gestión del state file** debe llevar un aviso de alcance en su encabezado ("aplica a Terraform/OpenTofu y Pulumi; no a CDK/CloudFormation"). Es la **única** sección que necesita ese aviso. Ninguna otra sección debe repetir la discusión de herramientas.

**6. Dos matices que la skill debe recoger porque contradicen la intuición y aparecen en fuentes primarias:**
- El default de retención **no es universal**: los docs de CDK marcan `RETAIN` como default para constructs con datos persistentes, mientras CloudFormation documenta que, sin `DeletionPolicy`, **borra** por defecto. Redacción segura: *"la retención es un atributo por recurso; verifica el default del construct/recurso concreto"*.
- El preview **no es siempre exacto**: `cdk diff --method template` es "less accurate" según los propios docs. Y `pulumi preview --ignore-protect` desactiva la protección para esa operación. La skill debe advertir de ambos escapes.
