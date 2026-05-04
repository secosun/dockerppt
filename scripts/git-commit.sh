#!/usr/bin/env bash
set -e

# AI PPT 代码提交脚本
# 用法: ./scripts/git-commit.sh [提交描述]

cd "$(dirname "$0")/.."

# 检查 git 状态
echo "=== 当前 Git 状态 ==="
git status --short
echo ""

# 定义默认提交信息
DEFAULT_MSG="feat(架构): 移除 Gateway 内嵌 ppt-orchestrator，改用外部 LangGraph API

变更内容:
- docker-compose.yml:
  - 设置 OPENCLAW_GATEWAY_EMBEDDED_AGENT_DISABLED=1 禁用内嵌 Agent
  - 设置 OPENCLAW_GATEWAY_ALLOW_EMBEDDED_HTTP_INGRESS=0
  - 设置 OPENCLAW_GATEWAY_SEED_PPT_AGENTS=0 禁用 PPT Agent 注入
  - 更新架构说明文档

- openclawcluster/docker/distributed-dev-gateway-default-agents.json:
  - 清空 agents.list，移除 ppt-orchestrator 默认配置

架构变更:
- ✅ Gateway 仅作为纯 API 网关，不运行任何 Agent 推理
- ✅ 所有 PPT 生成通过外部 ppt-langgraph API (8000) 处理
- ✅ 已通过完整销毁-重建验证"

# 使用用户提供的信息或默认信息
COMMIT_MSG="${1:-$DEFAULT_MSG}"

echo ""
echo "=== 即将提交的变更 ==="
git diff --stat
echo ""

read -p "是否继续提交? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "已取消提交"
    exit 0
fi

# 提交代码
echo ""
echo "正在提交..."
git add -A
git commit -m "$COMMIT_MSG"

echo ""
echo "✅ 提交完成!"
echo ""
echo "如需推送到远程，请执行:"
echo "  git push origin main"
