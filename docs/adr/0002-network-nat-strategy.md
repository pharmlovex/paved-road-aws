# ADR 0002: Network design and outbound internet access (NAT strategy)

- **Status:** Proposed (to be confirmed when the VPC module is built in phase 2)
- **Date:** 2026-09-27
- **Phase:** 2 (Network)

## Context

Phase 2 introduces a reusable VPC module, consumed first by the `dev` environment and later by `prod`. Workloads planned for phase 3 are:

- containers on **ECS Fargate**, behind an **Application Load Balancer**
- a **PostgreSQL database on RDS**

Fargate tasks need **outbound** internet access to pull container images from ECR, send logs to CloudWatch, and read secrets from Secrets Manager. The database needs no internet access at all. Nothing except the load balancer should accept inbound traffic from the internet.

The textbook AWS design puts workloads in private subnets and gives them outbound access through a **NAT gateway**. NAT gateways are reliable and fully managed, but they are one of the most common sources of unexpected AWS bills: each one is charged hourly whether or not it is used, plus a per-GB processing charge. For a personal project with a monthly budget of about $30, a single idle NAT gateway could consume most of the budget.

The ALB requires subnets in at least two Availability Zones, so the VPC spans **two AZs** in every environment.

The design must therefore balance three things: **security** (minimal internet exposure), **resilience**, and **cost**, and it must allow `dev` and `prod` to make different trade-offs.

## Options considered

Approximate costs are for `eu-west-2` at the time of writing, excluding data transfer. Check current AWS pricing before relying on them.

**1. Private subnets with one NAT gateway per AZ.** The AWS-recommended production design. Each AZ keeps outbound access if another AZ fails. Roughly $35–40 per NAT gateway per month, so $70–80 for two AZs, plus data processing charges.

**2. Private subnets with a single shared NAT gateway.** Halves the cost (roughly $35–40 per month), but the NAT gateway's AZ becomes a single point of failure for outbound traffic from both AZs, and cross-AZ traffic adds data charges.

**3. NAT instance** (a small EC2 instance, e.g. an ARM `t4g.nano`, doing NAT). Only a few dollars a month, but it is self-managed: patching, monitoring, failure handling and scaling become our responsibility.

**4. VPC endpoints instead of NAT.** Workloads reach AWS services privately through endpoints. The S3 gateway endpoint is free, but Fargate also needs interface endpoints (ECR API, ECR Docker, CloudWatch Logs, Secrets Manager), each charged per AZ per hour. Four interface endpoints across two AZs cost more than a single NAT gateway, and they do not provide general internet access.

**5. Public subnets for Fargate tasks, no NAT.** Tasks receive a public IP and reach the internet directly. Inbound access is still blocked by security groups, which only allow traffic from the ALB. The main cost is AWS's public IPv4 charge (about $3.60 per address per month). The database stays in private subnets with no route to the internet.

## Decision

Build **one VPC module with a configurable outbound strategy**, rather than hard-coding a single design:

```hcl
nat_mode = "none" | "single" | "per_az"

```

The module always creates:

- **public subnets** in two AZs (for the ALB, and for workloads when `nat_mode = "none"`)
- **private application subnets** in two AZs (used when a NAT mode is enabled)
- **isolated database subnets** in two AZs, with **no route to the internet** in any mode
- a free **S3 gateway endpoint**, so S3 traffic (including ECR image layers) avoids NAT charges

Environment choices:


| Environment | `nat_mode` | Workload placement                                | Approx. network cost    |
| ----------- | ---------- | ------------------------------------------------- | ----------------------- |
| `dev`       | `none`     | Public subnets, public IPs, inbound from ALB only | A few dollars per month |
| `prod`      | `per_az`   | Private subnets behind NAT                        | $70–80 per month        |


`single` remains available as a middle ground, for example for a staging environment.

## Consequences

**Positive**

- `dev` stays within budget and can run for long periods without cost anxiety.
- The database is private and unreachable from the internet in every environment.
- The same module serves every environment. Moving `dev` to a production-like setup is a one-line change, not a redesign.
- The module demonstrates a core platform-engineering pattern: sensible defaults with explicit, documented trade-offs that each environment can choose.

**Negative and risks**

- `dev` **differs from** `prod` **at the network layer.** Tasks having public IPs in `dev` means an overly permissive security group would expose them directly. Mitigated by locking task security groups to accept traffic only from the ALB's security group, and by policy checks in phase 4.
- **Issues that only appear with NAT** (for example, outbound IP allow-listing or NAT port exhaustion) will not be caught in `dev`. A short-lived `single` or `per_az` test run can cover this when needed.
- **The module is more complex** than a fixed design, because it must handle three routing modes. This is covered by clear variable validation and examples.
- **Public IPv4 charges** still apply in `dev`; they are small but not zero.

## Revisit when

- the project gains real users or sensitive data in `dev`
- IPv6-only or egress-only designs become practical for all required AWS services
- a staging environment is added (likely candidate for `single`)

