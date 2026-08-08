# Research: Identidad de workload sin credencial almacenada — terminología vigente, propósito declarado y alcance fuera del proveedor (AWS, Azure, GCP)

**Fecha:** 2026-08-08

**Alcance:** verificación de las 3 claims del Paso 5 del plan de implementación de la skill de IaC/cloud. Se verifica, por proveedor: (1) el término **vigente** para una identidad que un workload asume sin credencial almacenada, incluyendo renombres y términos superados; (2) si el propósito declarado por el proveedor es eliminar credenciales estáticas de larga vida, **en las palabras del propio proveedor**; (3) si el mecanismo cubre cómputo que corre **fuera** de ese proveedor.

**Páginas consultadas** (todas el 2026-08-08):

AWS
- `https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html`
- `https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_terms-and-concepts.html`
- `https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2.html`
- `https://docs.aws.amazon.com/rolesanywhere/latest/userguide/introduction.html`
- `https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_oidc.html`
- `https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_outbound_getting_started.html`

Azure / Microsoft Entra
- `https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview`
- `https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation`
- `https://learn.microsoft.com/en-us/entra/architecture/service-accounts-managed-identities`
- `https://learn.microsoft.com/en-us/entra/fundamentals/new-name`
- `https://learn.microsoft.com/en-us/azure/service-fabric/concepts-managed-identity`
- `https://learn.microsoft.com/en-us/azure/azure-arc/servers/managed-identity-authentication`
- `https://learn.microsoft.com/en-us/azure/azure-arc/servers/overview`

Google Cloud
- `https://cloud.google.com/iam/docs/service-account-overview`
- `https://cloud.google.com/iam/docs/workload-identities`
- `https://cloud.google.com/iam/docs/workload-identity-federation`
- `https://cloud.google.com/kubernetes-engine/docs/concepts/workload-identity`
- `https://cloud.google.com/iam/docs/migrate-from-service-account-keys`
- `https://cloud.google.com/blog/products/identity-security/make-iam-for-gke-easier-to-use-with-workload-identity-federation`

---

**Nota de método**

- **Ningún sitio devolvió 403.** El método usado para las tres nubes fue `curl -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ... Chrome/120.0 Safari/537.36"` seguido de extracción a texto plano con un script Python (eliminación de `<script>`/`<style>`, desescape de entidades, colapso de espacios). Funcionó igual de bien en `docs.aws.amazon.com`, `cloud.google.com` y `learn.microsoft.com`. No fue necesario recurrir al workaround documentado por bloqueo de user-agent, pero se usó el mismo user-agent por precaución.
- **Microsoft Learn MCP** (`microsoft_docs_fetch` / `microsoft_docs_search`) se usó de forma complementaria para las dos páginas centrales de Azure (managed identities overview y workload identity federation) y para **localizar** la nota oficial del renombre `MSI → managed identities`. Las citas de este documento se verificaron además contra el texto descargado por `curl`, que es el que queda archivado.
- **WebSearch** se usó exclusivamente para *localizar* la página de Google Cloud que documenta el renombre de GKE. La cita correspondiente **no** proviene del resumen del buscador: se extrajo del HTML del blog descargado con `curl` (`identity-gcp-gke-rename-blog.txt`, línea 86).
- **Una URL resultó inexistente:** `https://cloud.google.com/iam/docs/workload-identity-overview` devuelve **404**. La página vigente equivalente es `https://cloud.google.com/iam/docs/workload-identities` ("Identities for workloads"), que es la que se usó. El archivo del 404 se conserva como evidencia.
- **Fuentes crudas:** todos los textos descargados están en el directorio de scratchpad de esta sesión, bajo `raw/`, con prefijo `identity-`. El archivo `identity-MANIFEST.txt` mapea cada archivo a su URL de origen para que las citas de este documento sean auditables con `grep`.
- **Regla de "sin cifras":** varias de las páginas consultadas contienen límites concretos (número máximo de credenciales federadas por aplicación de Entra ID, número de claves de firma que el identity platform almacena, límite de conexiones concurrentes al metadata server de GKE, ventana de tolerancia de reloj para JWT en IAM). **Ninguna de esas frases se cita aquí**, precisamente para no introducir cifras al skill. Donde una cita habría arrastrado una cifra, se eligió otra frase equivalente de la misma página. Las duraciones de los tokens se reportan solo como el proveedor las califica ("temporary", "short-lived"), con la duración concreta elidida como `[…]` — de hecho ninguna de las citas seleccionadas contiene una duración concreta.

---

## 1. Término vigente en cada proveedor para una identidad que un workload asume sin credencial almacenada

**VEREDICTO GENERAL: CORRECTED.**

La claim es correcta en que cada proveedor tiene un término, pero la formulación ingenua ("cada nube tiene su managed identity") es errónea en dos puntos verificados: (a) en GCP el término que designa la variante *sin credencial almacenada* **no** es "service account" a secas — una service account puede tener llaves — sino la service account **adjunta** (*attached service account*), y (b) hay renombres vigentes en Azure y en GCP que hacen que buena parte del material público use nombres superados.

### 1.1 AWS — **VEREDICTO POR PROVEEDOR: SUPPORTED**

Término vigente: **IAM role**. Para EC2 el vehículo de entrega es el **instance profile**.

> "An IAM role is an IAM identity that you can create in your account that has specific permissions. An IAM role is similar to an IAM user, in that it is an AWS identity with permission policies that determine what the identity can and cannot do in AWS. However, instead of being uniquely associated with one person, a role is intended to be assumable by anyone who needs it. Also, a role does not have standard long-term credentials such as a password or access keys associated with it. Instead, when you assume a role, it provides you with temporary security credentials for your role session."

Fuente: `https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html`, verbatim.

Sobre el instance profile, que es la pieza que la simplificación popular suele omitir o confundir con el rol:

> "This extra step is the creation of an instance profile attached to the instance. The instance profile contains the role and can provide the role's temporary credentials to an application that runs on the instance."

Fuente: `https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2.html`, verbatim.

AWS también nombra explícitamente el subtipo **service role**:

> "A service role is an IAM role that a service assumes to perform actions on your behalf."

Fuente: `https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html`, sección "Roles terms and concepts", verbatim.

**Renombres:** ninguno detectado. AWS no ha renombrado "IAM role", "instance profile" ni "service role" en las páginas consultadas. AWS **no** usa el término "managed identity" ni "workload identity" como nombre de producto.

### 1.2 Azure — **VEREDICTO POR PROVEEDOR: CORRECTED**

Término vigente: **managed identity** (*managed identities for Azure resources*), en dos variantes: **system-assigned** y **user-assigned**.

> "A managed identity is an identity that can be assigned to an Azure compute resource (Azure Virtual Machine, Azure Virtual Machine Scale Set, Service Fabric Cluster, Azure Kubernetes cluster) or any App hosting platform supported by Azure. Once a managed identity is assigned on the compute resource, it can be authorized, directly or indirectly, to access downstream dependency resources, such as a storage account, SQL database, Cosmos DB, and so on. Managed identity replaces secrets such as access keys or passwords."

Fuente: `https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview`, verbatim.

Microsoft encuadra "managed identity" dentro de la categoría más amplia **workload identity** — y aquí está el matiz terminológico que el skill debe respetar: en el vocabulario de Microsoft, "workload identity" **no** es sinónimo de "managed identity"; es el género del que managed identity es una especie:

> "At a high level, there are two types of identities: human and machine/non-human identities. Machine / non-human identities consist of device and workload identities. In Microsoft Entra, workload identities are applications, service principals, and managed identities."

Fuente: `https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview`, verbatim.

Distinción entre variantes, verbatim de la misma página:

> "System-assigned. Some Azure resources, such as virtual machines allow you to enable a managed identity directly on the resource."

> "User-assigned. You may also create a managed identity as a standalone Azure resource. You can create a user-assigned managed identity and assign it to one or more Azure Resources."

Y la recomendación explícita de Microsoft, que contradice la suposición popular de que system-assigned es "lo por defecto":

> "User-assigned managed identities, which are provisioned independently from compute and can be assigned to multiple compute resources, are the recommended managed identity type for Microsoft services."

Fuente: `https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview`, verbatim.

**Renombres (los dos que el skill debe declarar):**

Término superado 1 — **MSI / Managed Service Identity**:

> "Managed identities for Azure is the new name for the service formerly known as Managed Service Identity (MSI)."

Fuente: `https://learn.microsoft.com/en-us/azure/service-fabric/concepts-managed-identity`, verbatim. *(Nota: esta declaración aparece en una página de producto — Service Fabric — no en la overview central de managed identities; es la formulación más explícita que se encontró en documentación oficial vigente.)*

Término superado 2 — **Azure Active Directory / Azure AD**:

> "Microsoft renamed Azure Active Directory (Azure AD) to Microsoft Entra ID to communicate the multicloud, multiplatform functionality of the products, alleviate confusion with Windows Server Active Directory, and unify the Microsoft Entra product family."

Fuente: `https://learn.microsoft.com/en-us/entra/fundamentals/new-name`, verbatim.

La misma página confirma que la familia de producto para identidades de workload se llama hoy **Microsoft Entra Workload ID**, listada junto a Microsoft Entra ID, Microsoft Entra External ID y Microsoft Entra ID Governance.

**Por qué se marca CORRECTED:** la claim tal como la asume el plan trata "workload identity" como el término Azure del concepto. En el vocabulario de Microsoft el término correcto para *la identidad sin credencial almacenada adjunta a un recurso de cómputo* es **managed identity**; "workload identity" es la categoría paraguas (que incluye también applications y service principals, los cuales **sí** llevan secreto o certificado). Confundirlos es exactamente el tipo de error que este pase busca prevenir.

### 1.3 GCP — **VEREDICTO POR PROVEEDOR: CORRECTED**

Google Cloud tiene **tres** términos distintos y el skill debe no mezclarlos.

Primero, la **service account** no es por sí misma la identidad sin credencial: la propia doc de Google lista la llave como una de las formas de autenticarse como service account.

> "A service account is a special kind of account typically used by an application or compute workload, such as a Compute Engine instance, rather than a person. A service account is identified by its email address, which is unique to the account."

> "The most common way to let an application authenticate as a service account is to attach a service account to the resource running the application. For example, you can attach a service account to a Compute Engine instance so that applications running on that instance can authenticate as the service account."

> "There are other ways to let applications authenticate as service accounts besides attaching a service account. For example, you could set up Workload Identity Federation to allow external workloads to authenticate as service accounts, or create a service account key and use it in any environment to obtain OAuth 2.0 access tokens."

Fuente: `https://cloud.google.com/iam/docs/service-account-overview`, verbatim.

El término que designa la variante sin credencial almacenada es **attached service account**:

> "For some Google Cloud resources, you can specify a user-managed service account that the resource uses as its default identity. This process is known as attaching the service account to the resource, or associating the service account with the resource."

Fuente: `https://cloud.google.com/iam/docs/workload-identities`, verbatim.

Y la doc explicita que, con una service account adjunta, las credenciales son de corta duración y automáticas (duración concreta elidida: la fuente no da ninguna en esta frase, y el skill debe decir solo "short-lived"):

> "Obtaining short-lived credentials. In many cases, such as attached service accounts and commands using the gcloud CLI `--impersonate-service-account` flag, these credentials are obtained automatically—you don't need to create or manage them yourself."

Fuente: `https://cloud.google.com/iam/docs/service-account-overview`, verbatim.

Segundo término: **Workload Identity Federation** — para workloads externos.

> "Using Workload Identity Federation, you can provide on-premises or multicloud workloads with access to Google Cloud resources by using federated identities instead of a service account key."

Fuente: `https://cloud.google.com/iam/docs/workload-identity-federation`, verbatim.

Tercer término: **Workload Identity Federation for GKE** — específico de GKE, con **renombre confirmado**.

> "Workload Identity Federation for GKE lets you use IAM policies to grant Kubernetes workloads in your GKE cluster access to specific Google Cloud APIs without needing manual configuration or less secure methods like service account key files."

> "Workload Identity Federation for GKE is available through IAM Workload Identity Federation, which provides identities for workloads that run in environments inside and outside Google Cloud."

Fuente: `https://cloud.google.com/kubernetes-engine/docs/concepts/workload-identity`, verbatim.

El nombre superado, declarado por Google:

> "The preferred option has been to use GKE Workload Identity. Earlier this year, we renamed it Workload Identity Federation for GKE, and rolled out a significant update that made it even easier to use."

Fuente: `https://cloud.google.com/blog/products/identity-security/make-iam-for-gke-easier-to-use-with-workload-identity-federation`, verbatim.

**Hedge que se debe conservar:** este renombre está declarado en el **blog** de Google Cloud, no en una nota de renombre dentro de la documentación de referencia. La documentación vigente simplemente usa el nombre nuevo en todas partes sin declarar el anterior. Buscando `formerly` / `previously` / `renamed` en las páginas de concepto y how-to de GKE no aparece ninguna nota de renombre. El skill puede afirmar el renombre, pero apoyado en el blog, no en la doc de referencia.

Nota adicional de terminología GCP: la página "Identities for workloads" lista además **managed workload identities** (identidades atestiguadas para Compute Engine y GKE, orientadas a mTLS entre workloads) y **agent identities**. Son conceptos distintos de Workload Identity Federation y el skill no debe usar "managed workload identity" como sinónimo de "attached service account".

---

## 2. El propósito del patrón es eliminar credenciales estáticas de larga vida, en las palabras del proveedor

**VEREDICTO GENERAL: CORRECTED.** Dos de los tres proveedores lo dicen de forma reconocible; **Azure nunca lo dice llanamente** en los términos de la claim, y su formulación real es distinta en un sentido que importa.

### 2.1 AWS — **VEREDICTO POR PROVEEDOR: SUPPORTED**

AWS es el único de los tres que usa literalmente la expresión "long-term credentials", y lo hace varias veces.

> "Also, a role does not have standard long-term credentials such as a password or access keys associated with it. Instead, when you assume a role, it provides you with temporary security credentials for your role session."

Fuente: `https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html`, verbatim.

> "Instead, you can and should use an IAM role to manage temporary credentials for applications that run on an Amazon EC2 instance. When you use a role, you don't have to distribute long-term credentials (such as sign-in credentials or access keys) to an Amazon EC2 instance. Instead, the role supplies temporary permissions that applications can use when they make calls to other AWS resources."

Fuente: `https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2.html`, verbatim.

> "However, we strongly recommend that you do not store AWS credentials long-term in applications outside AWS. Instead, configure your applications to request temporary AWS security credentials dynamically when needed using OIDC federation."

Fuente: `https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_oidc.html`, verbatim.

> "Using IAM Roles Anywhere means you don't need to manage long-term AWS credentials for workloads running outside of AWS."

Fuente: `https://docs.aws.amazon.com/rolesanywhere/latest/userguide/introduction.html`, verbatim.

### 2.2 Azure — **VEREDICTO POR PROVEEDOR: CORRECTED**

Microsoft **no** enuncia el propósito como "eliminar credenciales estáticas de larga vida". Lo enuncia como **eliminar la necesidad de que un desarrollador gestione credenciales**, y además dice explícitamente que las credenciales siguen existiendo — solo que la plataforma las gestiona y las rota. Ese es el hedge y no debe suavizarse.

Lo más cercano a la claim:

> "A common challenge for developers is the management of secrets, credentials, certificates, and keys used to secure communication between services. Manual handling of secrets and certificates are a known source of security issues and outages. Managed identities eliminate the need for developers to manage these credentials. Applications can use managed identities to obtain Microsoft Entra tokens without having to manage any credentials."

Fuente: `https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview`, verbatim. Nótese: *eliminate the need for developers to **manage** these credentials*, no "eliminate the credentials".

La frase que explicita que las credenciales existen y son rotadas por la plataforma:

> "With managed identities, credentials are fully managed, rotated, and protected by Azure. Identities are provided and deleted with Azure resources."

Fuente: `https://learn.microsoft.com/en-us/entra/architecture/service-accounts-managed-identities`, verbatim.

Y el beneficio que Microsoft sí formula de forma tajante:

> "You don't need to manage credentials. Credentials aren't even accessible to you."

Fuente: `https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview`, verbatim.

Donde Microsoft **sí** se acerca al lenguaje de la claim es en la página de workload identity federation, y aun ahí habla de secretos y certificados que hay que almacenar y rotar, no de "credenciales de larga vida":

> "For a software workload running outside of Azure, or those running in Azure but use app registrations for their identities, you need to use application credentials (a secret or certificate) to access Microsoft Entra protected resources (such as Azure, Microsoft Graph, Microsoft 365, or third-party resources). These credentials pose a security risk and have to be stored securely and rotated regularly. You also run the risk of service downtime if the credentials expire."

> "You eliminate the maintenance burden of manually managing credentials and eliminates the risk of leaking secrets or having certificates expire."

Fuente: `https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation`, verbatim (incluido el error de concordancia "eliminates" del original).

**Consecuencia para el skill:** no atribuir a Microsoft la frase "elimina credenciales de larga vida". La formulación fiel es: *la plataforma gestiona, rota y protege la credencial, y esta no es accesible ni siquiera para ti*.

### 2.3 GCP — **VEREDICTO POR PROVEEDOR: SUPPORTED, con hedge**

Google lo enuncia, pero apuntando al objeto concreto (la **service account key**) y hablando de eliminar la **carga** de mantenerla y asegurarla, no la credencial en abstracto:

> "Applications running outside Google Cloud can use service account keys to access Google Cloud resources. However, service account keys are powerful credentials, and can present a security risk if they are not managed correctly. Workload Identity Federation eliminates the maintenance and security burden associated with service account keys."

Fuente: `https://cloud.google.com/iam/docs/workload-identity-federation`, verbatim. El hedge está en "eliminates the maintenance and security **burden** associated with service account keys" — no "eliminates service account keys".

La doc de migración lo refuerza en el mismo registro condicional:

> "Service account keys are commonly used to authenticate to Google Cloud services. However, they can also become a security risk if they're not managed properly, increasing your vulnerability to threats like credential leakage, privilege escalation, information disclosure, and non-repudiation."

Fuente: `https://cloud.google.com/iam/docs/migrate-from-service-account-keys`, verbatim. Nótese el "**can** also become a security risk **if** they're not managed properly" — Google no dice que la llave sea insegura per se.

Donde Google sí usa el adjetivo "long-lived" es en el blog, no en la doc de referencia:

> "we're helping our users move away from less secure authentication methods such as long-lived, unauditable, service account keys towards more secure alternatives when authenticating to Google Cloud APIs and services."

Fuente: `https://cloud.google.com/blog/products/identity-security/make-iam-for-gke-easier-to-use-with-workload-identity-federation`, verbatim.

---

## 3. ¿El mecanismo de cada proveedor sirve para cómputo que corre FUERA de ese proveedor?

**VEREDICTO GENERAL: CORRECTED.** Los tres proveedores tienen una ruta para workloads externos, pero la formulación que el plan asumía para Azure ("una managed identity adjunta a un recurso de Azure no se extiende fuera de Azure") es **demasiado tajante**: Azure Arc extiende managed identities a máquinas alojadas fuera de Azure.

### 3.1 AWS — **VEREDICTO POR PROVEEDOR: SUPPORTED**

AWS lista el caso externo dentro de la propia definición de quién puede asumir un rol:

> "Services that deliver temporary security credentials to your applications that run outside of AWS, such as IAM Roles Anywhere or Amazon ECS Anywhere"

Fuente: `https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html`, sección "Roles terms and concepts" (lista "Roles can be assumed by the following"), verbatim.

**Ruta 1 — IAM Roles Anywhere** (basada en certificados X.509):

> "You can use AWS Identity and Access Management Roles Anywhere to obtain temporary security credentials in IAM for workloads such as servers, containers, and applications that run outside of AWS. Your workloads can use the same IAM policies and IAM roles that you use with AWS applications to access AWS resources. Using IAM Roles Anywhere means you don't need to manage long-term AWS credentials for workloads running outside of AWS."

> "To use IAM Roles Anywhere, your workloads must use X.509 certificates issued by your certificate authority (CA). You register the CA with IAM Roles Anywhere as a trust anchor to establish trust between your public-key infrastructure (PKI) and IAM Roles Anywhere."

Fuente: `https://docs.aws.amazon.com/rolesanywhere/latest/userguide/introduction.html`, verbatim.

Límite de alcance que el skill debe conservar (es un dato de diseño, no una cifra):

> "For IAM Roles Anywhere, the trust boundary is established at the account level. This means: Certificates issued by any trust anchor in the account can be used to assume any target role in that same account, unless you specify conditions in the role's trust policy. There is no automatic integration with organization-wide controls."

Fuente: misma página, verbatim.

**Ruta 2 — OIDC federation** (basada en JWT de un IdP externo), que es la ruta natural para CI/CD:

> "With OIDC federation, you don't need to create custom sign-in code or manage your own user identities. Instead, you can use OIDC in applications, such as GitHub Actions or any other OpenID Connect (OIDC)-compatible IdP, to authenticate with AWS. They receive an authentication token, known as a JSON Web Token (JWT), and then exchange that token for temporary security credentials in AWS that map to an IAM role with permissions to use specific resources in your AWS account."

> "OIDC federation supports both machine-to-machine authentication (such as CI/CD pipelines, automated scripts, and serverless applications) and human user authentication."

Fuente: `https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_oidc.html`, verbatim.

*(Dato colateral verificado, no parte de la claim: AWS también tiene la dirección inversa, **outbound identity federation**, que emite un JWT desde AWS para que un workload en AWS se autentique ante un servicio externo — `https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_outbound_getting_started.html`. La propia doc advierte que ese JWT no sirve para federar de vuelta hacia AWS.)*

### 3.2 Azure — **VEREDICTO POR PROVEEDOR: CORRECTED**

Hay que separar tres situaciones, y la claim del plan solo contemplaba dos.

**(a) Managed identity adjunta a un recurso de Azure: sí está acotada — pero el lenguaje de acotamiento es más estrecho de lo que suele citarse.** La frase de scoping que existe en la doc se refiere a la variante *system-assigned*, y acota el uso al **recurso**, no genéricamente a "Azure":

> "By design, only that Azure resource can use this identity to request tokens from Microsoft Entra ID."

Fuente: `https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview`, sección "Managed identity types", viñeta "System-assigned", verbatim.

El acotamiento a plataformas de Azure viene de la definición misma:

> "A managed identity is an identity that can be assigned to an Azure compute resource (Azure Virtual Machine, Azure Virtual Machine Scale Set, Service Fabric Cluster, Azure Kubernetes cluster) or any App hosting platform supported by Azure."

Fuente: misma página, verbatim.

Y la página de workload identity federation confirma el reparto de escenarios:

> "When these workloads run on Azure, you can use managed identities and the Azure platform manages the credentials for you."

Fuente: `https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation`, verbatim.

**(b) Workload identity federation: sí cubre cómputo fuera de Azure.**

> "You use workload identity federation to configure a user-assigned managed identity or app registration in Microsoft Entra ID to trust tokens from an external identity provider (IdP), such as GitHub or Google. The user-assigned managed identity or app registration in Microsoft Entra ID becomes an identity for software workloads running, for example, in on-premises Kubernetes or GitHub Actions workflows. Once that trust relationship is created, your external software workload exchanges trusted tokens from the external IdP for access tokens from Microsoft identity platform."

> "Workloads running on any Kubernetes cluster (Azure Kubernetes Service (AKS), Amazon Web Services EKS, Google Kubernetes Engine (GKE), or on-premises). Establish a trust relationship between your user-assigned managed identity or app in Microsoft Entra ID and a Kubernetes workload"

> "Other workloads running in compute platforms outside of Azure. Configure a trust relationship between your user-assigned managed identity or application in Microsoft Entra ID and the external IdP for your compute platform."

Fuente: `https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation`, verbatim.

Detalle de precisión que el skill debe conservar: en Azure, el objeto federable es una **user-assigned managed identity** o un **app registration** — **no** una system-assigned managed identity. La doc nombra siempre "user-assigned managed identity or app registration" y nunca la variante system-assigned en este contexto.

**(c) Azure Arc: managed identity para máquinas fuera de Azure — el punto que invalida la formulación tajante del plan.**

> "Azure Arc-enabled servers lets you manage Windows and Linux physical servers and virtual machines hosted outside of Azure, on your corporate network or with another cloud provider. With Azure Arc, these machines that you host outside of Azure are considered hybrid machines, with a representation of each machine in Azure."

Fuente: `https://learn.microsoft.com/en-us/azure/azure-arc/servers/overview`, verbatim.

> "Applications or processes running directly on an Azure Arc-enabled server can use managed identities to access other Azure resources that support Microsoft Entra ID-based authentication. An application can obtain an access token representing its identity, which is system-assigned for Azure Arc-enabled servers, and use it as a bearer token to authenticate itself to another service."

Fuente: `https://learn.microsoft.com/en-us/azure/azure-arc/servers/managed-identity-authentication`, verbatim.

> "When you onboard your server to Azure Arc-enabled servers and configure it to use a managed identity, several actions occur (similar to what happens for an Azure VM)"

Fuente: misma página, verbatim.

**Por qué CORRECTED:** decir "una managed identity solo funciona dentro de Azure" es falso para un pipeline híbrido. La formulación correcta es: *una managed identity requiere que el cómputo sea un recurso de Azure Resource Manager; un servidor on-prem o en otra nube puede llegar a serlo vía Azure Arc, y entonces recibe una managed identity system-assigned. Si el cómputo no es ni recurso nativo ni recurso Arc, la vía es workload identity federation sobre una user-assigned managed identity o un app registration.*

### 3.3 GCP — **VEREDICTO POR PROVEEDOR: SUPPORTED**

Google separa el caso interno del externo de forma explícita en la misma página.

Para workloads en Google Cloud, los métodos son "Attached service accounts / Workload Identity Federation for GKE (for workloads running on Google Kubernetes Engine only) / Managed workload identities (for workloads that run on Compute Engine and GKE only) / Service account keys". Para workloads externos:

> "If you're running workloads outside of Google Cloud, you can use the following methods to configure identities for your workloads: Workload Identity Federation / Service account keys"

> "You can use Workload Identity Federation with workloads on Google Cloud or external workloads that run on platforms such as AWS, Azure, GitHub, and GitLab."

> "Workload Identity Federation lets you use credentials from external identity providers like AWS, Azure, and Active Directory to generate short-lived credentials, which workloads can use to temporarily impersonate service accounts."

> "Workload Identity Federation is the preferred way to configure identities for external workloads."

Fuente: `https://cloud.google.com/iam/docs/workload-identities`, verbatim.

Lista de orígenes soportados, verbatim de la página de referencia:

> "You can use Workload Identity Federation with workloads that authenticate using X.509 client certificates; that run on Amazon Web Services (AWS) or Azure; on-premises Active Directory; deployment services, such as GitHub and GitLab; and with any identity provider (IdP) that supports OpenID Connect (OIDC) or Security Assertion Markup Language (SAML) V2.0."

Fuente: `https://cloud.google.com/iam/docs/workload-identity-federation`, verbatim.

Dos modos de acceso, cuya distinción el skill no debe borrar:

> "With Workload Identity Federation, you can use Identity and Access Management (IAM) to grant IAM roles to principals that are based on federated identities in a workload identity pool. You can grant access to the principals on specific Google Cloud resources. This approach is called direct access. Alternatively, you can grant access to a service account, which can then access Google Cloud resources. This approach is called service account impersonation."

> "We recommend that you use Workload Identity Federation to provide access directly to a Google Cloud resource. Although most Google Cloud APIs support Workload Identity Federation, some APIs have limitations. As an alternative, you can use service account impersonation."

Fuente: `https://cloud.google.com/iam/docs/workload-identity-federation`, verbatim. **Hedge que se debe conservar:** Google recomienda acceso directo pero advierte que "some APIs have limitations" — no promete cobertura universal.

**Scoping del mecanismo interno:** la *attached service account* está declarada como método para "workloads on Google Cloud" y no aparece en la lista de métodos para workloads externos. Además:

> "In most cases, you must attach a service account to a resource when you create that resource. After the resource is created, you cannot change which service account is attached to the resource. Compute Engine instances are an exception to this rule; you can change which service account is attached to an instance as needed."

Fuente: `https://cloud.google.com/iam/docs/workload-identities`, verbatim.

---

## Resumen de veredictos

| # | Claim | AWS | Azure | GCP | Veredicto general |
|---|-------|-----|-------|-----|-------------------|
| 1 | Término vigente para la identidad sin credencial almacenada; renombres y términos superados | **SUPPORTED** — "IAM role" + "instance profile"; sin renombres | **CORRECTED** — el término es "managed identity", no "workload identity" (que es la categoría paraguas); renombres: MSI → managed identities, Azure AD → Microsoft Entra ID | **CORRECTED** — el término es "attached service account", no "service account" a secas; renombre: GKE Workload Identity → Workload Identity Federation for GKE (declarado en blog, no en la doc de referencia) | **CORRECTED** |
| 2 | El propósito declarado es eliminar credenciales estáticas de larga vida, en palabras del proveedor | **SUPPORTED** — usa literalmente "long-term credentials" en cuatro páginas distintas | **CORRECTED** — nunca lo dice llanamente; dice "eliminate the need for developers to **manage** these credentials" y "credentials are fully managed, **rotated**, and protected by Azure" | **SUPPORTED con hedge** — "eliminates the maintenance and security **burden** associated with service account keys"; "long-lived" solo aparece en el blog | **CORRECTED** |
| 3 | El mecanismo cubre cómputo fuera del proveedor | **SUPPORTED** — IAM Roles Anywhere (X.509) y OIDC federation (JWT); trust boundary a nivel de cuenta | **CORRECTED** — managed identity adjunta sí está acotada al recurso, pero Azure Arc lleva managed identities system-assigned a máquinas fuera de Azure; y workload identity federation federa **user-assigned MI o app registration**, nunca system-assigned | **SUPPORTED** — WIF desde AWS/Azure/AD on-prem/GitHub/GitLab/OIDC/SAML/X.509; hedge: "some APIs have limitations" | **CORRECTED** |

## Implicación para el skill

**Tabla de terminología que el skill debe usar (y la que debe evitar):**

| Concepto | AWS | Azure / Microsoft Entra | Google Cloud |
|---|---|---|---|
| Identidad que el cómputo del propio proveedor asume sin credencial almacenada | **IAM role**, entregado a EC2 mediante un **instance profile**; subtipos **service role** y **service-linked role** | **managed identity**, en variantes **system-assigned** y **user-assigned** (Microsoft recomienda user-assigned) | **attached service account** (una *user-managed service account* adjunta al recurso) |
| Identidad para workloads en Kubernetes del propio proveedor | IAM role para tareas de ECS / roles de servicio de EKS | managed identity + workload identity federation (AKS) | **Workload Identity Federation for GKE** |
| Identidad para cómputo fuera del proveedor | **IAM Roles Anywhere** (X.509) y **OIDC federation** hacia un IAM role | **workload identity federation** sobre una **user-assigned managed identity** o un **app registration**; alternativamente **Azure Arc** convierte la máquina externa en recurso Azure con managed identity system-assigned | **Workload Identity Federation** (workload identity pool + workload identity pool provider) |
| Credencial que el patrón sustituye | long-term credentials: password, access keys | secrets: application secret o certificado del app registration | **service account key** |
| Términos superados que NO debe usar el skill sin marcarlos | — | **MSI / Managed Service Identity**; **Azure AD / Azure Active Directory** | **GKE Workload Identity** (nombre anterior de Workload Identity Federation for GKE) |
| Términos que NO debe cruzar entre nubes | no llamar "managed identity" a un IAM role | no llamar "workload identity" a una managed identity: en Entra, *workload identity* incluye applications y service principals, que sí llevan secreto | no llamar "service account" a secas a la variante sin credencial; y no usar "managed workload identities" (mTLS, otro producto) como sinónimo |

**Claims que el skill debe formular distinto de como el plan asumía:**

1. **Claim 2, Azure.** No escribir "Azure elimina las credenciales de larga vida". La formulación fiel a Microsoft es: *la plataforma gestiona, rota y protege la credencial, y esta no es accesible ni siquiera para el dueño de la suscripción*. Microsoft habla de eliminar la **gestión** de credenciales, no las credenciales.
2. **Claim 2, GCP.** No escribir "Workload Identity Federation elimina las service account keys". La doc de referencia dice que elimina la **carga** de mantenimiento y seguridad asociada a ellas; "long-lived" es lenguaje del blog, no de la doc.
3. **Claim 3, Azure.** No escribir "una managed identity no funciona fuera de Azure". Es falso para un pipeline híbrido por Azure Arc. Formulación correcta: *una managed identity requiere que el cómputo sea un recurso de Azure Resource Manager; un servidor on-prem o en otra nube puede serlo vía Azure Arc y recibe entonces una managed identity system-assigned; si no lo es, la vía es workload identity federation sobre una user-assigned managed identity o un app registration.*
4. **Claim 3, Azure (precisión adicional).** En workload identity federation el objeto federable es siempre **user-assigned** managed identity o app registration. Escribir "federas la managed identity" sin calificar es ambiguo y, para system-assigned, incorrecto.
5. **Claim 3, GCP (hedge).** Al recomendar *direct resource access* sobre *service account impersonation*, conservar la advertencia de Google de que algunas APIs tienen limitaciones — no presentar el acceso directo como universalmente soportado.
6. **Claim 1, GCP (procedencia).** El renombre GKE Workload Identity → Workload Identity Federation for GKE está declarado en el blog de Google Cloud; la documentación de referencia usa el nombre nuevo sin declarar el anterior. Si el skill cita el renombre, debe apuntar al blog.
7. **Sin cifras.** Las páginas consultadas contienen límites y ventanas temporales concretas. El skill debe decir "temporary security credentials" (AWS) y "short-lived credentials" (GCP) tal cual el proveedor las califica, y no adjuntar ninguna duración.
