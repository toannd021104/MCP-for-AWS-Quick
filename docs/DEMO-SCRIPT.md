# Kịch bản Demo — Private MCP + Amazon Quick

**Chủ đề:** Trợ lý AI điều tra sự cố trên dữ liệu nội bộ, mà dữ liệu không rời mạng riêng.
**Thời lượng:** ~6–7 phút.
**Thông điệp chính:** *AI gặp dữ liệu, một cách an toàn.*

---

## CHUẨN BỊ TRƯỚC KHI DEMO (làm trước, đừng làm live)

- [ ] MCP server + Jaeger đang chạy (service `jaeger-mcp` active).
- [ ] Đã seed trace demo: SSH vào instance chạy `python3 seed_traces.py`.
      (Jaeger all-in-one lưu in-memory → seed lại nếu instance vừa restart.)
- [ ] Mở sẵn 3 tab/cửa sổ:
      1. Terminal (để chạy lệnh `dig` chứng minh private)
      2. Terminal SSH qua bastion (sẵn sàng gõ lệnh trong VPC)
      3. Amazon Quick console (đã đăng nhập, mở connector MCP)
- [ ] Mở sẵn slide solution (`solution-deck.pptx`).

**Thông số cần nhớ:**
- Hostname: `mcp.example.com`
- Bastion IP: (lấy mới nếu instance tạo lại)
- MCP private IP: (lấy mới nếu instance tạo lại)

---

## PHẦN 1 — Mở đầu: Vấn đề (1 phút)

> **Nói:**
> "Amazon Quick là trợ lý AI doanh nghiệp. Nó mạnh, nhưng nhiều dữ liệu quan
> trọng của chúng ta lại nằm trong mạng riêng — database, hệ thống giám sát.
> Câu hỏi: làm sao cho AI dùng được dữ liệu đó mà không phơi nó ra Internet?"

**Thao tác:** chiếu slide *Problem* (sơ đồ đỏ: Quick → Internet → dữ liệu lộ).

> **Chốt:** "Mở endpoint public là rủi ro. Chúng ta cần cách khác."

---

## PHẦN 2 — Giải pháp (1 phút)

**Thao tác:** chuyển slide *Solution* (sơ đồ xanh: Quick → VPC → MCP).

> **Nói:**
> "Giải pháp: đặt MCP server hoàn toàn trong VPC. Quick chạm tới qua một kết nối
> riêng. Hai nguyên tắc: **chứng chỉ công khai** để TLS hợp lệ, **tên miền riêng**
> để chỉ thấy được bên trong mạng. Dữ liệu không bao giờ ra ngoài."

---

## PHẦN 3 — Chứng minh "private" là thật (1.5 phút) ⭐ điểm nhấn

Đây là phần thuyết phục nhất — cho thấy cùng một tên, 2 kết quả khác nhau.

**Thao tác 1 — hỏi DNS từ Internet (tab terminal laptop):**
```bash
dig +short A mcp.example.com @1.1.1.1
```
> **Nói:** "Tôi hỏi DNS công khai địa chỉ của server. Kết quả... *trống*. Từ
> Internet, server này **không tồn tại**. Không ai dò tới được."

**Thao tác 2 — hỏi DNS từ trong VPC (tab SSH qua bastion):**
```bash
ssh -J ec2-user@<bastion-ip> ec2-user@<mcp-private-ip> \
  'getent hosts mcp.example.com'
```
> **Nói:** "Nhưng từ bên trong VPC, cùng cái tên đó trả về IP private của load
> balancer. Đây gọi là split-horizon DNS — tên ẩn với thế giới, chỉ sống nội bộ."

**Thao tác 3 — gọi HTTPS thật trong VPC:**
```bash
ssh -J ec2-user@<bastion-ip> ec2-user@<mcp-private-ip> \
  'curl -s https://mcp.example.com/health'
# {"status":"ok","server":"jaeger-mcp","version":"1.0.0"}
```
> **Chốt:** "TLS hợp lệ, server trả lời — nhưng toàn bộ chỉ xảy ra trong mạng riêng."

---

## PHẦN 4 — Quick đã kết nối (1 phút)

**Thao tác:** mở Amazon Quick console → connector MCP → màn hình Tools.

> **Nói:**
> "Trong Quick, tôi đã tạo connector trỏ tới `https://mcp.example.com/mcp`
> qua VPC connection. Quick tự phát hiện các tool — đây là 11 công cụ điều tra
> Jaeger: tìm trace, phân tích lỗi, điều tra sự cố..."

**Thao tác:** lướt qua danh sách tool (get-services, find-error-traces,
investigate-user-issue...). Chỉ ra Read vs Write.

---

## PHẦN 5 — Use case chính: Điều tra sự cố (2 phút) ⭐ cao trào

**Bối cảnh kể:**
> "Giả sử khách hàng phàn nàn: *tôi bị lỗi 500 khi thanh toán*. Bình thường kỹ
> sư phải lục log nhiều dịch vụ. Giờ tôi chỉ cần hỏi Quick."

**Thao tác:** trong Quick chat, gõ:
```
I got a 500 error at checkout. What's the root cause?
```
(hoặc tiếng Việt: *Tôi bị lỗi 500 khi thanh toán, nguyên nhân là gì?*)

> **Trong lúc Quick chạy, nói:**
> "Quick đang gọi tool `investigate-user-issue` qua kết nối private, tool đó query
> Jaeger trong VPC, tìm các trace lỗi."

**Kết quả mong đợi:** Quick chỉ ra chuỗi lỗi:
```
checkout-service (500)
   └─ payment-service: "payment failed: bank timeout"
        └─ bank-api: "upstream bank gateway timeout after 3000ms"  ← ROOT CAUSE
   inventory-service: 200 OK
```

> **Chốt:**
> "Quick tìm ra nguyên nhân gốc: dịch vụ thanh toán timeout khi gọi API ngân
> hàng. Từ câu hỏi tới root cause trong vài giây — và dữ liệu trace **chưa từng
> rời VPC**."

**(Tuỳ chọn) đào sâu:** hỏi tiếp:
```
Analyze that failing trace in detail.
```
→ Quick gọi `analyze-trace` → hiện span chậm nhất (bank-api 3000ms) + error spans.

---

## PHẦN 6 — Kết (30 giây)

**Thao tác:** quay lại slide *Summary*.

> **Nói:**
> "Tóm lại: AI hữu ích hơn vì dùng được dữ liệu thật; dữ liệu an toàn hơn vì
> không bao giờ ra Internet; vận hành đơn giản vì dùng hạ tầng mạng tiêu chuẩn.
> **AI gặp dữ liệu, một cách an toàn.**"

---

## CÂU HỎI THƯỜNG GẶP (chuẩn bị sẵn để trả lời)

**Q: Không có auth thì có an toàn không?**
> An toàn nhờ cô lập mạng: server không có IP public, hostname chỉ phân giải
> trong VPC, security group khóa chặt. Có thể bật thêm OAuth khi cần lớp nữa.

**Q: Sao không trỏ Quick thẳng vào EC2?**
> Vì TLS (ACM cert chỉ gắn được ALB), tên ổn định, health check, và cách ly.

**Q: Resolver inbound để làm gì?**
> Quick không dùng VPC resolver mặc định, nên cần một IP DNS thật để hỏi và phân
> giải hostname private.

**Q: Dữ liệu này là thật chứ?**
> Đây là trace mô phỏng cho demo. Trong thực tế là trace thật từ hệ thống production.

---

## PHƯƠNG ÁN DỰ PHÒNG (nếu có sự cố live)

- **Quick trả lời rỗng / không tìm thấy lỗi:**
  → trace có thể đã hết (Jaeger in-memory). SSH chạy lại `python3 seed_traces.py`,
    dùng lookback rộng. Hoặc demo bằng terminal (Phần 3) thay vì Quick.

- **Mạng/SSH lỗi:**
  → có sẵn ảnh chụp màn hình kết quả mỗi bước để trình chiếu thay thế.

- **Connector Quick chưa thấy đủ tool:**
  → recreate connector, hoặc demo trực tiếp bằng `curl` qua bastion (Phần 3).

- **Hết giờ:**
  → bỏ Phần 4, đi thẳng từ Phần 3 (chứng minh private) sang Phần 5 (use case).

---

## LỆNH SEED LẠI TRACE (copy nhanh)
```bash
ssh -J ec2-user@<bastion-ip> ec2-user@<mcp-private-ip> \
  'cd /home/ec2-user/mcp-server && python3 seed_traces.py'
```
