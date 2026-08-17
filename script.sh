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
    parted /dev/sda resizepart $(blkid|grep /dev/sda|sort|tail -n 1|cut -c 9) 100%
    pvresize /dev/sda$(blkid|grep /dev/sda|sort|tail -n 1|cut -c 9)
    lvextend -l +100%FREE /dev/vg0/lv-0
    resize2fs /dev/vg0/lv-0
    clear
    echo -e " Upgrade Disk Success. VPS Restart After 3 Seconds"
    sleep 3
    reboot
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
    systemctl restart network
else
    echo -e "Hệ Điều Hành Không Hợp Lệ"
fi