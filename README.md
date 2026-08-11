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
````

The cluster name is generated from the environment and application variables rather than being hardcoded. This allows the same Terraform configuration to create separate environments without changing the underlying module.

The cluster runs **Kubernetes 1.36** and is deployed into the private subnets created by the VPC module.

Cluster creator administrator permissions were also enabled so that the identity provisioning the cluster can immediately administer the Kubernetes cluster.

### EKS Add-ons

The EKS configuration also installs the Kubernetes and AWS add-ons required by the environment.

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

The configuration installs **CoreDNS**, **kube-proxy**, **Amazon VPC CNI**, the **EKS Pod Identity Agent**, and the **AWS EBS CSI Driver**.

The EBS CSI Driver is particularly important for this project because MySQL requires persistent storage. It allows Kubernetes to dynamically provision Amazon EBS volumes when PersistentVolumeClaims are created.

The add-ons required before worker nodes are available are configured with `before_compute = true`, ensuring that the required components are installed as part of the cluster provisioning process.

### EKS Pod Identity

Instead of configuring long-lived AWS credentials inside Kubernetes workloads, the project uses **EKS Pod Identity** to provide AWS permissions to the EBS CSI Driver.

The EBS CSI Driver is associated with an IAM role through the following configuration:

```hcl
pod_identity_association = [
  {
    role_arn        = var.ebs_csi_role_arn
    service_account = "ebs-csi-controller-sa"
  }
]
```

This allows the EBS CSI controller to authenticate with AWS and perform the operations required to create and manage EBS volumes.

Using Pod Identity avoids storing AWS access keys inside Kubernetes and provides a cleaner way of connecting Kubernetes service accounts with AWS IAM permissions.

### Managed Node Group

The cluster was configured with an **EKS Managed Node Group** containing three EC2 worker nodes.

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

The node configuration is parameterized so that the AMI type and EC2 instance type can be changed through Terraform variables.

The node group has a desired capacity of three nodes, with a minimum of one and a maximum of three. This provides multiple worker nodes for running workloads while still allowing the environment to scale down when necessary.

### AWS Fargate

A Fargate profile was created specifically for the Java application namespace.

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

This configuration allows workloads deployed into the `java-app` namespace to run on AWS Fargate rather than the EC2 worker nodes.

The result is a mixed compute environment where the Java application can run on Fargate while stateful workloads such as MySQL can run on the managed EC2 nodes where persistent EBS storage is available.

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


