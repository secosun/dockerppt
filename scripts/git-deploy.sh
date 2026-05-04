#!/usr/bin/env bash
set -e

# AI PPT 代码提交并推送脚本
# 用法: ./scripts/git-deploy.sh [分支名]

cd "$(dirname "$0")/.."

BRANCH="${1:-main}"

echo "=========================================="
echo "  AI PPT Git 部署脚本"
echo "=========================================="
echo ""
echo "当前分支: $(git rev-parse --abbrev-ref HEAD)"
echo "目标分支: $BRANCH"
echo ""

# 检查 git 状态
if [ -n "$(git status --porcelain)" ]; then
    echo "检测到未提交的变更:"
    git status --short
    echo ""

    read -p "是否提交这些变更? (y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # 调用提交脚本
        "$(dirname "$0")/git-commit.sh"
    else
        echo "已取消"
        exit 0
    fi
else
    echo "没有未提交的变更"
fi

echo ""
echo "正在推送到 origin/$BRANCH ..."
git push origin "$BRANCH"

echo ""
echo "✅ 部署完成!"
echo ""
git log -1 --oneline
