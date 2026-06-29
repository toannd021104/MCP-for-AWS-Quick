# Quick MCP — Note tổng hợp (Step 1 → 10) + Hỏi đáp

Mục tiêu: cho Amazon Quick gọi được một MCP server **nằm hoàn toàn trong VPC**
(private), TLS vẫn hợp lệ, DNS chỉ phân giải trong VPC. Ý tưởng cốt lõi:
**public cert + private DNS**.

Khác với blog gốc: domain dùng `example.com` (Cloudflare), VPC tự tạo CIDR
`10.0.0.0/16`, ID không hardcode (Terraform tự tham chiếu).

---

## Tóm tắt từng bước (đã làm)

| Step | Làm gì | File Terraform |
|------|--------|----------------|
| 0 | VPC `10.0.0.0/16` + 2 private subnet + 1 public subnet + route table | `network.tf` |
| 1 | NAT gateway + EIP + Internet Gateway (cho private subnet ra net lúc setup) | `network.tf` |
| 2 | 3 security group: bastion, ALB, MCP (chuỗi tin cậy) | `security-groups.tf` |
| 3 | EC2 MCP server (private) + bastion (public) + user-data (Docker, Jaeger, MCP) + key pair | `compute.tf`, `keypair.tf`, `mcp-userdata.sh.tftpl` |
| 4 | ACM certificate cho `mcp.example.com` (DNS validation qua Cloudflare) | `acm.tf` |
| 5 | Internal ALB + target group (:8000, health `/health`) + HTTPS listener :443 | `alb.tf` |
| 6 | Route 53 private hosted zone + alias `mcp.example.com → ALB` | `dns.tf` |
| 7 | Route 53 Resolver inbound endpoint (2 IP private cho Quick hỏi DNS) | `resolver.tf` |
| 8 | Amazon Quick VPC connection (ENI vào subnet + SG + IAM role + 2 IP resolver) | `quick.tf` |
| 9 | Verify từ trong VPC: resolve hostname + HTTPS `/health` + `tools/list` | (test thủ công) |
| 10 | Tạo MCP connector trong Quick console (việc tay trên UI) | — |

MCP server app: `jaeger-mcp-server/` (FastAPI, `/health` + `/mcp`, 4 tools query
Jaeger), push lên `https://github.com/toannd021104/jaeger-mcp`.

---

## Giá trị thực tế (account david, us-east-1)
- Hostname: `mcp.example.com`
- ACM cert: ISSUED
- ALB: `quick-mcp-alb` (internal)
- Resolver inbound IPs: `10.0.116.X`, `10.0.101.Y`
- Quick VPC connection id: `quick-mcp-vpc` (AVAILABLE)
- Step 9 verify: hostname resolve về IP private ALB, HTTPS trả 200, 4 tools OK.

---

## Luồng request lúc chạy
```
User hỏi Quick → Quick gọi https://mcp.example.com/mcp qua VPC connection
   │
   ▼
ENI của Quick (trong private subnet)
   │ 1) hỏi DNS :53 ─────► Resolver inbound (10.0.116.X/10.0.101.Y)
   │                          └─► private hosted zone → IP private ALB
   │ 2) HTTPS :443 ───────► ALB (TLS terminate, cert ACM)
   │                          └─► HTTP :8000 → MCP server → Jaeger
   ◄──────────── kết quả trả về theo đúng đường ────────────
```
Mọi thứ bằng IP private, không ra internet.

---

# HỎI ĐÁP — vì sao cần từng thành phần

## Q1: Tại sao dùng internal ALB mà không trỏ thẳng EC2?
1. **TLS**: Quick bắt buộc HTTPS. ACM cert chỉ gắn được vào ALB (không gắn vào
   EC2). ALB là nơi kết thúc TLS bằng cert hợp lệ.
2. **Tên ổn định**: ALB có DNS name cố định để alias trỏ tới. IP EC2 đổi mỗi
   lần tạo lại.
3. **Health check** tự động + dễ mở rộng nhiều MCP server.
4. **Cách ly bảo mật**: Quick → ALB → MCP, Quick không chạm thẳng máy chứa dữ liệu.

## Q2: Public subnet để làm gì?
Chứa 2 thứ trung gian:
- **NAT gateway**: cho MCP server (private) ra net tải Docker/Jaeger lúc setup,
  nhưng net không vào được (chỉ outbound).
- **Bastion**: SSH jump host để vào MCP server private.
MCP server luôn ở private subnet (không IP public, net không chạm tới).

## Q3: ENI của Quick là gì?
"Card mạng ảo" mà AWS cắm vào subnet của bạn thay mặt Quick (Quick vốn ở ngoài
VPC). Có IP private, dùng SG bạn kiểm soát. Là "cánh tay nối dài" để traffic của
Quick xuất phát từ bên trong VPC chứ không qua internet.

## Q4: Resolver inbound là gì? Có phải public không?
- Là điểm DNS có IP private cố định để Quick hỏi và phân giải được hostname
  private (chỉ tồn tại trong private hosted zone).
- **Hoàn toàn private** (IP 10.0.x.x, SG chỉ mở 53 trong VPC). "Bên ngoài" chỉ
  nghĩa là "ngoài VPC resolver mặc định", không phải internet.

## Q5: Inbound vs Outbound endpoint?
- **Inbound**: câu hỏi DNS đi TỪ ngoài VÀO VPC để hỏi tên private của bạn (dùng ở đây).
- **Outbound**: câu hỏi DNS đi TỪ trong VPC RA ngoài (vd hỏi DNS on-prem). Không dùng.

## Q6: Đã có VPC connection rồi sao còn cần resolver?
- VPC connection lo **đường đi** (ENI vào mạng private).
- Resolver lo **địa chỉ** (đổi tên `mcp...` → IP). Quick không dùng VPC resolver
  mặc định nên phải có resolver inbound. Thiếu nó → lỗi `hostname cannot be resolved`.
- Không thể trỏ thẳng IP vì TLS cần TÊN khớp cert, và IP ALB có thể đổi.

## Q7: Thứ tự resolver trước hay VPC connection trước?
**Resolver trước.** Vì VPC connection cần 2 IP của resolver làm tham số đầu vào
(`dns_resolvers`). Trong Terraform, vì `dns_resolvers` tham chiếu resource resolver
nên thứ tự được ép tự động.

## Q8: Vì sao cần ACM cert dù hostname là private?
TLS handshake cần cert mà TÊN khớp hostname và được tin cậy công khai. Việc cấp
cert chỉ cần chứng minh sở hữu domain (qua CNAME ở Cloudflare), không cần hostname
phải public. Đây là "public cert + private DNS".

## Q9: Vì sao 2 loại DNS dễ nhầm?
- **CNAME validation ở Cloudflare** = DNS công khai, để ACM xác thực sở hữu domain.
- **Alias record ở private hosted zone** = DNS riêng trong VPC, trỏ hostname về ALB.
Hai cái khác nhau hoàn toàn.

---

## Step 10 — Tạo connector trong Quick console (việc tay)
1. Connectors → Create for your team → Model Context Protocol (MCP).
2. MCP server endpoint: `https://mcp.example.com/mcp`
3. Connection type: named VPC connection → `quick-mcp-vpc`
4. Authentication: No authentication
5. Create → Quick phát hiện các tool và đăng ký thành action.

---

## Lưu ý vận hành
- ACM cert tự gia hạn miễn là CNAME validation còn trên Cloudflare (để **DNS only**).
- Một số tài nguyên đặt tên mới (`quick-mcp-alb`, `quick-mcp-tg`,
  `quick-mcp-vpc`, role `private-mcp-quick-vpc-conn`) để tránh trùng với
  tài nguyên của bài blog gốc còn sót trong account.
- NAT gateway + EIP + ALB + Quick connection có tính phí — nhớ `terraform destroy`
  khi không dùng.
