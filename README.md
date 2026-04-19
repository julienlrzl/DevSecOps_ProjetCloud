# DevSecOps — Audit de sécurité et remédiation automatisée (IaaS / PaaS)

Cours 8CLD876 — Architecture des systèmes infonuagiques, UQAC, Hiver 2026.

## Concept

Ce projet démontre l'approche DevSecOps appliquée à un système de gestion de dossiers médicaux.
L'idée centrale : déployer une infrastructure AWS intentionnellement vulnérable, l'auditer avec des outils
open-source, puis montrer la version corrigée et comparer les rapports avant/après.

```
Infrastructure vulnérable → Audit Prowler → Findings → Infrastructure sécurisée → Audit Prowler → Différence
```

L'application fictive de référence est un système de dossiers médicaux. Ce contexte justifie chaque
décision de sécurité : les données médicales sont parmi les plus sensibles (HIPAA, PIPEDA).

## Structure du projet

```
terraform/vulnerable/   ← Étudiant 1 : infra IaaS mal configurée (failles intentionnelles)
terraform/secure/       ← Étudiant 1 : infra IaaS corrigée (bonnes pratiques)
audit/                  ← Étudiant 2 : rapports Prowler avant/après
docker/                 ← Étudiant 3 : Dockerfile vulnérable + sécurisé, rapports Trivy
docs/                   ← Schémas d'architecture + liste des vulnérabilités
```

## Fournisseur cloud

AWS, région `ca-central-1`.

## Répartition

| Étudiant | Responsabilité |
|----------|---------------|
| 1 | Terraform IaaS vulnérable + sécurisé |
| 2 | Audit Prowler, analyse des findings |
| 3 | Dockerfile vulnérable + sécurisé, scan Trivy |

---

## Étudiant 1 — Terraform IaaS

### Valider les fichiers Terraform (sans compte AWS)

```bash
# Infrastructure vulnérable
cd terraform/vulnerable
terraform init
terraform validate

# Infrastructure sécurisée
cd terraform/secure
terraform init
terraform validate
```

### Générer les schémas d'architecture

```bash
# Installer la dépendance (ou réutiliser le venv existant)
pip install diagrams

# Schéma vulnérable
python docs/architecture_vulnerable.py

# Schéma sécurisé
python docs/architecture_secure.py
```

Les fichiers PNG sont générés dans `docs/` (ignorés par git).

### Failles intentionnelles documentées

Voir `docs/vulnerabilities.md` pour la liste complète avec impact médical et vecteurs STRIDE.
