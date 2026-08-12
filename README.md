<table>
  <tr>
    <td width="70" align="center" valign="middle">
      <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/terraform/terraform-original.svg" width="55" height="55" alt="Terraform Logo" />
    </td>
    <td valign="middle">
      <h1 style="border-bottom: none; margin: 0; padding: 0; line-height: 1.2;">Terraform on AWS</h1>
      <span style="font-size: 15px; color: #57606a;">Provisioning Amazon EKS Infrastructure with Remote State &amp; CI/CD</span>
    </td>
  </tr>
</table>

---
This project demonstrates how to provision and manage a complete **Amazon Elastic Kubernetes Service (Amazon EKS)** environment using **Terraform** following Infrastructure as Code (IaC) best practices. In the [previous project](https://github.com/lihandafabius/Devops_Nana-Techworld_Bootcamp/blob/main/kubernetes-on-AWS-exercises/README.md), the EKS cluster and its supporting infrastructure were provisioned using **eksctl**, while the VPC was created using an AWS **CloudFormation VPC template**. This project builds on that environment by moving the infrastructure provisioning into Terraform.

Using Terraform provides a more consistent and reusable way to manage the entire infrastructure from a single IaC tool. It allows infrastructure to be **version-controlled, modular, reviewed before deployment, and reproduced consistently** across multiple environments such as **development, testing, staging, and production**.

Instead of manually creating AWS networking resources, IAM roles, EKS clusters, node groups, and Kubernetes add-ons, the entire infrastructure is defined declaratively using Terraform modules. This approach makes the infrastructure reproducible, version-controlled, and easier to maintain as the platform evolves.

The project provisions an Amazon EKS cluster with:

* A dedicated VPC with public and private subnets
* Managed EC2 worker nodes
* An AWS Fargate profile for application workloads
* The AWS EBS CSI Driver for persistent storage
* EKS Pod Identity for secure IAM authentication
* MySQL deployed through Helm with persistent Amazon EBS volumes

In addition to infrastructure provisioning, the project implements **remote Terraform state management** using **Amazon S3** and a **Jenkins CI/CD pipeline** that automatically validates, plans, and applies infrastructure changes from a Git repository. This enables infrastructure updates to follow the same collaborative and automated workflow used for application deployments.

## Project objectives

Throughout this project, the following technologies and concepts are implemented:

* Provisioning AWS infrastructure using **Terraform**
* Creating a modular Terraform project structure
* Deploying an Amazon EKS cluster with managed node groups
* Configuring AWS Fargate profiles for Kubernetes workloads
* Deploying MySQL using Helm with persistent Amazon EBS storage
* Installing and configuring the AWS EBS CSI Driver
* Implementing **EKS Pod Identity** for secure IAM authentication
* Configuring remote Terraform state in Amazon S3
* Enabling **Terraform state locking** for concurrent team collaboration
* Building a Jenkins CI/CD pipeline for infrastructure provisioning
* Validating and reviewing infrastructure changes before deployment
* Applying Infrastructure as Code best practices for reproducibility and automation

* Applying Infrastructure as Code best practices for reproducibility and automation


## Project structure

The Terraform project is organized into reusable modules, separating networking, Kubernetes infrastructure, and application storage components. This modular structure makes the infrastructure easier to maintain, extend, and reuse across multiple environments.

```text
.
├── jenkinsfile
├── LICENSE
├── README.md
└── terraform
    ├── main.tf
    ├── providers.tf
    ├── variables.tf
    ├── outputs.tf
    └── modules
        ├── vpc
        │   ├── main.tf
        │   ├── output.tf
        │   └── variables.tf
        ├── eks
        │   ├── main.tf
        │   ├── outputs.tf
        │   └── variables.tf
        └── mysql
            ├── main.tf
            ├── providers.tf
            ├── outputs.tf
            └── values.yaml
```

The root Terraform configuration orchestrates the entire infrastructure by invoking the VPC, EKS, and MySQL modules. Each module is responsible for a specific part of the infrastructure, allowing changes to be made independently while keeping the overall deployment consistent and reusable.

---
<details>
<summary>Exercise 1: Create Amazon EKS Cluster</summary>

<br />

The Terraform configuration was hosted in a **separate Git repository** from the Java application. This follows Infrastructure as Code and GitOps practices by keeping infrastructure changes independent from application changes. It allows the infrastructure team to version, review, and manage the AWS environment separately while also making it possible to reuse the same Terraform configuration for development, testing, staging, and production environments.

### Terraform modules

The infrastructure was divided into reusable **Terraform modules** rather than placing all resources in a single Terraform configuration. The project was organized into three main modules: **VPC**, **EKS**, and **MySQL**, making the infrastructure easier to maintain, reuse, and manage independently.

### VPC module

The **VPC module** provides the networking foundation for the Amazon EKS cluster. It creates a VPC with **public and private subnets** distributed across multiple Availability Zones. Public subnets are used for internet-facing resources such as load balancers and the NAT Gateway, while private subnets host the EKS worker nodes and Fargate workloads.

The module was implemented using the official **terraform-aws-modules/vpc/aws** module and configured with a **single NAT Gateway**, DNS hostnames, and subnet tagging required for Amazon EKS.

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name             = "${var.application_name}_vpc"
  cidr             = var.vpc_cidr_block
  private_subnets  = var.private_subnet_cidr_blocks
  public_subnets   = var.public_subnet_cidr_blocks
  azs              = data.aws_availability_zones.azs.names

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  tags = {
    "kubernetes.io/cluster/${var.environment}-${var.application_name}-eks-cluster" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.environment}-${var.application_name}-eks-cluster" = "shared"
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.environment}-${var.application_name}-eks-cluster" = "shared"
    "kubernetes.io/role/internal-elb" = 1
  }
}
```

> **Note:** The subnet tags allow Amazon EKS to automatically identify which subnets should be used for **public load balancers** and **internal load balancers**, enabling Kubernetes services of type `LoadBalancer` to integrate correctly with AWS networking.


### Amazon EKS module

The **EKS module** provisions the Kubernetes control plane, managed worker nodes, AWS Fargate profile, and the Kubernetes add-ons required by the environment. The cluster was created using the official **terraform-aws-modules/eks/aws** module and deployed into the private subnets created by the VPC module.

```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.24.1"

  name               = "${var.environment}-${var.application_name}-eks-cluster"
  kubernetes_version = "1.36"

  subnet_ids = var.private_subnet_ids
  vpc_id     = var.vpc_id

  endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true
}
```

The cluster name is generated from Terraform variables, allowing the same configuration to create multiple environments without modifying the module. The cluster runs **Kubernetes 1.36**, exposes a public API endpoint, and enables administrator access for the identity that provisions the cluster.

### Managed node group

The cluster was configured with an **EKS Managed Node Group** running EC2 worker nodes for stateful workloads such as MySQL.

```hcl
eks_managed_node_groups = {
  default = {
    ami_type       = var.ami_type
    instance_types = var.instance_types

    min_size     = 1
    max_size     = 3
    desired_size = 3
  }
}
```

The node group maintains **three worker nodes** by default and can scale between **one and three nodes**. The AMI type and EC2 instance type are parameterized through Terraform variables, making the configuration reusable across different environments.

### AWS Fargate profile

A dedicated **AWS Fargate profile** was created for the `java-app` namespace so that application workloads can run without managing EC2 instances.

```hcl
fargate_profiles = {
  fargate_profile = {
    selectors = [
      {
        namespace = "java-app"
      }
    ]
  }
}
```

Any workload deployed into the `java-app` namespace is automatically scheduled onto **AWS Fargate**, while stateful workloads such as MySQL continue to run on the managed EC2 nodes where Amazon EBS storage is available.

> **Note:** Fargate is well suited for stateless application workloads, while stateful applications such as MySQL are better suited for EC2 worker nodes that can attach persistent EBS volumes.

### EKS add-ons

The cluster was configured with the Kubernetes and AWS add-ons required for networking, DNS, authentication, and persistent storage.

```hcl
addons = {
  coredns = {}

  eks-pod-identity-agent = {
    before_compute = true
  }

  kube-proxy = {}

  vpc-cni = {
    before_compute = true
  }

  aws-ebs-csi-driver = {
    before_compute = true

    pod_identity_association = [
      {
        role_arn        = var.ebs_csi_role_arn
        service_account = "ebs-csi-controller-sa"
      }
    ]
  }
}
```

The configuration installs **CoreDNS**, **kube-proxy**, **Amazon VPC CNI**, the **EKS Pod Identity Agent**, and the **AWS EBS CSI Driver**. The EBS CSI Driver enables Kubernetes to dynamically provision **Amazon EBS volumes**, which are required for MySQL persistent storage.

### EKS Pod Identity

To allow the EBS CSI Driver to interact with AWS securely, the project uses **EKS Pod Identity** instead of storing AWS credentials inside Kubernetes.

```hcl
module "ebs_csi_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.5"

  name = "${var.environment}-ebs-csi"

  attach_aws_ebs_csi_policy = true
}
```

The IAM role created by this module is associated with the `ebs-csi-controller-sa` service account, allowing the EBS CSI controller to create, attach, detach, and manage Amazon EBS volumes without exposing long-lived AWS access keys inside the cluster.

> **Note:** EKS Pod Identity is the recommended authentication method for EKS workloads because it provides temporary IAM credentials through Kubernetes service accounts and eliminates the need to manage AWS access keys inside containers.

![cluster creation](images/cluster_verify.png)


### MySQL with Helm

After the EKS infrastructure was provisioned, the third module was used to deploy **MySQL through Helm**.

The MySQL configuration was separated into a Helm values file so that the database configuration could be managed independently from the Terraform resource that installs the chart.

The deployment uses persistent Amazon EBS storage so that database data is retained when MySQL pods are recreated or rescheduled.

The MySQL module was also configured to depend on the EKS cluster:

```hcl
depends_on = [module.eks.cluster_name]
```

This is important because Terraform must create and make the Kubernetes cluster available before attempting to connect to it through the Helm provider.

The MySQL configuration also uses the Bitnami Legacy image repository:

```yaml
global:
  security:
    allowInsecureImages: true

image:
  registry: docker.io
  repository: bitnamilegacy/mysql
  tag: latest
```

This was required because the Bitnami MySQL repository structure had changed and the MySQL image had been moved to the `bitnamilegacy` repository.

The resulting deployment provides a MySQL database running inside the EKS cluster with persistent storage backed by Amazon EBS.

### Provisioning the Infrastructure

With the modules connected, the complete environment could be provisioned using the standard Terraform workflow.

```bash
terraform init
```

Terraform first downloads the required providers and initializes the modules.

The configuration was then validated before creating any resources:

```bash
terraform validate
```

A deployment plan was generated to review the resources Terraform intended to create:

```bash
terraform plan
```

Finally, the infrastructure was provisioned using:

```bash
terraform apply
```

Terraform handled the dependency chain between the components, creating the networking infrastructure first, followed by the EKS cluster and its supporting components, and finally the MySQL Helm deployment.

### Verification

After the Terraform deployment completed, the EKS cluster was connected to `kubectl` using:

```bash
aws eks update-kubeconfig \
  --region eu-north-1 \
  --name <cluster-name>
```

The worker nodes were then verified:

```bash
kubectl get nodes
```

The Kubernetes workloads and system components were also checked:

```bash
kubectl get pods -A
```

The completed Terraform deployment successfully provisioned the AWS networking, EKS cluster, managed worker nodes, Fargate profile, EBS CSI Driver, EKS Pod Identity integration, and persistent MySQL deployment from a single version-controlled Infrastructure as Code project.

</details>


