output "alb_dns_name" {
  description = "DNS du Load Balancer (seul point d'entrée public)"
  value       = aws_lb.alb.dns_name
}

output "cloudtrail_arn" {
  description = "ARN du CloudTrail — traçabilité complète activée"
  value       = aws_cloudtrail.main.arn
}

output "kms_key_id" {
  description = "ID de la clé KMS utilisée pour chiffrer S3, RDS et EBS"
  value       = aws_kms_key.main.key_id
}
