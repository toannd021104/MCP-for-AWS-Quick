# Private MCP prod environment

This environment deploys a production-style Amazon Quick remote MCP endpoint:

```text
Amazon Quick
  -> Amazon Quick VPC connection
  -> internal ALB
  -> ECS Fargate tasks in private subnets
  -> private data sources or internal APIs in the VPC
```

The ALB and ECS tasks are private. ECS tasks do not receive public IP addresses. AWS service access from the private subnets is provided through VPC endpoints for ECR, CloudWatch Logs, Secrets Manager, and S3.

## Remote state

This environment stores Terraform state in S3:

- Bucket: `private-mcp-terraform-state-307711587176-us-east-1`
- Key: `private-mcp/prod/terraform.tfstate`
- Region: `us-east-1`
- AWS profile: `mcp`

The backend bucket is bootstrapped outside this stack because it stores the stack state. It has S3 versioning, server-side encryption, public access blocking, and Terraform S3 lockfile locking enabled.

## First-time setup

Create a real tfvars file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Review every value, then run:

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
```

Do not run `terraform apply` until the plan has been reviewed.

## Important apply order

Terraform creates the ECR repository and ECS service in one stack. For a clean first deploy, either:

- set `container_image` to an existing image that already exists, or
- apply only ECR first, push the MCP image, then apply the full stack.

The module defaults to `<created-ecr-repo>:latest` when `container_image` is null.

For the first bootstrap, keep `desired_count = 0`. After the MCP server image is pushed to ECR, change `desired_count = 1` and run another plan/apply.
