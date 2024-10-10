# Demo Terraform module

This is a demo Terraform module that can be used to create a demo infrastructure.

## Requirements

- terraform >= 1.5.0
- aws provider >= 5.0.0

## Usage

```hcl
module "dev" {
  source = "./modules/infra"

  name = "demo-dev"

  vpc_cidr = "10.0.0.0/16"
  private_subnets = ["10.0.10.0/24","10.0.20.0/24","10.0.30.0/24"]
  public_subnets = ["10.10.60.0/24","10.0.70.0/24","10.0.80.0/24"]


  create_key_pair = true
  public_server_count = 0
  private_server_count = 1

  tags = {
    "Environment" = "dev"
  }
}
```
