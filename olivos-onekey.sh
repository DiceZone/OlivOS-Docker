#!/bin/bash

# 检查并安装 openssl（如果不存在）- 仅适配 Ubuntu/Debian
if ! command -v openssl &> /dev/null; then
    echo "检测到系统未安装 openssl，正在安装..."
    sudo apt-get update && sudo apt-get install -y openssl

    if command -v openssl &> /dev/null; then
        echo "openssl 安装成功"
    else
        echo "错误：openssl 安装失败"
        echo "请确保系统是 Ubuntu 或 Debian，并且 apt 可用"
        exit 1
    fi
fi

# 处理命令行参数
IMAGE_TAG="latest"  # 默认使用 latest
CHANNEL=""          # 暂存渠道
LOGIN_METHOD="napcat"  # 登录方式: napcat/llbot，默认为 napcat
AUTO_CONFIRM=false     # 静默模式
PY_PACKAGES=""         # 额外 Python 包

# 允许的渠道值
ALLOWED_CHANNELS=("latest" "stable" "pre")

# 如果用户没有提供参数，显示交互式引导
if [ $# -eq 0 ]; then
    echo ""
    echo "   ██████╗ ██╗     ██╗██╗   ██╗ ██████╗ ███████╗"
    echo "  ██╔═══██╗██║     ██║██║   ██║██╔═══██╗██╔════╝"
    echo "  ██║   ██║██║     ██║██║   ██║██║   ██║███████╗"
    echo "  ██║   ██║██║     ██║╚██╗ ██╔╝██║   ██║╚════██║"
    echo "  ╚██████╔╝███████╗██║ ╚████╔╝ ╚██████╔╝███████║"
    echo "   ╚═════╝ ╚══════╝╚═╝  ╚═══╝   ╚═════╝ ╚══════╝"
    echo "=================================================================="
    echo "          OlivOS 一键部署脚本 by DiceZone 2026-04-29"
    echo "=================================================================="
    echo ""

    # 询问版本渠道
    echo "请选择版本渠道："
    echo "1) latest - 最新版本（默认，推荐）"
    echo "2) stable - 稳定版本"
    echo "3) pre - 预发布版本"

    while true; do
        read -p "请输入选择 (1-3，默认1): " choice
        choice=${choice:-1}

        case $choice in
            1) CHANNEL="latest" ; break ;;
            2) CHANNEL="stable" ; break ;;
            3) CHANNEL="pre" ; break ;;
            *) echo "错误：请输入 1-3 之间的数字" ;;
        esac
    done

    # 询问登录方式
    echo ""
    echo "请选择登录方式："
    echo "1) NapCat（默认，推荐）"
    echo "2) LLBot"

    while true; do
        read -p "请输入选择 (1-2，默认1): " login_choice
        login_choice=${login_choice:-1}

        case $login_choice in
            1) LOGIN_METHOD="napcat" ; break ;;
            2) LOGIN_METHOD="llbot" ; break ;;
            *) echo "错误：请输入 1-2 之间的数字" ;;
        esac
    done

    # 询问额外 Python 包
    echo ""
    echo "可选：指定额外安装的 Python 包（多个包名用空格分隔）"
    echo "例如：requests aiohttp beautifulsoup4"
    read -p "请输入（留空跳过）: " py_input
    PY_PACKAGES=${py_input:-}

    # 询问 QQ 号
    echo ""
    while true; do
        read -p "请输入骰娘 QQ 号（必须输入）: " ACCOUNT

        if [ -z "$ACCOUNT" ]; then
            echo "错误：QQ号不能为空"
        elif [[ ! $ACCOUNT =~ ^[0-9]+$ ]]; then
            echo "错误：QQ号必须是纯数字"
        else
            echo "已输入骰娘 QQ 号: $ACCOUNT"
            break
        fi
    done

    # 确认执行
    echo ""
    echo "即将部署 OlivOS，使用 $CHANNEL 版本渠道，登录方式: $LOGIN_METHOD，QQ 号: $ACCOUNT"
    if [ -n "$PY_PACKAGES" ]; then
        echo "额外 Python 包: $PY_PACKAGES"
    fi
    read -p "确认执行？(y/N): " confirm

    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo "已取消部署"
        exit 0
    fi

    echo ""
else
    # 参数处理逻辑
    while getopts ":c:m:a:p:y" opt; do
      case $opt in
        c)
          CHANNEL="$OPTARG"
          ;;
        m)
          LOGIN_METHOD="$OPTARG"
          ;;
        a)
          ACCOUNT="$OPTARG"
          ;;
        p)
          PY_PACKAGES="$OPTARG"
          ;;
        y)
          AUTO_CONFIRM=true
          ;;
        \?)
          echo "无效选项: -$OPTARG" >&2
          exit 1
          ;;
        :)
          echo "选项 -$OPTARG 需要参数." >&2
          exit 1
          ;;
      esac
    done

    # 验证渠道参数
    if [ -n "$CHANNEL" ]; then
      if ! [[ " ${ALLOWED_CHANNELS[@]} " =~ " $CHANNEL " ]]; then
        echo "错误：-c 参数的值必须是 latest、stable 或 pre"
        exit 1
      fi
    else
      CHANNEL="latest"
    fi

    # 验证登录方式参数
    if [ -n "$LOGIN_METHOD" ]; then
      if [[ "$LOGIN_METHOD" != "napcat" && "$LOGIN_METHOD" != "llbot" ]]; then
        echo "错误：-m 参数的值必须是 napcat 或 llbot"
        exit 1
      fi
    else
      LOGIN_METHOD="napcat"
    fi

    # 验证 QQ 号
    if [ -z "$ACCOUNT" ]; then
        echo "错误：必须指定骰娘 QQ 号（-a 参数）"
        echo "用法: bash <(curl -sL olivos.dice.zone) -a 123456"
        echo "       bash <(curl -sL olivos.dice.zone) -a 123456 -c stable -m llbot"
        exit 1
    fi

    if [[ ! $ACCOUNT =~ ^[0-9]+$ ]]; then
        echo "错误：QQ号必须是纯数字"
        exit 1
    fi
fi

# 设置镜像标签
if [ -n "$CHANNEL" ]; then
  IMAGE_TAG="$CHANNEL"
fi
echo "将使用镜像标签: shiaworkshop/olivos:$IMAGE_TAG"
sleep 1

# 检测 Docker 是否已安装
check_docker_installed() {
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# 配置目录和文件路径
OLIVOS_BASE_DIR="/opt/OlivOS-Docker"
COMPOSE_FILE="docker-compose.yml"
ENV_FILE=".env"

# 生成随机MAC地址
generate_mac() {
    random_bytes=$(openssl rand -hex 4)
    formatted_bytes=$(echo "$random_bytes" | sed -E 's/(..)(..)(..)(..)/\1:\2:\3:\4/')
    echo "02:42:$formatted_bytes"
}

# 检测并安装 Docker
if check_docker_installed; then
    echo "Docker 和 Docker Compose 已安装，跳过安装步骤"
    sleep 1
else
    echo "正在安装 Docker..."
    sleep 1

    max_retries=3
    retry_count=0
    install_success=false

    while [ $retry_count -lt $max_retries ]; do
        echo "尝试 #$((retry_count+1)) 安装 Docker..."

        # 使用自维护安装脚本镜像源解决国内网络问题
        curl --retry 3 --retry-delay 5 --connect-timeout 20 --max-time 60 \
             -fsSL https://dice.zone/bash/docker_install.sh -o get-docker.sh
        echo "已下载Docker安装脚本"
        sleep 1

        # 替换为腾讯云镜像源
        sed -i 's|https://download.docker.com|https://mirrors.tencent.com/docker-ce|g' get-docker.sh
        echo "已配置腾讯云镜像源"
        sleep 1

        sudo sh get-docker.sh
        echo "执行Docker安装脚本"
        sleep 1

        # 验证安装
        if command -v docker &> /dev/null && docker compose version &> /dev/null; then
            install_success=true
            break
        else
            echo "部分安装步骤失败，正在重试..."
            retry_count=$((retry_count+1))
            sleep 1
        fi
    done

    # 清理临时文件
    sudo rm -f get-docker.sh

    # 最终验证安装
    if ! $install_success; then
        echo ""
        echo "============================================================"
        echo "错误：Docker 安装失败！可能原因："
        echo "1. 网络连接不稳定或被限制"
        echo "2. 系统软件源配置问题"
        echo "3. 安装源被阻止"
        echo ""
        echo "建议解决方案："
        echo "1. 检查网络连接并重试"
        echo "2. 手动安装 Docker：https://docs.docker.com/engine/install/"
        echo "============================================================"
        exit 1
    else
        echo "Docker 安装成功！"
        sleep 1
    fi

    # 添加当前用户到docker组
    sudo usermod -aG docker $USER
    echo "已将当前用户添加到docker组"
    sleep 1
fi

# 使用毫秒镜像服务加速
echo "配置毫秒镜像服务加速..."
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json >/dev/null <<EOF
{
  "registry-mirrors": [
    "https://docker.1ms.run"
  ]
}
EOF
echo "已配置镜像加速"
sleep 1

sudo systemctl restart docker
sudo systemctl enable docker
echo "已重启并启用Docker服务"
sleep 1

# 验证 Docker 服务状态
if ! sudo systemctl is-active --quiet docker; then
    echo "警告：Docker 服务未运行，正在尝试启动..."
    sudo systemctl start docker
    sleep 1
    if ! sudo systemctl is-active --quiet docker; then
        echo "错误：无法启动 Docker 服务"
        exit 1
    else
        echo "Docker服务已成功启动"
        sleep 1
    fi
else
    echo "Docker服务运行正常"
    sleep 1
fi

# 创建 OlivOS-Docker 基础目录
echo "设置 OlivOS-Docker 环境..."
sudo mkdir -p -m 755 "$OLIVOS_BASE_DIR"
sudo mkdir -p -m 755 "$OLIVOS_BASE_DIR/OlivOS"
echo "已创建 OlivOS 数据目录: $OLIVOS_BASE_DIR"
sleep 1

# 生成MAC地址
MAC_ADDRESS=$(generate_mac)
echo "生成 MAC 地址: $MAC_ADDRESS"

# 进入基础目录
cd "$OLIVOS_BASE_DIR"

# 创建 .env 文件
echo "创建 .env 配置文件..."
sudo tee "$ENV_FILE" > /dev/null <<EOF
ACCOUNT=$ACCOUNT
PY_PACKAGES=$PY_PACKAGES
EOF
echo ".env 文件已创建"
sleep 1

# 创建存放 NapCat/LLBot 配置的子目录
if [ "$LOGIN_METHOD" == "napcat" ]; then
    sudo mkdir -p "napcat/config" "napcat/QQ_DATA"
    echo "NapCat 配置目录已创建"
else
    sudo mkdir -p "llbot/config" "llbot/QQ_DATA"
    echo "LLBot 配置目录已创建"

    # 生成 LLBot 配置文件（HTTP Server + HTTP Client 模式对接 OlivOS）
    sudo tee "llbot/config/config_${ACCOUNT}.json" > /dev/null <<LLBOTCONF_EOF
{
  "webui": {
    "enable": true,
    "port": 3080
  },
  "milky": {
    "enable": false,
    "reportSelfMessage": false,
    "http": {
      "port": 3010,
      "prefix": "",
      "accessToken": ""
    },
    "webhook": {
      "urls": [],
      "accessToken": ""
    }
  },
  "satori": {
    "enable": false,
    "port": 5600,
    "token": ""
  },
  "ob11": {
    "enable": true,
    "connect": [
      {
        "type": "ws",
        "enable": false,
        "port": 3001,
        "heartInterval": 60000,
        "token": "",
        "reportSelfMessage": false,
        "reportOfflineMessage": false,
        "messageFormat": "array",
        "debug": false
      },
      {
        "type": "ws-reverse",
        "enable": false,
        "url": "",
        "heartInterval": 60000,
        "token": "",
        "reportSelfMessage": false,
        "reportOfflineMessage": false,
        "messageFormat": "array",
        "debug": false
      },
      {
        "type": "http",
        "enable": true,
        "port": 3000,
        "token": "7777777",
        "reportSelfMessage": false,
        "reportOfflineMessage": false,
        "messageFormat": "array",
        "debug": false
      },
      {
        "type": "http-post",
        "enable": true,
        "url": "http://olivos-app:55001/OlivOSMsgApi/qq/onebot/default",
        "enableHeart": false,
        "heartInterval": 60000,
        "token": "7777777",
        "reportSelfMessage": false,
        "reportOfflineMessage": false,
        "messageFormat": "array",
        "debug": false
      }
    ]
  },
  "log": true,
  "autoDeleteFile": false,
  "autoDeleteFileSecond": 60,
  "musicSignUrl": "",
  "msgCacheExpire": 120,
  "onlyLocalhost": false,
  "ffmpeg": "/tmp/ffmpeg"
}
LLBOTCONF_EOF
    echo "LLBot 配置文件已生成"
fi

# 根据登录方式生成 docker-compose.yml
echo "生成 docker-compose.yml..."
if [ "$LOGIN_METHOD" == "llbot" ]; then
    sudo tee "$COMPOSE_FILE" > /dev/null <<COMPOSE_EOF
services:
  olivos-app:
    image: shiaworkshop/olivos:$IMAGE_TAG
    container_name: olivos-main-\${ACCOUNT}
    stdin_open: true
    tty: true
    working_dir: /app
    volumes:
      - "./OlivOS:/app/OlivOS"
      - "./llbot/config:/app/napcat/config"
    environment:
      - LOGIN_UIN=\${ACCOUNT}
      - PY_PACKAGES=\${PY_PACKAGES:-}
    networks:
      - olivos
    depends_on:
      - llbot

  pmhq:
    image: linyuchen/pmhq:latest
    privileged: true
    container_name: pmhq-\${ACCOUNT}
    hostname: OlivOS-PMHQ-\${ACCOUNT}
    environment:
      - ENABLE_HEADLESS=false
      - AUTO_LOGIN_QQ=\${ACCOUNT}
    networks:
      - olivos
    volumes:
      - "./llbot/QQ_DATA:/root/.config/QQ"
      - "./OlivOS:/app/OlivOS"

  llbot:
    image: linyuchen/llbot:latest
    ports:
      - "\${WEBUI_PORT:-6099}:3080"
    container_name: llbot-\${ACCOUNT}
    hostname: OlivOS-LLBot-\${ACCOUNT}
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
      - PMHQ_HOST=pmhq
      - WEBUI_PORT=3080
    networks:
      - olivos
    volumes:
      - "./llbot/QQ_DATA:/root/.config/QQ"
      - "./llbot/config:/app/llbot/data:rw"
    depends_on:
      - pmhq

networks:
  olivos:
    driver: bridge
COMPOSE_EOF
else
    sudo tee "$COMPOSE_FILE" > /dev/null <<COMPOSE_EOF
services:
  olivos-app:
    image: shiaworkshop/olivos:$IMAGE_TAG
    container_name: olivos-main-\${ACCOUNT}
    stdin_open: true
    tty: true
    working_dir: /app
    volumes:
      - "./OlivOS:/app/OlivOS"
      - "./napcat/config:/app/napcat/config"
    environment:
      - LOGIN_UIN=\${ACCOUNT}
      - PY_PACKAGES=\${PY_PACKAGES:-}
    networks:
      - olivos
    depends_on:
      - napcat

  napcat:
    image: mlikiowa/napcat-docker:latest
    container_name: napcat-\${ACCOUNT}
    ports:
      - "\${WEBUI_PORT:-6099}:6099"
    volumes:
      - "./napcat/config:/app/napcat/config"
      - "./napcat/QQ_DATA:/app/.config/QQ"
      - "./OlivOS:/app/OlivOS"
    environment:
      - ACCOUNT=\${ACCOUNT}
    networks:
      - olivos
    mac_address: "${MAC_ADDRESS}"

networks:
  olivos:
    driver: bridge
COMPOSE_EOF
fi
echo "docker-compose.yml 已生成"
sleep 1

# 设置目录权限
sudo chmod -R 755 "$OLIVOS_BASE_DIR"
if [ "$LOGIN_METHOD" == "napcat" ]; then
    sudo chmod -R 777 "$OLIVOS_BASE_DIR/napcat/config"
else
    sudo chmod -R 777 "$OLIVOS_BASE_DIR/llbot/config"
fi

# 启动服务
echo "正在启动 OlivOS 服务..."
sleep 1
export $(grep -v '^#' "$ENV_FILE" | xargs)
sudo docker compose -p "olivos-${ACCOUNT}" up -d

# 检测内网IP
get_internal_ip() {
    internal_ip=$(ip route get 1 | grep -Eo 'src ([0-9\.]{7,15})' | awk '{print $2}' 2>/dev/null)
    if [ -z "$internal_ip" ]; then
        internal_ip=$(hostname -I | awk '{print $1}' 2>/dev/null)
    fi
    if [ -z "$internal_ip" ]; then
        internal_ip=$(ip addr show | grep -E 'inet (192\.168|10\.|172\.16)' | head -1 | awk '{print $2}' | cut -d'/' -f1)
    fi
    echo "$internal_ip"
}

# 检测公网IP
get_external_ip() {
    if ! external_ip=$(curl -s --connect-timeout 3 https://ipinfo.io/ip 2>/dev/null); then
        external_ip=$(curl -s --connect-timeout 3 https://ifconfig.me 2>/dev/null)
    fi
    if ! echo "$external_ip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
        external_ip="无法自动获取公网IP"
    fi
    echo "$external_ip"
}

# 获取IP地址
echo "获取网络配置信息..."
sleep 1
INTERNAL_IP=$(get_internal_ip)
EXTERNAL_IP=$(get_external_ip)

# 输出信息
echo ""
echo "============================================================"
echo "安装完成！以下是重要信息："
echo ""
echo "OlivOS 数据目录: $OLIVOS_BASE_DIR"
echo "使用的镜像标签: $IMAGE_TAG"
echo "登录方式: $LOGIN_METHOD"
echo "骰娘 QQ 号: $ACCOUNT"
echo ""

if [ -n "$PY_PACKAGES" ]; then
    echo "额外 Python 包已配置: $PY_PACKAGES"
    echo ""
fi

if [ "$LOGIN_METHOD" == "napcat" ]; then
    echo "NapCat WebUI（扫码登录用）:"
    echo "  内网: http://${INTERNAL_IP}:${WEBUI_PORT:-6099}"
    echo "  公网: http://${EXTERNAL_IP}:${WEBUI_PORT:-6099}"
else
    echo "LLBot WebUI（扫码登录用）:"
    echo "  内网: http://${INTERNAL_IP}:${WEBUI_PORT:-6099}"
    echo "  公网: http://${EXTERNAL_IP}:${WEBUI_PORT:-6099}"
fi
echo ""
echo "管理命令:"
echo "  # 查看 OlivOS 日志"
echo "  sudo docker compose -p olivos-${ACCOUNT} logs -f olivos-app"
echo ""
echo "  # 查看 NapCat/LLBot 日志（获取二维码）"
echo "  sudo docker compose -p olivos-${ACCOUNT} logs ${LOGIN_METHOD}"
echo ""
echo "  # 重启服务"
echo "  sudo docker compose -p olivos-${ACCOUNT} restart"
echo ""
echo "  # 停止服务"
echo "  sudo docker compose -p olivos-${ACCOUNT} down"
echo ""
echo "  # 更新服务"
echo "  sudo docker compose -p olivos-${ACCOUNT} pull"
echo "  sudo docker compose -p olivos-${ACCOUNT} up -d --force-recreate"
echo ""
echo "如需自定义端口或额外 Python 包，编辑 ${OLIVOS_BASE_DIR}/.env 文件后重启即可"
echo ""
echo "============================================================"
echo "⚡要饭链接：https://afdian.com/a/dicezone"
echo "⭐项目地址：https://github.com/DiceZone/OlivOS-Docker"
echo "============================================================"
