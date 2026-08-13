# Encryption and Secrets

[`statefulness-and-the-one-way-door.md`](statefulness-and-the-one-way-door.md) establishes what makes this domain different: the resource holds the thing you cannot recreate. That property is what makes the security boundary around a data store a different problem from the one around an application. An application endpoint exposes the operations it implements right now; a data store endpoint exposes the accumulated history.

Three independent controls decide that boundary: **who the pipeline is** (identity), **where it can be reached from** (network placement), and **whether the bytes are readable off the medium** (encryption). This file covers the third, together with the governance that arrives with it: what encryption at rest is documented to do, what a key you control changes, who has to hold permission on that key — which differs by provider more than anything else in this skill — and where the credentials identity could not eliminate are kept. The first two controls are [`identity-and-network-access.md`](identity-and-network-access.md). None substitutes for another, and the most common failure here is believing the third covers the first, which is why the opening section is about what default encryption does *not* buy.

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
| Storing a pipeline credential because "the service needs a password" | Most stored keys are replaceable by an attached identity or federation | Attached identity, then federation, then a secret store referenced at runtime |
