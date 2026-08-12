# Identity, Network and Encryption

[`statefulness-and-the-one-way-door.md`](statefulness-and-the-one-way-door.md) establishes what makes this domain different: the resource holds the thing you cannot recreate. That property is what makes the security boundary around a data store a different problem from the one around an application. An application endpoint exposes the operations it implements right now; a data store endpoint exposes the accumulated history. Loose authorization on an application scopes the damage to what a request can do; loose authorization on a warehouse scopes it to everything ever written.

Three independent controls decide that boundary: **who the pipeline is** (identity), **where it can be reached from** (network placement), and **whether the bytes are readable off the medium** (encryption). None substitutes for another, and the most common failure here is believing the third covers the first.

## A pipeline has nobody sitting in front of it

Almost all access-control writing assumes a human at the other end: an MFA prompt, a session, a login. A scheduled job has none of those, and nobody to challenge. The naive resolution hands the job a credential — an access key, a password, a key file — turning the problem into "where do we keep the secret", which nobody has ever solved well.

All three major providers offer instead an identity attached to the compute, from which credentials are obtained rather than stored. **The term differs by provider, and the terms are not interchangeable.**

**AWS — the term is `IAM role`.** The definition carries the point: "a role does not have standard long-term credentials such as a password or access keys associated with it. Instead, when you assume a role, it provides you with temporary security credentials for your role session." For EC2 the delivery vehicle is a separate object, the **instance profile**, which "contains the role and can provide the role's temporary credentials to an application that runs on the instance." The subtype **service role** is "an IAM role that a service assumes to perform actions on your behalf." AWS is the only one of the three that states the purpose in the words most people paraphrase: with a role "you don't have to distribute long-term credentials".

**Azure — the term is `managed identity`**, in two variants, **system-assigned** and **user-assigned**. Microsoft's recommendation contradicts the popular default: "User-assigned managed identities … are the recommended managed identity type for Microsoft services."

Two precision points. First, **`workload identity` is not Azure's word for this.** In Microsoft Entra it is the genus, not the species: "In Microsoft Entra, workload identities are applications, service principals, and managed identities." Applications and service principals *do* carry a secret or a certificate, so the broader term names the category containing the thing you were avoiding. Second, **Microsoft does not claim to eliminate credentials**: "Managed identities eliminate the need for developers to manage these credentials", and "credentials are fully managed, rotated, and protected by Azure … Credentials aren't even accessible to you." The credential exists; the platform owns its lifecycle. Do not attribute "eliminates long-lived credentials" to Microsoft.

Note two renames, because most material predates them: `Managed Service Identity (MSI)` is superseded — "Managed identities for Azure is the new name for the service formerly known as Managed Service Identity (MSI)" — and `Azure Active Directory` / `Azure AD` is now **Microsoft Entra ID**.

**Google Cloud — the term is `attached service account`, not "service account".** A service account by itself is not the credential-free variant; the alternatives include "create a service account key and use it in any environment." The credential-free variant is attached to the resource: "you can specify a user-managed service account that the resource uses as its default identity. This process is known as attaching the service account to the resource." Its credentials are **short-lived** and "obtained automatically". Google's purpose is scoped to the object it replaces: Workload Identity Federation "eliminates the maintenance and security burden associated with service account keys" — the *burden*, not the keys.

## Compute that runs outside the provider

A real pipeline is rarely all in one place: the build runs in a CI system, an extractor on a server in a datacentre, the transform in the cloud. The axis that matters is whether the mechanism reaches compute the provider does not host.

- **AWS** has two routes. **IAM Roles Anywhere** covers "workloads such as servers, containers, and applications that run outside of AWS", using X.509 certificates from a certificate authority registered "as a trust anchor". Read its scope limit first: "the trust boundary is established at the account level … There is no automatic integration with organization-wide controls." The second route, **OIDC federation**, is the natural one for CI/CD — an external identity provider issues a JWT, exchanged "for temporary security credentials in AWS that map to an IAM role".
- **Azure** does reach outside, so the flat claim that a managed identity only works inside Azure is false for a hybrid pipeline. Two routes, federating different objects. **Workload identity federation** trusts tokens from an external IdP, and the federable object is always "a user-assigned managed identity or app registration" — never a system-assigned one; it covers "workloads running on any Kubernetes cluster" and "other workloads running in compute platforms outside of Azure". Separately, **Azure Arc-enabled servers** brings machines "hosted outside of Azure, on your corporate network or with another cloud provider" into Azure as resources, after which they "can use managed identities" — system-assigned in that case. The rule: a managed identity requires the compute to be an Azure resource, Azure Arc is how an outside machine becomes one, and otherwise use workload identity federation over a user-assigned managed identity or an app registration.
- **Google Cloud** uses **Workload Identity Federation**, "the preferred way to configure identities for external workloads", usable "with workloads that authenticate using X.509 client certificates; that run on Amazon Web Services (AWS) or Azure; on-premises Active Directory; deployment services, such as GitHub and GitLab; and with any identity provider (IdP) that supports OpenID Connect (OIDC) or Security Assertion Markup Language (SAML) V2.0." Two access modes, whose difference you should not collapse: **direct access**, granting IAM roles to the federated principal, and **service account impersonation**. Google recommends direct access, with a hedge to keep: "some APIs have limitations." Inside Google Cloud the GKE-specific mechanism is **Workload Identity Federation for GKE**, previously `GKE Workload Identity` — a rename declared in Google Cloud's blog, not in the reference documentation, which uses the current name throughout.

Whether a service can be reached this way belongs to the **ecosystem fit** axis in [`choosing-a-managed-service.md`](choosing-a-managed-service.md) — the axis most often skipped, and a service your identity plane cannot reach will be reached by a stored key instead.

## Least privilege on a data store: the interesting permission is bulk read

Access-control reviews are trained on write and delete, because those break things. For a data platform the operation that ends careers is **read**, at volume, and it is the permission handed out most casually — it feels harmless, it unblocks an analyst immediately, and nothing visibly changes when you grant it. A broad read grant is the exfiltration surface, and unlike a bad write it leaves the system working perfectly.

**Distinguish reading a table from reading the bytes underneath it.** A warehouse or query engine enforces its controls at its own layer: views projecting a subset of columns, row-level predicates, masking, audit of every statement. If the same data is files in object storage and a principal holds a read grant at the storage layer, the engine is not in the path — the files can be read whole, unfiltered, without the engine's audit trail. Two grants that sound alike ("read access to the customer data") authorize very different blast radii depending on the layer they were written at.

**The access boundary and the contract boundary should be the same boundary.** The table you expose deliberately, with a declared schema and compatibility rules, is the interface — see [`data-contracts-and-schema-compatibility.md`](../../quality-data-engineering/references/data-contracts-and-schema-compatibility.md). The files beneath it carry no compatibility promise. A storage-layer read grant lets a consumer couple to that detail, giving you a consumer whose expectations you never agreed to and cannot see: a data-contract failure that arrived through a permissions change.

## Network placement

The other independent control is reachability. A public endpoint answers anyone who can resolve its name and present a credential; a private path answers only networks you attached to it.

That asymmetry is sharper for a store. **The blast radius is the corpus, not the request**: the accumulated history, including everything deleted from the systems of record but never from the landing zone. And nothing fails closed in front of it; authorization is alone in the path.

**The private path is a named product**, checked 2026-08-12 because this area renames: AWS **PrivateLink** (resource: **interface VPC endpoint**), **Azure Private Link** (**private endpoint**), Google Cloud **Private Service Connect** (**endpoint**). Each is a billed resource: an hourly meter plus a meter per volume processed, AWS charging the hour *per Availability Zone*, Azure splitting processed data by direction. All three are regional by default with a named way out: `cross Region endpoint`, `Global reach`, `global access`. Azure's endpoint still "must be deployed in the same region and subscription as the virtual network"; only its target may sit elsewhere.

**AWS's gateway endpoint is not PrivateLink**, in AWS's own words: "Gateway endpoints do not use AWS PrivateLink, unlike other types of VPC endpoints." It works by route table rather than DNS, carries no charge, and instances reaching S3 or DynamoDB through one "access the service using its public endpoint". Both types exist for both, so this is a choice.

Placement is *in addition to* identity: a private path does not make an over-broad read grant safe, it puts the over-permissioned reader inside the network.

## "Encrypted at rest by default" — what it actually buys

Encryption at rest by default is real, documented, and largely not optional:

- Amazon S3 "applies server-side encryption with Amazon S3 managed keys (SSE-S3) as the base level of encryption for every bucket", and "You can no longer disable encryption for new object uploads." Scope matters — it is not retroactive: S3 "only automatically encrypts new object uploads", and existing objects need S3 Batch Operations "to create encrypted copies".
- Azure Storage: "Data in Azure Storage is encrypted and decrypted transparently using 256-bit AES encryption … Azure Storage encryption is enabled for all storage accounts. Azure Storage encryption can't be disabled."
- Cloud Storage "always encrypts your data on the server side, before it is written to disk, at no additional charge."

Now the misconception this section exists for: **default encryption at rest does not protect you from an over-permissioned reader. It protects you from compromise of the physical medium.** Azure states that threat model plainly — "Attacks against data at rest include attempts to obtain physical access to the hardware that stores the data … a server's hard drive might be mishandled during maintenance" — and frames the control as an overlapping layer, listing "facility and physical security, data access control, and auditing" as the *other* measures it backs up.

No provider states that negative half as such. It is composed from what they do document, so present it as reasoning, not quotation. Decryption is transparent to anyone already authorized — AWS, on default encryption, "There is no change in the way that you access objects that are automatically encrypted", and Google, on CMEK-protected resources, "the user experience for accessing resources is similar to using Google Cloud's default encryption". And excess permission on keys is filed as an access-control failure, not an encryption failure: AWS Well-Architected lists "Using overly permissive permissions on decryption keys" among its common anti-patterns and states the dependency conditionally — "Protecting your data at rest reduces the risk of unauthorized access, **when** encryption and appropriate access controls are implemented." Google's separation-of-duties guidance exists to stop one principal holding everything needed to use "a key to access and decrypt data which that user has no valid reason to access."

An authorized principal reading encrypted data gets plaintext. That is the design, not a gap. "It's encrypted at rest" answers a compliance question and a stolen-disk question, and nothing about the read grant you handed out and forgot.

## Customer-managed keys, in each provider's own term

| Provider | Term for a key you control | Term for the default | Trap |
|---|---|---|---|
| AWS | **customer managed key** (no hyphen), within the umbrella term **KMS key** / **AWS KMS key** | **AWS owned key** encrypts customer data by default; **AWS managed key** is a legacy type "no longer being created for new AWS services" | Do not write `CMK` for AWS: it is retired, and it meant *customer master key* — **all** KMS keys, not only yours |
| Azure | **customer-managed key** (hyphenated); must be stored in Azure Key Vault or Azure Key Vault Managed HSM | **Microsoft-managed key**, also documented as **platform-managed key** and "also sometimes called service-managed keys" — three labels, one concept | Azure does abbreviate `CMK`, and Azure SQL's documentation uses `CMK` and `BYOK` "interchangeably, but they represent some differences". It collides with AWS's retired abbreviation and means something else |
| Google Cloud | **customer-managed encryption key**, abbreviated **CMEK** | **Google-owned and Google-managed encryption keys** | CMEK is a service *integration mode*, not only a key type: "Like Google Cloud's default encryption, CMEK is server-side, symmetric, envelope encryption of customer data. The difference … is that CMEK protection uses a key that a customer controls" |

Using one provider's term for another's mechanism is not a style problem: it sends readers to documentation describing different behaviour, and the behaviour genuinely differs — as the next section shows.

## Key access is its own policy surface — but who needs it depends on the provider

Two claims get merged here. Separate them.

**Holds everywhere: the key has its own policy surface, distinct from the data store's.**

- **AWS**: "Every KMS key must have exactly one key policy … Key policies are the primary way to control access to KMS keys." IAM alone is not enough — "Without permission from the key policy, IAM policies that allow permissions have no effect" — and the surfaces do not even share a scope: "Unlike IAM policies, which are global, key policies are Regional."
- **Azure**: Key Vault "offers two authorization systems: Azure role-based access control (Azure RBAC), which operates on Azure's control and data planes, and the access policy model, which operates on the data plane alone." Which to use is not taste: "Azure RBAC is the recommended authorization system for the Azure Key Vault data plane", anyone holding `Microsoft.KeyVault/vaults/write` "can grant themselves data plane access by configuring a Key Vault access policy", and "Legacy access policies have known security vulnerabilities and lack support for Privileged Identity Management (PIM)."
- **Google Cloud**: IAM roles are granted on "a key directly", a key ring, a project, a folder or an organization, and the model names two disjoint duties — **key managers**, "authorized to manage key lifecycles", and **key users**, "authorized to use keys including encryption, decryption, signing, or signature verification".

**Does not generalise: that a principal needs permission on the data store *and* on the key.** That is an AWS pattern, specifically with SSE-KMS. Write it per provider.

- **AWS, with SSE-KMS: the caller does need both.** "To download an object encrypted with an AWS KMS key, you need `kms:Decrypt` permissions for the key", and writing needs "`kms:GenerateDataKey` permissions on the key" — on top of the S3 permission. Note the scope: SSE-KMS, not the default state of a bucket. Under SSE-S3 there is no customer key in the path and no second permission, which is why S3's default-encryption FAQ can say access does not change.
- **Azure Storage with a customer-managed key: the reader does not need key permission — a service identity holds it.** "An Azure Key Vault admin grants permissions to encryption keys to a managed identity", user-assigned or system-assigned and associated with the storage account, needing `wrapkey` / `unwrapkey` / `get` at a minimum. The customer controls the key's *state*, not a per-principal permission: disable the key and "clients can't call operations that read from or write to a resource or its metadata" — the documentation says **for all users**.
- **Google Cloud with CMEK: the provider denies the both-permissions rule explicitly.** "The principal that creates or views resources in the CMEK-integrated service **does not require** the Cloud KMS CryptoKey Encrypter/Decrypter … for the CMEK used to protect the resource." A **service agent** does the work — "a special service account called a *service agent* that performs encryption and decryption with customer-managed keys" — and Google recommends the reader *not* hold the role: "we recommend that the service account is the only principal authorized to use the key", with IAM deny policies as the guardrail and Cloud KMS Autokey "granting the key usage role to the required service agent—not to the person requesting the key."

The consequence is concrete. On AWS with SSE-KMS the key policy is a genuine second per-principal gate and can carry part of your access-control design. In the Azure and Google Cloud models it cannot: the only lever over a live key is availability, and pulling it takes the store offline for everyone at once. Key revocation there is an **incident-response** control, not an access-control one — so any design saying "we'll restrict who can decrypt" must name its provider and encryption mode before it means anything.

## Secrets for pipelines

Work the residue down in this order.

1. **Prefer no secret.** Everything the provider's identity plane can reach — its own storage, warehouse, queues, key store — should be reached by an attached identity. A secret you never created cannot leak, expire, or be committed.
2. **Reach outward with federation before reaching for a key.** A CI job, an on-premises extractor, a workload in another cloud: that is what the federation mechanisms above are for, and where most stored keys could have been deleted and were not.
3. **What remains goes in a purpose-built store.** Third-party API tokens, partner SFTP credentials and passwords for engines outside the provider's identity plane are irreducible. They belong in a managed secret store, referenced at runtime rather than materialised into configuration, an image or a repository. Consuming-side handling is [`external-api-integration.md`](../../python-data-engineering/references/external-api-integration.md)'s territory; what belongs here is that the credential's home is infrastructure.
4. **Remember the secret store is a data store.** The read-grant section applies to it, and the interesting permission is again bulk read — of every secret it holds. Azure's warning above shows how that grant arrives sideways, through a management role that can attach itself a data-plane policy.

And the one people miss entirely: the infrastructure code provisioning all of this writes a state file, and **that state file can contain secrets in plain text**. It is a data store you did not think of as one, it usually lives in a bucket, and its read grant is usually the broadest here. [`iac-for-stateful-resources.md`](iac-for-stateful-resources.md) covers storing, locking and permissioning it.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| "It's encrypted at rest, so the data is protected" | The threat model is the physical medium; decryption is transparent to anyone already authorized | Audit read grants separately from encryption settings — overlapping layers, not one control |
| Assuming a principal needs permission on the store *and* on the key | True for AWS with SSE-KMS; under Azure customer-managed keys and Google Cloud CMEK a service identity holds it | Name the provider and encryption mode before calling the key a second gate; where it is not one, revocation fails closed for everyone |
| Calling a managed identity a "workload identity", or a Google Cloud identity a bare "service account" | In Microsoft Entra, workload identity also covers applications and service principals, which carry a secret; a Google Cloud service account can have a key | Use `IAM role` (+ `instance profile`), `managed identity` and `attached service account`, each only for its own provider |
| Claiming a managed identity cannot work outside Azure | Azure Arc-enabled servers makes an outside machine an Azure resource with a system-assigned managed identity | Otherwise use workload identity federation over a **user-assigned** managed identity or an app registration |
| Reviewing engine grants and storage grants separately | Views, row filters, masking and audit live at the engine; a storage-layer read grant bypasses all of them | Review both layers as one question; a principal holding both is a finding |
| Treating a private network path as a substitute for least privilege | It limits *where from*, not *how much* | Require identity, network placement and key policy to each hold alone |
| Storing a pipeline credential because "the service needs a password" | Most stored keys are replaceable by an attached identity or federation | Attached identity, then federation, then a secret store referenced at runtime |
