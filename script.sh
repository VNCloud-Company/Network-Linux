#!/bin/bash

# Kiểm tra tham số truyền vào (IP và GATEWAY)
IP_ADDR="$1"
GATEWAY_ADDR="$2"

if [ -z "$IP_ADDR" ] || [ -z "$GATEWAY_ADDR" ]; then
    echo "Lỗi: Vui lòng truyền đủ 2 tham số IP và GATEWAY!"
    echo "Cú pháp: $0 <IP_ADDRESS> <GATEWAY>"
    echo "Ví dụ: $0 103.74.103.48 103.74.103.1"
    exit 1
fi

# Kiểm tra hệ điều hành
if cat /etc/os-release | grep PRETTY_NAME | grep "Debian" > /dev/null; then
    parted /dev/sda resizepart $(blkid|grep /dev/sda|sort|tail -n 1|cut -c 9) 100%
    pvresize /dev/sda$(blkid|grep /dev/sda|sort|tail -n 1|cut -c 9)
    lvextend -l +100%FREE /dev/vg0/lv-0
    xfs_growfs /dev/vg0/lv-0
    clear
    echo -e " Upgrade Disk Success. VPS Restart After 3 Seconds"
    sleep 3
    reboot
elif cat /etc/os-release | grep PRETTY_NAME | grep "Ubuntu" > /dev/null; then
    CFG=$(ls /etc/netplan/*.yaml /etc/netplan/*.yml 2>/dev/null | head -n 1)

    if [ -z "$CFG" ] || [ ! -f "$CFG" ]; then
        echo "Lỗi: Không tìm thấy file cấu hình netplan trong /etc/netplan/!"
        exit 1
    fi

    echo "File cấu hình Netplan: $CFG"

    # Tạo bản sao lưu dự phòng (backup)
    cp "$CFG" "${CFG}.bak_$(date +%Y%m%d_%H%M%S)"

    # Cập nhật IP và Gateway bằng Python3 để đảm bảo chính xác định dạng YAML
    if command -v python3 > /dev/null 2>&1; then
        python3 - "$CFG" "$IP_ADDR" "$GATEWAY_ADDR" << 'EOF'
import sys, re

cfg_file = sys.argv[1]
ip_arg = sys.argv[2]
gw_arg = sys.argv[3]

with open(cfg_file, 'r') as f:
    content = f.read()

# Xác định IP kèm Prefix (giữ prefix cũ hoặc mặc định /24)
if '/' in ip_arg:
    ip_with_prefix = ip_arg
else:
    m_prefix = re.search(r'addresses:.*?\n\s*-\s*\d+\.\d+\.\d+\.\d+(/\d+)', content, re.DOTALL)
    prefix = m_prefix.group(1) if m_prefix else '/24'
    ip_with_prefix = f"{ip_arg}{prefix}"

# 1. Thay thế IP ở phần ethernets/addresses (chỉ thay IP đầu tiên, không đụng đến nameservers)
def repl_ip(match):
    indent = match.group(1)
    return f"{indent}- {ip_with_prefix}"

content_new, count = re.subn(
    r'(addresses:\s*\n\s*)-\s*\d+\.\d+\.\d+\.\d+(?:/\d+)?',
    repl_ip,
    content,
    count=1
)

if count == 0:
    content_new, count = re.subn(
        r'(addresses:\s*\[)\s*\d+\.\d+\.\d+\.\d+(?:/\d+)?',
        rf'\g<1>{ip_with_prefix}',
        content,
        count=1
    )

# 2. Thay thế Gateway
if 'gateway4:' in content_new:
    content_new = re.sub(r'gateway4:\s*\d+\.\d+\.\d+\.\d+', f'gateway4: {gw_arg}', content_new)
elif 'via:' in content_new:
    content_new = re.sub(r'via:\s*\d+\.\d+\.\d+\.\d+', f'via: {gw_arg}', content_new)

with open(cfg_file, 'w') as f:
    f.write(content_new)

print(f"[OK] Đã cập nhật IP thành {ip_with_prefix}")
print(f"[OK] Đã cập nhật Gateway thành {gw_arg}")
EOF
    else
        # Dự phòng bằng sed nếu máy chưa cài python3
        if [[ "$IP_ADDR" != *"/"* ]]; then
            PREFIX=$(grep -E -o '/[0-9]+' "$CFG" | head -n 1)
            [ -z "$PREFIX" ] && PREFIX="/24"
            IP_WITH_PREFIX="${IP_ADDR}${PREFIX}"
        else
            IP_WITH_PREFIX="$IP_ADDR"
        fi

        sed -i -E "s|gateway4:[[:space:]]*.*|gateway4: $GATEWAY_ADDR|" "$CFG"
        sed -i -E "s|via:[[:space:]]*.*|via: $GATEWAY_ADDR|" "$CFG"
        sed -i -E "s|-[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?|- $IP_WITH_PREFIX|g" "$CFG"
    fi

    echo -e "\n--- CẤU HÌNH MỚI TRONG FILE $CFG ---"
    cat "$CFG"
    netplan apply
elif cat /etc/os-release | grep PRETTY_NAME | grep "CentOS" > /dev/null; then
    # Tự động tìm Network Interface card chính (default route)
    IF=$(ip route | awk '/default/{print $5;exit}')

    if [ -z "$IF" ]; then
        echo "Lỗi: Không tìm thấy Network Interface mặc định!"
        exit 1
    fi

    CFG="/etc/sysconfig/network-scripts/ifcfg-$IF"

    echo "Network Interface: $IF"
    echo "File cấu hình: $CFG"

    # Kiểm tra sự tồn tại của file cấu hình
    if [ ! -f "$CFG" ]; then
        echo "Lỗi: File cấu hình $CFG không tồn tại!"
        exit 1
    fi

    # Tạo bản sao lưu dự phòng (backup)
    cp "$CFG" "${CFG}.bak_$(date +%Y%m%d_%H%M%S)"

    # Kiểm tra và thay thế IPADDR
    if grep -q "^IPADDR=" "$CFG"; then
        sed -i "s|^IPADDR=.*|IPADDR=$IP_ADDR|" "$CFG"
        echo "[OK] Đã cập nhật IPADDR thành $IP_ADDR"
    else
        echo "IPADDR=$IP_ADDR" >> "$CFG"
        echo "[OK] Đã thêm IPADDR=$IP_ADDR vào file"
    fi

    # Kiểm tra và thay thế GATEWAY
    if grep -q "^GATEWAY=" "$CFG"; then
        sed -i "s|^GATEWAY=.*|GATEWAY=$GATEWAY_ADDR|" "$CFG"
        echo "[OK] Đã cập nhật GATEWAY thành $GATEWAY_ADDR"
    else
        echo "GATEWAY=$GATEWAY_ADDR" >> "$CFG"
        echo "[OK] Đã thêm GATEWAY=$GATEWAY_ADDR vào file"
    fi

    echo -e "\n--- CẤU HÌNH MỚI TRONG FILE $CFG ---"
    grep -E "^(IPADDR|GATEWAY|NETMASK|DEVICE|BOOTPROTO)=" "$CFG"
    systemctl restart network

elif cat /etc/os-release | grep PRETTY_NAME | grep "AlmaLinux" > /dev/null; then
    IF=$(ip route | awk '/default/{print $5;exit}')

    if [ -z "$IF" ]; then
        echo "Lỗi: Không tìm thấy Network Interface mặc định!"
        exit 1
    fi

    CFG="/etc/sysconfig/network-scripts/ifcfg-$IF"

    echo "Network Interface: $IF"
    echo "File cấu hình: $CFG"

    # Kiểm tra sự tồn tại của file cấu hình
    if [ ! -f "$CFG" ]; then
        echo "Lỗi: File cấu hình $CFG không tồn tại!"
        exit 1
    fi

    # Tạo bản sao lưu dự phòng (backup)
    cp "$CFG" "${CFG}.bak_$(date +%Y%m%d_%H%M%S)"

    # Kiểm tra và thay thế IPADDR
    if grep -q "^IPADDR=" "$CFG"; then
        sed -i "s|^IPADDR=.*|IPADDR=$IP_ADDR|" "$CFG"
        echo "[OK] Đã cập nhật IPADDR thành $IP_ADDR"
    else
        echo "IPADDR=$IP_ADDR" >> "$CFG"
        echo "[OK] Đã thêm IPADDR=$IP_ADDR vào file"
    fi

    # Kiểm tra và thay thế GATEWAY
    if grep -q "^GATEWAY=" "$CFG"; then
        sed -i "s|^GATEWAY=.*|GATEWAY=$GATEWAY_ADDR|" "$CFG"
        echo "[OK] Đã cập nhật GATEWAY thành $GATEWAY_ADDR"
    else
        echo "GATEWAY=$GATEWAY_ADDR" >> "$CFG"
        echo "[OK] Đã thêm GATEWAY=$GATEWAY_ADDR vào file"
    fi

    echo -e "\n--- CẤU HÌNH MỚI TRONG FILE $CFG ---"
    grep -E "^(IPADDR|GATEWAY|NETMASK|DEVICE|BOOTPROTO)=" "$CFG"
    nmcli connection reload && nmcli connection up "$IF"
else
    echo -e "Hệ Điều Hành Không Hợp Lệ"
fi