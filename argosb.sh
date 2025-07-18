#!/bin/sh

# متغیرهای ضروری
export uuid=${uuid:-''}
export port_an=${anpt:-''}

# تولید UUID (اگر وجود نداشته باشد)
insuuid(){
    if [ -z "$uuid" ]; then
        if [ -e "$HOME/agsb/sing-box" ]; then
            uuid=$("$HOME/agsb/sing-box" generate uuid)
        else
            uuid=$("$HOME/agsb/xray" uuid)
        fi
    fi
    echo "$uuid" > "$HOME/agsb/uuid"
    echo "UUID密码：$uuid"
}

# نصب Sing-box (ضروری برای AnyTLS)
installsb(){
    echo "=========启用Sing-box内核========="
    if [ ! -e "$HOME/agsb/sing-box" ]; then
        curl -Lo "$HOME/agsb/sing-box" -# --retry 2 https://github.com/yonggekkk/ArgoSB/releases/download/argosbx/sing-box-$cpu
        chmod +x "$HOME/agsb/sing-box"
        sbcore=$("$HOME/agsb/sing-box" version 2>/dev/null | awk '/version/{print $NF}')
        echo "已安装Sing-box正式版内核：$sbcore"
    fi
    
    # شروع فایل پیکربندی
    cat > "$HOME/agsb/sb.json" <<EOF
{
"log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
EOF
    
    # تولید UUID
    insuuid
    
    # تولید گواهی SSL (ضروری برای AnyTLS)
    command -v openssl >/dev/null 2>&1 && openssl ecparam -genkey -name prime256v1 -out "$HOME/agsb/private.key" >/dev/null 2>&1
    command -v openssl >/dev/null 2>&1 && openssl req -new -x509 -days 36500 -key "$HOME/agsb/private.key" -out "$HOME/agsb/cert.pem" -subj "/CN=www.bing.com" >/dev/null 2>&1
    
    # دانلود گواهی از منبع خارجی (اگر openssl در دسترس نباشد)
    if [ ! -f "$HOME/agsb/private.key" ]; then
        curl -Lso "$HOME/agsb/private.key" https://github.com/yonggekkk/ArgoSB/releases/download/argosbx/private.key
        curl -Lso "$HOME/agsb/cert.pem" https://github.com/yonggekkk/ArgoSB/releases/download/argosbx/cert.pem
    fi
    
    # تنظیم AnyTLS inbound (اگر فعال باشد)
    if [ -n "$anp" ]; then
        anp=anpt
        if [ -z "$port_an" ]; then
            port_an=443
        fi
        echo "$port_an" > "$HOME/agsb/port_an"
        echo "Anytls端口：$port_an"
        
        cat >> "$HOME/agsb/sb.json" <<EOF
        {
            "type":"anytls",
            "tag":"anytls-sb",
            "listen":"::",
            "listen_port":${port_an},
            "users":[
                {
                  "password":"${uuid}"
                }
            ],
            "padding_scheme":[],
            "tls":{
                "enabled": true,
                "certificate_path": "$HOME/agsb/cert.pem",
                "key_path": "$HOME/agsb/private.key"
            }
        },
EOF
    fi
}

# تکمیل پیکربندی و شروع سرویس
complete_config(){
    # حذف کاما آخر و اضافه کردن outbound
    sed -i '${s/,\s*$//}' "$HOME/agsb/sb.json"
    cat >> "$HOME/agsb/sb.json" <<EOF
],
"outbounds": [
{
"type":"direct",
"tag":"direct"
}
]
}
EOF
    
    # شروع sing-box
    nohup "$HOME/agsb/sing-box" run -c "$HOME/agsb/sb.json" >/dev/null 2>&1 &
}

# تشخیص CPU architecture
case $(uname -m) in
    aarch64) cpu=arm64;;
    x86_64) cpu=amd64;;
    *) echo "目前脚本不支持$(uname -m)架构" && exit
esac

# ایجاد دایرکتوری
mkdir -p "$HOME/agsb"

# تنظیم متغیر anp برای فعال‌سازی AnyTLS
[ -z "${anpt+x}" ] || anp=yes

# بررسی وجود متغیر AnyTLS
if [ "$anp" = yes ]; then
    installsb
    complete_config
    echo "AnyTLS inbound راه‌اندازی شد"
else
    echo "متغیر anpt تنظیم نشده - AnyTLS فعال نمی‌شود"
fi
