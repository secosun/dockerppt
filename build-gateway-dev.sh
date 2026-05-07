#!/bin/bash
# 仅构建 Gateway，不重启容器

set -e

PROJECT_DIR="/home/sunxike/lpls/aippt/openclawcluster"

echo "🔨 构建 Gateway (开发模式)..."
cd "$PROJECT_DIR"
pnpm build 2>&1 | tail -15

echo ""
echo "✅ 构建完成！"
echo "   如需重启容器：./reload-gateway.sh"
echo "   构建并重启：./reload-gateway.sh --build"
