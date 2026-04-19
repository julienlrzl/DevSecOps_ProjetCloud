from diagrams import Diagram, Cluster, Edge
from diagrams.aws.network import InternetGateway
from diagrams.aws.compute import EC2
from diagrams.aws.database import RDS
from diagrams.aws.storage import S3
from diagrams.aws.security import IAM
from diagrams.onprem.client import Users

graph_attr = {
    "nodesep": "1.5",
    "ranksep": "2.0",
    "fontsize": "15",
    "pad": "1.0",
    "size": "18,12",
    "dpi": "150",
}

node_attr = {
    "fontsize": "12",
    "width": "1.8",
    "height": "1.8",
}

# Génère : architecture_vulnerable.png
with Diagram(
    "IaaS Vulnerable - Dossiers Medicaux",
    filename="docs/architecture_vulnerable",
    show=False,
    direction="LR",
    graph_attr=graph_attr,
    node_attr=node_attr,
):
    internet = Users("Internet\n/ Attaquant")

    with Cluster("AWS ca-central-1"):
        igw = InternetGateway("Internet\nGateway")

        with Cluster("VPC - Subnet PUBLIC uniquement\n(aucune separation reseau)"):
            ec2 = EC2("EC2 App\nFaille : IP publique directe\nFaille : SSH ouvert 0.0.0.0/0\nFaille : EBS non chiffre")
            rds = RDS("RDS MySQL\nFaille : Accessible publiquement\nFaille : Non chiffree\nFaille : Pas de Multi-AZ")
            s3  = S3("S3\nFaille : Acces public non bloque\nFaille : Pas de chiffrement")
            iam = IAM("IAM Role\nFaille : AdministratorAccess")

        # CloudTrail absent intentionnellement

    internet >> igw >> ec2
    internet >> Edge(label="Port 3306\nacces direct", color="red", style="bold") >> rds
    internet >> Edge(label="Acces\npublic", color="red", style="bold") >> s3
    ec2 - iam
