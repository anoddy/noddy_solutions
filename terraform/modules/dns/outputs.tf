output "fqdns" {
  description = "Fully qualified names of the created records."
  value       = [for r in aws_route53_record.ipv4 : r.fqdn]
}
