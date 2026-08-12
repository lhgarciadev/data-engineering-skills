# Research: conectividad privada a un servicio gestionado — nombre de producto, endpoint público por defecto, forma del cargo, alcance y la distinción interface/gateway (AWS / Azure / GCP)

**Fecha:** 2026-08-08 (serie de entrega). **Fecha real de consulta de todas las páginas: 2026-08-12.** Todo dato de nombre de producto de este documento queda sellado con esa fecha de comprobación; esta área tiene renombres frecuentes y el sello es parte de la evidencia.

**Alcance:** verificación de las 5 claims de conectividad privada que la skill `iac-cloud-data-engineering` necesita antes de poder nombrar producto alguno en `references/identity-network-and-encryption.md`. Hasta hoy esa sección se abstiene deliberadamente: enuncia la asimetría de riesgo y dice "cada proveedor tiene su propio nombre para el camino privado", sin nombrar ninguno.

**Páginas consultadas** (todas el 2026-08-12):

AWS
- `https://docs.aws.amazon.com/vpc/latest/privatelink/what-is-privatelink.html`
- `https://docs.aws.amazon.com/vpc/latest/privatelink/concepts.html`
- `https://docs.aws.amazon.com/vpc/latest/privatelink/gateway-endpoints.html`
- `https://docs.aws.amazon.com/vpc/latest/privatelink/create-interface-endpoint.html`
- `https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-s3.html`
- `https://aws.amazon.com/privatelink/pricing/`
- `https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_VPC.WorkingWithRDSInstanceinaVPC.html`

Azure
- `https://learn.microsoft.com/en-us/azure/private-link/private-link-overview`
- `https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview`
- `https://learn.microsoft.com/en-us/azure/storage/common/storage-network-security`
- `https://learn.microsoft.com/en-us/azure/storage/common/storage-private-endpoints`
- `https://azure.microsoft.com/en-us/pricing/details/private-link/`

Google Cloud
- `https://cloud.google.com/vpc/docs/private-service-connect`
- `https://cloud.google.com/vpc/docs/about-accessing-vpc-hosted-services-endpoints`
- `https://cloud.google.com/vpc/pricing`
- `https://cloud.google.com/sql/docs/mysql/configure-ip`

**Nota de método**: todas las páginas se descargaron con `curl -A "Mozilla/5.0 …"` y se convirtieron a texto plano con un script Python de stripping de HTML; los archivos quedaron en un directorio scratchpad local de la sesión, y cada cita de este documento es grepeable en ellos. No se recibió ningún 403. **No se usó `WebSearch` en esta ronda**: todas las URLs se alcanzaron directamente. **No se usó el MCP de Microsoft Learn como fuente citable**; las citas de Azure provienen del HTML servido por `learn.microsoft.com` y por `azure.microsoft.com`.

**Bloqueo parcial que hay que registrar, no rellenar**: la página de precios de Azure Private Link (`azure.microsoft.com/…/private-link/`) renderiza las cifras por JavaScript. Servida sin JS, muestra los nombres de medidor con el importe como marcador `$-`. Esto **favorece** la regla no-numbers de este repo: los medidores son citables literalmente y no hay ninguna cifra que elidir. Pero significa que este documento **no puede afirmar nada sobre magnitudes relativas de precio en Azure**, y no lo hace.

**Nota sobre elisión de cifras**: por la regla no-numbers, toda cifra dentro de una cita se elide visiblemente como `[…]`. Las unidades de facturación (`por hora`, `por GB`, `por GiB procesado`, `por Availability Zone`) **no** son cifras y son exactamente el objeto de la claim 3, así que se conservan literales. Las fechas (`2026-07-23`) y los identificadores de versión no son cifras y se conservan.

---

## 1. El nombre de producto vigente de cada proveedor para alcanzar un servicio gestionado por camino privado, en palabras del propio proveedor

**VEREDICTO GLOBAL: SUPPORTED**, con un matiz de nomenclatura en AWS que la claim 5 desarrolla y que el skill no puede omitir.

| Proveedor | Nombre del producto/capacidad | Nombre del recurso que se crea | Comprobado |
|---|---|---|---|
| AWS | **AWS PrivateLink** | **interface VPC endpoint** (y, sin PrivateLink, **gateway endpoint**) | 2026-08-12 |
| Azure | **Azure Private Link** | **private endpoint** (y **Private Link service** del lado productor) | 2026-08-12 |
| Google Cloud | **Private Service Connect** | **Private Service Connect endpoint** (y **backends**, **interfaces**) | 2026-08-12 |

### 1.1 AWS — VEREDICTO PARCIAL: SUPPORTED

> "AWS PrivateLink is a highly available, scalable technology that you can use to privately connect your VPC to services and resources as if they were in your VPC. You do not need to use an internet gateway, NAT device, public IP address, Direct Connect connection, or AWS Site-to-Site VPN connection to allow communication with the service or resource from your private subnets. Therefore, you control the specific API endpoints, sites, services, and resources that are reachable from your VPC."

Fuente: `https://docs.aws.amazon.com/vpc/latest/privatelink/what-is-privatelink.html`, verbatim.

El recurso que el consumidor crea se llama **VPC endpoint**, y AWS enumera sus tipos:

> "A consumer creates a VPC endpoint to connect their VPC to an endpoint service or resource. A consumer must specify the endpoint service, resource, or service network when creating a VPC endpoint. There are multiple types of VPC endpoints. You must create the type of VPC endpoint that you require.
> - Interface - Create an interface endpoint to send TCP or UDP traffic to an endpoint service. Traffic destined for the endpoint service is resolved using DNS.
> - GatewayLoadBalancer - Create a Gateway Load Balancer endpoint to send traffic to a fleet of virtual appliances using private IP addresses. …
> - Resource - Create a resource endpoint to access a resource that was shared with you and resides in another VPC. …
> - Service network - Create a service-network endpoint to access a service network that you created or was shared with you. …"

Fuente: `https://docs.aws.amazon.com/vpc/latest/privatelink/concepts.html`, sección "VPC endpoints", verbatim.

**Dato de deriva que el skill debe conocer**: la lista vigente al 2026-08-12 incluye los tipos `Resource` y `Service network`, ausentes de la formulación clásica "interface o gateway". Reducir AWS PrivateLink a *interface* y *gateway* es hoy incorrecto contra esta página.

### 1.2 Azure — VEREDICTO PARCIAL: SUPPORTED

> "Azure Private Link enables you to access Azure PaaS Services (for example, Azure Storage and SQL Database) and Azure hosted customer-owned/partner services over a private endpoint in your virtual network."
>
> "Traffic between your virtual network and the service travels the Microsoft backbone network. Exposing your service to the public internet is no longer necessary. You can create your own private link service in your virtual network and deliver it to your customers. Setup and consumption using Azure Private Link is consistent across Azure PaaS, customer-owned, and shared partner services."

Fuente: `https://learn.microsoft.com/en-us/azure/private-link/private-link-overview`, verbatim. La página lleva `Last updated on 2026-07-23`.

Y la definición del recurso:

> "A private endpoint is a network interface that uses a private IP address from your virtual network. This network interface connects you privately and securely to a service that's powered by Azure Private Link. By enabling a private endpoint, you're bringing the service into your virtual network."

Fuente: `https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview`, verbatim.

**Nombres distintos, roles distintos**, y el skill no debe colapsarlos: `private endpoint` es el recurso del **consumidor**; `Private Link service` es el del **productor** ("service behind standard load balancer", en palabras de la misma página de overview).

### 1.3 Google Cloud — VEREDICTO PARCIAL: SUPPORTED

> "Private Service Connect is a capability of Google Cloud networking that allows consumers to access managed services privately from inside their VPC network. Similarly, it allows managed service producers to host these services in their own separate VPC networks and offer a private connection to their consumers. For example, when you use Private Service Connect to access Cloud SQL, you are the service consumer, and Google is the service producer."
>
> "With Private Service Connect, consumers can use their own internal IP addresses to access services without leaving their VPC networks. Traffic remains entirely within Google Cloud. Private Service Connect provides service-oriented access between consumers and producers with granular control over how services are accessed."

Fuente: `https://cloud.google.com/vpc/docs/private-service-connect`, verbatim.

Google nombra explícitamente que "capacidad" no es "un recurso": los recursos tienen nombres propios:

> "Private Service Connect endpoints. Endpoints are deployed by using forwarding rules that provide the consumer an IP address that is mapped to the Private Service Connect service."
>
> "Private Service Connect backends. Backends are deployed by using network endpoint groups (NEGs) that let consumers direct traffic to their load balancer before reaching a Private Service Connect service."
>
> "Service producers can initiate connections to service consumers by using Private Service Connect interfaces."

Fuente: misma página, sección "Private Service Connect types", verbatim.

**Renombre documentado, y el skill debe conocerlo porque el nombre viejo aún circula:**

> "Note: Private Service Connect backends were previously referred to as Private Service Connect endpoints with consumer HTTP(S) service controls."

Fuente: `https://cloud.google.com/vpc/pricing`, sección Private Service Connect, verbatim. Comprobado 2026-08-12.

---

## 2. Si los servicios de datos gestionados son alcanzables en un endpoint público por defecto, por proveedor, y qué hace realmente desactivar el acceso público

**VEREDICTO GLOBAL: CORRECTED.** La formulación popular —"el store está público por defecto y el endpoint privado lo cierra"— es **falsa como generalización de los tres proveedores**, y falsa en direcciones distintas en cada uno.

- **Azure**: SUPPORTED en la forma más limpia. El default documentado es abierto a cualquier red, y hay un interruptor de acceso público separado del endpoint privado.
- **AWS**: **CORRECTED**. AWS **no** publica una noción general de "desactivar el endpoint público" para sus servicios de datos. Para S3/DynamoDB, el endpoint sigue siendo el público incluso a través de un gateway endpoint — AWS lo dice literalmente. El equivalente funcional se ejerce con **política**, no con un interruptor de red. Para RDS sí existe un interruptor (`Public access`), pero su default no está enunciado en la página consultada.
- **GCP**: SUPPORTED con una precondición que el proveedor enuncia explícitamente: en Cloud SQL no se puede desactivar la IP pública sin haber configurado antes la IP privada.

### 2.1 Azure — el default es abierto, y desactivarlo NO afecta al camino privado. VEREDICTO PARCIAL: SUPPORTED

> "Azure Storage firewall rules provide granular control over network access to your storage account's public endpoint. By default, storage accounts allow connections from any network, but you can restrict access by configuring network rules that define which sources can connect to your storage account."

Fuente: `https://learn.microsoft.com/en-us/azure/storage/common/storage-network-security`, verbatim.

Y **qué hace realmente desactivarlo** — esta es la parte que la claim pide y la que más se malinterpreta:

> "You can secure your storage account to only accept connections from your virtual network by configuring the storage firewall to deny access through its public endpoint by default. You don't need a firewall rule to allow traffic from a virtual network that has a private endpoint, since the storage firewall only controls access through the public endpoint. Private endpoints instead rely on the consent flow for granting subnets access to the storage service."
>
> "Additionally, when a private endpoint is configured, traffic from the associated virtual network is always allowed, even if public network access is disabled on the storage account."

Fuente: `https://learn.microsoft.com/en-us/azure/storage/common/storage-private-endpoints`, verbatim.

Es decir, en Azure el firewall y el endpoint privado son **superficies de autorización distintas que no se solapan**: el firewall gobierna el endpoint público y **nada más**; el endpoint privado se autoriza por el flujo de consentimiento. Desactivar el acceso público **no** puede cortar el camino privado, por construcción.

### 2.2 AWS — el gateway endpoint NO deja de usar el endpoint público. VEREDICTO PARCIAL: CORRECTED

Esta es la cita más contraintuitiva de todo el documento y el skill debe reproducirla:

> "When your instances access Amazon S3 or DynamoDB through a gateway endpoint, they access the service using its public endpoint. The security groups for these instances must allow traffic to and from the service."

Fuente: `https://docs.aws.amazon.com/vpc/latest/privatelink/gateway-endpoints.html`, sección "Security", verbatim.

Lo que AWS ofrece en su lugar es **restricción por política**, sobre superficies distintas:

> "A VPC endpoint policy is an IAM resource policy that you attach to a VPC endpoint. It determines which principals can use the VPC endpoint to access the endpoint service. The default VPC endpoint policy allows all actions by all principals on all resources over the VPC endpoint."

Fuente: `https://docs.aws.amazon.com/vpc/latest/privatelink/concepts.html`, verbatim. Obsérvese el default: **permisivo**.

Y del lado del recurso:

> "You can create a bucket policy that restricts access to a specific endpoint by using the `aws:sourceVpce` condition key. The following policy denies access to the specified bucket using the specified actions unless the specified gateway endpoint is used."

Fuente: `https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-s3.html`, sección "Control access using bucket policies", verbatim.

Para bases de datos gestionadas sí existe un interruptor, con nombre propio:

> "When you launch a DB instance inside a VPC, the DB instance has a private IP address for traffic inside the VPC. This private IP address isn't publicly accessible. You can use the Public access option to designate whether the DB instance also has a public IP address in addition to the private IP address. If the DB instance is designated as publicly accessible, its DNS endpoint resolves to the private IP address from within the VPC. It resolves to the public IP address from outside of the VPC. Access to the DB instance is ultimately controlled by the security group it uses."

Fuente: `https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_VPC.WorkingWithRDSInstanceinaVPC.html`, verbatim.

**Marcado como inferencia, no como cita**: la página de RDS **no enuncia cuál es el valor por defecto** de `Public access`. Este documento no lo afirma. Lo que sí está enunciado es la condición necesaria, y esa sí es citable:

> "In addition, for a DB instance to be publicly accessible, the subnets in its DB subnet group must have an internet gateway."

Fuente: misma página, verbatim.

### 2.3 GCP — se puede desactivar la IP pública, pero solo con una precondición. VEREDICTO PARCIAL: SUPPORTED

> "You can disable public IP, but only if your instance is also configured to use Private IP. To enable private IP, see Configuring an existing instance to use private IP."

Fuente: `https://cloud.google.com/sql/docs/mysql/configure-ip`, sección "Disable public IP", verbatim.

Y el efecto colateral operativo, que es exactamente el tipo de dato que hace que esto sea una decisión de infraestructura y no un checkbox:

> "Note: When you disable public IP for an instance, you release its IPv4 address. If you later re-enable public IP for this instance, it gets a different IPv4 address, and all applications that use the public IP address to connect to this instance must be modified."

Fuente: misma página, verbatim.

Google documenta además un estado intermedio — IP pública activa, pero sin ninguna red autorizada:

> "Configure an instance to refuse all public IP connections"

Fuente: misma página, encabezado de sección literal, verbatim.

**Marcado como inferencia**: esta página **no** dice si una instancia nueva de Cloud SQL nace con IP pública activada. Este documento no lo afirma; el default de Cloud SQL queda **UNSUPPORTED** en esta ronda.

---

## 3. Si el camino privado tiene cargo propio, y su forma

**VEREDICTO GLOBAL: SUPPORTED**, con una corrección importante: **no todos los caminos privados cobran**, y la excepción no es marginal — es precisamente la que usan las cargas de datos en AWS.

Forma del cargo, por proveedor y por tipo de recurso (unidades, nunca importes):

| Proveedor | Recurso | Forma del cargo |
|---|---|---|
| AWS | interface / resource endpoint | **por hora y por Availability Zone** + **por GB procesado** |
| AWS | **gateway endpoint** (S3, DynamoDB) | **sin cargo adicional** |
| Azure | private endpoint | **por hora** + **por GB procesado, separado por dirección (inbound / outbound)** |
| Azure | Private Link service (lado productor) | **sin cargo** |
| GCP | PSC endpoint (forwarding rule) | **por hora** + **por GiB procesado** (consumer data processing) |
| GCP | PSC interface | **sin cargo por hora**; sí procesamiento de datos |
| GCP | PSC backend | precio del balanceador, no un medidor propio de PSC |

### 3.1 AWS — VEREDICTO PARCIAL: SUPPORTED

> "You are billed for hourly usage and data processing charges."

Fuente: `https://docs.aws.amazon.com/vpc/latest/privatelink/create-interface-endpoint.html`, verbatim.

La forma completa, en la página de precios:

> "You will be billed for each hour that your VPC endpoint remains provisioned in each Availability Zone, irrespective of the state of its association with the service (learn more). Such hourly billing for your VPC endpoint will stop when you delete it. … Each partial VPC endpoint-hour consumed is billed as a full hour. Data processing charges apply for each Gigabyte processed through the VPC endpoint regardless of the traffic's source or destination."

Fuente: `https://aws.amazon.com/privatelink/pricing/`, verbatim. Nótense las dos precisiones que el skill debe conservar: **por Availability Zone** (no por endpoint), y **con independencia de si el endpoint está asociado a un servicio**: un endpoint huérfano sigue facturando.

Y la excepción, que es la que importa para un data lake:

> "There is no additional charge for using gateway endpoints."

Fuente: `https://docs.aws.amazon.com/vpc/latest/privatelink/gateway-endpoints.html`, verbatim.

### 3.2 Azure — VEREDICTO PARCIAL: SUPPORTED

Los nombres de medidor, literales de la página de precios (con los importes ya ausentes en el HTML servido, ver Nota de método):

> "Private Link Service — No charge for private link service"
>
> "Private endpoint — $- per hour"
>
> "Inbound Data Processed — $- per GB"
>
> "Outbound Data Processed — $- per GB"

Fuente: `https://azure.microsoft.com/en-us/pricing/details/private-link/`, verbatim; los `$-` son literales del HTML servido sin JavaScript, no elisiones de este documento.

La forma direccional, que es específica de Azure y contraintuitiva:

> "Data processed charges will be based on the direction of traffic. e.g. if you are writing to a Storage account through Private Endpoint you will pay for Outbound Data Processed. Similarly, if you are reading from a Storage account through Private Endpoint you will pay for Inbound Data Processed."

Fuente: misma página, verbatim.

Y dos precisiones del FAQ:

> "Partial Hours will be charged as full hours."
>
> "Yes, above prices are premiums for Private Link capability. Data transfer pricing will apply to data."

Fuente: misma página, verbatim. Es decir: el camino privado es un **premio sobre** el transporte, no lo sustituye.

### 3.3 GCP — VEREDICTO PARCIAL: SUPPORTED

Encabezados de columna literales de la tabla de precios (unidades, sin importes):

> "Price per hour (USD)" — "Price per GiB processed, inbound and outbound data transfer"

Fuente: `https://cloud.google.com/vpc/pricing`, sección "Private Service Connect", verbatim.

Y las reglas de forma:

> "Private Service Connect does not charge for inter-zone data transfer for traffic to or from Private Service Connect endpoints."
>
> "Consumer-to-producer traffic is billed to the project of the consumer resource originating the traffic. Producer-to-consumer traffic is billed to the project of the consumer resource receiving the traffic."
>
> "For endpoints with global access, when the endpoint is accessed by resources in other regions, inter-regional data transfer charges also apply to that traffic."

Fuente: misma página, verbatim.

Para la interface, la forma es distinta:

> "Private Service Connect interface used for access to a producer or consumer VPC network — No hourly charge"

Fuente: misma página, verbatim.

**Lo que el skill puede afirmar sin derivar nada**: en los tres proveedores el camino privado es un recurso con **medidor horario propio más un medidor por volumen procesado**, salvo el gateway endpoint de AWS (gratis) y la PSC interface de GCP (sin cargo horario). Ninguna comparación de magnitud entre proveedores es sostenible desde estas fuentes, y este documento no hace ninguna.

---

## 4. Si la conectividad privada es de alcance regional o global

**VEREDICTO GLOBAL: CORRECTED.** La respuesta correcta no es "regional" ni "global": es **regional por defecto en los tres, con una vía explícita de salida en los tres, y con nombres distintos**. Y el caso que sí es rígidamente regional —el gateway endpoint de AWS— es precisamente el que se usa para object storage.

| Proveedor | Default | Vía de salida, con su nombre |
|---|---|---|
| AWS interface endpoint | regional | **cross Region endpoint** (opción documentada en el flujo de creación) |
| AWS gateway endpoint | regional, **sin salida** | ninguna; ni siquiera sale del VPC |
| Azure private endpoint | el endpoint vive en la región de la VNet | **Global reach**: el recurso destino puede estar en otra región |
| GCP PSC endpoint | misma región y misma VPC | **global access** |

### 4.1 AWS — interface: regional con opción cross-region. VEREDICTO PARCIAL: SUPPORTED

> "(Optional) If creating an endpoint to an AWS service in another Region, select the Enable cross Region endpoint checkbox and then select the service region from the drop down."

Fuente: `https://docs.aws.amazon.com/vpc/latest/privatelink/create-interface-endpoint.html`, verbatim.

Y confirmado desde el lado del precio:

> "You can use Interface endpoints to connect to supported VPC endpoint services outside your AWS region. There is no premium for accessing a service in another region. You incur standard PrivateLink charges for data processing and hours. In addition, AWS cross-region data transfer rates will apply."

Fuente: `https://aws.amazon.com/privatelink/pricing/`, verbatim.

### 4.2 AWS — gateway: estrictamente regional, y ni siquiera sale del VPC. VEREDICTO PARCIAL: SUPPORTED

> "A gateway endpoint is available only in the Region where you created it. Be sure to create your gateway endpoint in the same Region as your S3 buckets."

Fuente: `https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-s3.html`, sección "Considerations", verbatim.

> "Traffic that's destined for the service (Amazon S3 or DynamoDB) in a different Region goes to the internet gateway because prefix lists are specific to a Region."

Fuente: `https://docs.aws.amazon.com/vpc/latest/privatelink/gateway-endpoints.html`, verbatim.

Y la limitación que rompe la mayoría de las topologías hub-and-spoke:

> "Endpoint connections cannot be extended out of a VPC. Resources on the other side of a VPN connection, VPC peering connection, transit gateway, or Direct Connect connection in your VPC cannot use a gateway endpoint to communicate with Amazon S3."

Fuente: `https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-s3.html`, verbatim.

### 4.3 Azure — el endpoint es regional, el recurso destino no tiene por qué serlo. VEREDICTO PARCIAL: SUPPORTED

> "Global reach: Connect privately to services running in other regions. The consumer's virtual network could be in region A and it can connect to services behind Private Link in region B."

Fuente: `https://learn.microsoft.com/en-us/azure/private-link/private-link-overview`, sección "Key benefits", verbatim.

Y la restricción exacta, que es la mitad que el nombre "Global reach" oculta:

> "The private endpoint must be deployed in the same region and subscription as the virtual network."
>
> "The private-link resource can be deployed in a different region than the one for the virtual network and private endpoint."

Fuente: `https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview`, verbatim. El *endpoint* es regional; lo global es a qué puede apuntar.

### 4.4 GCP — regional por defecto, con `global access` como opción. VEREDICTO PARCIAL: SUPPORTED

> "By default, the endpoint can be accessed only by clients that are in the same region and the same VPC network (or Shared VPC network) as the endpoint. For information about making endpoints available in other regions, see Global access."

Fuente: `https://cloud.google.com/vpc/docs/about-accessing-vpc-hosted-services-endpoints`, verbatim.

> "Private Service Connect endpoints that are used to access services are regional resources. However, you can make an endpoint available in other regions by configuring global access."
>
> "Global access lets resources in any region send traffic to Private Service Connect endpoints. You can use global access to provide high availability across services that are hosted in multiple regions, or to allow clients to access a service that is not in the same region as the client."

Fuente: misma página, sección "Global access", verbatim.

---

## 5. La distinción que AWS hace entre interface endpoint y gateway endpoint

**VEREDICTO GLOBAL: CORRECTED**, y esta es la corrección más importante del documento. El folclore los presenta como sabores del mismo producto, uno para S3/DynamoDB y otro para lo demás. **AWS dice literalmente lo contrario**: el gateway endpoint **no es PrivateLink**.

### 5.1 AWS declara que el gateway endpoint NO usa PrivateLink

> "There is another type of VPC endpoint, Gateway, which creates a gateway endpoint to send traffic to Amazon S3 or DynamoDB. Gateway endpoints do not use AWS PrivateLink, unlike the other types of VPC endpoints."

Fuente: `https://docs.aws.amazon.com/vpc/latest/privatelink/concepts.html`, verbatim.

Repetido en la propia página de gateway endpoints, es decir, no es una nota al pie aislada:

> "Gateway VPC endpoints provide reliable connectivity to Amazon S3 and DynamoDB without requiring an internet gateway or a NAT device for your VPC. Gateway endpoints do not use AWS PrivateLink, unlike other types of VPC endpoints."

Fuente: `https://docs.aws.amazon.com/vpc/latest/privatelink/gateway-endpoints.html`, verbatim.

**Hedge que se conserva sin suavizar**: ambas páginas viven **dentro** de la guía "AWS PrivateLink" de Amazon VPC. AWS documenta el gateway endpoint en el manual de PrivateLink mientras afirma que no usa PrivateLink. El skill debe registrar la contradicción de encuadre tal cual, no resolverla.

### 5.2 El mecanismo es distinto: DNS e interfaz de red frente a tabla de rutas

Interface endpoint — se resuelve por DNS y materializa una interfaz de red en cada subred:

> "Interface - Create an interface endpoint to send TCP or UDP traffic to an endpoint service. Traffic destined for the endpoint service is resolved using DNS."
>
> "An endpoint network interface is a requester-managed network interface that serves as an entry point for traffic destined to an endpoint service, resource, or service network. For each subnet that you specify when you create a VPC endpoint, we create an endpoint network interface in the subnet."

Fuente: `https://docs.aws.amazon.com/vpc/latest/privatelink/concepts.html`, verbatim.

Gateway endpoint — se materializa como una **ruta**, y la unidad de asociación es la tabla de rutas, no la subred:

> "When you create a gateway endpoint, you select the VPC route tables for the subnets that you enable. The following route is automatically added to each route table that you select. The destination is a prefix list for the service owned by AWS and the target is the gateway endpoint."
>
> "All instances in the subnets associated with a route table associated with a gateway endpoint automatically use the gateway endpoint to access the service. Instances in subnets that aren't associated with these route tables use the public service endpoint, not the gateway endpoint."

Fuente: `https://docs.aws.amazon.com/vpc/latest/privatelink/gateway-endpoints.html`, verbatim.

### 5.3 La consecuencia que AWS enuncia y que el folclore invierte

El gateway endpoint **no** saca el tráfico del endpoint público del servicio:

> "When your instances access Amazon S3 or DynamoDB through a gateway endpoint, they access the service using its public endpoint."

Fuente: misma página, verbatim.

Lo que sí cambia es la dirección de origen que ve el servicio:

> "The source IPv4 or IPv6 addresses from instances in your affected subnets as received by Amazon S3 change from public addresses to the private addresses in your VPC. An endpoint switches network routes, and disconnects open TCP connections. The previous connections that used public addresses are not resumed. We recommend that you do not have any critical tasks running when you create or modify an endpoint; or that you test to ensure that your software can automatically reconnect to Amazon S3 after the connection break."

Fuente: `https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-s3.html`, verbatim. **Este párrafo es operativamente crítico y no aparece en ninguna versión del folclore**: crear un gateway endpoint sobre un VPC vivo corta las conexiones TCP abiertas.

### 5.4 Ambos tipos existen para S3 y para DynamoDB, y AWS lo dice

> "Amazon S3 and DynamoDB support both gateway endpoints and interface endpoints."

Fuente: `https://docs.aws.amazon.com/vpc/latest/privatelink/gateway-endpoints.html`, verbatim.

Es decir, la afirmación "para S3 se usa gateway" no es una regla del producto sino una elección, y la elección tiene forma de coste (claim 3: gateway sin cargo, interface con cargo horario y por GB) y forma de alcance (claim 4: gateway no cruza el borde del VPC, interface sí).

---

## Resumen de veredictos

| # | Claim | AWS | Azure | GCP | Veredicto global |
|---|---|---|---|---|---|
| 1 | Nombre de producto vigente, en palabras del proveedor | **SUPPORTED** — *AWS PrivateLink*; recurso = *VPC endpoint*, tipos vigentes *Interface*, *GatewayLoadBalancer*, *Resource* y *Service network*, más el gateway aparte | **SUPPORTED** — *Azure Private Link*; recurso = *private endpoint* (consumidor) / *Private Link service* (productor) | **SUPPORTED** — *Private Service Connect*; recursos = *endpoints*, *backends*, *interfaces*; renombre documentado backends ← "endpoints with consumer HTTP(S) service controls" | **SUPPORTED** |
| 2 | Endpoint público por defecto y efecto de desactivarlo | **CORRECTED** — no hay interruptor general; con gateway endpoint el acceso sigue siendo "using its public endpoint"; el control es política (`aws:sourceVpce`, endpoint policy con default permisivo). RDS sí tiene `Public access`, cuyo **default no está enunciado** | **SUPPORTED** — "By default, storage accounts allow connections from any network"; el firewall gobierna **solo** el endpoint público; el private endpoint queda permitido aunque el acceso público esté deshabilitado | **SUPPORTED con precondición** — "You can disable public IP, but only if your instance is also configured to use Private IP"; el **default** de IP pública en Cloud SQL queda **UNSUPPORTED** | **CORRECTED** |
| 3 | Cargo propio y su forma | **SUPPORTED** — interface: por hora **y por AZ** + por GB procesado, aunque esté desasociado; **gateway: sin cargo adicional** | **SUPPORTED** — private endpoint por hora + por GB procesado **separado por dirección**; Private Link service sin cargo; es un *premium* sobre el transporte | **SUPPORTED** — endpoint: por hora + por GiB procesado; interface: sin cargo horario; backend: precio de balanceador | **SUPPORTED** |
| 4 | Alcance regional o global | **SUPPORTED** — interface: regional con *cross Region endpoint*; gateway: solo su Región y **no sale del VPC** | **SUPPORTED** — *Global reach*, pero el endpoint "must be deployed in the same region … as the virtual network" | **SUPPORTED** — regional por defecto, *global access* como opción | **CORRECTED** (regional por defecto + salida nombrada en los tres, no "regional" ni "global") |
| 5 | Interface vs gateway según AWS | **CORRECTED** — "Gateway endpoints do not use AWS PrivateLink"; mecanismo por tabla de rutas, no DNS+ENI; acceso "using its public endpoint"; crear/modificar el endpoint **corta conexiones TCP abiertas**; ambos tipos existen para S3 y DynamoDB | n/a | n/a | **CORRECTED** |

## Implicación para el skill

1. **La sección de alcanzabilidad de `identity-network-and-encryption.md` ya puede nombrar producto**, con estos nombres y no otros: **AWS PrivateLink** (recurso: *VPC endpoint*, tipo *interface*), **Azure Private Link** (recurso: *private endpoint*), **Private Service Connect** (recurso: *endpoint*). Sellar la fecha de comprobación: 2026-08-12.

2. **No escribir "el gateway endpoint es la variante de PrivateLink para S3".** AWS afirma dos veces lo contrario. La formulación correcta es: *para S3 y DynamoDB existen dos mecanismos distintos — un gateway endpoint, que AWS declara que no usa PrivateLink y que funciona por tabla de rutas contra el endpoint público del servicio, y un interface endpoint, que sí es PrivateLink.*

3. **Corregir la premisa de "desactivar el acceso público".** Es un interruptor real en Azure y en Cloud SQL (este último con precondición); en AWS para object storage **no existe** como interruptor de red y se ejerce con política de recurso y de endpoint, cuyo default es permisivo. Un skill que enuncie "desactiva el endpoint público del store" como consejo uniforme está dando una instrucción inejecutable en el proveedor donde más se usa object storage.

4. **La forma de coste pertenece a `sizing-and-the-cost-model.md`, no a la sección de red**: medidor horario + medidor por volumen procesado, con dos excepciones nombradas (gateway endpoint de AWS sin cargo; PSC interface sin cargo horario). En AWS el medidor horario es **por Availability Zone** y **corre aunque el endpoint no esté asociado a nada** — eso es un renglón de factura huérfano, exactamente el patrón que ese archivo cataloga.

5. **El alcance se enuncia como "regional por defecto, con una vía de salida nombrada"**, no como "regional" a secas. Los nombres son *cross Region endpoint* (AWS), *Global reach* (Azure) y *global access* (GCP), y en Azure la mitad regional persiste: el endpoint vive en la región de la VNet.

6. **Añadir a la tabla de errores comunes**: crear o modificar un gateway endpoint sobre un VPC en producción **desconecta las conexiones TCP abiertas** contra S3, según AWS. Es un cambio de red con efecto sobre trabajos en vuelo, no una operación transparente.

7. **Lo que sigue siendo abstención**: el default de acceso público de una instancia nueva de Cloud SQL y el default de `Public access` en RDS. Ninguna de las páginas consultadas lo enuncia y este documento no lo rellena de memoria.
