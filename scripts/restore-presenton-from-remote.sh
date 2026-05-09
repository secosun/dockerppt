#!/usr/bin/env bash
# 经 192.168.3.142 SOCKS 从 GitHub 恢复 presenton 子模块（HTTPS + 代理，避免直连 SSH）。
# 用法（在 aippt 仓库根目录）:
#   bash scripts/restore-presenton-from-remote.sh
# 或先赋权再直接执行:
#   chmod +x scripts/restore-presenton-from-remote.sh
#   ./scripts/restore-presenton-from-remote.sh
# 覆盖代理:
#   PRESENTON_PROXY=socks5h://127.0.0.1:10808 bash scripts/restore-presenton-from-remote.sh
#
# 说明: 父仓库可能记录提交 569714f...，若该提交不在公开远端，检出的是 origin 默认分支当前 HEAD，
#       与父仓库 gitlink 不一致时需在父仓库更新 submodule 指针或换含该提交的镜像。

set -euo pipefail
cd "$(dirname "$0")/.."

PROXY="${PRESENTON_PROXY:-socks5h://192.168.3.142:10808}"

_git_clone() {
	git \
		-c "url.https://github.com/.insteadOf=git@github.com:" \
		-c "http.proxy=${PROXY}" \
		-c "https.proxy=${PROXY}" \
		-c "http.version=HTTP/1.1" \
		-c "http.postBuffer=524288000" \
		"$@"
}

echo "[restore-presenton] 代理: ${PROXY}"

git submodule deinit -f presenton 2>/dev/null || true
rm -rf presenton .git/modules/presenton

echo "[restore-presenton] 克隆 secosun/presenton ..."
_git_clone clone --progress https://github.com/secosun/presenton.git presenton

echo "[restore-presenton] 接子模块目录 ..."
mv presenton/.git .git/modules/presenton
printf 'gitdir: ../.git/modules/presenton\n' >presenton/.git
git config -f .git/modules/presenton/config core.worktree ../../../presenton
git submodule init presenton

echo "[restore-presenton] 完成."
git submodule status presenton
(cd presenton && git rev-parse HEAD && test -f Dockerfile && echo "[restore-presenton] Dockerfile 存在。")
