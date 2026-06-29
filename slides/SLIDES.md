---
title: Private MCP + Amazon Quick — Step 1→4
author: toannd
---

# Slide 1 — Bối cảnh & Mục tiêu

**Bài toán:** Amazon Quick cần gọi một MCP server chứa dữ liệu nội bộ nhạy cảm,
nhưng dữ liệu **không được đi qua endpoint public**.

**Giải pháp:** Dựng MCP server **private trong VPC**, Quick chạm tới qua
**Quick VPC connection** — không bước nào ra internet.

**Ý tưởng cốt lõi:** `public cert + private DNS`
- Cert được tin cậy công khai → TLS hợp lệ
- Tên chỉ phân giải trong VPC → dữ liệu không rời mạng nội bộ

**Use case:** Incident response — hỏi "tôi bị lỗi 500", Quick query Jaeger trả root cause.

---

# Slide 2 — Kiến trúc tổng thể

```
User ──► Amazon Quick
              │ (Quick VPC connection: ENI trong private subnet)
              ▼
        [Private subnet]
          Resolver inbound (DNS)  ─► private hosted zone ─► IP ALB
          Internal ALB (TLS, cert ACM) ─HTTP:8000─► MCP server ─► Jaeger
        [Public subnet]
          NAT gateway (outbound setup) + Bastion (SSH)
```

**4 trụ cột:**
1. Mạng (VPC, subnet, NAT) — Step 1
2. Bảo mật (security groups) — Step 2
3. Compute (EC2 MCP + Jaeger) — Step 3
4. TLS (ACM cert) — Step 4

---

# Slide 3 — Biến dùng chung

```bash
VPC=vpc-xxxx                 # 172.31.0.0/16 (blog) | 10.0.0.0/16 (của ta)
SUBNET_A=subnet-xxxx         # private us-east-1a
SUBNET_B=subnet-xxxx         # private us-east-1b
PUB_SUBNET=subnet-xxxx       # public us-east-1a (NAT + bastion)
HOSTNAME=mcp.example.com
```

Hai loại subnet:
- **Private**: nơi chứa MCP server (không IP public)
- **Public**: chỉ chứa thành phần trung gian (NAT, bastion)

---

# Slide 4 — STEP 1: NAT Gateway (1/2)

**Mục đích:** MCP server ở private subnet **cần ra internet lúc setup** để:
- Cài Docker, Python
- Kéo image Jaeger
- Cài Python packages

Nhưng **không cho internet đi vào** → dùng NAT (chỉ một chiều outbound).

```bash
EIP=$(aws ec2 allocate-address --domain vpc --query AllocationId --output text)
NAT=$(aws ec2 create-nat-gateway --subnet-id $PUB_SUBNET \
        --allocation-id $EIP --query NatGateway.NatGatewayId --output text)
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT
```

---

# Slide 5 — STEP 1: NAT Gateway (2/2)

**Trỏ default route của private subnet về NAT:**

```bash
aws ec2 create-route --route-table-id <private-rtb> \
  --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT
```

**Luồng ra internet:**
```
MCP server (private) ─► private route table (0.0.0.0/0)
                      ─► NAT gateway (public subnet)
                      ─► Internet Gateway ─► Internet
```

> NAT **phải** đặt ở public subnet (vì NAT cần đi ra qua IGW).
> Sau khi setup xong có thể gỡ NAT để tiết kiệm chi phí.

---

# Slide 6 — STEP 2: Security Groups (1/2)

**Mục đích:** dựng "chuỗi tin cậy" — ai được nói chuyện với ai.

```
Internet ─SSH:22─► Bastion ─SSH:22─► MCP server
                   VPC ─HTTPS:443─► ALB ─HTTP:8000─► MCP server
```

**3 security group:**
| SG | Cho vào (ingress) |
|----|-------------------|
| Bastion | SSH :22 từ internet (0.0.0.0/0) |
| ALB | HTTPS :443 từ trong VPC |
| MCP | :8000 từ ALB SG; SSH :22 từ Bastion SG |

---

# Slide 7 — STEP 2: Security Groups (2/2)

```bash
# Bastion: SSH từ internet
aws ec2 authorize-security-group-ingress --group-id $BASTION_SG \
  --protocol tcp --port 22 --cidr 0.0.0.0/0

# ALB: HTTPS từ trong VPC
aws ec2 authorize-security-group-ingress --group-id $ALB_SG \
  --protocol tcp --port 443 --cidr 172.31.0.0/16

# MCP: 8000 chỉ từ ALB SG; 22 chỉ từ Bastion SG
aws ec2 authorize-security-group-ingress --group-id $MCP_SG \
  --protocol tcp --port 8000 --source-group $ALB_SG
aws ec2 authorize-security-group-ingress --group-id $MCP_SG \
  --protocol tcp --port 22 --source-group $BASTION_SG
```

**Điểm hay:** dùng **source-group** (tham chiếu SG) thay vì IP → MCP chỉ nhận
traffic từ đúng ALB, dù IP ALB đổi vẫn đúng.

---

# Slide 8 — STEP 3: EC2 MCP server (1/2)

**Mục đích:** chạy MCP server + Jaeger.

- **MCP server**: instance ARM (`t4g.medium`) trong **private subnet**
- **Bastion**: instance nhỏ (`t4g.nano`) trong **public subnet** (SSH jump)

```bash
# MCP server (private)
aws ec2 run-instances --instance-type t4g.medium --subnet-id $SUBNET_A \
  --security-group-ids $MCP_SG --user-data file://mcp-userdata.sh ...

# Bastion (public, có IP public)
aws ec2 run-instances --instance-type t4g.nano --subnet-id $PUB_SUBNET \
  --associate-public-ip-address --security-group-ids $BASTION_SG ...
```

---

# Slide 9 — STEP 3: EC2 MCP server (2/2)

**user-data tự động cài đặt khi boot:**

```bash
dnf install -y docker python3.11 git
systemctl enable --now docker

# Jaeger all-in-one
docker run -d --name jaeger --restart=always \
  -p 16686:16686 -p 4317:4317 -p 4318:4318 jaegertracing/all-in-one

# MCP server :8000 như systemd service (tự restart)
git clone <repo> mcp-server
python3.11 -m venv venv && ./venv/bin/pip install -r requirements.txt
systemctl enable --now jaeger-mcp
```

**Verify qua bastion:**
```bash
ssh -J ec2-user@<bastion-ip> ec2-user@<mcp-private-ip> \
  'systemctl is-active jaeger-mcp; curl -s localhost:8000/health'
# active  {"status":"ok",...}
```

---

# Slide 10 — STEP 4: ACM Certificate (1/2)

**Mục đích:** ALB cần cert **được tin cậy công khai**, tên khớp hostname, để
TLS handshake thành công.

```bash
# Xin cert, xác thực bằng DNS
CERT_ARN=$(aws acm request-certificate --domain-name $HOSTNAME \
  --validation-method DNS --query CertificateArn --output text)

# Đọc bản ghi CNAME cần thêm
aws acm describe-certificate --certificate-arn $CERT_ARN \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord'
# { "Name": "_xxx.mcp.example.com", "Type": "CNAME",
#   "Value": "_yyy.acm-validations.aws." }
```

---

# Slide 11 — STEP 4: ACM Certificate (2/2)

**Thêm CNAME ở DNS provider (Cloudflare) — việc tay duy nhất:**
- Type: CNAME
- Name: `_xxx.mcp.toannd`
- Value: `_yyy.acm-validations.aws`
- ⚠️ **DNS only** (tắt proxy cam) — nếu không ACM không thấy record thật

```bash
aws acm wait certificate-validated --certificate-arn $CERT_ARN
# Status: ISSUED  → cert tự gia hạn vĩnh viễn
```

**Tại sao DNS validation:** chứng minh sở hữu domain. Vì domain ở provider
ngoài, AWS không tự ghi được → phải thêm tay. Đây là lý do "public cert" dù
hostname private.

---

# Slide 12 — Tổng kết Step 1→4

| Step | Thành phần | Vai trò |
|------|-----------|---------|
| 1 | NAT gateway | Cho MCP server ra net lúc setup (1 chiều) |
| 2 | 3 Security groups | Chuỗi tin cậy: Bastion→MCP, ALB→MCP |
| 3 | EC2 + user-data | Chạy Jaeger + MCP server :8000 |
| 4 | ACM cert | TLS hợp lệ cho hostname (public cert) |

**Tiếp theo (Step 5→10):** ALB → private DNS → resolver inbound →
Quick VPC connection → verify → tạo connector trong Quick.

---

# Slide 13 — Q&A nhanh

- **Vì sao ALB không trỏ thẳng EC2?** TLS (ACM chỉ gắn ALB) + tên ổn định + cách ly.
- **Public subnet làm gì?** Chứa NAT + bastion (trung gian), không chứa app.
- **NAT vs IGW?** IGW = 2 chiều cho public; NAT = chỉ outbound cho private.
- **Cert private mà sao public?** Cấp cert chỉ cần chứng minh sở hữu domain.
