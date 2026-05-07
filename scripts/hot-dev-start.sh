#!/bin/bash
set -e

echo "🔥 启动 PPT 热开发环境"
echo "═══════════════════════════════════════════════════"

# 1. 先确保有编译好的代码
echo ""
echo "📦 [1/4] 编译 TypeScript 代码..."
cd openclawcluster
pnpm build 2>&1 | tail -5
cd ..

# 2. 停止旧容器
echo ""
echo "🛑  [2/4] 停止旧容器..."
docker-compose -f docker-compose.yml -f docker-compose.hot.yml down 2>/dev/null || true

# 3. 启动热开发模式
echo ""
echo "🚀 [3/4] 启动热开发容器..."
docker-compose -f docker-compose.yml -f docker-compose.hot.yml up -d

# 4. 等待服务就绪
echo ""
echo "⏳ [4/4] 等待服务启动..."
sleep 5

# 检查服务状态
echo ""
echo "📊 服务状态:"
docker-compose -f docker-compose.yml -f docker-compose.hot.yml ps

echo ""
echo "═══════════════════════════════════════════════════"
echo "✅ 热开发环境已启动！"
echo ""
echo "📝 开发工作流:"
echo "  ├── 修改 Python 代码 → 自动重载 (uvicorn --reload / watchmedo)"
echo "  ├── 修改 TypeScript 代码 → ./scripts/hot-reload-gateway.sh"
echo "  └── 查看日志 → ./scripts/hot-dev-logs.sh"
echo ""
echo "🔍 常用命令:"
echo "  ./scripts/hot-dev-logs.sh openclaw-gateway     # 查看 Gateway 日志"
echo "  ./scripts/hot-dev-logs.sh langgraph   # 查看 LangGraph 日志"
echo "  ./scripts/hot-dev-logs.sh worker      # 查看 Worker 日志"
echo "  ./scripts/hot-reload-gateway.sh       # 编译并重启 Gateway"
echo ""
echo "🌐 服务端点:"
echo "  • Gateway:  http://localhost:18789"
echo "  • LangGraph: http://localhost:8000"
echo "  • Presenton: http://localhost:8001"
echo "═══════════════════════════════════════════════════"
