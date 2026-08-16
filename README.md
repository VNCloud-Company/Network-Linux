# Network Linux Script

Script tự động cấu hình lại địa chỉ **IP (`IPADDR`)** và **Gateway (`GATEWAY`)** cho VPS / Server Linux (CentOS).

---

## 🚀 Hướng Dẫn Sử Dụng Nhanh (One-liner)

Bạn có thể chạy script trực tiếp từ GitHub qua lệnh `curl` mà không cần tải file về máy.

### 📌 Cú Pháp:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/VNCloud-Company/Network-Linux/refs/heads/main/script.sh) <IP_ADDRESS> <GATEWAY>
```

### 💡 Ví Dụ Thực Tế:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/VNCloud-Company/Network-Linux/refs/heads/main/script.sh) 103.74.103.48 103.74.103.1
```

---

## 💻 Chạy Trực Tiếp Tại Local

Nếu bạn đã tải repository về máy hoặc máy chủ:

```bash
chmod +x script.sh
./script.sh 103.74.103.48 103.74.103.1
```

---

## ✨ Tính Năng Nổi Bật

- 🔍 **Tự động nhận diện Network Interface**: Tự động tìm card mạng chính (`default route`) đang sử dụng.
- 💾 **Sao lưu an toàn**: Tự động tạo bản sao lưu (`.bak`) cho file cấu hình trước khi chỉnh sửa.
- ⚙️ **Cập nhật thông minh**: Kiểm tra và thay thế hoặc thêm mới dòng `IPADDR` và `GATEWAY`.
- 🔄 **Khởi động lại Network**: Tự động chạy `systemctl restart network` để áp dụng cấu hình ngay lập tức.
- 🐧 **Hỗ trợ Hệ điều hành**: Đã hỗ trợ hệ điều hành CentOS (Debian, Ubuntu, AlmaLinux đang tiếp tục cập nhật).
