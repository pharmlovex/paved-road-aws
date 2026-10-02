resource "aws_route53_zone" "this" {
  name    = var.zone_name
  comment = "Delegated from Cloudflare (kowopeweb.com). Managed by paved-road-aws."

  # Recreating this zone would assign new nameservers and silently break
  # the delegation in Cloudflare. Treat it like the state bucket.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_acm_certificate" "wildcard" {
  domain_name               = "*.${var.zone_name}"
  subject_alternative_names = [var.zone_name]
  validation_method         = "DNS"

  # If the cert ever needs replacing, create the new one before
  # deleting the old, so an attached ALB is never left without a cert.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.wildcard.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  allow_overwrite = true
  zone_id         = aws_route53_zone.this.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
}

resource "aws_acm_certificate_validation" "wildcard" {
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}