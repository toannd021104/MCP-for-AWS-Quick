# Setup private MCP server cho Amazon Quick qua VPC connection

Tai lieu nay mo ta cach trien khai private MCP server trong AWS VPC va ket noi Amazon Quick toi MCP server do bang Amazon Quick VPC connection.

## 1. Ket luan kien truc

Amazon Quick MCP integration co 2 cach ket noi MCP server:

- MCP server reachable over public internet.
- Private MCP server reachable tu VPC trong AWS account bang Amazon Quick VPC connection.

Voi yeu cau private/prod, dung flow sau:

```text
Amazon Quick
  |
  | Amazon Quick VPC connection
  v
Private/internal ALB trong VPC
  |
  v
ECS Fargate MCP server trong private subnet
  |
  v
Private data source / internal API trong VPC
```

Khong can public MCP endpoint cho flow nay. MCP server, ALB va data source deu co the private trong VPC.

Luu y quan trong: neu MCP server dung OAuth, cac OAuth endpoints ma Quick can goi van phai reachable over public internet theo AWS doc history. Neu muon private hoan toan cho PoC, bat dau voi no-auth/service auth don gian, sau do thiet ke OAuth rieng.

## 2. Kien truc khuyen nghi

Khuyen nghi production:

```text
Quick VPC connection
  -> internal ALB
  -> ECS Fargate task, no public IP
  -> private data source/internal service
```

Thanh phan:

- Existing VPC.
- Public subnets chi can neu account/VPC da co san cho nhung workload khac; private MCP flow khong can public ALB.
- Private subnets cho ECS task va VPC endpoints.
- Internal ALB trong private subnets.
- ECS Fargate service trong private subnets, `assign_public_ip = false`.
- VPC endpoints cho:
  - ECR API
  - ECR Docker registry
  - CloudWatch Logs
  - Secrets Manager
  - S3 gateway endpoint
- Amazon Quick VPC connection tro toi VPC/subnets/security group co the reach internal ALB.
- Private DNS record, vi du:

```text
mcp.apppayvn.pngha.io.vn -> internal ALB
```

Endpoint trong Amazon Quick:

```text
http://mcp.apppayvn.pngha.io.vn/mcp
```

Hoac HTTPS private neu ban muon terminate TLS o internal ALB voi certificate phu hop:

```text
https://mcp.apppayvn.pngha.io.vn/mcp
```

## 3. Vi sao khong can public endpoint

Neu dung Amazon Quick VPC connection, Quick tao network connectivity vao VPC cua ban. Khi tao MCP connector, ban chon VPC connection va nhap MCP server URL reachable tu VPC do.

Do do:

- Khong can public hosted zone cho MCP endpoint.
- Khong can public ALB cho MCP endpoint.
- Khong can expose ECS task ra internet.
- Database/internal API khong public.

Van can:

- MCP endpoint reachable tu VPC connection.
- Security group cho phep traffic tu Quick VPC connection/network interface den internal ALB.
- ALB forward den ECS task.
- ECS task co quyen va network de goi private data source/internal API.

## 4. Cac option compute

### Option A: ECS Fargate + internal ALB

Khuyen nghi.

Uu diem:

- Runtime managed, khong can quan ly OS.
- Phu hop remote HTTP MCP server.
- De scale, log CloudWatch, deploy image tu ECR.
- ECS task co the nam hoan toan trong private subnet.

Nhuoc diem:

- Can Docker image va ECR.
- Can ALB target group/health check dung.

### Option B: EC2 + internal ALB

Dung khi can SSH/debug truc tiep hoac MCP server co yeu cau runtime dac biet.

Uu diem:

- De debug.
- Linh hoat ve OS/runtime.

Nhuoc diem:

- Phai tu quan ly patching, hardening, service restart, autoscaling.

### Option C: Lambda trong VPC

Chi phu hop khi tool ngan, stateless, va request xu ly nhanh.

Uu diem:

- It van hanh.

Nhuoc diem:

- MCP HTTP streaming/long-running khong phu hop bang ECS.
- Timeout Quick MCP operations la 60 giay, nen tool phai rat gon.

## 5. Chuan bi thong tin AWS

Dat bien moi truong:

```bash
export AWS_PROFILE=mcp
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text)
export VPC_ID=vpc-00a0bb566f620d017
```

Kiem tra VPC:

```bash
aws ec2 describe-vpcs \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --query 'Vpcs[*].[VpcId,CidrBlock,State,IsDefault]' \
  --output table
```

Kiem tra subnet:

```bash
aws ec2 describe-subnets \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock,MapPublicIpOnLaunch]' \
  --output table
```

Kiem tra security group:

```bash
aws ec2 describe-security-groups \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[*].[GroupId,GroupName,Description]' \
  --output table
```

## 6. Security group design

### Quick VPC connection security group

Dung security group nay khi tao Amazon Quick VPC connection.

Outbound:

- TCP `80` hoac `443` toi internal ALB security group.

### Internal ALB security group

Inbound:

- TCP `80` hoac `443` tu Quick VPC connection security group.

Outbound:

- TCP MCP container port, vi du `8080`, toi ECS task security group.

### ECS task security group

Inbound:

- TCP `8080` tu internal ALB security group.

Outbound:

- TCP `443` toi VPC endpoint security group.
- TCP toi data source/internal API security group theo port can thiet.

### VPC endpoint security group

Inbound:

- TCP `443` tu ECS task security group.

## 7. Private DNS

Dung private hosted zone neu muon co ten noi bo de Quick VPC connection resolve duoc:

```text
apppayvn.pngha.io.vn
```

Record:

```text
mcp.apppayvn.pngha.io.vn -> internal ALB
```

Neu khong dung private DNS, co the dung internal ALB DNS name truc tiep trong Amazon Quick MCP connector, nhung private DNS de doc va de thay doi ha tang sau nay tot hon.

## 8. MCP server requirements

MCP server can:

- Ho tro remote MCP over HTTP.
- Co endpoint `/mcp`.
- Co health check `/health`.
- Tool execution nen duoi 60 giay.
- Khong phu thuoc custom HTTP headers, vi Quick MCP operations khong ho tro custom headers.
- Neu thay doi tool list, can recreate MCP integration de Quick discover lai.

Endpoint noi bo:

```text
http://mcp.apppayvn.pngha.io.vn/mcp
```

Health check:

```text
http://mcp.apppayvn.pngha.io.vn/health
```

## 9. Terraform flow

Thu tu production nen lam:

1. Tao private subnets.
2. Tao VPC endpoints cho ECR/Logs/Secrets/S3.
3. Tao ECR repository.
4. Tao IAM roles cho ECS task.
5. Tao ECS cluster/task definition/service voi `desired_count = 0`.
6. Tao internal ALB + target group.
7. Push MCP image len ECR.
8. Doi `desired_count = 1`.
9. Tao Amazon Quick VPC connection.
10. Tao Amazon Quick MCP connector, chon VPC connection va nhap private MCP URL.

## 10. Tao Amazon Quick VPC connection

Co the tao tu console hoac AWS CLI. CLI `create-vpc-connection` can:

- AWS account ID.
- VPC connection ID.
- Name.
- It nhat 2 subnet IDs.
- It nhat 1 security group ID.
- IAM role ARN cho Quick assume.
- DNS resolvers optional neu can custom resolver.

Vi du CLI:

```bash
aws quicksight create-vpc-connection \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --aws-account-id "$AWS_ACCOUNT_ID" \
  --vpc-connection-id private-mcp-vpc \
  --name "Private MCP VPC" \
  --subnet-ids subnet-private-a subnet-private-b \
  --security-group-ids sg-quick-vpc-connection \
  --role-arn arn:aws:iam::$AWS_ACCOUNT_ID:role/service-role/QuickSight-VPC-Role
```

Kiem tra:

```bash
aws quicksight describe-vpc-connection \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --aws-account-id "$AWS_ACCOUNT_ID" \
  --vpc-connection-id private-mcp-vpc
```

Trang thai mong doi:

```text
CreationStatus: CREATION_SUCCESSFUL
AvailabilityStatus: AVAILABLE
```

## 11. Tao MCP connector trong Amazon Quick

Trong Amazon Quick console:

1. Chon **Connectors**.
2. Chon **Create for your team**.
3. Chon **Model Context Protocol (MCP)**.
4. Nhap MCP server endpoint:

```text
http://mcp.apppayvn.pngha.io.vn/mcp
```

5. Chon VPC connection vua tao.
6. Chon authentication method:
   - No authentication cho PoC noi bo.
   - Service authentication/OAuth cho production.
7. Create connector.
8. Review discovered tools/actions.
9. Share connector cho team can dung.

## 12. Kiem thu

MCP server hien co cac tool PoC:

- `echo`
- `environment`
- `s3_list_orders`
- `s3_get_order`
- `rds_list_customers`
- `rds_revenue_summary`

Test tu trong VPC truoc:

```bash
curl -i http://mcp.apppayvn.pngha.io.vn/health
curl -i http://mcp.apppayvn.pngha.io.vn/mcp
```

Kiem tra ALB target health:

```bash
aws elbv2 describe-target-health \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --target-group-arn TARGET_GROUP_ARN
```

Kiem tra ECS service:

```bash
aws ecs describe-services \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --cluster private-mcp \
  --services private-mcp
```

Kiem tra CloudWatch Logs:

```bash
aws logs tail /ecs/private-mcp \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --follow
```

## 13. Troubleshooting

### Quick khong connect duoc private MCP

Kiem tra:

- VPC connection status da `AVAILABLE`.
- Subnet cua VPC connection co route/security group toi internal ALB.
- Private DNS resolve duoc tu VPC.
- ALB target health la healthy.
- ECS task dang running.
- MCP server listen dung port va path `/mcp`.

### Tool timeout

Quick MCP operations co timeout 60 giay. Nen:

- Gioi han query/result.
- Dung pagination.
- Dung async job/status tool neu tac vu dai.

### Auth loi

Kiem tra:

- OAuth endpoints co reachable over public internet neu dung OAuth.
- Callback URI cua Quick da duoc allow-list.
- Token scopes phu hop metadata.

## 14. Bao mat va van hanh

- Khong public MCP endpoint neu dung VPC connection.
- Khong public database/internal API.
- ECS task khong co public IP.
- Secret de trong Secrets Manager/SSM Parameter Store.
- IAM task role least privilege.
- Security group chi mo source/destination can thiet.
- CloudWatch Logs bat retention.
- Bat CloudTrail.
- Dung auth cho production.
- Recreate MCP integration khi thay doi tool list.

## 15. Tai lieu tham khao

- Amazon Quick MCP integration: https://docs.aws.amazon.com/quick/latest/userguide/mcp-integration.html
- AWS What's New - Amazon Quick supports VPC connectivity for MCP: https://aws.amazon.com/about-aws/whats-new/2026/06/amazon-quick-vpc-mcp/
- Amazon Quick doc history: https://docs.aws.amazon.com/quick/latest/userguide/doc-history.html
- Configuring VPC connections in Amazon Quick Sight: https://docs.aws.amazon.com/quick/latest/userguide/working-with-aws-vpc.html
- AWS CLI `quicksight create-vpc-connection`: https://docs.aws.amazon.com/cli/latest/reference/quicksight/create-vpc-connection.html
