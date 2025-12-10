# Docker 快速入门 - ARMv7 (Armbian)

**5 分钟快速部署指南**

## 前置要求

```bash
# 检查是否已安装 Docker
docker --version

# 如未安装，运行：
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

## 方式一：Docker Compose（推荐）

### 1. 配置

```bash
# 复制示例配置
cp docker-compose.example.yml docker-compose.yml

# 编辑配置（修改 SERVER_ADDR 和 TOKEN）
nano docker-compose.yml
```

最少需要修改这两行：
```yaml
- SERVER_ADDR=your-worker.workers.dev:443  # 改成你的 Worker 地址
- TOKEN=your-token-here                     # 改成你的令牌
```

### 2. 启动

```bash
# 构建并启动
docker-compose up -d

# 查看日志
docker-compose logs -f
```

### 3. 测试

```bash
# 测试代理是否工作
curl -x socks5://localhost:30000 https://ip.sb
```

✅ **完成！** 代理已在 `localhost:30000` 运行

---

## 方式二：直接使用 Docker

### 1. 构建镜像

```bash
docker build -t ech-workers:armv7 .
```

### 2. 运行容器

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

**修改以下参数：**
- `your-worker.workers.dev:443` → 你的 Worker 地址
- `your-token-here` → 你的认证令牌

### 3. 测试

```bash
curl -x socks5://localhost:30000 https://ip.sb
```

✅ **完成！**

---

## 常用命令

```bash
# 查看状态
docker ps | grep ech-workers

# 查看日志（实时）
docker logs -f ech-workers-proxy

# 停止
docker stop ech-workers-proxy

# 启动
docker start ech-workers-proxy

# 重启
docker restart ech-workers-proxy
```

---

## 配置参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-f` | Worker 地址（必需） | 无 |
| `-l` | 监听地址 | `0.0.0.0:30000` |
| `-token` | 认证令牌 | 无 |
| `-routing` | 分流模式 | `global` |

### 分流模式

- **`global`**: 全局代理（所有流量走代理）
- **`bypass_cn`**: 绕过中国大陆 IP（国内直连，国外走代理）
- **`none`**: 直连模式（所有流量直连）

---

## 故障排除

### 容器无法启动

```bash
# 查看错误日志
docker logs ech-workers-proxy

# 常见原因：
# 1. 缺少必需参数 -f
# 2. Worker 地址错误
# 3. 网络连接问题
```

### 端口被占用

```bash
# 修改端口映射（改用 30001）
docker run -d \
  --name ech-workers-proxy \
  -p 30001:30000 \
  ...
```

### 无法连接代理

```bash
# 1. 检查容器状态
docker ps | grep ech-workers

# 2. 检查防火墙
sudo iptables -L -n | grep 30000

# 3. 测试本地连接
curl -v -x socks5://127.0.0.1:30000 http://www.google.com
```

---

## 进阶配置

### 使用 bypass_cn 模式（国内直连）

```bash
docker run -d \
  --name ech-workers-proxy \
  -p 30000:30000 \
  ech-workers:armv7 \
  -l 0.0.0.0:30000 \
  -f your-worker.workers.dev:443 \
  -token your-token-here \
  -routing bypass_cn
```

首次使用会自动下载中国 IP 列表（约 1-2 分钟）。

### 开机自启

```bash
# Docker Compose 方式
docker-compose up -d  # 已包含 restart: unless-stopped

# 或使用 systemd（见 DOCKER.md）
```

### 性能优化（低端设备）

在 `docker-compose.yml` 中：

```yaml
deploy:
  resources:
    limits:
      cpus: '0.5'
      memory: 128M
```

---

## 支持的设备

✅ Orange Pi PC/Zero  
✅ Banana Pi M1/M2/M3  
✅ Raspberry Pi 2 Model B  
✅ NanoPi Neo/Air  
✅ 其他 ARMv7 设备

---

## 更多帮助

- **完整文档**: [DOCKER.md](DOCKER.md)
- **项目主页**: [README.md](README.md)
- **问题反馈**: https://github.com/byJoey/ech-wk/issues

---

**祝使用愉快！** 🚀
