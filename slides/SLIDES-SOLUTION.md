---
title: Kết nối an toàn Amazon Quick với dữ liệu nội bộ qua Private MCP
author: toannd
level: solution
---

# Slide 1 — Tiêu đề

## Kết nối an toàn Amazon Quick với hệ thống nội bộ
### Private MCP Connection — đưa AI vào trong vành đai bảo mật của doanh nghiệp

*Giải pháp giúp trợ lý AI truy cập dữ liệu nhạy cảm mà dữ liệu không bao giờ rời mạng riêng.*

---

# Slide 2 — Bối cảnh

**Amazon Quick** là trợ lý AI doanh nghiệp: tìm kiếm dữ liệu, xây agent, tự động hoá quy trình.

Quick kết nối hệ thống ngoài qua **MCP connector**.

**Nhưng:** nhiều hệ thống quan trọng của doanh nghiệp nằm **bên trong mạng riêng** —
cơ sở dữ liệu, hệ thống giám sát, công cụ nội bộ.

> Câu hỏi đặt ra: Làm sao cho AI dùng được dữ liệu này mà **không phơi nó ra Internet**?

---

# Slide 3 — Vấn đề

**Cách thông thường:** mở một endpoint public để AI gọi vào.

Rủi ro:
- Dữ liệu nhạy cảm đi qua đường công cộng
- Tăng bề mặt tấn công (ai cũng có thể dò tới)
- Khó tuân thủ quy định bảo mật / dữ liệu

**Yêu cầu của doanh nghiệp:**
- Dữ liệu **không rời mạng nội bộ**
- AI vẫn truy cập được bình thường
- Bảo mật theo nguyên tắc "ít quyền nhất"

---

# Slide 4 — Giải pháp

## Private MCP Connection

Đặt MCP server **hoàn toàn bên trong mạng riêng (VPC)**.
Amazon Quick chạm tới qua một **kết nối riêng**, không qua Internet.

**Nguyên tắc cốt lõi:**
- **Chứng chỉ công khai** → bảo mật kết nối (mã hoá) vẫn đạt chuẩn
- **Tên miền riêng** → chỉ nhìn thấy được bên trong mạng nội bộ

→ Kết quả: AI dùng được dữ liệu, nhưng dữ liệu **không bao giờ ra ngoài**.

---

# Slide 5 — Cách hoạt động (mức cao)

```
Người dùng hỏi Quick
        │
        ▼
   Amazon Quick ──── kết nối riêng ────► Mạng nội bộ (VPC)
                                              │
                                     "Lễ tân an toàn" (ALB + TLS)
                                              │
                                       MCP Server (dữ liệu)
                                              │
                                       Hệ thống nội bộ (vd Jaeger)
```

Toàn bộ luồng đi **bên trong mạng riêng** — không có chặng nào ra Internet công cộng.

---

# Slide 6 — Use case minh hoạ: Điều tra sự cố

**Tình huống:** Khách hàng báo "Tôi bị lỗi 500 khi thanh toán".

**Trước đây:** kỹ sư phải tự dò log nhiều hệ thống → mất thời gian.

**Với giải pháp này:**
1. Hỏi Amazon Quick bằng ngôn ngữ tự nhiên
2. Quick gọi MCP server (an toàn, trong mạng riêng)
3. MCP truy vấn hệ thống giám sát, tìm nguyên nhân gốc
4. Quick trả lời: *"Lỗi do dịch vụ thanh toán timeout khi gọi ngân hàng"*

→ Từ câu hỏi tới root cause trong vài giây.

---

# Slide 7 — Giá trị mang lại

| Khía cạnh | Lợi ích |
|-----------|---------|
| **Bảo mật** | Dữ liệu không rời mạng nội bộ, không endpoint public |
| **Tuân thủ** | Đáp ứng yêu cầu về cô lập dữ liệu nhạy cảm |
| **Tốc độ** | Trả lời sự cố bằng ngôn ngữ tự nhiên, tức thì |
| **Đơn giản** | Dùng hạ tầng mạng tiêu chuẩn đội ngũ đã quen |
| **Chi phí** | Ít thành phần trung gian, không phí xử lý dữ liệu thừa |

---

# Slide 8 — Vì sao chọn cách này

So với phương án thay thế (qua dịch vụ gateway quản lý):

- **Ít thành phần hơn** → dễ vận hành, ít điểm hỏng
- **Không cổng public** → bảo mật mặc định tốt hơn
- **Đường kết nối chính thức** của Amazon Quick → được hỗ trợ, ổn định
- **Linh hoạt xác thực:** chạy không cần auth (dựa vào cô lập mạng) hoặc bật
  OAuth khi cần lớp bảo vệ bổ sung

---

# Slide 9 — Hai lớp bảo vệ

**Lớp 1 — Mạng (luôn có):**
- Chỉ thành phần trong mạng riêng mới chạm được MCP server
- Tên miền chỉ phân giải nội bộ, không IP public
- Phân quyền chặt: mỗi thành phần chỉ nói chuyện đúng đối tượng

**Lớp 2 — Danh tính (tuỳ chọn):**
- Bật OAuth service-to-service: Quick phải có "vé" hợp lệ mới gọi được
- Phù hợp khi nhiều nhóm dùng chung hạ tầng

---

# Slide 10 — Kết quả & Mở rộng

**Đã đạt được:**
- Amazon Quick gọi được MCP server private, end-to-end an toàn
- Trợ lý AI điều tra sự cố trên dữ liệu nội bộ
- Dữ liệu không rời vành đai bảo mật

**Có thể mở rộng:**
- Kết nối thêm nguồn dữ liệu nội bộ khác (DB, kho dữ liệu, công cụ riêng)
- Siết bảo mật hơn nữa (bỏ truy cập quản trị trực tiếp, dùng kênh riêng)
- Nhân rộng cho nhiều nhóm / nhiều use case

---

# Slide 11 — Tổng kết

> **Private MCP Connection** đưa sức mạnh của Amazon Quick vào *bên trong*
> vành đai bảo mật của doanh nghiệp.

- AI hữu ích hơn — dùng được dữ liệu thật
- Dữ liệu an toàn hơn — không bao giờ ra Internet
- Vận hành đơn giản — hạ tầng mạng tiêu chuẩn

**AI gặp dữ liệu, một cách an toàn.**
