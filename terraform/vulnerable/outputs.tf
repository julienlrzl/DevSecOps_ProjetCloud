output "ec2_public_ip" {
  description = "IP publique de l'instance EC2 (directement exposée)"
  value       = aws_instance.app.public_ip
}

output "rds_endpoint" {
  description = "Endpoint RDS (accessible publiquement)"
  value       = aws_db_instance.mysql.endpoint
}

output "s3_bucket_name" {
  description = "Nom du bucket S3 (potentiellement public)"
  value       = aws_s3_bucket.dossiers.bucket
}
