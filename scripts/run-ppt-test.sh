#!/usr/bin/env bash
# 简化版：直接调用 tsx，避免 shell JSON 解析问题
set -euo pipefail

cd /home/sunxike/lpls/aippt/openclawcluster

export OPENCLAW_GATEWAY_TOKEN="openclaw-distributed-secret-key"
export GATEWAY_WS_URL="ws://127.0.0.1:18789"
export WEIXIN_SIM_USER_ID="weixin-sim-agricultural-test-$(date +%H%M%S)"
export WEIXIN_SIM_WS_TRACK_PPT=1
export WEIXIN_SIM_WS_PPT_FOLLOWUP_MAX=0
export WEIXIN_SIM_AGENT_WAIT_MS=1800000
export WEIXIN_SIM_WS_VERBOSE_WAIT=1
export WEIXIN_SIM_AGENT_ID="ppt-orchestrator"

# 使用环境变量传JSON会有转义问题，直接写临时文件
cat > /tmp/ppt-rounds.json << 'JSONEOF'
[
  "我想做一份面向投资机构和农业部门的专业汇报PPT。主题是「河南农产品通过B2C直销模式直达城市消费者的经济可行性技术报告」。要求12-15页，覆盖：1）河南省主要农产品品类与产能分析；2）当前传统流通渠道痛点与成本结构；3）B2C直销模式的技术可行性（冷链、物流、溯源）；4）成本收益模型与盈亏平衡点测算；5）目标城市消费群体画像与购买意愿分析；6）风险评估与应对策略。请先给出详细的页面级大纲。本轮仅做需求规划，不要启动物化。",
  "请立即启动多智能体物化流程。生成PPT"
]
JSONEOF

export WEIXIN_SIM_WS_ROUNDS="$(cat /tmp/ppt-rounds.json)"

echo "=== 配置信息 ==="
echo "用户ID: $WEIXIN_SIM_USER_ID"
echo "Gateway: $GATEWAY_WS_URL"
echo ""
echo "=== 发送消息 ==="
echo "$WEIXIN_SIM_WS_ROUNDS" | jq .
echo ""
echo "=== 开始测试 $(date '+%Y-%m-%d %H:%M:%S') ==="
echo ""

# 直接执行
pnpm exec tsx scripts/gateway-weixin-chat-ws-multi.ts
