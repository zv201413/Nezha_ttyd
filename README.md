# Nezha_ttyd

All-in-one Docker image: **Nezha Dashboard v2 + Nginx(gRPC) + Cloudflare Tunnel + TTYD**  
一键部署，一个容器跑通哪吒监控，零端口暴露，带网页终端。

---

## 架构

```
Agent → Cloudflare(443) → Tunnel → cloudflared → nginx:80(grpc_pass) → dashboard:8008
                                                      └─ ttyd:7681 / ttyd:7682 ...
```

一条 Cloudflare Tunnel 复用多个域名，各自映射到不同服务。

---

## 环境变量

| 变量 | 必填 | 说明 |
|------|------|------|
| `TUNNEL_TOKEN` | ✅ | Cloudflare Tunnel Token |
| `NZ_AGENT_KEY` | ❌ | 固定面板 `agent_secret_key`，防止重启后密钥变更 |
| `TTYD_P1` | ❌ | TTYD 实例1，格式 `端口:用户名:密码` |
| `TTYD_P2` | ❌ | TTYD 实例2（可继续拓展 P3、P4...） |

### 示例

```bash
TUNNEL_TOKEN=eyJhIjoi...
NZ_AGENT_KEY=MyFixedKey123
TTYD_P1=7681:admin:pass123
TTYD_P2=7682:root:pass456
```

---

## 部署

### PaaS 平台（爪云 / justrunmy.app 等）

填以下信息部署：

```
容器镜像: ghcr.io/你的用户名/nezha-ttyd:latest  （或 Docker Hub 地址）
端口: 80
环境变量: 按上表填写
```

### 自建服务器

```bash
docker run -d --name nezha \
  -p 80:80 \
  -v /opt/nezha/data:/opt/nezha/data \
  -e TUNNEL_TOKEN=eyJhIjoi... \
  -e NZ_AGENT_KEY=MyFixedKey123 \
  -e TTYD_P1=7681:admin:pass123 \
  ghcr.io/你的用户名/nezha-ttyd:latest
```

---

## Cloudflare Zero Trust 配置

隧道创建好后，在 **Public Hostname** 添加规则：

| 域名 | 服务 |
|------|------|
| `nezha.你的域名.com` | `localhost:80` |
| `ttyd1.你的域名.com` | `localhost:7681` |
| `ttyd2.你的域名.com` | `localhost:7682` |

> 所有服务走同一条隧道（同一个 TUNNEL_TOKEN），通过不同域名访问不同服务。

---

## 哪吒面板后台

路径 `/dashboard`，首次登录 `admin / admin`，立即修改密码。

---

## 构建自己的镜像

```bash
git clone https://github.com/你的用户名/Nezha_ttyd.git
cd Nezha_ttyd

docker build -t nezha-ttyd .

# 或推送到 GitHub Packages
docker tag nezha-ttyd ghcr.io/你的用户名/nezha-ttyd:latest
docker push ghcr.io/你的用户名/nezha-ttyd:latest
```
