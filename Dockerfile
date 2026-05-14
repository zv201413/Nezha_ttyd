FROM alpine:latest AS builder

ARG TARGETARCH=amd64

# Download all binaries
WORKDIR /tmp

RUN apk add --no-cache curl

# ttyd
RUN curl -SL \
    https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.x86_64 \
    -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd

# cloudflared
RUN curl -SL \
    https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${TARGETARCH} \
    -o /usr/local/bin/cloudflared && chmod +x /usr/local/bin/cloudflared

# Nezha Dashboard v2
RUN curl -SL \
    https://github.com/nezhahq/nezha/releases/download/v2.0.7/dashboard-linux-${TARGETARCH}.zip \
    -o /tmp/dashboard.zip && \
    unzip /tmp/dashboard.zip -d /opt/nezha && \
    mv /opt/nezha/dashboard-linux-${TARGETARCH} /opt/nezha/dashboard && \
    chmod +x /opt/nezha/dashboard && \
    rm -f /tmp/dashboard.zip

# --- runtime stage ---
FROM alpine:latest

RUN apk add --no-cache \
    nginx \
    supervisor \
    libcap \
    openssl \
    ca-certificates \
    tzdata \
    bash

# Copy binaries from builder
COPY --from=builder /usr/local/bin/ttyd /usr/local/bin/ttyd
COPY --from=builder /usr/local/bin/cloudflared /usr/local/bin/cloudflared
COPY --from=builder /opt/nezha/dashboard /opt/nezha/dashboard

# Config files
COPY conf/nginx.conf /etc/nginx/http.d/default.conf
COPY conf/supervisord.conf /etc/supervisord.conf
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

# ttyd needs CAP_NET_RAW for ping in ttyd shell
RUN setcap cap_net_raw+ep /usr/bin/ping 2>/dev/null || true

EXPOSE 80

VOLUME ["/opt/nezha/data"]

ENTRYPOINT ["/entrypoint.sh"]
