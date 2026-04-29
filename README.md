# OlivOS-Docker

用于在linux上使用docker-compose快速组装OlivOS+Napcat（或LLBot）

支援amd64/arm64版本

OlivOS镜像会随上游版本发布自动更新，支持稳定版和预发布版双通道

[Docker Hub](https://hub.docker.com/r/shiaworkshop/olivos)

## 镜像说明

镜像构建分为三类标签：

- **latest** - 最新版本（始终指向最新版本）
- **stable / vx.x.x** - 对应有版本号的正式发布版本
- **pre / sha-xxxxxxx** - 对应预发布通道的版本

## 一键部署脚本（推荐新手）

```bash
bash <(curl -sL https://raw.githubusercontent.com/DiceZone/OlivOS-Docker/main/olivos-onekey.sh)
```

交互式引导，按提示选择版本渠道、登录方式和 QQ 号即可。

### 参数用法

```bash
bash <(curl -sL ...) -a 123456 -c stable -m napcat
```

- `-a`：骰娘QQ号（必须）
- `-c`：版本渠道（latest/stable/pre，默认 latest）
- `-m`：登录方式（napcat/llbot，默认 napcat）
- `-p`：额外Python包（如 `-p "requests aiohttp"`）
- `-y`：静默模式，跳过确认

## 手动部署

### 准备工作

#### 确保已安装 Docker 和 Docker Compose
- Docker 安装​​：参考 [官方文档](https://docs.docker.com/engine/install/)

- ​​Docker Compose 安装​​：通常随 Docker Desktop 自动安装，独立安装可参考 [官方指南](https://docs.docker.com/compose/install/)

#### 创建数据目录

  创建存储 OlivOS 和 napcat 数据的本地目录，用于持久化数据。

  我们以默认位置为例：

  ```
  mkdir -p -m 755 /opt/OlivOS-Docker
  cd /opt/OlivOS-Docker
  ```

#### 配置环境变量

  下载 `docker-compose.yml` ，在同一级创建 `.env` 文件。
  
  ```
  wget https://raw.githubusercontent.com/DiceZone/OlivOS-Docker/refs/heads/main/docker-compose.yml
  echo 'ACCOUNT=123456' > .env
  ```

  在 `.env` 内，变量 `ACCOUNT` 是键入骰娘账号，所以要替换`123456`为你实际的骰娘账号。

### 使用 LLBot 登录

如需使用 LLBot 替代 NapCat，请参考 `olivos-onekey.sh` 中的 LLBot 模式 compose 配置，
或直接使用一键脚本（`-m llbot` 参数）。

LLBot 使用 **HTTP Server + HTTP Client** 模式对接 OlivOS：
- HTTP Server 监听 3000 端口，接收 OlivOS 的 API 请求
- HTTP Client 上报事件到 `http://olivos-app:55001/OlivOSMsgApi/qq/onebot/default`

### 额外 Python 依赖

在 `.env` 文件中添加 `PY_PACKAGES` 变量，多个包名用空格分隔：

```
PY_PACKAGES=requests aiohttp beautifulsoup4
```

容器启动时会使用清华源自动 pip 安装这些包。

### 运行服务
1. 启动所有服务
```
docker-compose up -d
```
2. 查看容器状态
```
docker-compose ps
```
3. 停止服务
```
docker-compose down
```
4. 更新服务
```
# 拉取最新镜像
docker-compose pull
# 重新创建容器
docker-compose up -d --force-recreate
```

（可选）启动时指定项目名称中包含UIN

```
export $(grep -v '^#' .env | xargs) && docker-compose -p "olivos-${ACCOUNT}" up -d
```

这样启动出来的容器名称会变成下面这样，更方便管理

```
olivos-123456_olivos-main_1
olivos-123456_napcat_1
```

### 登录

容器日志能看到二维码，同时也推荐你使用NapCat/LLBot的webUI去扫码登录，比如 `IP:6099` 或者你启动容器时映射的其他端口号。

