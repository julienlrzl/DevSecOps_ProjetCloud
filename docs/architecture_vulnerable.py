from diagrams import Diagram, Cluster, Edge
from diagrams.aws.network import InternetGateway, VPC
from diagrams.aws.compute import EC2
from diagrams.aws.database import RDS
from diagrams.aws.storage import S3
from diagrams.aws.security import IAM
from diagrams.onprem.client import Users

# Génère : architecture_vulnerable.png
with Diagram(
    "IaaS Vulnérable — Dossiers Médicaux",
    filename="docs/architecture_vulnerable",
    show=False,
    direction="TB"
):
    internet = Users("Internet / Attaquant")

    with Cluster("AWS ca-central-1"):
        igw = InternetGateway("Internet Gateway")

        with Cluster("VPC — Subnet PUBLIC uniquement"):
            ec2 = EC2("EC2 App\n⚠ IP publique directe\n⚠ SSH ouvert 0.0.0.0/0\n⚠ EBS non chiffré")
            rds = RDS("RDS MySQL\n⚠ Accessible publiquement\n⚠ Non chiffré\n⚠ Pas de Multi-AZ")
            s3  = S3("S3\n⚠ Accès public non bloqué\n⚠ Pas de chiffrement")
            iam = IAM("IAM Role\n⚠ AdministratorAccess")

        # Pas de CloudTrail

    internet >> igw >> ec2
    internet >> Edge(label="Port 3306\naccès direct", color="red") >> rds
    internet >> Edge(label="Accès public", color="red") >> s3
    ec2 - iam
