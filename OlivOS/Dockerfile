FROM python:3.11-slim

# 设置中国时区
ENV TZ=Asia/Shanghai
RUN apt-get update && \
    apt-get install -y tzdata git wget && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone && \
    rm -rf /var/lib/apt/lists/*

# 初始化应用目录
WORKDIR /app/OlivOS
RUN git clone https://github.com/OlivOS-Team/OlivOS.git . && \
    # 删除自带的account.json
    rm -f conf/account.json && \
    # 安装依赖
    pip install --no-cache-dir -i https://pypi.tuna.tsinghua.edu.cn/simple \
        --trusted-host pypi.tuna.tsinghua.edu.cn \
        .

# 下载核心插件
RUN mkdir -p /app/OlivOS/plugin/app && \
    wget -q -P /app/OlivOS/plugin/app \
    https://github.com/OlivOS-Team/OlivaDiceCore/releases/latest/download/OlivaDiceCore.opk \
    https://github.com/OlivOS-Team/OlivaDiceJoy/releases/latest/download/OlivaDiceJoy.opk \
    https://github.com/OlivOS-Team/OlivaDiceLogger/releases/latest/download/OlivaDiceLogger.opk \
    https://github.com/OlivOS-Team/OlivaDiceMaster/releases/latest/download/OlivaDiceMaster.opk \
    https://github.com/OlivOS-Team/ChanceCustom/releases/latest/download/ChanceCustom.opk \
    https://github.com/OlivOS-Team/OlivaDiceOdyssey/releases/latest/download/OlivaDiceOdyssey.opk

# 下载 NapCat 和 LLBot 配置文件模板
RUN mkdir -p /app/napcat/config && \
    wget -q -O /app/napcat/config/napcat-config-example.json \
    https://raw.githubusercontent.com/DiceZone/OlivOS-Docker/refs/heads/main/NapCat/config-example.json && \
    wget -q -O /app/napcat/config/llbot-config-example.json \
    https://raw.githubusercontent.com/DiceZone/OlivOS-Docker/refs/heads/main/LLBot/config-example.json

# 创建备份目录
RUN cp -r /app /opt/backup-app

# 启动脚本
RUN echo '#!/bin/bash\n\
# 判断主程序文件修复\n\
if [ ! -f "/app/OlivOS/main.py" ]; then\n\
    echo "从备份文件修复主程序目录..."\n\
    cp -af /opt/backup-app/OlivOS/ /app/\n\
else\n\
    for file in main.py; do\n\
        if [ ! -f "/app/OlivOS/${file}" ]; then\n\
            cp -af /opt/backup-app/OlivOS/* /app/OlivOS/\n\
        fi\n\
    done\n\
fi\n\
\n\
# 插件文件修复\n\
PLUGIN_FILES=(\n\
    "OlivaDiceCore.opk"\n\
    "OlivaDiceJoy.opk"\n\
    "OlivaDiceLogger.opk"\n\
    "OlivaDiceMaster.opk"\n\
    "ChanceCustom.opk"\n\
    "OlivaDiceOdyssey.opk"\n\
)\n\
mkdir -p /app/OlivOS/plugin/app\n\
for plugin in "${PLUGIN_FILES[@]}"; do\n\
    if [ ! -f "/app/OlivOS/plugin/app/${plugin}" ]; then\n\
        echo "修复丢失的插件:${plugin}"\n\
        cp -f "/opt/backup-app/OlivOS/plugin/app/${plugin}" "/app/OlivOS/plugin/app/"\n\
    fi\n\
done\n\
\n\
# 账户配置生成\n\
CONF_DIR="/app/OlivOS/conf"\n\
CONF_FILE="${CONF_DIR}/account.json"\n\
mkdir -p "${CONF_DIR}"\n\
\n\
if [ -f "${CONF_FILE}" ]; then\n\
    # 检查现有配置是否有效\n\
    if ! grep -q "sdk_type" "${CONF_FILE}"; then\n\
        echo "检测到无效配置，正在重新生成..."\n\
        rm -f "${CONF_FILE}"\n\
    fi\n\
fi\n\
\n\
if [ ! -f "${CONF_FILE}" ]; then\n\
    echo "生成全新账户配置......"\n\
    UIN="${LOGIN_UIN:-123456}"\n\
    \n\
    if [ "${MODE:-}" = "llbot" ]; then\n\
        SDK_HOST="http://llbot"\n\
        SDK_PORT=5700\n\
    else\n\
        SDK_HOST="http://napcat"\n\
        SDK_PORT=5700\n\
    fi\n\
    \n\
    cat <<EOF > "${CONF_FILE}"\n\
{\n\
    "account": [\n\
        {\n\
            "id": ${UIN},\n\
            "password": "",\n\
            "sdk_type": "onebot",\n\
            "platform_type": "qq",\n\
            "model_type": "default",\n\
            "server": {\n\
                "auto": false,\n\
                "type": "port",\n\
                "host": "${SDK_HOST}",\n\
                "port": ${SDK_PORT},\n\
                "access_token": "7777777"\n\
            },\n\
            "extends": {},\n\
            "debug": false\n\
        }\n\
    ]\n\
}\n\
EOF\n\
    \n\
    # 根据 MODE 生成对应的登录端配置文件\n\
    if [ "${MODE:-}" = "llbot" ]; then\n\
        # LLBot 模式：生成 config_${UIN}.json（HTTP Server + HTTP Client）\n\
        LLBOT_CONF="/app/napcat/config/config_${UIN}.json"\n\
        if [ ! -f "${LLBOT_CONF}" ]; then\n\
            mkdir -p /app/napcat/config\n\
            cp "/opt/backup-app/napcat/config/llbot-config-example.json" "${LLBOT_CONF}"\n\
            echo "已生成 LLBot 配置文件：${LLBOT_CONF}"\n\
        else\n\
            echo "检测到已有 LLBot 配置文件，保留用户修改：${LLBOT_CONF}"\n\
        fi\n\
    else\n\
        # NapCat 模式（默认）：生成 onebot11_${UIN}.json\n\
        NAPCAT_CONF="/app/napcat/config/onebot11_${UIN}.json"\n\
        if [ ! -f "${NAPCAT_CONF}" ]; then\n\
            mkdir -p /app/napcat/config\n\
            cp "/opt/backup-app/napcat/config/napcat-config-example.json" "${NAPCAT_CONF}"\n\
            echo "已生成 NapCat 配置文件：${NAPCAT_CONF}"\n\
        else\n\
            echo "检测到已有 NapCat 配置文件，保留用户修改：${NAPCAT_CONF}"\n\
        fi\n\
    fi\n\
fi\n\
\n\
# 自动安装所有 requirements*.txt\n\
REQUIREMENTS_FILES=$(find /app/OlivOS -maxdepth 5 -name "requirements*.txt" 2>/dev/null)\n\
if [ -n "${REQUIREMENTS_FILES}" ]; then\n\
    echo "检测到以下 requirements 文件，开始安装依赖..."\n\
    for req_file in ${REQUIREMENTS_FILES}; do\n\
        echo "  安装: ${req_file}"\n\
        pip install --no-cache-dir -i https://pypi.tuna.tsinghua.edu.cn/simple \\\n\
            --trusted-host pypi.tuna.tsinghua.edu.cn \\\n\
            -r "${req_file}" || echo "    警告：${req_file} 部分依赖安装失败"\n\
    done\n\
fi\n\
\n\
cd /app/OlivOS\n\
exec python3 main.py "$@"' > /usr/local/bin/olivos-entrypoint && \
    chmod +x /usr/local/bin/olivos-entrypoint

# 设置工作目录和入口点
WORKDIR /app/OlivOS
ENTRYPOINT ["olivos-entrypoint"]
