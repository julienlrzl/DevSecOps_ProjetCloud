# Analyse de Sécurité — Comparaison Dockerfile Vulnérable vs Sécurisé

## Résultats des scans Trivy

| Catégorie        | Version Vulnérable | Version Sécurisée |
|------------------|--------------------|-------------------|
| CVEs OS          | 418                | 0                 |
| CVEs Python      | 22                 | 0                 |
| **Total**        | **440**            | **0**             |

---

## Problèmes identifiés dans la version vulnérable

### 1. Image de base obsolète
- `python:3.6-slim` basée sur Debian 11.2 (2021), non maintenue
- Source de 418 CVEs au niveau du système d'exploitation

### 2. Secrets AWS en dur dans le Dockerfile
- Les variables `AWS_ACCESS_KEY_ID` et `AWS_SECRET_ACCESS_KEY` étaient
  définies directement dans le `ENV` du Dockerfile
- N'importe qui ayant accès à l'image peut les lire

### 3. Application tournant en root
- Par défaut, Docker exécute les processus en tant que root
- En cas de faille, l'attaquant a un accès total au conteneur

### 4. Dépendances Python obsolètes
- Flask 1.1.4, Werkzeug 1.0.1, Jinja2 2.11.3 (versions 2020)
- Source de 22 CVEs Python

### 5. Mot de passe en dur dans le code
- Fallback `"SuperSecretAdmin123!"` dans `os.environ.get()`
- Le secret est exposé dans le code source

### 6. Debug activé
- `app.run(debug=True)` expose des informations système en cas d'erreur

---

## Corrections apportées dans la version sécurisée

| Problème                  | Correction                                      |
|---------------------------|-------------------------------------------------|
| Image obsolète            | `python:3.11-alpine` (légère et maintenue)      |
| Secrets dans Dockerfile   | Supprimés, passés via variables d'environnement |
| Exécution en root         | Création d'un utilisateur `appuser` non-root    |
| Dépendances obsolètes     | Mises à jour vers Flask 3.x, Werkzeug 3.x, etc.|
| Mot de passe en dur       | Erreur levée si la variable est absente         |
| Debug activé              | `debug=False` en production                     |