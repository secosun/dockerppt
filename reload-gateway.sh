#!/bin/bash
# Gateway 开发模式热重载脚本
# 用法：./reload-gateway.sh [--build]
#   --build: 先执行 pnpm build（默认跳过构建，直接重启）

set -e

PROJECT_DIR="/home/sunxike/lpls/aippt/openclawcluster"
CONTAINER_NAME="aippt-gateway"

echo "🔄 Gateway 热重载开始..."

# 可选：执行构建
if [ "$1" = "--build" ] || [ "$1" = "-b" ]; then
  echo "🔨 正在构建 TypeScript..."
  cd "$PROJECT_DIR"
  pnpm build 2>&1 | tail -10
  echo "✅ 构建完成！"
fi

# 重启容器
echo "🔄 重启 Gateway 容器..."
docker restart $CONTAINER_NAME

# 等待健康检查
sleep 3

# 显示状态
echo ""
echo "📊 容器状态："
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep gateway

echo ""
echo "📝 最新日志："
docker logs --tail 20 $CONTAINER_NAME 2>&1 | tail -10

echo ""
echo "✅ Gateway 热重载完成！"
