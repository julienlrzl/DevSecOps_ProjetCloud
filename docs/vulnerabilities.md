# Vulnérabilités IaaS — Avant / Après remédiation

Application fictive : système de gestion de dossiers médicaux.
Fournisseur : AWS, région ca-central-1.

---

## Tableau des failles

| # | Ressource Terraform | Faille intentionnelle | Catégorie STRIDE | Impact dans le contexte médical | Correction appliquée | Fichier de référence |
|---|--------------------|-----------------------|------------------|----------------------------------|----------------------|----------------------|
| 1 | `aws_security_group.ec2_open` | Port 22 (SSH) ouvert à `0.0.0.0/0` | **Spoofing** | Un attaquant peut tenter d'usurper une identité via brute-force SSH ou une clé compromise pour accéder au serveur hébergeant les dossiers médicaux | Port 22 absent — accès de gestion via SSM Session Manager uniquement | `terraform/vulnerable/main.tf` → `terraform/secure/main.tf` |
| 2 | `aws_instance.app` | Instance EC2 dans subnet public avec IP publique directe, sans load balancer | **Tampering** | L'application est directement exposée à Internet — toute faille applicative (injection, RCE) est immédiatement exploitable depuis n'importe où | EC2 déplacée en subnet privé, ALB en frontal dans subnet public | `vulnerable/main.tf` → `secure/main.tf` |
| 3 | `aws_instance.app` `root_block_device` | Volume EBS non chiffré (`encrypted = false`) | **Information Disclosure** | En cas de snapshot non autorisé ou de vol de disque, tous les dossiers médicaux sont lisibles en clair | `encrypted = true` avec clé KMS dédiée | `vulnerable/main.tf` → `secure/main.tf` |
| 4 | `aws_iam_role_policy_attachment.admin` | IAM Role avec `AdministratorAccess` attaché à l'instance | **Elevation of Privilege** | Si l'EC2 est compromise (ex. via RCE), l'attaquant obtient un contrôle total du compte AWS : création d'utilisateurs, exfiltration de données, destruction de ressources | IAM Role restreint : `secretsmanager:GetSecretValue` + CloudWatch Logs + SSM uniquement | `vulnerable/main.tf` → `secure/main.tf` |
| 5 | `aws_s3_bucket_public_access_block` | `block_public_acls = false` — accès public non bloqué, pas de chiffrement | **Information Disclosure** | Les dossiers médicaux stockés dans S3 pourraient être accessibles publiquement si une ACL ou une policy permissive est appliquée par erreur | `block_public_acls = true` sur les 4 paramètres + chiffrement SSE-KMS | `vulnerable/main.tf` → `secure/main.tf` |
| 6 | `aws_db_instance.mysql` | `publicly_accessible = true` — RDS accessible depuis Internet | **Information Disclosure** | N'importe qui sur Internet peut tenter de se connecter à la base de données contenant les dossiers médicaux (brute-force, CVE MySQL) | `publicly_accessible = false` + security group restreint à `sg-ec2-app` uniquement | `vulnerable/main.tf` → `secure/main.tf` |
| 7 | `aws_db_instance.mysql` | `storage_encrypted = false` — données RDS non chiffrées au repos | **Information Disclosure** | En cas de compromission du stockage AWS ou d'un snapshot, les données médicales de la base sont lisibles en clair | `storage_encrypted = true` avec clé KMS + `manage_master_user_password = true` | `vulnerable/main.tf` → `secure/main.tf` |
| 8 | *(absent)* | Aucun CloudTrail — zéro traçabilité des accès et des actions AWS | **Repudiation** | Impossible de détecter une intrusion, de l'auditer ou de prouver qui a accédé à quels dossiers médicaux (non-conformité PIPEDA/HIPAA) | CloudTrail multi-région activé, logs stockés dans S3 chiffré avec validation d'intégrité | `secure/main.tf` → `aws_cloudtrail.main` |

---

## Résumé de la surface d'attaque réduite

| Indicateur | Infrastructure vulnérable | Infrastructure sécurisée |
|------------|--------------------------|--------------------------|
| Ports ouverts sur Internet | 22, 80, 443 (sur EC2 direct) | 443 (sur ALB uniquement) |
| Instances avec IP publique | EC2 + RDS | Aucune |
| Données chiffrées au repos | Non | Oui (KMS) |
| Droits IAM de l'instance | AdministratorAccess | Moindre privilège |
| Traçabilité (audit) | Aucune | CloudTrail complet |
| Credentials base de données | En clair dans variables.tf | Secrets Manager |
| Haute disponibilité RDS | Non (single-AZ) | Oui (Multi-AZ) |
