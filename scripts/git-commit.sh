#!/usr/bin/env bash
set -e

# AI PPT 代码提交脚本（支持 Git 子模块）
# 用法: ./scripts/git-commit.sh [提交描述]

cd "$(dirname "$0")/.."

# 检查是否存在 Git 子模块或嵌套的独立 Git 仓库
# 支持两种模式：1) git submodule 管理  2) 嵌套独立 Git 仓库
HAS_SUBMODULES=0
SUBMODULES=""

# 方式1: 检查 .gitmodules 配置的正式子模块
if [ -f .gitmodules ]; then
    SUBMODULES=$(git config --file .gitmodules --get-regexp path | awk '{print $2}')
fi

# 方式2: 检查常见子目录是否为独立 Git 仓库（嵌套仓库）
# 注意：这些目录不是 git submodule，而是独立仓库嵌套在主仓库中
NESTED_REPOS="openclawcluster presenton peip_inference_interface"
for repo in $NESTED_REPOS; do
    if [ -d "$repo/.git" ]; then
        # 避免重复添加
        if ! echo "$SUBMODULES" | grep -q "$repo"; then
            SUBMODULES="$SUBMODULES $repo"
        fi
    fi
done

# 去除首尾空格
SUBMODULES=$(echo "$SUBMODULES" | xargs)

if [ -n "$SUBMODULES" ]; then
    HAS_SUBMODULES=1
fi

# 检查 git 状态
echo "=== 当前 Git 状态 ==="
git status --short
echo ""

if [ $HAS_SUBMODULES -eq 1 ]; then
    echo "=== 检测到 Git 子模块 ==="
    echo "$SUBMODULES"
    echo ""

    # 检查子模块是否有变更
    echo "=== 子模块变更检查 ==="
    SUBMODULE_CHANGES=0
    for sm in $SUBMODULES; do
        if [ -d "$sm" ]; then
            SM_STATUS=$(cd "$sm" && git status --porcelain)
            if [ -n "$SM_STATUS" ]; then
                echo "⚠️  $sm 有未提交的变更:"
                cd "$sm" && git status --short && cd ..
                SUBMODULE_CHANGES=1
            else
                echo "✅ $sm 无变更"
            fi
        fi
    done
    echo ""

    # 如果子模块有变更，询问是否先提交子模块
    if [ $SUBMODULE_CHANGES -eq 1 ]; then
        read -p "检测到子模块变更，是否先提交子模块? (y/N) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for sm in $SUBMODULES; do
                if [ -d "$sm" ]; then
                    SM_STATUS=$(cd "$sm" && git status --porcelain)
                    if [ -n "$SM_STATUS" ]; then
                        echo ""
                        echo "正在提交子模块: $sm"
                        cd "$sm"
                        git add -A
                        git commit -m "chore: 更新子模块" || echo "子模块 $sm 提交跳过"
                        cd ..
                    fi
                fi
            done
            echo ""
            echo "✅ 子模块提交完成"
            echo ""
        fi
    fi
fi

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
echo "=== 即将提交的变更（主项目） ==="
git diff --stat
echo ""

read -p "是否继续提交主项目? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "已取消提交"
    exit 0
fi

# 提交代码（包含子模块更新）
echo ""
echo "正在提交主项目..."
git add -A
git commit -m "$COMMIT_MSG"

echo ""
echo "✅ 提交完成!"
echo ""
echo "如需推送到远程（含子模块），请执行:"
echo "  ./scripts/git-deploy.sh"
