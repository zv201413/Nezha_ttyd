# Nezha_ttyd

这是一个高度精简且全能的 Docker 镜像：**Nezha Dashboard v2 + 网页终端（TTYD）**。
一键部署，一个容器跑通哪吒监控，带网页终端。

> **探针监控说明**：
> 为了保证容器在各大 PaaS 平台上的极致兼容性，本镜像**仅包含面板**。如需监控服务器：
> 1. **真实的 VPS / 虚拟机**：请直接使用官方后台复制的原始命令（`curl -L ... install.sh`）在宿主机运行，依赖 `systemd` 最稳定。
> 2. **PaaS 平台 / 纯容器环境**：由于没有 `systemd`，官方脚本会报错。请将原始命令粘贴到 [Argosbx 转换面板](https://zv201413.github.io/argosbx-new/)，一键生成免 systemd 的 `nohup` 容器专用命令后再执行。

---

## 🚀 推荐部署方案：Northflank（最简单，自带 SSL）

Northflank 会自动为应用分配带 HTTPS 的专属域名。**不需要配置 Tunnel，也不需要搞证书**，这是最推荐的部署方式。

### 1. 创建应用 (Service)

在 Northflank 创建一个 Service，选择 Docker image 模式，并按以下参数配置：

| 设置项 | 填写内容 |
|--------|--------|
| **镜像地址** | `ghcr.io/zv201413/nezha_ttyd:latest` |
| **端口 1 (Port)** | `80` (用于访问哪吒面板及 gRPC 通信) |
| **端口 2 (Port)** | `7681` (如果需要用到 TTYD 网页终端) |
| **持久化存储 (Volume)** | 挂载路径填 `/opt/nezha/data`（必填，否则重启数据全丢） |

**环境变量 (Variables)**：

| 变量名 | 必填 | 说明 |
|--------|------|------|
| `NZ_AGENT_KEY` | ❌ | 固定面板 Agent 通信密钥，防止重启后密钥变更 |
| `TTYD_P1` | ❌ | 网页终端，格式 `7681:admin:你的密码` |

### 2. 访问面板

部署成功后，查看 Northflank 分配的域名：
- **哪吒面板**：`https://xxx.northflank.app`
- **TTYD 终端**：`https://xxx.northflank.app:7681`

> 首次登录哪吒面板后台，路径为 `/dashboard`，默认账号密码为 `admin / admin`，请立即修改！

---

## ☁️ 其他 PaaS 平台（如 爪云, Zeabur 等）

如果平台不自动提供 SSL 域名，推荐使用 **Cloudflare Tunnel** 进行内网穿透。

### 平台配置

| 设置项 | 填写内容 |
|--------|--------|
| **镜像地址** | `ghcr.io/zv201413/nezha_ttyd:latest` |
| **持久化目录** | 挂载到 `/opt/nezha/data` |
| **环境变量** | `TUNNEL_TOKEN=eyJh...` (你的 Cloudflare Tunnel Token)<br>`NZ_AGENT_KEY=MyFixedKey123`<br>`TTYD_P1=7681:admin:密码` |

### Cloudflare Zero Trust 配置
在 Cloudflare Public Hostname 添加规则：
- `nezha.你的域名.com` → 指向 `http://localhost:80`
- `ttyd.你的域名.com` → 指向 `http://localhost:7681`

---

## 💻 自建服务器部署 (Docker)

```bash
docker run -d --name nezha \
  --restart unless-stopped \
  -p 8008:80 \
  -p 7681:7681 \
  -v /opt/nezha/data:/opt/nezha/data \
  -e NZ_AGENT_KEY=MyFixedKey123 \
  -e TTYD_P1=7681:admin:你的终端密码 \
  ghcr.io/zv201413/nezha_ttyd:latest
```

---

## 🛠 高级设置：多个 TTYD 终端

如果需要开多个终端供不同用户使用：
```bash
TTYD_P1=7681:admin:密码1
TTYD_P2=7682:user2:密码2
```
*注意：记得在部署平台或 Cloudflare Tunnel 中放行对应的端口号。*

---

## 🗑️ 探针卸载指南

如果你按照本说明在宿主机或容器中安装了探针（Komari/Nezha Agent），请根据你的**安装方式**选择卸载步骤：

### 场景一：真实 VPS（使用官方 `.sh` 脚本安装的）
官方脚本会自动把探针塞进系统服务里（systemd）并安装到 `/opt` 目录。在当前目录执行 `rm` 是没用的！

**彻底卸载步骤**：
```bash
# 1. 停止并禁用服务
sudo systemctl stop nezha-agent
sudo systemctl disable nezha-agent

# 2. 删除服务配置文件并刷新
sudo rm /etc/systemd/system/nezha-agent.service
sudo systemctl daemon-reload

# 3. 删除探针老巢（极其重要）
sudo rm -rf /opt/nezha
```

### 场景二：纯容器环境 / PaaS（使用 Argosbx 生成的 `nohup` 裸跑命令）
使用面板转换出来的指令，属于“绿色免安装”模式，没有系统服务残留。

**彻底卸载步骤**：
```bash
# 1. 猎杀后台驻留的进程
pkill -f nezha-agent

# 2. 直接删掉当前目录下下载的二进制文件及日志
rm -f nezha-agent agent.log
```
