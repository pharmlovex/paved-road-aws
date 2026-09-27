# ADR 0001: State management with S3, native locking and KMS-backed state encryption

- **Status:** Accepted
- **Date:** 2026-09-27
- **Phase:** 1 (Foundations)

## Context

OpenTofu records everything it manages in a state file. That file is critical: if it is lost or corrupted, OpenTofu no longer knows what it created, and the platform can no longer be safely changed.

The state file for this platform needs to be:

- **Shared.** It must be usable from a laptop today and from a CI pipeline (GitHub Actions) in phase 4, so it cannot live on one machine.
- **Safe from concurrent writes.** Two `apply` runs at the same time (for example, a developer and the pipeline) must not overwrite each other.
- **Recoverable.** An accidental bad write should be reversible.
- **Confidential.** State contains sensitive values in plain text. Once phase 3 adds RDS, the database password will be stored in state.
- **Cheap and simple** to operate for a small platform.

There is also a bootstrapping problem: the storage for state has to exist before any stack can use it, including the stack that creates it.

## Decision

1. **Store state in a dedicated S3 bucket** (`paved-road-tfstate-<account-id>`), with:
  - versioning enabled, so any previous state version can be restored
  - all public access blocked
  - S3 server-side encryption at rest
  - `prevent_destroy` so the bucket cannot be deleted by an accidental `tofu destroy`
2. **Use OpenTofu's native S3 locking** (`use_lockfile = true`, available since OpenTofu 1.10). A lock file is written next to the state during operations.
3. **Encrypt state client-side with OpenTofu's** `encryption` **block**, using the `aws_kms` key provider and the `aes_gcm` method, with a dedicated KMS key (`alias/paved-road-tfstate`) that has automatic rotation and `prevent_destroy`. Encryption is set to `enforced = true` for both state and plan files.
4. **Give each stack its own state key** within the bucket (`bootstrap/terraform.tfstate`, later `envs/dev/terraform.tfstate`, `envs/prod/terraform.tfstate`), so stacks are isolated and one bucket serves the whole platform.
5. **Solve the bootstrap problem with a self-hosting bootstrap stack.** It is first applied with local state to create the bucket and KMS key, then its state is migrated into the bucket (`tofu init -migrate-state`), then encryption is enabled using a temporary `unencrypted` fallback that is removed once state has been rewritten encrypted.

## Alternatives considered

**Local state only.** Rejected. It cannot be shared with CI, has no locking, and a lost laptop means lost state.

**DynamoDB table for locking.** This was the standard pattern for years. Rejected because native S3 locking now provides the same protection with one fewer resource to create, secure and pay for, and it keeps the bootstrap stack smaller.

**S3 server-side encryption only.** Rejected as insufficient on its own. It protects data on AWS's disks, but anyone with `s3:GetObject` on the bucket can still read state in plain text. Client-side encryption means reading state also requires permission to use the KMS key, giving two independent controls.

**Passphrase-based key provider (**`pbkdf2`**).** Rejected. The passphrase would have to be distributed to every engineer and stored as a CI secret, and rotating it is manual. With KMS, access is controlled through IAM, the pipeline role can simply be granted `kms:GenerateDataKey` and `kms:Decrypt`, key usage is logged in CloudTrail, and rotation is automatic.

**A managed backend (e.g. a hosted state service).** Rejected for this project. It adds an external dependency and cost, and managing state infrastructure directly is part of what this project demonstrates.

## Consequences

**Positive**

- State is shared, locked, versioned and encrypted twice, which is suitable for both local use and CI.
- Access to state can be granted and audited entirely through IAM and CloudTrail.
- The bootstrap stack is itself managed as code, with no hand-created resources.
- Adding a new environment only needs a new state key, not new infrastructure.

**Negative and risks**

- **The KMS key is a single point of failure.** If it is deleted, every encrypted state file becomes permanently unreadable. Mitigated by `prevent_destroy` and KMS's mandatory deletion waiting period (set to 30 days).
- **Extra cost** of roughly $1 per month for the KMS key.
- **Bootstrapping a new account is multi-step** (local state, migrate, encrypt, enforce). This is documented in the README.
- **Anyone operating the platform needs KMS permissions** in addition to S3 permissions. This is intended, but it must be remembered when creating the CI role in phase 4.
- **The bucket name contains the account ID and is hard-coded** in [`backend.tf`](http://backend.tf). This is acceptable for a single-account setup and should be revisited if the platform moves to multiple accounts.

