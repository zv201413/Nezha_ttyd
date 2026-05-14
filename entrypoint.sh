#!/bin/bash
set -e

CONF_DIR=/etc/supervisor/conf.d
mkdir -p "$CONF_DIR"

# ──────────────────────────────────────────────
# 1. nginx
# ──────────────────────────────────────────────
cat > "$CONF_DIR/nginx.conf" << 'SUP'
[program:nginx]
command=nginx -g "daemon off;"
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
SUP

# ──────────────────────────────────────────────
# 2. Nezha Dashboard
# ──────────────────────────────────────────────
DASHBOARD_BIN=/opt/nezha/dashboard
DASHBOARD_DATA=/opt/nezha/data

# 如果用户设置了 NZ_AGENT_KEY，在 config.yaml 中固定密钥
if [ -n "$NZ_AGENT_KEY" ] && [ -f "$DASHBOARD_DATA/config.yaml" ]; then
    sed -i "s/agent_secret_key:.*/agent_secret_key: $NZ_AGENT_KEY/" "$DASHBOARD_DATA/config.yaml"
fi

cat > "$CONF_DIR/dashboard.conf" << SUP
[program:dashboard]
command=$DASHBOARD_BIN
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
SUP

# ──────────────────────────────────────────────
# 3. Cloudflare Tunnel
# ──────────────────────────────────────────────
if [ -z "$TUNNEL_TOKEN" ]; then
    echo "[ERROR] TUNNEL_TOKEN is not set. Cloudflare Tunnel will not start."
else
    cat > "$CONF_DIR/tunnel.conf" << SUP
[program:tunnel]
command=/usr/local/bin/cloudflared tunnel --no-autoupdate run --protocol http2 --http2-origin --token $TUNNEL_TOKEN
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
SUP
fi

# ──────────────────────────────────────────────
# 4. TTYD instances (multiple)
# ──────────────────────────────────────────────
# 格式: TTYD_P1=端口:用户名:密码
# 例子: TTYD_P1=7681:admin:pass123
#       TTYD_P2=7682:root:pass456
for var in $(compgen -A variable | grep -E '^TTYD_P[0-9]+$' | sort); do
    IFS=':' read -r port user pass <<< "${!var}"

    if [ -z "$port" ] || [ -z "$user" ] || [ -z "$pass" ]; then
        echo "[WARN] $var format invalid (expected port:user:pass), got: ${!var}"
        continue
    fi

    name="ttyd_${var#TTYD_P}"

    cat > "$CONF_DIR/${name}.conf" << SUP
[program:$name]
    command=/usr/local/bin/ttyd -c $user:$pass -p $port -W bash
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
SUP

    echo "[INFO] TTYD instance '$name' -> port $port, user: $user"
done

# ──────────────────────────────────────────────
# 5. Start supervisor
# ──────────────────────────────────────────────
exec supervisord -c /etc/supervisord.conf
