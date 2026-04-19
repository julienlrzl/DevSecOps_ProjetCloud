from diagrams import Diagram, Cluster, Edge
from diagrams.aws.network import InternetGateway, ELB, VPC
from diagrams.aws.compute import EC2
from diagrams.aws.database import RDS
from diagrams.aws.storage import S3
from diagrams.aws.security import IAM, KMS, SecretsManager
from diagrams.aws.management import Cloudtrail, SystemsManager
from diagrams.onprem.client import Users

# Génère : architecture_secure.png
with Diagram(
    "IaaS Sécurisée — Dossiers Médicaux",
    filename="docs/architecture_secure",
    show=False,
    direction="TB"
):
    internet = Users("Utilisateurs")

    with Cluster("AWS ca-central-1"):
        igw = InternetGateway("Internet Gateway")
        kms = KMS("KMS\n(chiffrement S3, RDS, EBS)")
        cloudtrail = Cloudtrail("CloudTrail\n(audit complet)")

        with Cluster("VPC multi-couches"):

            with Cluster("Subnets Publics, ALB uniquement"):
                alb = ELB("Application Load Balancer\nHTTPS uniquement")

            with Cluster("Subnets Privés — Applicatif"):
                ec2  = EC2("EC2 App\nSubnet privé\nEBS chiffré KMS\nPas de SSH")
                ssm  = SystemsManager("SSM Session Manager\nAccès de gestion sans SSH")
                iam  = IAM("IAM Role\nMoindre privilège")
                sm   = SecretsManager("Secrets Manager\nCredentials RDS")

            with Cluster("Subnets Privés, Base de données"):
                rds = RDS("RDS MySQL\nChiffrée KMS\nMulti-AZ\nNon publique")

            with Cluster("S3 Privé"):
                s3 = S3("S3 Dossiers\nAccès public bloqué\nChiffrement SSE-KMS")

    internet >> igw >> alb >> ec2
    ec2 >> rds
    ec2 >> sm
    ec2 - ssm
    ec2 - iam
    s3 - kms
    rds - kms
    cloudtrail >> s3
