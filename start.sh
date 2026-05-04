#!/bin/bash
# AI PPT 统一部署启动脚本
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================"
echo "  AI PPT 统一部署启动"
echo "========================================"
echo ""

# 检查 .env 文件
if [ ! -f ".env" ]; then
    echo "⚠️  未找到 .env 文件，从 .env.example 创建..."
    cp .env.example .env
    echo "✅ 已创建 .env，请填入 LLM API Key 后重新运行"
    echo ""
    echo "编辑命令: nano .env"
    echo ""
    echo "必填项:"
    echo "  - ANTHROPIC_API_KEY 或 ANTHROPIC_AUTH_TOKEN"
    echo "  - ANTHROPIC_BASE_URL"
    echo "  - ANTHROPIC_MODEL"
    exit 1
fi

# 检查端口是否被占用
echo "🔍 检查端口占用..."
for port in 18789 8000 5000; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "⚠️  端口 $port 已被占用，请先释放"
        lsof -Pi :$port -sTCP:LISTEN
        exit 1
    fi
done
echo "✅ 端口检查通过"
echo ""

# 构建镜像
echo "🔨 构建 Docker 镜像..."
docker compose build

echo ""
echo "🚀 启动服务..."
docker compose up -d

echo ""
echo "⏳ 等待服务就绪 (约 30-60 秒)..."
sleep 10

echo ""
echo "📊 服务状态:"
docker compose ps

echo ""
echo "========================================"
echo "  服务启动中！"
echo "========================================"
echo ""
echo "查看日志: docker compose logs -f"
echo ""
echo "访问地址:"
echo "  - OpenClaw Gateway: http://localhost:18789"
echo "  - PPT LangGraph:   http://localhost:8000/health"
echo "  - Presenton:       http://localhost:5000"
echo ""
echo "停止服务: docker compose down"
echo ""
