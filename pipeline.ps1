$ErrorActionPreference = "Continue"
$InitialPath = Get-Location

Write-Host "DÉMARRAGE DU PIPELINE DEVSECOPS"

#DOCKER
Write-Host "Construction de l'image Docker"
Set-Location -Path "docker\secure"
docker build --no-cache -t api-medicale-secure:latest .

#TRIVY
Write-Host "Scan de l'image avec Trivy"
trivy image api-medicale-secure:latest

#CHECKOV
Write-Host "Audit de l'infrastructure Terraform avec Checkov"
Set-Location -Path "docker\secure\terraform_PaaS"
checkov -d .

# Retour au dossier initial
Set-Location -Path $InitialPath

