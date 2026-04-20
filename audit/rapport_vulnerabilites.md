# Rapport d'Analyse de Sécurité Infrastructure-as-Code (Checkov)

Ce rapport détaille les vulnérabilités de sécurité identifiées dans les fichiers Terraform du projet. Les vulnérabilités sont classées par niveau de sévérité, de la plus critique à la moins critique.

---

## 🛑 Résumé des Résultats

| Sévérité | Nombre de vulnérabilités |
| :--- | :--- |
| 🔴 **Critique / Haute** | 12 |
| 🟠 **Moyenne** | 25 |
| 🟡 **Faible** | 18 |
| **Total** | **55** |

---

## 🔴 Vulnérabilités de Sévérité Haute / Critique

Ces vulnérabilités présentent un risque direct d'exposition de données, d'accès non autorisé ou de compromission majeure de l'infrastructure.

### 1. IAM & Accès (Privilèges Excessifs)
- **ID :** `CKV_AWS_274`
- **Titre :** L'utilisation de la politique `AdministratorAccess` pour les rôles, utilisateurs ou groupes IAM est interdite.
- **Ressource :** `aws_iam_role_policy_attachment.admin` (`/vulnerable/main.tf`)
- **Impact :** Un utilisateur ou un service avec ce rôle possède des droits illimités sur l'ensemble du compte AWS.

### 2. Réseau & Connectivité (Exposition Publique)
- **ID :** `CKV_AWS_24`
- **Titre :** Le port SSH (22) est ouvert au monde entier (0.0.0.0:0).
- **Ressource :** `aws_security_group.ec2_open` (`/vulnerable/main.tf`)
- **Impact :** Tentatives de force brute et accès non autorisés potentiels sur les instances EC2.

- **ID :** `CKV_AWS_17`
- **Titre :** La base de données RDS est accessible publiquement.
- **Ressource :** `aws_db_instance.mysql` (`/vulnerable/main.tf`)
- **Impact :** Exposition directe de la base de données sur Internet, augmentant drastiquement les risques d'attaque.

### 3. Protection des Données (Chiffrement & S3)
- **ID :** `CKV_AWS_16`
- **Titre :** Les données stockées dans RDS ne sont pas chiffrées au repos.
- **Ressource :** `aws_db_instance.mysql` (`/vulnerable/main.tf`)
- **Impact :** Risque de fuite de données en cas de compromission physique ou de sauvegarde non protégée.

- **ID :** `CKV_AWS_8`
- **Titre :** Les volumes EBS ne sont pas chiffrés.
- **Ressource :** `aws_instance.app` (`/vulnerable/main.tf`)

- **IDs :** `CKV_AWS_53`, `CKV_AWS_54`, `CKV_AWS_55`, `CKV_AWS_56`
- **Titre :** Absence de blocage d'accès public sur les compartiments S3.
- **Ressource :** `aws_s3_bucket_public_access_block.dossiers` (`/vulnerable/main.tf`)
- **Impact :** Risque de rendre des données sensibles accessibles publiquement via des politiques ou des ACL mal configurées.

---

## 🟠 Vulnérabilités de Sévérité Moyenne

Ces vulnérabilités concernent principalement la journalisation, la résilience et des configurations de sécurité secondaires.

### 1. IAM & Métadonnées
- **ID :** `CKV_AWS_79`
- **Titre :** Instance Metadata Service Version 1 (IMDSv1) est activé.
- **Ressources :** `aws_instance.app` dans `/secure/main.tf` et `/vulnerable/main.tf`.
- **Impact :** Facilite les attaques de type SSRF (Server Side Request Forgery).

### 2. Base de données RDS (Résilience & Monitoring)
- **ID :** `CKV_AWS_157` : Multi-AZ non activé (impacte la haute disponibilité).
- **ID :** `CKV_AWS_133` : Absence de politique de sauvegarde.
- **ID :** `CKV_AWS_118` & `CKV_AWS_129` : Monitoring amélioré et journaux non activés.

### 3. S3 & Stockage
- **ID :** `CKV_AWS_21` : Versioning S3 non activé (perte de données accidentelle possible).
- **ID :** `CKV_AWS_145` : Chiffrement S3 par défaut avec KMS non configuré.
- **ID :** `CKV_AWS_18` : Journalisation des accès S3 non activée.

### 4. Réseau
- **ID :** `CKV_AWS_130` : Assignation automatique d'IP publique dans les sous-réseaux VPC (`/vulnerable/main.tf`).
- **ID :** `CKV2_AWS_11` : Flow Logs VPC non activés (difficulté d'audit réseau).

---

## 🟡 Vulnérabilités de Sévérité Faible

Configurations recommandées pour une meilleure hygiène de sécurité et gestion opérationnelle.

- **ID :** `CKV_AWS_23` : Absence de description sur les règles de groupes de sécurité.
- **ID :** `CKV_AWS_126` : Monitoring détaillé EC2 non activé.
- **ID :** `CKV_AWS_226` : Mises à jour mineures automatiques RDS désactivées.
- **ID :** `CKV_AWS_161` : Authentification IAM RDS non activée.
- **ID :** `CKV2_AWS_62` : Notifications d'événements S3 non activées.
- **ID :** `CKV2_AWS_12` : Le groupe de sécurité par défaut du VPC ne restreint pas tout le trafic.

---

## 🛠 Recommandations Générales

1. **Appliquer le principe du moindre privilège :** Supprimer l'attachement de `AdministratorAccess` et définir des politiques IAM granulaires.
2. **Durcir le réseau :** Fermer le port 22 au monde entier, utiliser un Bastion ou AWS Client VPN.
3. **Chiffrement systématique :** Activer le chiffrement au repos pour tous les volumes RDS, S3 et EBS.
4. **Isoler les données :** S'assurer que les bases de données RDS ne possèdent pas d'adresse IP publique (`publicly_accessible = false`).
5. **Activer l'audit :** Activer les Flow Logs VPC, CloudTrail et la journalisation S3/RDS pour permettre une réponse aux incidents efficace.

---

