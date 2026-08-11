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

This project demonstrates how to provision and manage a complete **Amazon Elastic Kubernetes Service (Amazon EKS)** environment using **Terraform** following Infrastructure as Code (IaC) best practices. The goal is to create a reusable, modular, and automated infrastructure platform that can be deployed repeatedly across multiple environments such as **development, testing, staging, and production**.

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
<summary>Exercise 1: Provisioning the EKS Environment with Terraform</summary>

<br />

The Terraform configuration was hosted in a **separate Git repository** from the Java application. This follows Infrastructure as Code and GitOps practices by keeping infrastructure changes independent from application changes. It allows the infrastructure team to version, review, and manage the AWS environment separately while also making it possible to reuse the same Terraform configuration for development, testing, staging, and production environments.

### Terraform Modules

The infrastructure was divided into reusable **Terraform modules** rather than placing all resources inside a single Terraform configuration.

Modules make the configuration easier to maintain because each major part of the infrastructure has its own responsibility. Changes to the networking configuration, for example, can be made independently from the EKS cluster or MySQL configuration.

The first module created was the **VPC module**. The VPC provides the networking foundation required by the EKS cluster and contains both public and private subnets distributed across multiple Availability Zones.

The public subnets provide networking for resources that need external connectivity, while the private subnets are used for the EKS worker nodes and other infrastructure that should not be directly exposed to the internet.

The VPC configuration was parameterized using Terraform variables so that the CIDR ranges and subnet configuration can be changed for different environments without modifying the module itself.

The VPC module exposes the VPC ID and subnet IDs as outputs. These values are then passed to the EKS module, allowing Terraform to automatically establish the dependency between the networking and cluster resources.

### Amazon EKS Cluster

The second module provisions the **Amazon EKS cluster** using the `terraform-aws-modules/eks/aws` module.

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
