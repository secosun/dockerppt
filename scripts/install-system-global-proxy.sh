#!/usr/bin/env bash
# 将 SOCKS/HTTP 代理写入系统级配置（登录 shell、systemd 用户会话环境）。
# 默认: socks5h://192.168.3.142:10808（与仓库 .env.example / git-deploy 一致）
#
# 用法（需 root）:
#   sudo PROXY_URL='socks5h://192.168.3.142:10808' ./scripts/install-system-global-proxy.sh
# HTTP 代理示例:
#   sudo PROXY_URL='http://127.0.0.1:7890' ./scripts/install-system-global-proxy.sh
#
# 生效: 重新登录，或 `source /etc/profile.d/99-global-proxy.sh`
# Docker: 见脚本内说明（守护进程对 SOCKS 支持因版本而异，常需本地 HTTP 转发）

set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$(id -u)" -ne 0 ]; then
	echo "请使用 root 运行: sudo $0" >&2
	exit 1
fi

PROXY_URL="${PROXY_URL:-socks5h://192.168.3.142:10808}"
NO_PROXY_VALUE="${NO_PROXY_VALUE:-localhost,127.0.0.1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,169.254.0.0/16,::1,docker.internal}"

PROFILE_SH="/etc/profile.d/99-global-proxy.sh"
ENV_CONF="/etc/environment.d/99-global-proxy.conf"

cat >"$PROFILE_SH" <<EOF
# 由 aippt/scripts/install-system-global-proxy.sh 生成 — 可改 PROXY_URL 后重新执行脚本
export http_proxy="${PROXY_URL}"
export https_proxy="${PROXY_URL}"
export HTTP_PROXY="${PROXY_URL}"
export HTTPS_PROXY="${PROXY_URL}"
export ALL_PROXY="${PROXY_URL}"
export all_proxy="${PROXY_URL}"
export NO_PROXY="${NO_PROXY_VALUE}"
export no_proxy="${NO_PROXY_VALUE}"
EOF
chmod 644 "$PROFILE_SH"

mkdir -p /etc/environment.d
cat >"$ENV_CONF" <<EOF
# systemd / 部分显示管理器会读取（需重新登录）
http_proxy=${PROXY_URL}
https_proxy=${PROXY_URL}
HTTP_PROXY=${PROXY_URL}
HTTPS_PROXY=${PROXY_URL}
ALL_PROXY=${PROXY_URL}
all_proxy=${PROXY_URL}
NO_PROXY=${NO_PROXY_VALUE}
no_proxy=${NO_PROXY_VALUE}
EOF
chmod 644 "$ENV_CONF"

echo "[install-global-proxy] 已写入:"
echo "  $PROFILE_SH"
echo "  $ENV_CONF"
echo "[install-global-proxy] PROXY_URL=$PROXY_URL"

# Git（写入调用 sudo 的用户，而非 root）
if [ -n "${SUDO_USER:-}" ] && id "$SUDO_USER" &>/dev/null; then
	sudo -u "$SUDO_USER" -H git config --global http.proxy "$PROXY_URL"
	sudo -u "$SUDO_USER" -H git config --global https.proxy "$PROXY_URL"
	echo "[install-global-proxy] 已为用户 $SUDO_USER 设置 git global http(s).proxy"
fi

# Docker 守护进程：官方文档推荐 HTTP/HTTPS；若 PROXY_URL 为 socks，请改用本地 HTTP 代理或 privoxy
DOCKER_DROPIN="/etc/systemd/system/docker.service.d/http-proxy.conf"
if [ -d /etc/systemd/system ] && systemctl list-unit-files docker.service &>/dev/null; then
	mkdir -p "$(dirname "$DOCKER_DROPIN")"
	cat >"$DOCKER_DROPIN" <<EOF
[Service]
Environment="HTTP_PROXY=${PROXY_URL}"
Environment="HTTPS_PROXY=${PROXY_URL}"
Environment="NO_PROXY=${NO_PROXY_VALUE}"
EOF
	chmod 644 "$DOCKER_DROPIN"
	systemctl daemon-reload
	if systemctl is-active --quiet docker 2>/dev/null; then
		systemctl restart docker
		echo "[install-global-proxy] 已更新 Docker 守护进程代理并重启 docker"
	else
		echo "[install-global-proxy] 已写入 Docker drop-in；docker 未运行，启动时会生效"
	fi
else
	echo "[install-global-proxy] 未检测到 docker.service，跳过 Docker 配置"
fi

echo "[install-global-proxy] 完成。请重新登录终端/桌面会话，或执行: source $PROFILE_SH"
