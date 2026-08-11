# <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128"><g fill-rule="evenodd"><path d="M77.941 44.5v36.836L46.324 62.918V26.082zm0 0" fill="#5c4ee5"/><path d="M81.41 81.336l31.633-18.418V26.082L81.41 44.5zm0 0" fill="#4040b2"/><path d="M11.242 42.36L42.86 60.776V23.941L11.242 5.523zm0 0M77.941 85.375L46.324 66.957v36.82l31.617 18.418zm0 0" fill="#5c4ee5"/></g></svg>
Terraform on AWS – Provisioning Amazon EKS Infrastructure with Remote State and CI/CD

This project demonstrates how to provision and manage a complete **Amazon Elastic Kubernetes Service (Amazon EKS)** environment using **Terraform** following Infrastructure as Code (IaC) best practices. The goal is to create a reusable, modular, and automated infrastructure platform that can be deployed repeatedly across multiple environments such as development, testing, staging, and production.

Instead of manually creating AWS networking resources, IAM roles, EKS clusters, node groups, and Kubernetes add-ons, the entire infrastructure is defined declaratively using Terraform modules. This makes the infrastructure reproducible, version-controlled, and easier to maintain as the platform evolves.

The project provisions an Amazon EKS cluster with:

* A dedicated VPC with public and private subnets
* Managed EC2 worker nodes
* An AWS Fargate profile for application workloads
* The AWS EBS CSI Driver for persistent storage
* EKS Pod Identity for secure IAM authentication
* MySQL deployed through Helm with persistent Amazon EBS volumes

In addition to infrastructure provisioning, the project implements **remote Terraform state management** using Amazon S3 and a **Jenkins CI/CD pipeline** that automatically validates, plans, and applies infrastructure changes from a Git repository. This enables infrastructure updates to follow the same collaborative workflow used for application deployments.

## Project Objectives

Throughout this project the following technologies and concepts are implemented:

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

Rather than focusing solely on the final infrastructure, this documentation also covers the Terraform architecture, module design, AWS integration, CI/CD workflow, troubleshooting process, and the lessons learned while automating a production-style Kubernetes environment on AWS.
