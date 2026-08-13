vpc_cidr_block             = "10.0.0.0/16"
private_subnet_cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidr_blocks  = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
environment                = "prod"
instance_types             = ["t3.small"]
ami_type                   = "AL2023_x86_64_STANDARD"
application_name           = "java-app"