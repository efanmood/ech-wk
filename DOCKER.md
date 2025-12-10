# Docker 部署指南 - ARMv7 (Armbian)

本指南介绍如何在 ARMv7 架构的 Armbian 设备上使用 Docker 部署 ECH Workers 代理服务。

## 📋 目录

- [系统要求](#系统要求)
- [快速开始](#快速开始)
- [构建镜像](#构建镜像)
- [运行容器](#运行容器)
- [配置说明](#配置说明)
- [使用 Docker Compose](#使用-docker-compose)
- [故障排除](#故障排除)
- [高级配置](#高级配置)

## 系统要求

### 硬件要求
- **架构**: ARMv7 (32-bit ARM)
- **内存**: 最低 512MB RAM（推荐 1GB+）
- **存储**: 至少 500MB 可用空间
- **网络**: 稳定的互联网连接

### 支持的设备（示例）
- Orange Pi PC/PC Plus/Zero
- Banana Pi M1/M2/M3
- Raspberry Pi 2 Model B
- NanoPi Neo/Neo Air
- 其他运行 Armbian 的 ARMv7 设备

### 软件要求
- **操作系统**: Armbian 22.x 或更高版本（基于 Debian/Ubuntu）
- **Docker**: 20.10+ 或 Docker CE
- **Docker Compose**: 2.x+（可选，但推荐）

## 快速开始

### 1. 安装 Docker

如果您的 Armbian 设备上还没有安装 Docker：

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装 Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 将当前用户添加到 docker 组（避免每次都用 sudo）
sudo usermod -aG docker $USER

# 重新登录以使组权限生效
# 或运行: newgrp docker

# 验证安装
docker --version
docker run --rm hello-world
```

### 2. 安装 Docker Compose（可选但推荐）

```bash
# 对于 ARMv7，需要使用 pip 安装
sudo apt install -y python3-pip
sudo pip3 install docker-compose

# 验证安装
docker-compose --version
```

### 3. 克隆项目（或下载源码）

```bash
git clone https://github.com/byJoey/ech-wk.git
cd ech-wk
```

## 构建镜像

### 方法 1: 直接构建

```bash
# 在项目根目录执行
docker build -t ech-workers:armv7 .

# 查看构建的镜像
docker images | grep ech-workers
```

构建参数说明：
- 使用多阶段构建优化镜像大小
- 第一阶段：使用 golang:1.23-alpine 编译 ARMv7 二进制
- 第二阶段：使用 alpine:3.19 作为运行时基础镜像
- 最终镜像大小约 20-30MB

### 方法 2: 使用构建参数

```bash
# 指定构建平台
docker buildx build --platform linux/arm/v7 -t ech-workers:armv7 .

# 如果需要推送到 registry
docker buildx build --platform linux/arm/v7 -t your-registry/ech-workers:armv7 --push .
```

### 验证构建

```bash
# 检查镜像架构
docker image inspect ech-workers:armv7 | grep Architecture

# 应该显示: "Architecture": "arm"
```

## 运行容器

### 基本运行（最小配置）

```bash
docker run -d \
  --name ech-workers-proxy \
  --restart unless-stopped \
  -p 30000:30000 \
  ech-workers:armv7 \
  -l 0.0.0.0:30000 \
  -f your-worker.workers.dev:443 \
  -token your-token-here \
  -routing global
```

### 完整配置运行

```bash
docker run -d \
  --name ech-workers-proxy \
  --restart unless-stopped \
  -p 30000:30000 \
  -e TZ=Asia/Shanghai \
  -v ech-data:/app/data \
  -v ech-logs:/app/logs \
  --memory="256m" \
  --cpus="1.0" \
  ech-workers:armv7 \
  -l 0.0.0.0:30000 \
  -f your-worker.workers.dev:443 \
  -ip your-server-ip \
  -token your-token-here \
  -dns dns.alidns.com/dns-query \
  -ech cloudflare-ech.com \
  -routing bypass_cn
```

### 容器管理命令

```bash
# 查看运行状态
docker ps | grep ech-workers

# 查看日志
docker logs -f ech-workers-proxy

# 查看最近 100 行日志
docker logs --tail 100 ech-workers-proxy

# 停止容器
docker stop ech-workers-proxy

# 启动容器
docker start ech-workers-proxy

# 重启容器
docker restart ech-workers-proxy

# 删除容器
docker rm -f ech-workers-proxy

# 查看容器资源使用
docker stats ech-workers-proxy
```

## 配置说明

### 必需参数

| 参数 | 说明 | 示例 |
|------|------|------|
| `-f` | 服务端地址（Workers 地址） | `your-worker.workers.dev:443` |
| `-l` | 本地监听地址 | `0.0.0.0:30000` |

### 可选参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-ip` | 指定服务端 IP（绕过 DNS） | 无 |
| `-token` | 身份验证令牌 | 无 |
| `-dns` | ECH 查询 DoH 服务器 | `dns.alidns.com/dns-query` |
| `-ech` | ECH 查询域名 | `cloudflare-ech.com` |
| `-routing` | 分流模式 | `global` |

### 分流模式说明

- **`global`**: 全局代理，所有流量都通过代理
- **`bypass_cn`**: 跳过中国大陆 IP，自动下载并使用 China IP 列表
- **`none`**: 直连模式，不改变代理行为

## 使用 Docker Compose

Docker Compose 提供了更简单的配置和管理方式。

### 1. 编辑配置文件

编辑 `docker-compose.yml` 文件，修改以下环境变量：

```yaml
environment:
  # 必需：您的 Worker 地址
  - SERVER_ADDR=your-worker.workers.dev:443
  # 可选：服务器 IP
  - SERVER_IP=1.2.3.4
  # 可选：认证令牌
  - TOKEN=your-token-here
  # 监听地址
  - LISTEN_ADDR=0.0.0.0:30000
  # 分流模式：global, bypass_cn, none
  - ROUTING_MODE=global
```

### 2. 启动服务

```bash
# 构建并启动（首次运行）
docker-compose up -d --build

# 启动服务（已构建）
docker-compose up -d

# 查看日志
docker-compose logs -f

# 查看服务状态
docker-compose ps

# 停止服务
docker-compose down

# 停止并删除卷
docker-compose down -v
```

### 3. 更新服务

```bash
# 拉取最新代码
git pull

# 重新构建并重启
docker-compose up -d --build

# 或分步操作
docker-compose build
docker-compose up -d
```

## 故障排除

### 问题 1: 镜像构建失败

**症状**: 构建时出现 "exec format error" 或架构不匹配错误

**解决方案**:
```bash
# 启用 QEMU 支持（在 x86_64 主机上交叉编译）
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# 使用 buildx
docker buildx create --use
docker buildx build --platform linux/arm/v7 -t ech-workers:armv7 .
```

### 问题 2: 容器启动后立即退出

**症状**: `docker ps` 看不到运行中的容器

**诊断**:
```bash
# 查看退出的容器
docker ps -a | grep ech-workers

# 查看日志
docker logs ech-workers-proxy
```

**常见原因**:
- 缺少必需参数 `-f`（服务端地址）
- 网络连接问题
- ECH 配置获取失败

### 问题 3: 内存不足

**症状**: 容器被 OOM Killer 终止

**解决方案**:
```bash
# 增加内存限制
docker run -d \
  --name ech-workers-proxy \
  --memory="512m" \
  --memory-swap="512m" \
  ech-workers:armv7 [参数...]

# 或在 docker-compose.yml 中修改：
deploy:
  resources:
    limits:
      memory: 512M
```

### 问题 4: 端口被占用

**症状**: "bind: address already in use"

**解决方案**:
```bash
# 检查端口占用
sudo netstat -tlnp | grep 30000
# 或
sudo lsof -i :30000

# 修改端口映射
docker run -d \
  --name ech-workers-proxy \
  -p 30001:30000 \
  ech-workers:armv7 [参数...]
```

### 问题 5: 无法连接代理

**症状**: 客户端连接代理超时或被拒绝

**诊断步骤**:
```bash
# 1. 检查容器是否运行
docker ps | grep ech-workers

# 2. 检查容器日志
docker logs --tail 50 ech-workers-proxy

# 3. 测试本地连接
curl -x socks5://localhost:30000 http://www.google.com

# 4. 检查防火墙
sudo iptables -L -n | grep 30000

# 5. 检查网络模式
docker inspect ech-workers-proxy | grep NetworkMode
```

### 问题 6: China IP 列表下载失败

**症状**: 使用 `bypass_cn` 模式时日志显示下载失败

**解决方案**:
```bash
# 预先下载 IP 列表并挂载到容器
mkdir -p ~/ech-workers-data
cd ~/ech-workers-data

# 下载 IPv4 列表
curl -L -o chn_ip.txt \
  "https://raw.githubusercontent.com/mayaxcn/china-ip-list/master/chn_ip.txt"

# 下载 IPv6 列表
curl -L -o chn_ip_v6.txt \
  "https://raw.githubusercontent.com/mayaxcn/china-ip-list/master/chn_ip_v6.txt"

# 运行容器时挂载这些文件
docker run -d \
  --name ech-workers-proxy \
  -v ~/ech-workers-data/chn_ip.txt:/app/chn_ip.txt:ro \
  -v ~/ech-workers-data/chn_ip_v6.txt:/app/chn_ip_v6.txt:ro \
  ech-workers:armv7 [参数...]
```

## 高级配置

### 1. 性能优化

对于低性能设备（如 Orange Pi Zero）：

```yaml
# docker-compose.yml 优化配置
services:
  ech-workers:
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 128M
        reservations:
          cpus: '0.1'
          memory: 32M
    
    # 使用主机网络模式（性能更好，但失去网络隔离）
    # network_mode: host
    
    # 禁用不必要的功能
    logging:
      driver: "json-file"
      options:
        max-size: "5m"
        max-file: "2"
```

### 2. 开机自启

使用 systemd 管理 Docker Compose 服务：

```bash
# 创建 systemd 服务文件
sudo nano /etc/systemd/system/ech-workers.service
```

内容：
```ini
[Unit]
Description=ECH Workers Proxy Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/path/to/ech-wk
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

启用服务：
```bash
sudo systemctl daemon-reload
sudo systemctl enable ech-workers.service
sudo systemctl start ech-workers.service
sudo systemctl status ech-workers.service
```

### 3. 监控和日志

#### 使用 Portainer 管理（可选）

```bash
# 安装 Portainer（ARM 版本）
docker volume create portainer_data

docker run -d \
  -p 9000:9000 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:linux-arm
```

然后访问 `http://your-device-ip:9000` 进行可视化管理。

#### 日志轮转

编辑 `/etc/docker/daemon.json`：
```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

重启 Docker：
```bash
sudo systemctl restart docker
```

### 4. 网络配置

#### 使用自定义网络

```bash
# 创建自定义桥接网络
docker network create --driver bridge ech-network

# 使用自定义网络运行
docker run -d \
  --name ech-workers-proxy \
  --network ech-network \
  -p 30000:30000 \
  ech-workers:armv7 [参数...]
```

#### 配置 DNS

```bash
docker run -d \
  --name ech-workers-proxy \
  --dns 8.8.8.8 \
  --dns 1.1.1.1 \
  ech-workers:armv7 [参数...]
```

### 5. 安全加固

```bash
# 使用非 root 用户（Dockerfile 已配置）
# 限制容器权限
docker run -d \
  --name ech-workers-proxy \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  --security-opt=no-new-privileges:true \
  --read-only \
  --tmpfs /tmp \
  ech-workers:armv7 [参数...]
```

## 测试代理连接

### 使用 curl 测试

```bash
# SOCKS5 代理测试
curl -x socks5://localhost:30000 http://www.google.com
curl -x socks5://localhost:30000 https://ip.sb

# HTTP 代理测试
curl -x http://localhost:30000 http://www.google.com
```

### 配置系统代理

#### 临时设置（当前终端）

```bash
export http_proxy="http://localhost:30000"
export https_proxy="http://localhost:30000"
export all_proxy="socks5://localhost:30000"
```

#### 永久设置

编辑 `~/.bashrc` 或 `~/.profile`：
```bash
# ECH Workers Proxy
export http_proxy="http://localhost:30000"
export https_proxy="http://localhost:30000"
export all_proxy="socks5://localhost:30000"
export no_proxy="localhost,127.0.0.1,192.168.0.0/16,10.0.0.0/8"
```

## 性能基准

典型 ARMv7 设备性能参考：

| 设备 | CPU | RAM | 网络延迟 | 吞吐量 |
|------|-----|-----|----------|--------|
| Orange Pi PC | H3 @ 1.2GHz | 1GB | ~50ms | ~80Mbps |
| Banana Pi M2+ | H3 @ 1.2GHz | 1GB | ~50ms | ~100Mbps |
| Raspberry Pi 2B | BCM2836 @ 900MHz | 1GB | ~60ms | ~60Mbps |

**注意**: 实际性能取决于网络条件、服务器位置和系统负载。

## 卸载

### 完全卸载

```bash
# 停止并删除容器
docker-compose down -v

# 或手动删除
docker stop ech-workers-proxy
docker rm ech-workers-proxy

# 删除镜像
docker rmi ech-workers:armv7

# 删除卷（如果有）
docker volume rm ech-data ech-logs

# 清理未使用的资源
docker system prune -a
```

## 支持和反馈

如果您在使用过程中遇到问题：

1. 查看 [故障排除](#故障排除) 部分
2. 检查容器日志: `docker logs ech-workers-proxy`
3. 提交 Issue: https://github.com/byJoey/ech-wk/issues
4. 查看主文档: [README.md](README.md)

## 许可证

本项目基于 MIT 许可证开源。详见 [LICENSE](LICENSE) 文件。
