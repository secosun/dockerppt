#!/bin/bash
set -e

cd "$(dirname "$0")/.."

SERVICE=${1:-"all"}

if [ "$SERVICE" = "all" ]; then
    echo "📊 查看所有服务日志 (按 Ctrl+C 退出)"
    echo "═══════════════════════════════════════════════════"
    docker-compose -f docker-compose.yml -f docker-compose.hot.yml logs -f --tail=50
else
    echo "📊 查看 $SERVICE 服务日志 (按 Ctrl+C 退出)"
    echo "═══════════════════════════════════════════════════"
    docker-compose -f docker-compose.yml -f docker-compose.hot.yml logs -f --tail=100 "$SERVICE"
fi
