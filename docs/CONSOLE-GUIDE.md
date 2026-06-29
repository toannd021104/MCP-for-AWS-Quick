# Hướng dẫn chi tiết: Dựng Private MCP + Amazon Quick TRÊN CONSOLE

Tài liệu này hướng dẫn làm **thủ công trên AWS Console** (giao diện web), từng
bước một, kèm giải thích **vì sao** cần bước đó. Dùng khi bạn muốn hiểu rõ từng
thành phần thay vì chạy Terraform.

**Region dùng xuyên suốt:** `us-east-1` (N. Virginia).
**Hostname mục tiêu:** `mcp.example.com`
**Quy ước đặt tên:** prefix `quick-mcp-` cho dễ tìm.

> Mẹo: mở sẵn 2 tab — một tab AWS Console, một tab ghi lại các ID (VPC id,
> subnet id, SG id, ALB DNS name, resolver IP...) vì các bước sau cần dùng lại.

---

## TỔNG QUAN THỨ TỰ

```
1. VPC                      → khung mạng riêng
2. Subnets (1 public, 2 private)
3. Internet Gateway         → cho public subnet ra net
4. NAT Gateway + EIP        → cho private subnet ra net (1 chiều)
5. Route tables             → nối subnet với IGW/NAT
6. Security Groups          → ai nói chuyện với ai
7. EC2: MCP server + Bastion
8. (cài app trên MCP server)
9. ACM certificate          → TLS cho hostname
10. Internal ALB + Target group + Listener
11. Route 53 private hosted zone + record
12. Route 53 Resolver inbound endpoint
13. Amazon Quick VPC connection
14. Tạo MCP connector trong Quick
```

---

## B1 — Tạo VPC

**Để làm gì:** VPC là "mạng riêng" của bạn trên AWS — một vùng mạng cô lập, nơi
mọi thành phần (EC2, ALB, ENI...) sẽ sống. Đây là nền móng của toàn bộ giải pháp
"private".

**Trên Console:**
1. Vào **VPC** → **Your VPCs** → **Create VPC**.
2. Chọn **VPC only** (không dùng "VPC and more" để tự kiểm soát từng bước).
3. Name tag: `quick-mcp-vpc`
4. IPv4 CIDR: `10.0.0.0/16`  (cho ~65k IP, đủ rộng)
5. **Create VPC**.
6. Chọn VPC vừa tạo → **Actions → Edit VPC settings** → bật **Enable DNS hostnames**
   và **Enable DNS resolution** (cần cho private hosted zone hoạt động).

> Ghi lại **VPC ID** (vd `vpc-0xxxx`).

---

## B2 — Tạo Public Subnet

**Để làm gì:** public subnet là nơi đặt **NAT Gateway** và **Bastion**. "Public"
nghĩa là subnet này có đường ra Internet trực tiếp (qua Internet Gateway ở B3).

**Trên Console:**
1. **VPC → Subnets → Create subnet**.
2. VPC: chọn `quick-mcp-vpc`.
3. Subnet name: `quick-mcp-public-a`
4. Availability Zone: `us-east-1a`
5. IPv4 CIDR: `10.0.0.0/20`
6. **Create subnet**.
7. Chọn subnet → **Actions → Edit subnet settings** → bật
   **Enable auto-assign public IPv4 address** (để bastion tự có IP public).

> Ghi lại **Public Subnet ID**.

---

## B3 — Tạo 2 Private Subnet

**Để làm gì:** private subnet là nơi đặt **MCP server**, **ALB**, **ENI của
Quick**, **Resolver**. "Private" = không có IP public, Internet không vào được.
Cần **2 subnet ở 2 AZ khác nhau** vì ALB và Quick VPC connection bắt buộc trải
trên ≥ 2 AZ (đảm bảo dự phòng).

**Trên Console:** (làm 2 lần)
1. **Subnets → Create subnet** → VPC `quick-mcp-vpc`.
2. Subnet 1: name `quick-mcp-private-a`, AZ `us-east-1a`, CIDR `10.0.96.0/20`.
3. Subnet 2: name `quick-mcp-private-b`, AZ `us-east-1b`, CIDR `10.0.112.0/20`.
4. **KHÔNG** bật auto-assign public IP (để chúng thực sự private).

> Ghi lại **2 Private Subnet ID**.

---

## B4 — Tạo Internet Gateway (IGW)

**Để làm gì:** IGW là "cửa ra Internet" của VPC. Public subnet cần nó để NAT và
bastion liên lạc với Internet. Không có IGW thì public subnet cũng không ra net được.

**Trên Console:**
1. **VPC → Internet Gateways → Create internet gateway**.
2. Name: `quick-mcp-igw` → **Create**.
3. Chọn IGW vừa tạo → **Actions → Attach to VPC** → chọn `quick-mcp-vpc` → **Attach**.

> IGW phải được "attach" vào VPC mới dùng được.

---

## B5 — Tạo Elastic IP (cho NAT)

**Để làm gì:** NAT Gateway cần một **IP tĩnh public** để đại diện khi đi ra
Internet. Elastic IP (EIP) là IP public cố định bạn cấp phát.

**Trên Console:**
1. **VPC → Elastic IPs → Allocate Elastic IP address**.
2. Để mặc định → **Allocate**.
3. Đặt tag Name: `quick-mcp-nat-eip` (tuỳ chọn).

> Ghi lại **Allocation ID** của EIP.

---

## B6 — Tạo NAT Gateway

**Để làm gì:** MCP server nằm ở private subnet nhưng lúc setup cần ra Internet
(cài Docker, kéo image Jaeger, cài Python packages). NAT cho phép **đi ra** nhưng
**không cho đi vào** → giữ tính private. NAT đặt ở **public subnet**.

**Trên Console:**
1. **VPC → NAT Gateways → Create NAT gateway**.
2. Name: `quick-mcp-nat`
3. Subnet: chọn **public subnet** (`quick-mcp-public-a`).
4. Connectivity type: **Public**.
5. Elastic IP: chọn EIP vừa tạo ở B5.
6. **Create NAT gateway** → chờ trạng thái **Available** (vài phút).

> NAT Gateway có tính phí theo giờ + dữ liệu. Sau khi setup xong có thể xoá.

---

## B7 — Tạo Route Tables

**Để làm gì:** route table quyết định "gói tin đi đâu". Cần 2 cái:
- **Public RT**: gửi `0.0.0.0/0` (mọi traffic ra ngoài) → IGW.
- **Private RT**: gửi `0.0.0.0/0` → NAT Gateway.

**Trên Console:**

**Public route table:**
1. **VPC → Route tables → Create route table**.
2. Name: `quick-mcp-public-rt`, VPC: `quick-mcp-vpc` → **Create**.
3. Chọn nó → tab **Routes → Edit routes → Add route**:
   `0.0.0.0/0` → Target: **Internet Gateway** → `quick-mcp-igw`. **Save**.
4. Tab **Subnet associations → Edit** → gắn **public subnet**.

**Private route table:**
1. **Create route table** → Name `quick-mcp-private-rt`, VPC `quick-mcp-vpc`.
2. **Edit routes → Add route**: `0.0.0.0/0` → Target: **NAT Gateway** → `quick-mcp-nat`. **Save**.
3. **Subnet associations → Edit** → gắn **cả 2 private subnet**.

> Đây là lúc "kích hoạt" đường ra net: public qua IGW, private qua NAT.

---

## B8 — Tạo Security Groups

**Để làm gì:** SG là "tường lửa" cấp instance — quy định ai được kết nối tới ai.
Tạo 3 SG theo chuỗi tin cậy: Bastion → MCP, ALB → MCP.

**Trên Console:** (**VPC → Security groups → Create security group**, làm 3 lần)

**1) Bastion SG** (`quick-mcp-bastion-sg`)
- Inbound: SSH (TCP 22) từ `0.0.0.0/0` (hoặc IP của bạn cho an toàn hơn).
- Outbound: để mặc định (All traffic).
- *Vì sao:* để bạn SSH vào bastion từ máy mình.

**2) ALB SG** (`quick-mcp-alb-sg`)
- Inbound: HTTPS (TCP 443) từ `10.0.0.0/16` (trong VPC).
- Outbound: mặc định.
- *Vì sao:* ALB nhận HTTPS từ trong VPC (và sau này từ Quick ENI).

**3) MCP SG** (`quick-mcp-mcp-sg`)
- Inbound rule 1: TCP **8000**, Source = **ALB SG** (chọn group, không phải IP).
- Inbound rule 2: TCP **22**, Source = **Bastion SG**.
- Outbound: mặc định (cần để ra NAT cài đặt).
- *Vì sao:* MCP server chỉ nhận traffic app từ ALB, và SSH từ bastion — không
  từ bất kỳ đâu khác.

> Dùng **Source = Security Group** (không phải IP) là điểm cốt lõi: dù IP đổi,
> luật vẫn đúng, và tạo "chuỗi tin cậy" rõ ràng.

---

## B9 — Tạo Key Pair (để SSH)

**Để làm gì:** key pair là cặp khoá SSH để đăng nhập EC2. Không có nó không vào
được máy.

**Trên Console:**
1. **EC2 → Key Pairs → Create key pair**.
2. Name: `quick-mcp-key`, type **RSA**, format **.pem**.
3. **Create** → trình duyệt tải về file `quick-mcp-key.pem`.
4. Lưu file an toàn, đặt quyền: `chmod 600 quick-mcp-key.pem`.

---

## B10 — Tạo EC2: MCP Server (private)

**Để làm gì:** đây là máy chạy MCP server + Jaeger. Đặt trong **private subnet**.

**Trên Console:**
1. **EC2 → Instances → Launch instances**.
2. Name: `quick-mcp-server`.
3. AMI: **Amazon Linux 2023**, Architecture **64-bit (Arm)**.
4. Instance type: `t4g.medium`.
5. Key pair: `quick-mcp-key`.
6. **Network settings → Edit**:
   - VPC: `quick-mcp-vpc`
   - Subnet: **private-a**
   - Auto-assign public IP: **Disable**
   - Security group: chọn **MCP SG** (`quick-mcp-mcp-sg`).
7. Storage: 30 GB gp3.
8. **Advanced details → User data**: dán script cài Docker + Jaeger + MCP server
   (xem phần PHỤ LỤC A ở cuối).
9. **Launch instance**.

> Ghi lại **Private IP** của MCP server (vd `10.0.x.x`).

---

## B11 — Tạo EC2: Bastion (public)

**Để làm gì:** MCP server private không SSH thẳng từ Internet được. Bastion ở
public subnet làm "trạm trung chuyển" SSH.

**Trên Console:**
1. **Launch instances** → Name: `quick-mcp-bastion`.
2. AMI: Amazon Linux 2023 (Arm). Type: `t4g.nano`.
3. Key pair: `quick-mcp-key`.
4. **Network settings**:
   - Subnet: **public subnet**
   - Auto-assign public IP: **Enable**
   - Security group: **Bastion SG**.
5. **Launch instance**.

> Ghi lại **Public IP** của bastion.
> SSH vào MCP server: `ssh -J ec2-user@<bastion-public-ip> ec2-user@<mcp-private-ip>`

---

## B12 — Yêu cầu ACM Certificate

**Để làm gì:** ALB cần một chứng chỉ TLS **được tin cậy công khai**, tên khớp
hostname, để HTTPS hoạt động. ACM cấp miễn phí và tự gia hạn.

**Trên Console:**
1. **Certificate Manager (ACM) → Request certificate → Request a public certificate**.
2. Domain name: `mcp.example.com`.
3. Validation method: **DNS validation**.
4. **Request**.
5. Mở cert vừa tạo → copy bản ghi **CNAME** (Name + Value) ở phần
   "Domain → Create records / CNAME".

**Tại DNS provider (Cloudflare):**
6. Thêm 1 record CNAME: Name + Value đúng như ACM cho, **Proxy = DNS only** (tắt cam).
7. Quay lại ACM, chờ Status chuyển **Issued** (vài phút).

> *Vì sao DNS validation:* chứng minh bạn sở hữu domain. Vì domain ở provider
> ngoài, AWS không tự ghi được → bạn thêm tay CNAME. Đây là "public cert" dù
> hostname sẽ chỉ phân giải private.

> Ghi lại **Certificate ARN**.

---

## B13 — Tạo Target Group

**Để làm gì:** target group định nghĩa "ALB forward tới đâu" — ở đây là MCP
server cổng 8000, kèm health check `/health`.

**Trên Console:**
1. **EC2 → Target Groups → Create target group**.
2. Target type: **IP addresses**.
3. Name: `quick-mcp-tg`. Protocol **HTTP**, Port **8000**. VPC: `quick-mcp-vpc`.
4. Health check path: `/health`.
5. **Next** → Register targets: nhập **Private IP của MCP server**, Port `8000` → **Include as pending**.
6. **Create target group**.

> Target sẽ "unhealthy" cho tới khi MCP app chạy trên :8000 và trả 200 ở /health.

---

## B14 — Tạo Internal ALB + HTTPS Listener

**Để làm gì:** ALB là "lễ tân" — kết thúc TLS bằng cert ACM, rồi chuyển request
xuống MCP server. "Internal" = không có IP public.

**Trên Console:**
1. **EC2 → Load Balancers → Create load balancer → Application Load Balancer**.
2. Name: `quick-mcp-alb`. Scheme: **Internal**.
3. Network: VPC `quick-mcp-vpc`. Mappings: chọn **cả 2 private subnet**.
4. Security group: **ALB SG**.
5. Listeners: **HTTPS : 443**:
   - Default action: **Forward to** `quick-mcp-tg`.
   - Secure listener settings: Certificate (from ACM) = cert ở B12.
   - Security policy: `ELBSecurityPolicy-TLS13-1-2-2021-06`.
6. **Create load balancer**.

> Ghi lại **ALB DNS name** (dạng `internal-quick-mcp-alb-xxx.us-east-1.elb.amazonaws.com`).

---

## B15 — Tạo Route 53 Private Hosted Zone + Record

**Để làm gì:** đây là thứ làm `mcp.example.com` **phân giải về ALB, nhưng
chỉ trong VPC**. Đây là phần "private DNS" của giải pháp.

**Trên Console:**

**Tạo zone:**
1. **Route 53 → Hosted zones → Create hosted zone**.
2. Domain name: `example.com`.
3. Type: **Private hosted zone**.
4. VPC: Region `us-east-1`, chọn `quick-mcp-vpc`.
5. **Create hosted zone**.

**Tạo alias record:**
6. Mở zone → **Create record**.
7. Record name: `mcp` (sẽ thành `mcp.example.com`).
8. Record type: **A**.
9. Bật **Alias** → Route traffic to: **Alias to Application/Classic Load Balancer**
   → Region `us-east-1` → chọn ALB `quick-mcp-alb`.
10. **Create records**.

> *Vì sao private zone:* tên này chỉ tồn tại trong VPC → bên ngoài không phân
> giải được → dữ liệu không lộ. Alias trỏ thẳng tới ALB (ổn định hơn IP).

---

## B16 — Tạo Route 53 Resolver Inbound Endpoint

**Để làm gì:** Amazon Quick **không dùng VPC resolver mặc định**. Nó cần một địa
chỉ IP DNS cụ thể để hỏi. Resolver inbound tạo ra các ENI có **IP private cố
định** để Quick gửi truy vấn DNS tới (và tra được private hosted zone).

**Trước tiên tạo SG cho resolver** (`quick-mcp-resolver-sg`):
- Inbound: TCP 53 từ `10.0.0.0/16`, và UDP 53 từ `10.0.0.0/16`.

**Trên Console:**
1. **Route 53 → Resolver → Inbound endpoints → Create inbound endpoint**.
2. Name: `quick-mcp-resolver-inbound`. VPC: `quick-mcp-vpc`.
3. Security group: `quick-mcp-resolver-sg`.
4. IP addresses: thêm 2 dòng — mỗi dòng chọn 1 private subnet (a và b),
   IP để **Use an IP address selected automatically**.
5. **Create**.
6. Mở endpoint → copy **2 IP** mà nó cấp (vd `10.0.x.x`, `10.0.y.y`).

> Ghi lại **2 IP resolver** — bước sau (Quick VPC connection) cần điền vào.
> *Vì sao cần:* xem giải thích "ENI ở trong VPC nhưng Quick không dùng resolver
> .2 mặc định, nên phải có IP DNS thật".

---

## B17 — Tạo IAM Role cho Quick VPC Connection

**Để làm gì:** Quick cần một IAM role để **tạo và quản lý các ENI** trong VPC của
bạn. Role này chỉ cho phép quản lý ENI, không gate traffic.

**Trên Console:**
1. **IAM → Roles → Create role**.
2. Trusted entity: **Custom trust policy**, dán:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "quicksight.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
```
3. Đính kèm policy (inline) cho phép:
   `ec2:CreateNetworkInterface`, `ec2:ModifyNetworkInterfaceAttribute`,
   `ec2:DeleteNetworkInterface`, `ec2:DescribeSubnets`, `ec2:DescribeSecurityGroups`
   (Resource `*`).
4. Name: `quick-mcp-vpc-conn-role` → **Create role**.

---

## B18 — Tạo SG cho Quick ENI + mở ALB nhận từ Quick

**Để làm gì:** ENI của Quick cần SG riêng để giới hạn nó chỉ đi tới ALB (443) và
resolver (53). Đồng thời ALB phải chấp nhận 443 từ SG này.

**Trên Console:**

**Tạo Quick ENI SG** (`quick-mcp-quick-eni-sg`):
- Outbound rule 1: TCP 443 → Destination **ALB SG**.
- Outbound rule 2: TCP 53 → Destination **Resolver SG**.
- Outbound rule 3: UDP 53 → Destination **Resolver SG**.
- (Inbound: không cần — SG là stateful.)

**Sửa ALB SG** thêm inbound:
- TCP 443 từ **Quick ENI SG**.

> *Vì sao:* khóa chặt — Quick ENI chỉ nói chuyện được với ALB và DNS, không gì khác.

---

## B19 — Tạo Amazon Quick VPC Connection

**Để làm gì:** đây là mảnh ghép cho Quick "đặt chân" vào VPC của bạn. Nó tạo ENI
trong private subnet, dùng SG bạn chỉ định, và biết hỏi DNS ở 2 IP resolver.

**Trên Console (Amazon Quick / QuickSight admin):**
1. Vào **Manage Quick / QuickSight → Manage VPC connections → Add VPC connection**.
2. Name: `quick-mcp-vpc`.
3. VPC: `quick-mcp-vpc`.
4. Subnets: chọn **2 private subnet**.
5. Security group: **Quick ENI SG**.
6. DNS resolver endpoints: nhập **2 IP resolver** từ B16.
7. IAM role: `quick-mcp-vpc-conn-role`.
8. **Create** → chờ trạng thái **Available**.

> *Vì sao điền 2 IP resolver:* nếu thiếu, Quick không phân giải được hostname →
> lỗi "hostname cannot be resolved".

---

## B20 — Verify (từ trong VPC, qua bastion)

**Để làm gì:** kiểm tra cả đường đi hoạt động trước khi cắm vào Quick.

```bash
ssh -J ec2-user@<bastion-public-ip> ec2-user@<mcp-private-ip> \
  'getent hosts mcp.example.com; curl -s https://mcp.example.com/health'
```
Kỳ vọng: hostname resolve về IP private của ALB, và `/health` trả
`{"status":"ok",...}`.

> Nếu OK nghĩa là TLS + private DNS + ALB + MCP đều thông.

---

## B21 — Tạo MCP Connector trong Amazon Quick

**Để làm gì:** đây là bước cuối — đăng ký MCP server với Quick để dùng các tool.

**Trên Console (Amazon Quick):**
1. **Connectors → Create for your team → Model Context Protocol (MCP)**.
2. MCP server endpoint: `https://mcp.example.com/mcp`.
3. Connection type: **A named VPC connection** → `quick-mcp-vpc`.
4. Authentication: **No authentication** (hoặc Service-to-service OAuth nếu đã dựng Cognito).
5. **Create and continue** → Quick phát hiện các tool và đăng ký thành action.
6. Ở "Manage Tools & Permissions": đặt các tool read = **Always allow**, tool
   write = **Ask every time** (tuỳ ý).

> Xong! Giờ hỏi Quick "tôi bị lỗi 500 lúc checkout" → nó gọi tool MCP → query
> Jaeger → trả root cause.

---

## PHỤ LỤC A — User data cho MCP server (B10)

```bash
#!/bin/bash
set -euxo pipefail
dnf install -y docker python3.11 git
systemctl enable --now docker

# Jaeger all-in-one
docker run -d --name jaeger --restart=always \
  -p 16686:16686 -p 4317:4317 -p 4318:4318 -p 9411:9411 \
  jaegertracing/all-in-one:latest

# MCP server (FastAPI) trên :8000
cd /home/ec2-user
git clone https://github.com/toannd021104/jaeger-mcp.git mcp-server
cd mcp-server
python3.11 -m venv venv
./venv/bin/pip install -r requirements.txt
chown -R ec2-user:ec2-user /home/ec2-user/mcp-server

cat >/etc/systemd/system/jaeger-mcp.service <<UNIT
[Unit]
Description=Jaeger MCP Server
After=network.target docker.service
[Service]
Environment=PORT=8000
Environment=JAEGER_URL=http://localhost:16686
ExecStart=/home/ec2-user/mcp-server/venv/bin/python main.py
WorkingDirectory=/home/ec2-user/mcp-server
User=ec2-user
Restart=always
[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now jaeger-mcp
```

---

## PHỤ LỤC B — Thứ tự phụ thuộc (vì sao làm theo thứ tự này)

```
VPC ─► Subnets ─► IGW + NAT ─► Route tables   (mạng phải xong trước)
                                    │
Security Groups ───────────────────┤
                                    ▼
                              EC2 (MCP + Bastion)
                                    │
ACM cert (song song được) ──────────┤
                                    ▼
                          Target group ─► ALB + Listener
                                    │
                          Private hosted zone + record (cần ALB DNS name)
                                    │
                          Resolver inbound (lấy 2 IP)
                                    ▼
                          Quick VPC connection (cần 2 IP resolver)
                                    ▼
                          MCP connector trong Quick
```

Quy tắc chung: cái nào **tạo ra giá trị** mà cái sau cần (ID, IP, DNS name) thì
phải làm trước. Ví dụ: phải có ALB rồi mới tạo được alias record; phải có
resolver rồi mới điền được IP vào Quick VPC connection.

---

## PHỤ LỤC C — Dọn dẹp (tránh tốn phí)

Xoá theo thứ tự ngược: MCP connector → Quick VPC connection → Resolver endpoint →
ALB + Target group → EC2 (MCP + Bastion) → NAT Gateway → release EIP →
Private hosted zone → ACM cert → Security groups → Subnets → IGW (detach rồi xoá)
→ VPC.

> NAT Gateway, EIP, ALB, Quick connection là các thành phần tính phí chính.
