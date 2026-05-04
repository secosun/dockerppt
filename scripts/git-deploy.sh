#!/usr/bin/env bash
set -e

# AI PPT 代码提交并推送脚本（支持 Git 子模块）
# 用法: ./scripts/git-deploy.sh [分支名]

cd "$(dirname "$0")/.."

BRANCH="${1:-main}"

echo "=========================================="
echo "  AI PPT Git 部署脚本（含子仓库）"
echo "=========================================="
echo ""
echo "当前分支: $(git rev-parse --abbrev-ref HEAD)"
echo "目标分支: $BRANCH"
echo ""

# 检查是否存在 Git 子模块或嵌套的独立 Git 仓库
# 支持两种模式：1) git submodule 管理  2) 嵌套独立 Git 仓库
HAS_SUBMODULES=0
SUBMODULES=""

# 方式1: 检查 .gitmodules 配置的正式子模块
if [ -f .gitmodules ]; then
    SUBMODULES=$(git config --file .gitmodules --get-regexp path | awk '{print $2}')
fi

# 方式2: 检查常见子目录是否为独立 Git 仓库（嵌套仓库）
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
    echo "检测到嵌套 Git 子仓库:"
    echo "$SUBMODULES" | sed 's/^/  - /'
    echo ""
fi

# 检查 git 状态
if [ -n "$(git status --porcelain)" ]; then
    echo "检测到未提交的变更:"
    git status --short
    echo ""

    read -p "是否提交这些变更? (y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # 调用提交脚本（会自动处理子模块）
        "$(dirname "$0")/git-commit.sh"
    else
        echo "已取消"
        exit 0
    fi
else
    echo "没有未提交的变更"
fi

# ========== 推送子模块 ==========
if [ $HAS_SUBMODULES -eq 1 ]; then
    echo ""
    echo "=========================================="
    echo "正在推送子模块..."
    for sm in $SUBMODULES; do
        if [ -d "$sm" ]; then
            echo ""
            echo "推送子模块: $sm"
            cd "$sm"
            # 检查子模块是否有需要推送的提交
            SM_BRANCH=$(git rev-parse --abbrev-ref HEAD)
            SM_COMMITS=$(git log origin/"$SM_BRANCH"..HEAD 2>/dev/null || true)
            if [ -n "$SM_COMMITS" ]; then
                echo "  待推送的提交:"
                echo "$SM_COMMITS" | head -3 | sed 's/^/    /'
                git push origin "$SM_BRANCH"
                echo "  ✅ $sm 推送完成"
            else
                echo "  ✅ $sm 无待推送内容"
            fi
            cd ..
        fi
    done
    echo ""
    echo "✅ 所有子模块推送完成"
fi

# ========== 推送主项目 ==========
echo ""
echo "=========================================="
echo "正在推送主项目: origin/$BRANCH ..."
git push origin "$BRANCH"

echo ""
echo "=========================================="
echo "✅ 全部部署完成!"
echo "=========================================="
echo ""
git log -1 --oneline
echo ""

# 推送成功提示
if [ $HAS_SUBMODULES -eq 1 ]; then
    echo "已同时推送: 主项目 + 所有子模块"
else
    echo "已推送: 主项目"
fi
