# Research: Cifrado en reposo por defecto, terminología de clave gestionada por el cliente y superficie de política de la clave (AWS / Azure / GCP)

**Fecha:** 2026-08-08

**Alcance:** verificación de las 3 claims del Paso 6 del plan de implementación de la skill de IaC/cloud. Fuentes primarias: documentación oficial de AWS (KMS Developer Guide, KMS API Reference, KMS Cryptographic Details, Amazon S3 User Guide, AWS Well-Architected Security Pillar), Microsoft Learn (Azure security fundamentals, Azure Storage, Azure Key Vault, Azure SQL) y Google Cloud (Cloud KMS, Cloud Storage, Default encryption at rest).

**Páginas consultadas** (todas el 2026-08-08):

AWS
- `https://docs.aws.amazon.com/kms/latest/developerguide/concepts.html`
- `https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html`
- `https://docs.aws.amazon.com/kms/latest/developerguide/control-access.html`
- `https://docs.aws.amazon.com/kms/latest/developerguide/overview.html`
- `https://docs.aws.amazon.com/kms/latest/APIReference/API_CreateKey.html`
- `https://docs.aws.amazon.com/kms/latest/cryptographic-details/basic-concepts.html`
- `https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html`
- `https://docs.aws.amazon.com/AmazonS3/latest/userguide/default-encryption-faq.html`
- `https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-encryption.html`
- `https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/protecting-data-at-rest.html`
- `https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/sec_protect_data_rest_access_control.html`

Azure
- `https://learn.microsoft.com/en-us/azure/security/fundamentals/encryption-atrest`
- `https://learn.microsoft.com/en-us/azure/storage/common/storage-service-encryption`
- `https://learn.microsoft.com/en-us/azure/storage/common/customer-managed-keys-overview`
- `https://learn.microsoft.com/en-us/azure/storage/common/customer-managed-keys-configure-existing-account`
- `https://learn.microsoft.com/en-us/azure/key-vault/general/security-features`
- `https://learn.microsoft.com/en-us/azure/key-vault/general/rbac-access-policy`
- `https://learn.microsoft.com/en-us/azure/key-vault/general/rbac-guide`
- `https://learn.microsoft.com/en-us/azure/azure-sql/database/transparent-data-encryption-byok-overview`

Google Cloud
- `https://cloud.google.com/kms/docs/cmek`
- `https://cloud.google.com/kms/docs/iam`
- `https://cloud.google.com/kms/docs/separation-of-duties`
- `https://cloud.google.com/kms/docs/reference/permissions-and-roles`
- `https://cloud.google.com/storage/docs/encryption`
- `https://cloud.google.com/docs/security/encryption/default-encryption`

**Nota de método**: la herramienta de fetch basada en LLM (`WebFetch`) funcionó sin bloqueos para `docs.aws.amazon.com`; **no se recibió ningún 403 en esta ronda**. Aun así, para dejar auditable cada cita, **todas** las páginas se volvieron a descargar con `curl -A "Mozilla/5.0 …"` y se extrajo texto plano con un script Python de stripping de HTML; los archivos resultantes están en `/tmp/claude-1000/-home-leonardo-garcia-dev-data-engineering-skills/bc10f192-c330-4b36-b218-d872fbb1f871/scratchpad/raw/` con prefijo `crypto-`. Cada cita de este documento es grepeable en esos archivos. Para Microsoft se usaron **ambas** vías: las herramientas MCP de Microsoft Learn (`microsoft_docs_search` / `microsoft_docs_fetch`) y `curl` sobre `learn.microsoft.com`; el contenido coincide y las citas se tomaron del texto obtenido por `curl` (guardado en crudo). Se usó `WebSearch` una sola vez, para localizar la página exacta donde AWS documenta el cambio de terminología CMK → KMS key; la cita final se verificó y guardó desde la página original, no desde el resumen del buscador.

**Nota sobre elisión de cifras**: por la regla no-numbers del repo, las cifras de rotación, cuotas y precios que aparecían dentro de las citas se han elidido como `[…]`. Los identificadores de algoritmo (AES-256, AES-GCM, AES-128, FIPS 140-2, TLS 1.2/1.3) se conservan porque son nombres de algoritmo/estándar, no límites de servicio. Las elisiones concretas se señalan bajo cada cita afectada.

---

## 1. Qué cubre "cifrado en reposo por defecto" y qué NO — en particular, si protege frente a un lector con permisos excesivos

**VEREDICTO GLOBAL: CORRECTED**

- **Parte A — "está cifrado en reposo por defecto"**: SUPPORTED verbatim en los tres proveedores.
- **Parte B — "no protege frente a un lector con permisos excesivos"**: **ningún proveedor enuncia el negativo de forma literal**. La afirmación queda *soportada por inferencia* a partir de tres piezas que sí son verbatim: (a) el modelo de amenaza que Azure declara explícitamente (ataque físico al hardware / defensa en profundidad), (b) las declaraciones de transparencia de AWS y Azure ("no hay cambio en la forma en que accedes a los objetos", "se cifra y descifra de forma transparente"), y (c) el hecho de que AWS liste "permisos excesivamente permisivos sobre las claves de descifrado" como *anti-patrón* de control de acceso — lo cual solo tiene sentido si el cifrado por sí mismo no detiene a ese principal. El skill debe presentarlo como inferencia razonada, no como cita.

### 1.A.1 AWS — S3 cifra por defecto

> "Amazon S3 now applies server-side encryption with Amazon S3 managed keys (SSE-S3) as the base level of encryption for every bucket in Amazon S3. Starting January 5, 2023, all new object uploads to Amazon S3 are automatically encrypted at no additional cost and with no impact on performance. SSE-S3, which uses 256-bit Advanced Encryption Standard (AES-256), is automatically applied to all new buckets and to any existing S3 bucket that doesn't already have default encryption configured."

Fuente: `https://docs.aws.amazon.com/AmazonS3/latest/userguide/default-encryption-faq.html`, verbatim.

Y sobre la imposibilidad de desactivarlo:

> "No. SSE-S3 is the new base level of encryption that's applied to all the new objects being uploaded to your bucket. You can no longer disable encryption for new object uploads."

Fuente: misma página, respuesta a "Can I disable encryption for the new objects being written to my bucket?", verbatim.

**Matiz que el skill NO debe omitir** — el cifrado por defecto aplica a objetos *nuevos*, no retroactivamente:

> "No. Beginning on January 5, 2023, Amazon S3 only automatically encrypts new object uploads. To encrypt existing objects, you can use S3 Batch Operations to create encrypted copies of your objects."

Fuente: misma página, verbatim.

### 1.A.2 Azure — Storage cifra por defecto y no se puede desactivar

> "Data in Azure Storage is encrypted and decrypted transparently using 256-bit AES encryption, one of the strongest block ciphers available, and is FIPS 140-2 compliant. Azure Storage encryption is similar to BitLocker encryption on Windows."
>
> "Azure Storage server-side encryption uses 256-bit AES Galois/Counter Mode (AES-GCM) to encrypt uploaded objects. Azure Storage encryption is enabled for all storage accounts. Azure Storage encryption can't be disabled. Because your data is secured by default, you don't need to modify your code or applications to take advantage of Azure Storage encryption."

Fuente: `https://learn.microsoft.com/en-us/azure/storage/common/storage-service-encryption`, sección "About Azure Storage service-side encryption", verbatim.

### 1.A.3 GCP — Cloud Storage cifra siempre, sin configuración

> "Cloud Storage always encrypts your data on the server side, before it is written to disk, at no additional charge."

Fuente: `https://cloud.google.com/storage/docs/encryption`, verbatim.

> "All data stored within Google Cloud is encrypted at rest using the same hardened key management systems that Google Cloud uses for our own encrypted data. These key management systems provide strict key access controls and auditing, and encrypt user data at rest using the AES-256 encryption standard. Google Cloud owns and controls the keys used to encrypt your data. You can't view or manage these keys or review key usage logs. Data from multiple customers might use the same key encryption key (KEK). No setup, configuration, or management is required."

Fuente: `https://cloud.google.com/kms/docs/cmek`, sección "Default encryption with Google-owned and Google-managed encryption keys", verbatim.

### 1.B.1 El modelo de amenaza declarado: Azure es el único proveedor que lo enuncia de forma directa

> "Encryption at rest protects stored data. Attacks against data at rest include attempts to obtain physical access to the hardware that stores the data and then compromise the contained data. In such an attack, a server's hard drive might be mishandled during maintenance, which allows an attacker to remove the hard drive. The attacker later puts the hard drive into a computer under their control to attempt to access the data."
>
> "Encryption at rest helps prevent an attacker from accessing unencrypted data by ensuring that data is encrypted on disk. If an attacker obtains a hard drive with encrypted data but not the encryption keys, the attacker must defeat the encryption to read the data."

Fuente: `https://learn.microsoft.com/en-us/azure/security/fundamentals/encryption-atrest`, sección "Purpose of encryption at rest", verbatim.

Y el encuadre como control **adicional**, no sustitutivo:

> "In addition to satisfying compliance and regulatory requirements, encryption at rest provides defense-in-depth protection. Microsoft Azure provides a compliant platform for services, applications, and data. The platform also provides comprehensive facility and physical security, data access control, and auditing. However, it's important to provide extra \"overlapping\" security measures in case one of the other security measures fails. Encryption at rest provides such a security measure."

Fuente: misma página, verbatim. Nótese la lista: "facility and physical security, **data access control**, and auditing" aparece como *otra* capa, distinta del cifrado en reposo. Es decir, Microsoft coloca la autorización y el cifrado en reposo como controles separados y superpuestos, no como el mismo control.

### 1.B.2 La transparencia para el llamante autorizado: AWS lo dice de forma explícita

> "No. Default encryption with SSE-S3 automatically encrypts your data as it's written to Amazon S3 and decrypts it for you when you access it. There is no change in the way that you access objects that are automatically encrypted."

Fuente: `https://docs.aws.amazon.com/AmazonS3/latest/userguide/default-encryption-faq.html`, respuesta a "I did not enable encryption for my buckets before this release. Do I need to change the way that I access objects?", verbatim.

> "You are not required to make any changes to your existing applications. Because default encryption is enabled for all of your buckets, all new objects uploaded to Amazon S3 are automatically encrypted."

Fuente: misma página, verbatim.

Esto es exactamente la mitad negativa de la claim expresada en positivo: el cifrado por defecto **no cambia nada** para quien ya tiene permiso de lectura. Un lector sobre-autorizado sigue obteniendo texto plano.

Google dice lo mismo del lado CMEK:

> "When a requester wants to access a resource encrypted with a customer-managed key, the service agent automatically attempts to decrypt the requested resource. If the service agent has permission to decrypt using the key, and you have not disabled or destroyed the key, the service agent provides encrypt and decrypt use of the key. Otherwise, the request fails."
>
> "No additional requester access is required, and since the service agent handles the encryption and decryption in the background, the user experience for accessing resources is similar to using Google Cloud's default encryption."

Fuente: `https://cloud.google.com/kms/docs/cmek`, sección "CMEK-integrated services handle resource access", verbatim.

### 1.B.3 AWS trata el exceso de permisos sobre claves como problema de *control de acceso*, no de cifrado

> "Protecting your data at rest reduces the risk of unauthorized access, when encryption and appropriate access controls are implemented."

Fuente: `https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/protecting-data-at-rest.html`, verbatim. La condicional "when … **and** appropriate access controls are implemented" es la clave: AWS no afirma que el cifrado por sí solo reduzca el riesgo de acceso no autorizado.

Y en la práctica SEC08-BP04, entre los "Common anti-patterns":

> "Using overly permissive permissions on decryption keys."

Fuente: `https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/sec_protect_data_rest_access_control.html`, verbatim.

> "You can enforce access control with the principle of least privilege, which provides only the necessary permissions to users and services to perform their tasks. This includes access to encryption keys. Review your AWS Key Management Service (AWS KMS) policies to verify that the level of access you grant is appropriate and that relevant conditions apply."

Fuente: misma página, verbatim.

### 1.B.4 Google: la separación de funciones existe precisamente porque un principal con todos los permisos puede leer

> "Separation of duties is the concept of ensuring that one principal does not have all necessary permissions required to complete a malicious action. In Cloud Key Management Service, this could be an action such as using a key to access and decrypt data which that user has no valid reason to access."

Fuente: `https://cloud.google.com/kms/docs/separation-of-duties`, verbatim.

> "Security Command Center: Monitor for KMS Role Separation findings to detect any principal, including a Project Owner or a Google service account, that possesses both administrative and cryptographic permissions on a single key."

Fuente: misma página, verbatim.

**Conclusión de la claim 1.** El positivo ("cifrado en reposo por defecto") es verbatim en los tres. El negativo ("no protege frente a un lector con permisos excesivos") **no aparece enunciado como tal en ninguna documentación de proveedor**. Lo que sí está documentado, y es suficiente para sostener la afirmación por composición, es: el modelo de amenaza es el acceso físico al medio de almacenamiento (Azure); el cifrado es una capa *superpuesta* al control de acceso, no el control de acceso (Azure, AWS Well-Architected); el descifrado es transparente para quien ya está autorizado (AWS FAQ, GCP CMEK); y el exceso de permisos sobre claves se cataloga como fallo de control de acceso, no como fallo de cifrado (AWS SEC08-BP04, GCP separation of duties). Por eso el veredicto es **CORRECTED**: la afirmación es correcta, pero el skill no puede citarla, tiene que derivarla.

---

## 2. El término correcto por proveedor para una clave gestionada por el cliente

**VEREDICTO GLOBAL: SUPPORTED**, con hedges terminológicos importantes que el skill debe reproducir.

| Proveedor | Término oficial actual | Abreviatura documentada | Trampa |
|---|---|---|---|
| AWS | **customer managed key** (sin guion), dentro del término paraguas **KMS key** / **AWS KMS key** | ninguna vigente; **CMK** está retirado | "CMK" en AWS significaba *customer master key* y designaba a **todas** las KMS keys, no solo a las del cliente |
| Azure | **customer-managed key** (con guion) | **CMK** (documentada al menos en Azure SQL, usada allí de forma intercambiable con BYOK) | choca con el CMK legado de AWS, que significa otra cosa |
| Google Cloud | **customer-managed encryption key**, abreviado **CMEK** | **CMEK** | Google también usa "customer-managed keys" a secas para las claves de Cloud KMS que uno crea |

### 2.1 AWS — VEREDICTO PARCIAL: SUPPORTED

> "The KMS keys that you create are *customer managed keys*. Customer managed keys are KMS keys in your AWS account that you create, own, and manage. You have full control over these KMS keys, including establishing and maintaining their key policies, IAM policies, and grants, enabling and disabling them, rotating their cryptographic material, adding tags, creating aliases that refer to the KMS keys, and scheduling the KMS keys for deletion."

Fuente: `https://docs.aws.amazon.com/kms/latest/developerguide/concepts.html`, sección "Customer managed keys", verbatim.

AWS distingue tres tipos, y el skill debe conocerlos porque el "por defecto" moderno **no** es una AWS managed key:

> "AWS managed keys are a legacy key type that is no longer being created for new AWS services as of 2021. Instead, new (and legacy) AWS services are using what's known as an *AWS owned key* to encrypt customer data by default."

Fuente: misma página, verbatim.

**El cambio de terminología (esto es lo que la claim pide registrar):**

> "AWS KMS is replacing the term customer master key (CMK) with AWS KMS key and KMS key. The concept has not changed. To prevent breaking changes, AWS KMS is keeping some variations of this term."

Fuente: `https://docs.aws.amazon.com/kms/latest/cryptographic-details/basic-concepts.html`, verbatim.

Y la misma nota, en tiempo verbal perfecto (es decir, el cambio ya está consumado) en la referencia de API:

> "AWS KMS has replaced the term customer master key (CMK) with AWS Key Management Service key and KMS key. The concept has not changed. To prevent breaking changes, AWS KMS is keeping some variations of this term."

Fuente: `https://docs.aws.amazon.com/kms/latest/APIReference/API_CreateKey.html`, verbatim.

**Hedge registrado, sin suavizar**: AWS dice que "mantiene algunas variaciones del término" para no romper compatibilidad. Esto es observable: la página vigente de conceptos ya no usa "CMK" en el cuerpo del texto, pero los **anclas de URL heredados siguen vivos** y el propio User Guide de S3 los enlaza — `concepts.html#customer-cmk`, `concepts.html#aws-managed-cmk`, `concepts.html#symmetric-cmks` (verificable en `https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html`). Es decir: el término está retirado de la prosa pero no del todo de la superficie del producto.

### 2.2 Azure — VEREDICTO PARCIAL: SUPPORTED

> "Data in a new storage account is encrypted with Microsoft-managed keys by default. You can continue to rely on Microsoft-managed keys for the encryption of your data, or you can manage encryption with your own keys. If you choose to manage encryption with your own keys, you have two options. You can use either type of key management, or both:
> - You can specify a *customer-managed key* to use for encrypting and decrypting data in Blob Storage and in Azure Files. Customer-managed keys must be stored in Azure Key Vault or Azure Key Vault Managed Hardware Security Module (HSM).
> - You can specify a *customer-provided key* on Blob Storage operations."

Fuente: `https://learn.microsoft.com/en-us/azure/storage/common/storage-service-encryption`, sección "About encryption key management", verbatim.

El término contrapuesto (el "por defecto") tiene **dos nombres oficiales** en Azure, y el skill debe saberlo:

> "**Platform-managed keys (default)** (also sometimes called service-managed keys): Azure automatically handles all aspects of encryption key management, including key generation, storage, rotation, and backup."

Fuente: `https://learn.microsoft.com/en-us/azure/security/fundamentals/encryption-atrest`, sección "Key management options", verbatim. Nótese que la documentación de Storage dice "Microsoft-managed keys" y la de security fundamentals dice "platform-managed keys (also sometimes called service-managed keys)": **tres etiquetas para el mismo concepto**, y la propia Microsoft lo reconoce con "also sometimes called". Este hedge se registra tal cual.

**La colisión de siglas.** Azure sí abrevia su término como "CMK", con un significado distinto al CMK legado de AWS:

> "In this article, the terms Customer Managed Key (CMK) and Bring Your Own Key (BYOK) are used interchangeably, but they represent some differences."

Fuente: `https://learn.microsoft.com/en-us/azure/azure-sql/database/transparent-data-encryption-byok-overview`, sección "Customer Managed Key (CMK) and Bring Your Own Key (BYOK)", verbatim. Obsérvese el hedge del propio Microsoft: "used interchangeably, **but they represent some differences**" — el documento usa CMK y BYOK como sinónimos sabiendo que no lo son del todo.

### 2.3 Google Cloud — VEREDICTO PARCIAL: SUPPORTED

> "This document provides an overview of using Cloud Key Management Service (Cloud KMS) for customer-managed encryption keys (CMEK). Using Cloud KMS CMEK gives you ownership and control of the keys that protect your data at rest in Google Cloud."

Fuente: `https://cloud.google.com/kms/docs/cmek`, verbatim.

> "Customer-managed encryption keys are encryption keys that you own. This capability lets you have greater control over the keys used to encrypt data at rest within supported Google Cloud services, and provides a cryptographic boundary around your data."

Fuente: misma página, sección "Customer-managed encryption keys (CMEK)", verbatim.

Google usa además la forma corta "customer-managed keys" para las mismas claves:

> "The Cloud KMS keys that you create are customer-managed keys. Google Cloud services that use your keys are said to have a *CMEK integration*."

Fuente: misma página, verbatim.

Y el término contrapuesto del lado del "por defecto" es **"Google-owned and Google-managed encryption keys"** (encabezado literal de sección en esa misma página).

**Diferencia clave que el skill debe respetar**: CMEK no es solo un tipo de clave, es un *modo de integración de servicio*. Google lo dice explícitamente:

> "Like Google Cloud's default encryption, CMEK is server-side, symmetric, envelope encryption of customer data. The difference from Google Cloud's default encryption is that CMEK protection uses a key that a customer controls."

Fuente: misma página, sección "What a CMEK-integrated service provides", verbatim.

---

## 3. El acceso a la clave se gobierna con su PROPIA superficie de política, separada de la del almacén de datos

**VEREDICTO GLOBAL: CORRECTED**

- **Parte A — "la clave tiene su propia superficie de política, distinta de la del data store"**: SUPPORTED verbatim en los tres proveedores.
- **Parte B — "un principal generalmente necesita AMBOS: permiso sobre el data store Y permiso de uso de la clave"**: **SUPPORTED solo en AWS**. En Azure y GCP es **CORRECTED**: quien usa la clave es la identidad del servicio (managed identity / service agent), no el llamante; el lector final normalmente **no** necesita permiso sobre la clave. Esta es la corrección más importante de todo el documento.

### 3.A.1 AWS — key policy + IAM + grants. VEREDICTO PARCIAL: SUPPORTED

> "A key policy is a resource policy for an AWS KMS key. Key policies are the primary way to control access to KMS keys. Every KMS key must have exactly one key policy. The statements in the key policy determine who has permission to use the KMS key and how they can use it. You can also use IAM policies and grants to control access to the KMS key, but every KMS key must have a key policy."
>
> "No AWS principal, including the account root user or key creator, has any permissions to a KMS key unless they are explicitly allowed, and never denied, in a key policy, IAM policy, or grant."
>
> "Unless the key policy explicitly allows it, you cannot use IAM policies to allow access to a KMS key. Without permission from the key policy, IAM policies that allow permissions have no effect."

Fuente: `https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html`, verbatim.

Los tres mecanismos, nombrados por el proveedor:

> "To control access to your KMS keys, you can use the following policy mechanisms.
> **Key policy** – Every KMS key has a key policy. It is the primary mechanism for controlling access to a KMS key. …
> **IAM policies** – You can use IAM policies in combination with the key policy and grants to control access to a KMS key. … To use an IAM policy to allow access to a KMS key, the key policy must explicitly allow it. …
> **Grants** – You can use grants in combination with the key policy and IAM policies to allow access to a KMS key. …"

Fuente: `https://docs.aws.amazon.com/kms/latest/developerguide/control-access.html`, verbatim.

> "Unlike IAM policies, which are global, key policies are Regional. A key policy controls access only to a KMS key in the same Region. It has no effect on KMS keys in other Regions."

Fuente: `https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html`, verbatim. (Detalle operativo relevante: la superficie de política de la clave tiene incluso un *scope* distinto al de IAM.)

### 3.A.2 Azure — Key Vault tiene DOS sistemas de autorización propios. VEREDICTO PARCIAL: SUPPORTED

> "Azure Key Vault offers two authorization systems: Azure role-based access control (Azure RBAC), which operates on Azure's control and data planes, and the access policy model, which operates on the data plane alone."
>
> "The access policy model is a legacy authorization system, native to Key Vault, which provides access to keys, secrets, and certificates. You can control access by assigning individual permissions to security principals (users, groups, service principals, and managed identities) at Key Vault scope."

Fuente: `https://learn.microsoft.com/en-us/azure/key-vault/general/rbac-access-policy`, verbatim.

Cuál usar (recomendación explícita del proveedor, con el motivo de seguridad):

> "With the Access Policy permission model, users with the Contributor, Key Vault Contributor, or any role that includes Microsoft.KeyVault/vaults/write permissions can grant themselves data plane access by configuring a Key Vault access policy. This can result in unauthorized access and management of your key vaults, keys, secrets, and certificates."

Fuente: misma página, bloque "Warning", verbatim.

> "Azure RBAC is the recommended authorization system for the Azure Key Vault data plane. Starting with API version […], Azure RBAC is also the default access control model for new key vaults, consistent with the Azure portal experience."

Fuente: misma página, sección "Data plane access control recommendation", verbatim; se ha elidido el identificador de versión de API por consistencia con la regla no-numbers del repo (el texto original nombra una versión concreta).

Y el propio doc de seguridad de Key Vault marca las access policies como no recomendadas:

> "**Don't use legacy access policies**: Legacy access policies have known security vulnerabilities and lack support for Privileged Identity Management (PIM). Don't use them for critical data and workloads. Azure RBAC mitigates potential unauthorized Key Vault access risks."

Fuente: `https://learn.microsoft.com/en-us/azure/key-vault/general/security-features`, verbatim.

La separación plano de control / plano de datos, también verbatim:

> "Azure Key Vault uses Microsoft Entra ID for authentication. Access is controlled through two interfaces: the control plane (for managing Key Vault itself) and the data plane (for working with keys, secrets, and certificates)."

Fuente: misma página, verbatim.

### 3.A.3 GCP — IAM sobre la clave y el key ring. VEREDICTO PARCIAL: SUPPORTED

> "To manage access to Cloud KMS resources, such as keys and key rings, you grant Identity and Access Management (IAM) roles. You can grant or restrict the ability to perform specific cryptographic operations, such as rotating a key or encrypting data. You can grant IAM roles on:
> - A key directly
> - A key ring, inherited by all keys in that key ring
> - A Google Cloud project, inherited by all keys in the project
> - A Google Cloud folder, inherited by all keys in all projects in the folder
> - A Google Cloud organization, inherited by all keys in folders in the organization"

Fuente: `https://cloud.google.com/kms/docs/iam`, sección "Overview", verbatim.

Y la distinción de roles que hace que la superficie de la clave sea genuinamente separada de la del dato:

> "In Cloud KMS, separation of duties requires a strict distinction between the following roles:
> - **Key managers**: Principals who are authorized to manage key lifecycles including creation, deletion, rotation, and state changes—for example, users with the Cloud KMS Admin role.
> - **Key users**: Principals who are authorized to use keys including encryption, decryption, signing, or signature verification—for example, users with the Cloud KMS CryptoKey Encrypter/Decrypter role."

Fuente: `https://cloud.google.com/kms/docs/separation-of-duties`, verbatim.

### 3.B.1 AWS — el llamante SÍ necesita permiso de clave. VEREDICTO PARCIAL: SUPPORTED

> "**Permissions**
> To successfully make a `PutObject` request to encrypt an object with an AWS KMS key to Amazon S3, you need `kms:GenerateDataKey` permissions on the key. To download an object encrypted with an AWS KMS key, you need `kms:Decrypt` permissions for the key. To perform a multipart upload to encrypt an object with an AWS KMS key, you must have the `kms:GenerateDataKey` and `kms:Decrypt` permissions for the key."

Fuente: `https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html`, verbatim.

Esto es la cita que sostiene la parte B de la claim **para AWS**: con SSE-KMS, el principal necesita `s3:GetObject` **y** `kms:Decrypt`. Reforzado en el escenario cross-account:

> "You must specify a key that you (the requester) have been granted `Encrypt` permission to."

Fuente: misma página, verbatim.

**Matiz que cambia el resultado**: esto aplica a **SSE-KMS**, no al cifrado por defecto. Con SSE-S3 (el estado por defecto de todo bucket) no hay ninguna clave de cliente en juego y por tanto no hay segundo permiso: "There is no change in the way that you access objects that are automatically encrypted" (citado en la claim 1). El skill debe decir "con SSE-KMS", no "en S3".

### 3.B.2 Azure — el llamante NO necesita permiso de clave. VEREDICTO PARCIAL: CORRECTED

Quien tiene permisos sobre la clave es la **managed identity de la cuenta de almacenamiento**, no el lector:

> "An Azure Key Vault admin grants permissions to encryption keys to a managed identity. The managed identity may be either a user-assigned managed identity that you create and manage, or a system-assigned managed identity that is associated with the storage account."
>
> "Azure Storage uses the managed identity to which the Azure Key Vault admin granted permissions in step 1 to authenticate access to Azure Key Vault via Microsoft Entra ID."
>
> "The managed identity that is associated with the storage account must have these permissions at a minimum to access a customer-managed key in Azure Key Vault: wrapkey / unwrapkey / get"

Fuente: `https://learn.microsoft.com/en-us/azure/storage/common/customer-managed-keys-overview`, sección "About customer-managed keys", verbatim.

Y la prueba de que el control se ejerce sobre el **estado de la clave**, no sobre los permisos del lector:

> "After the key has been disabled, clients can't call operations that read from or write to a resource or its metadata. Attempts to call these operations will fail with error code 403 (Forbidden) **for all users**."

Fuente: misma página, sección "Revoke access to a storage account that uses customer-managed keys", verbatim (énfasis añadido). El "for all users" es exactamente lo contrario de un permiso por principal: es un interruptor global.

> "When you disable the key in the key vault, the data in your Azure Storage account remains encrypted, but it becomes inaccessible until you reenable the key."

Fuente: `https://learn.microsoft.com/en-us/azure/storage/common/customer-managed-keys-configure-existing-account`, bloque "Caution", verbatim.

### 3.B.3 GCP — el proveedor niega explícitamente el "ambos permisos". VEREDICTO PARCIAL: CORRECTED

Esta es la cita más importante de todo el documento, porque contradice frontalmente la formulación popular de la claim:

> "**CMEK-integrated services handle resource access**
> The principal that creates or views resources in the CMEK-integrated service **does not require** the Cloud KMS CryptoKey Encrypter/Decrypter (`roles/cloudkms.cryptoKeyEncrypterDecrypter`) for the CMEK used to protect the resource.
> Each project resource has a special service account called a *service agent* that performs encryption and decryption with customer-managed keys. After you give the service agent access to a CMEK, that service agent will use that key to protect the resources of your choice."

Fuente: `https://cloud.google.com/kms/docs/cmek`, verbatim (énfasis añadido).

Google además **recomienda activamente** que el llamante no tenga ese permiso:

> "When you use Cloud KMS keys for customer-managed encryption keys, we recommend that the service account is the only principal authorized to use the key for encryption and decryption."
>
> "If you want to create a guardrail to enforce this recommendation, you can use IAM deny policies to remove encryption and decryption permissions from principals other than service accounts."

Fuente: `https://cloud.google.com/kms/docs/separation-of-duties`, verbatim.

> "Cloud KMS Autokey: … it automates separation of duties by automatically granting the key usage role to the required service agent—not to the person requesting the key."

Fuente: misma página, verbatim.

**Conclusión de la claim 3.** "El acceso a la clave se gobierna con su propia superficie de política" es correcto en los tres. "Un principal necesita ambos permisos" es un patrón **de AWS con SSE-KMS**, no una regla de los tres proveedores. En Azure Storage con CMK y en GCP con CMEK, el permiso de uso de la clave lo tiene una identidad de servicio y el lector final no lo necesita; lo que el cliente controla en esos casos es el **estado y la disponibilidad** de la clave (revocación → todo el acceso falla, para todos), no un permiso por principal.

---

## Resumen de veredictos

| # | Claim | AWS | Azure | GCP | Veredicto global |
|---|---|---|---|---|---|
| 1.A | Cifrado en reposo por defecto | **SUPPORTED** (S3 SSE-S3, base level, no desactivable, solo objetos nuevos) | **SUPPORTED** (Storage, "can't be disabled") | **SUPPORTED** ("always encrypts … before it is written to disk") | **SUPPORTED** |
| 1.B | NO protege frente a un lector con permisos excesivos | no enunciado; inferible de la FAQ de default encryption + WA SEC08-BP04 | no enunciado; inferible de "Purpose of encryption at rest" (amenaza física) + defensa en profundidad | no enunciado; inferible de CMEK "transparent" + separation of duties | **CORRECTED** — correcto, pero **ningún proveedor lo dice**; hay que derivarlo, no citarlo |
| 2 | Término correcto de clave gestionada por el cliente | **SUPPORTED** — *customer managed key* (sin guion), paraguas *KMS key*; **CMK retirado** (significaba *customer master key* = todas las KMS keys) | **SUPPORTED** — *customer-managed key* (con guion); abrevia **CMK**; el "por defecto" tiene 3 etiquetas (Microsoft-managed / platform-managed / service-managed) | **SUPPORTED** — *customer-managed encryption key* = **CMEK**; el "por defecto" es *Google-owned and Google-managed encryption keys* | **SUPPORTED** con hedges |
| 3.A | La clave tiene su propia superficie de política | **SUPPORTED** — key policy (obligatoria, una por clave) + IAM + grants; IAM no sirve sin permiso de la key policy | **SUPPORTED** — Key Vault: Azure RBAC (control + data plane) vs. access policies (legacy, data plane, desaconsejadas) | **SUPPORTED** — IAM sobre key / key ring / project / folder / organization | **SUPPORTED** |
| 3.B | El principal necesita AMBOS permisos (dato + clave) | **SUPPORTED** — solo con SSE-KMS: `kms:GenerateDataKey` para escribir, `kms:Decrypt` para leer | **CORRECTED** — los permisos `wrapkey`/`unwrapkey`/`get` los tiene la managed identity de la cuenta, no el lector | **CORRECTED** — verbatim: el principal "does not require" el rol Encrypter/Decrypter; lo usa el *service agent* | **CORRECTED** |

## Implicación para el skill

1. **No afirmar que "ningún proveedor dice que el cifrado en reposo no protege del lector sobre-autorizado" equivale a que la afirmación sea dudosa.** Es correcta, pero es una inferencia. Redactarla apoyada en lo que sí está documentado: el modelo de amenaza es el medio físico (Azure), el cifrado es una capa superpuesta al control de acceso (Azure, AWS WA), y el descifrado es transparente para quien ya tiene permiso (AWS FAQ, GCP CMEK).

2. **Usar exactamente estos términos, y no mezclarlos:**
   - AWS → **customer managed key** (sin guion) / término paraguas **KMS key** o **AWS KMS key**. Nunca escribir "CMK" en contexto AWS: está retirado y, además, significaba *customer master key*, que designaba a **todas** las KMS keys (incluidas las gestionadas por AWS), no solo a las del cliente.
   - Azure → **customer-managed key** (con guion). Si se abrevia "CMK", advertir que en Azure significa *Customer Managed Key* y no colisiona con el sentido AWS.
   - GCP → **customer-managed encryption key (CMEK)**.
   - Los contrapuestos: AWS **AWS owned key** (el que se usa hoy por defecto) y **AWS managed key** (legado, ya no se crea para servicios nuevos); Azure **Microsoft-managed key** / **platform-managed key** / **service-managed key** (tres etiquetas, Microsoft lo reconoce con "also sometimes called"); GCP **Google-owned and Google-managed encryption keys**.

3. **Reformular la claim 3 respecto a lo que asumía el plan.** No escribir "un principal necesita permiso sobre el almacén y sobre la clave" como regla general de los tres proveedores. La formulación correcta es: *la clave siempre tiene su propia superficie de política, separada de la del almacén de datos; quién debe tener permiso sobre esa superficie depende del proveedor* — el llamante en AWS con SSE-KMS, la identidad de servicio (managed identity en Azure, service agent en GCP) en los modelos CMK/CMEK. En estos últimos, el control del cliente se ejerce sobre el **estado de la clave** (deshabilitar → todo acceso falla, para todos los usuarios), no sobre un permiso por principal.

4. **Precisar el alcance del "por defecto" en S3.** SSE-S3 se aplica automáticamente a **objetos nuevos**; no reencripta retroactivamente los existentes. Y el permiso extra de KMS aparece solo con **SSE-KMS**, no con el cifrado por defecto.

5. **En Azure, si el skill menciona el modelo de acceso de Key Vault, debe decir que Azure RBAC es el recomendado y que las access policies son legacy con vulnerabilidades conocidas** — la documentación de Microsoft lo dice en un bloque "Warning", no de pasada.

6. **Aplicar la regla no-numbers.** Nada de periodos de rotación, cuotas de peticiones, límites de número de claves, precios ni versiones de API. AES-256, AES-GCM, AES-128 y FIPS 140-2 sí se pueden nombrar: son nombres de algoritmo y de estándar.
