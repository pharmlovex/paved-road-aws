output "zone_id" {
  value = aws_route53_zone.this.zone_id
}

output "zone_name" {
  value = aws_route53_zone.this.name
}

output "name_servers" {
  description = "Add these as NS records for 'paved-road' in Cloudflare."
  value       = aws_route53_zone.this.name_servers
}

output "certificate_arn" {
  description = "Validated wildcard cert for *.paved-road.kowopeweb.com and the apex."
  value       = aws_acm_certificate_validation.wildcard.certificate_arn
}