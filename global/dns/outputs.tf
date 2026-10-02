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