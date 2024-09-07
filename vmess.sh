请查看视频教程（Cloudflare的CDN设置域名回源进行加速） 视频教程https://youtu.be/6UZXHfc3zEU

#!/bin/bash

USERNAME=$(whoami)
HOSTNAME=$(hostname)
export UUID=${UUID:-'d36c4d9f-31c4-45f1-8c64-102a6142001e'}
export ARGO_DOMAIN=${ARGO_DOMAIN:-'自填'}   
export ARGO_AUTH=${ARGO_AUTH:-'自填'} 
export VMESS_PORT=自填

[[ "$HOSTNAME" == "s10.serv00.com" ]] && WORKDIR="/home/${USERNAME}/.vmess" || WORKDIR="/home/${USERNAME}/.vmess"
[ -d "$WORKDIR" ] || (mkdir -p "$WORKDIR" && chmod 777 "$WORKDIR")

install_singbox() {
    echo "开始安装sing-box..."
    cd $WORKDIR
    generate_config
    download_singbox && wait
    run_sb && sleep 3
    get_links
}

uninstall_singbox() {
    read -p "确定要卸载吗？【y/n】: " choice
    case "$choice" in
       [Yy])
          pkill -f 'web'
          pkill -f 'bot'
          rm -rf $WORKDIR
          ;;
        [Nn]) exit 0 ;;
        *) echo "无效的选择，请输入y或n" && menu ;;
    esac
}

kill_all_tasks() {
    read -p "清理所有进程将退出ssh连接，确定继续清理吗？【y/n】: " choice
    case "$choice" in
        [Yy]) killall -9 -u $(whoami) ;;
        *) menu ;;
    esac
}

# Download Dependency Files
download_singbox() {
    ARCH=$(uname -m) && DOWNLOAD_DIR="." && mkdir -p "$DOWNLOAD_DIR" && FILE_INFO=()
    if [ "$ARCH" == "arm" ] || [ "$ARCH" == "arm64" ] || [ "$ARCH" == "aarch64" ]; then
        FILE_INFO=("https://github.com/ansoncloud8/am-serv00-vmess/releases/download/1.0.0/arm64-sb web" "https://github.com/ansoncloud8/am-serv00-vmess/releases/download/1.0.0/arm64-bot13 bot")
    elif [ "$ARCH" == "amd64" ] || [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "x86" ]; then
        FILE_INFO=("https://github.com/ansoncloud8/am-serv00-vmess/releases/download/1.0.0/amd64-web web" "https://github.com/ansoncloud8/am-serv00-vmess/releases/download/1.0.0/amd64-bot bot")
    else
        echo "Unsupported architecture: $ARCH"
        exit 1
    fi
    for entry in "${FILE_INFO[@]}"; do
        URL=$(echo "$entry" | cut -d ' ' -f 1)
        NEW_FILENAME=$(echo "$entry" | cut -d ' ' -f 2)
        FILENAME="$DOWNLOAD_DIR/$NEW_FILENAME"
        if [ -e "$FILENAME" ]; then
            echo "$FILENAME 已存在，跳过下载"
        else
            wget -q -O "$FILENAME" "$URL"
            echo "下载 $FILENAME"
        fi
        chmod +x $FILENAME
    done
}

# Generating Configuration Files
generate_config() {
    cat > config.json << EOF
{
  "log": {
    "disabled": true,
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "google",
        "address": "tls://8.8.8.8",
        "strategy": "ipv4_only",
        "detour": "direct"
      }
    ],
    "rules": [
      {
        "rule_set": [
          "geosite-openai"
        ],
        "server": "wireguard"
      },
      {
        "rule_set": [
          "geosite-netflix"
        ],
        "server": "wireguard"
      },
      {
        "rule_set": [
          "geosite-category-ads-all"
        ],
        "server": "block"
      }
    ],
    "final": "google",
    "strategy": "",
    "disable_cache": false,
    "disable_expire": false
  },
  "inbounds": [
    {
      "tag": "vmess-ws-in",
      "type": "vmess",
      "listen": "::",
      "listen_port": $VMESS_PORT,
      "users": [
        {
          "uuid": "$UUID"
        }
      ],
      "transport": {
        "type": "ws",
        "path": "/vmess",
        "early_data_header_name": "Sec-WebSocket-Protocol"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    },
    {
      "type": "dns",
      "tag": "dns-out"
    },
    {
      "type": "wireguard",
      "tag": "wireguard-out",
      "server": "162.159.195.142",
      "server_port": 4198,
      "local_address": [
        "172.16.0.2/32",
        "2606:4700:110:83c7:b31f:5858:b3a8:c6b1/128"
      ],
      "private_key": "mPZo+V9qlrMGCZ7+E6z2NI6NOV34PD++TpAR09PtCWI=",
      "peer_public_key": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
      "reserved": [
        26,
        21,
        228
      ]
    }
  ],
  "route": {
    "rules": [
      {
        "protocol": "dns",
        "outbound": "dns-out"
      },
      {
        "ip_is_private": true,
        "outbound": "direct"
      },
      {
        "rule_set": [
          "geosite-openai"
        ],
        "outbound": "wireguard-out"
      },
      {
        "rule_set": [
          "geosite-netflix"
        ],
        "outbound": "wireguard-out"
      },
      {
        "rule_set": [
          "geosite-category-ads-all"
        ],
        "outbound": "block"
      }
    ],
    "rule_set": [
      {
        "tag": "geosite-netflix",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-netflix.srs",
        "download_detour": "direct"
      },
      {
        "tag": "geosite-openai",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo/geosite/openai.srs",
        "download_detour": "direct"
      },      
      {
        "tag": "geosite-category-ads-all",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ads-all.srs",
        "download_detour": "direct"
      }
    ],
    "final": "direct"
  },
  "experimental": {
    "cache_file": {
      "path": "cache.db",
      "cache_id": "mycacheid",
      "store_fakeip": true
    }
  }
}
EOF
}

# running files
run_sb() {
    nohup ./web run -c config.json >/dev/null 2>&1 &
    sleep 2
    pgrep -x "web" > /dev/null && echo "web is running" || { echo "web is not running, restarting..."; pkill -x "web" && nohup ./web run -c config.json >/dev/null 2>&1 & sleep 2; echo "web restarted"; }

    if [[ $ARGO_AUTH =~ ^[A-Z0-9a-z=]{120,250}$ ]]; then
        args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 run --token ${ARGO_AUTH}"
    elif [[ $ARGO_AUTH =~ TunnelSecret ]]; then
        args="tunnel --edge-ip-version auto --config tunnel.yml run"
    else
        args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 --logfile boot.log --loglevel info --url http://localhost:$VMESS_PORT"
    fi
    nohup ./bot $args >/dev/null 2>&1 &
    sleep 2
    pgrep -x "bot" > /dev/null && echo "bot is running" || { echo "bot is not running, restarting..."; pkill -x "bot" && nohup ./bot "${args}" >/dev/null 2>&1 & sleep 2; echo "bot restarted"; }
}

get_links() {
    get_argodomain() {
        if [[ -n $ARGO_AUTH ]]; then
            echo "$ARGO_DOMAIN"
        else
            grep -oE 'https://[[:alnum:]+\.-]+\.trycloudflare\.com' boot.log | sed 's@https://@@'
        fi
    }
    argodomain=$(get_argodomain)
    echo -e "\e[1;32mArgoDomain:\e[1;35m${argodomain}\e[0m\n"
    sleep 1
    IP=$(curl -s ipv4.ip.sb || { ipv6=$(curl -s --max-time 1 ipv6.ip.sb); echo "[$ipv6]"; })
    sleep 1
    cat > list.txt <<EOF
vmess://$(echo "{ \"v\": \"2\", \"ps\": \"\", \"add\": \"$IP\", \"port\": \"$VMESS_PORT\", \"id\": \"$UUID\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"\", \"path\": \"/vmess?ed=2048\", \"tls\": \"\", \"sni\": \"\", \"alpn\": \"\", \"fp\": \"\"}" | base64 -w0)

vmess://$(echo "{ \"v\": \"2\", \"ps\": \"\", \"add\": \"www.visa.com\", \"port\": \"443\", \"id\": \"$UUID\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/vmess?ed=2048\", \"tls\": \"tls\", \"sni\": \"$argodomain\", \"alpn\": \"\", \"fp\": \"\"}" | base64 -w0)

EOF
    cat list.txt
    echo "list.txt 保存成功"
    echo "运行完成!"
    sleep 3
}

#主菜单
menu() {
   clear
   echo ""
   echo "1. 安装sing-box"
   echo  "==============="
   echo "2. 卸载sing-box"
   echo  "==============="
   echo "3. 查看节点信息"
   echo  "==============="
   echo "4. 清理所有进程"
   echo  "==============="
   echo "0. 退出脚本"
   echo "==========="
   read -p "请输入选择(0-4): " choice
   echo ""
    case "${choice}" in
        1) install_singbox ;;
        2) uninstall_singbox ;; 
        3) cat $WORKDIR/list.txt ;; 
        4) kill_all_tasks ;;
        0) exit 0 ;;
        *) echo "无效的选项，请输入 0 到 4" ;;
    esac
}
menu