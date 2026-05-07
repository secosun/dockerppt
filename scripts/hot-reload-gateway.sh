#!/bin/bash
set -e

echo "🔄 热重载 Gateway"
echo "═══════════════════════════════════════════════════"

cd "$(dirname "$0")/../openclawcluster"

# 1. 编译 TypeScript
echo ""
echo "📦 [1/2] 编译 TypeScript..."
pnpm build 2>&1 | tail -10

# 2. 重启 Gateway 容器
echo ""
echo "🔄 [2/2] 重启 Gateway 容器..."
cd ..
docker-compose -f docker-compose.yml -f docker-compose.hot.yml restart openclaw-gateway

# 3. 等待就绪
echo ""
echo "⏳ 等待 Gateway 启动..."
sleep 3

# 检查健康状态
STATUS=$(docker exec aippt-gateway sh -c "curl -s http://localhost:18789/health 2>/dev/null || echo 'not ready'")
echo ""
echo "✅ Gateway 已重启！健康状态: $STATUS"
echo ""
echo "💡 查看日志: ./scripts/hot-dev-logs.sh gateway"
