# ADR 0003: Separate service and database modules; long-lived DNS stack

- Status: Accepted

- Date: 2026-10-02

## Context

Phase 3 introduces an application platform: an ECS Fargate service behind

an HTTPS ALB, backed by RDS Postgres. Two design questions arise:

1. Should the service and its database live in one module or two?

2. Where should DNS and TLS certificates live, given that `envs/dev` is

   destroyed when idle to save cost?

HTTPS requires an ACM certificate validated through DNS. The parent domain

[`kowopeweb.com`](http://kowopeweb.com) is hosted on Cloudflare.

## Decision

### Two modules: `modules/app-service` and `modules/postgres`

- `app-service`: ALB, listeners, ECS cluster/service/task definition,

  log group, alarms, IAM roles.

- `postgres`: RDS instance, subnet group, parameter group, security group,

  RDS-managed master secret.

- Environments compose them. The postgres module exposes its security group

  ID, endpoint, and secret ARN; app-service accepts them as inputs.

### Long-lived `global/dns` stack

- Route 53 hosted zone [`paved-road.kowopeweb.com`](http://paved-road.kowopeweb.com), delegated from Cloudflare

  via four NS records added manually (one-time).

- Wildcard ACM cert `*.[paved-road.kowopeweb.com](http://paved-road.kowopeweb.com)` + apex SAN, DNS-validated,

  in eu-west-2.

- Environments only consume the zone ID and cert ARN; they create their own

  records (e.g. [`dev.paved-road.kowopeweb.com`](http://dev.paved-road.kowopeweb.com)).

- The hosted zone has `prevent_destroy`.

## Consequences

Positive:

- Service redeploys and refactors cannot produce plans that replace the

  database; the database's lifecycle is independent.

- Services without a database can use the paved road unchanged.

- Destroying `envs/dev` never touches DNS delegation or certificates, so

  destroy/apply cycles are fast and safe.

- ACM managed renewal keeps working because validation records persist.

Negative / trade-offs:

- One more state file and stack to maintain.

- Cloudflare delegation is a manual step outside IaC. Accepted: it is a

  one-time change, and automating it would require storing a Cloudflare API

  token with access to the parent domain.

- Recreating the hosted zone would require updating Cloudflare NS records;

  mitigated by `prevent_destroy`.

## Alternatives considered

- Single `app-service` module including RDS: simpler wiring, but couples

  database lifecycle to service changes.

- Hosted zone and cert in `envs/dev`: nameservers would change on every

  recreate, breaking delegation.

- Cloudflare provider in OpenTofu: rejected for credential scope and low value.