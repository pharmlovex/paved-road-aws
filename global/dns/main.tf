resource "aws_route53_zone" "this" {
  name    = var.zone_name
  comment = "Delegated from Cloudflare (kowopeweb.com). Managed by paved-road-aws."

  # Recreating this zone would assign new nameservers and silently break
  # the delegation in Cloudflare. Treat it like the state bucket.
  lifecycle {
    prevent_destroy = true
  }
}