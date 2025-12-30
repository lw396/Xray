# Xray VLESS-REALITY Docker 部署指南

适用于 claw.cloud 及其他 Docker 环境的生产级部署。

## 特性

- **轻量级 Alpine 镜像** - 最终镜像约 35MB
- **自动密钥生成** - 首次启动自动生成并显示连接信息
- **单用户配置** - 简化的单 UUID 配置
- **内置路由规则** - 屏蔽广告、中国 IP/域名
- **健康检查** - 自动监控服务状态
- **配置持久化** - 支持密钥重用

## 快速开始

### 方式一：使用 Docker Compose（推荐）

1. 复制环境变量模板：
```bash
cp .env.example .env
```

2. 编辑 `.env` 文件（可选）：
```bash
# .env
XRAY_PORT=443
XRAY_UUID=                          # 留空自动生成
XRAY_SNI=www.microsoft.com
XRAY_FINGERPRINT=chrome
```

3. 构建并启动：
```bash
docker compose up -d
```

4. 查看连接信息：
```bash
docker logs xray-reality
```

### 方式二：使用 Docker 命令

```bash
docker run -d \
  --name xray-reality \
  --restart unless-stopped \
  -p 443:443 \
  -e XRAY_PORT=443 \
  -e XRAY_SNI=www.microsoft.com \
  xray-reality:latest
```

## 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `XRAY_PORT` | 监听端口 | 443 |
| `XRAY_UUID` | 用户 UUID | 自动生成 |
| `XRAY_SNI` | 伪装域名 | www.microsoft.com |
| `XRAY_PUBLIC_KEY` | 公钥 | 自动生成 |
| `XRAY_PRIVATE_KEY` | 私钥 | 自动生成 |
| `XRAY_SHORT_ID` | 短 ID | 自动生成 |
| `XRAY_FINGERPRINT` | TLS 指纹 | chrome |
| `TZ` | 时区 | Asia/Shanghai |

## 密钥重用

首次启动时会自动生成密钥对。如需重用相同密钥：

1. 获取首次运行生成的密钥（查看日志或容器内文件）：
```bash
docker exec xray-reality cat /etc/xray/keys.txt
```

2. 在 `.env` 文件中设置：
```env
XRAY_UUID=你的UUID
XRAY_PRIVATE_KEY=你的私钥
XRAY_PUBLIC_KEY=你的公钥
XRAY_SHORT_ID=你的短ID
```

3. 重启容器：
```bash
docker compose restart
```

## 客户端配置

启动后，日志会显示完整的连接信息：

```
═══════════════════════════════════════════════════════════
           Xray VLESS-REALITY Configuration
═══════════════════════════════════════════════════════════

Server Information:
  Address:     你的服务器IP
  Port:        443

Client Configuration:
  UUID:        生成的UUID
  Flow:        xtls-rprx-vision
  Security:    reality
  SNI:         www.microsoft.com
  Fingerprint: chrome
  Public Key:  生成的公钥
  Short ID:    生成的短ID

Share Link (VLESS URL):
vless://uuid@ip:443?encryption=none&security=reality&flow=xtls-rprx-vision&type=tcp&sni=www.microsoft.com&pbk=公钥&fp=chrome&sid=短ID#Xray-Reality
```

### 支持的客户端

- **v2rayN** (Windows)
- **Qv2ray** (Cross-platform)
- **Shadowrocket** (iOS)
- **Loon** (iOS)
- **SagerNet** (Android)
- **v2rayNG** (Android)

将 VLESS URL 导入客户端即可使用。

## 常用命令

```bash
# 查看日志
docker logs xray-reality

# 查看实时日志
docker logs -f xray-reality

# 查看配置
docker exec xray-reality cat /etc/xray/config.json

# 测试配置
docker exec xray-reality xray -test -config /etc/xray/config.json

# 查看密钥
docker exec xray-reality cat /etc/xray/keys.txt

# 重启容器
docker compose restart

# 停止容器
docker compose down

# 更新镜像
docker compose pull
docker compose up -d
```

## claw.cloud 部署注意事项

1. **端口映射**：确保在 claw.cloud 平台正确映射 443 端口
2. **防火墙**：确保 443 端口对外开放
3. **资源限制**：建议至少 256MB 内存
4. **持久化**：建议启用 Volume 持久化以保留密钥

## 高级配置

### 修改伪装域名

编辑 `.env` 文件，选择一个常见的网站域名：

```env
# 常用选项
XRAY_SNI=www.microsoft.com
XRAY_SNI=www.apple.com
XRAY_SNI=www.amazon.com
XRAY_SNI=www.cloudflare.com
```

### 自定义 UUID

```bash
# 生成 UUID
uuidgen

# 设置到环境变量
XRAY_UUID=你生成的UUID
```

### 构建特定版本

```bash
docker build --build-arg XRAY_VERSION=v1.8.24 -t xray-reality:v1.8.24 .
```

## 故障排除

### 容器无法启动

```bash
# 检查日志
docker logs xray-reality

# 验证配置
docker exec xray-reality xray -test -config /etc/xray/config.json
```

### 无法连接

1. 确认端口映射正确
2. 检查防火墙规则
3. 验证客户端配置是否与服务端匹配
4. 检查服务器 IP 是否正确

### 密钥不匹配

如果重新生成了密钥，客户端需要更新配置。建议在 `.env` 中固定密钥值。

## 安全建议

1. 定期更新 Xray 核心：`docker compose pull && docker compose up -d`
2. 使用强 UUID（不要使用默认值）
3. 考虑使用非标准端口（但不要使用已被封锁的端口）
4. 定期检查日志中的异常连接

## 许可证

本项目基于原 Xray 脚本修改，遵循原许可证。
