#!/usr/bin/env bash
# 联调：「河南农产品直销B2C城市消费者经济可行性」主题 WebSocket PPT 生成
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT/openclawcluster"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="/tmp/weixin-ppt-agricultural-${TIMESTAMP}.log"
echo "========================================" >&2
echo "WebSocket 微信渠道 PPT 生成测试" >&2
echo "========================================" >&2
echo "日志文件: $LOG_FILE" >&2
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')" >&2
echo "" >&2

export OPENCLAW_GATEWAY_TOKEN="openclaw-distributed-secret-key"
export GATEWAY_WS_URL="ws://127.0.0.1:18789"
export WEIXIN_SIM_USER_ID="weixin-sim-agricultural-${TIMESTAMP}"
export WEIXIN_SIM_WS_TRACK_PPT=1
export WEIXIN_SIM_WS_PPT_FOLLOWUP_MAX=0
export WEIXIN_SIM_AGENT_WAIT_MS=1800000  # 30分钟
export WEIXIN_SIM_WS_VERBOSE_WAIT=1
export WEIXIN_SIM_AGENT_ID="ppt-orchestrator"

echo "配置：" >&2
echo "  - 会话用户: $WEIXIN_SIM_USER_ID" >&2
echo "  - 等待超时: 30分钟" >&2
echo "  - Gateway: $GATEWAY_WS_URL" >&2
echo "" >&2

# 测试轮次：两轮模式
# Round 1: 需求收集
# Round 2: 触发物化生成
export WEIXIN_SIM_WS_ROUNDS='[
  "我想做一份面向投资机构和农业部门的专业汇报PPT。主题是「河南农产品通过B2C直销模式直达城市消费者的经济可行性技术报告」。要求15-20页，覆盖：1）河南省主要农产品品类与产能分析；2）当前传统流通渠道痛点与成本结构；3）B2C直销模式的技术可行性（冷链、物流、溯源）；4）成本收益模型与盈亏平衡点测算；5）目标城市消费群体画像与购买意愿分析；6）风险评估与应对策略；7）试点方案与实施路线图。风格要求：数据驱动，所有关键数据需标注来源，多用图表（成本结构对比图、物流时效地图、盈亏平衡分析模型）。请先给出详细的页面级大纲，明确列出每页的核心信息点和建议的图表类型。本轮仅做需求规划，不要启动物化。',
  "请立即启动多智能体物化流程。按顺序执行：knowledge知识检索→template模板匹配→data数据生成→material素材搜索→presenton渲染。每完成一步用 ✓ 汇报进度。生成PPT"
]'

echo "主题：河南农产品直销B2C城市消费者经济可行性技术报告" >&2
echo "页数：15-20页" >&2
echo "受众：投资机构、农业部门" >&2
echo "轮次：2轮（需求收集 + 物化生成）" >&2
echo "" >&2
echo "========================================" >&2
echo "开始执行时间: $(date '+%Y-%m-%d %H:%M:%S')" >&2
echo "========================================" >&2
echo "" >&2

# 记录开始时间
START_TIME=$(date +%s)

# 启动后台监控：实时查看容器日志
echo "=== 启动系统监控 ===" >&2
echo "" >&2

# 在后台打印关键容器日志
(
  while true; do
    sleep 60
    ELAPSED=$(( $(date +%s) - START_TIME ))
    echo "" >&2
    echo ">>> [系统监控] 已运行 ${ELAPSED} 秒 <<<" >&2
    echo ">>> [系统监控] Gateway 最近5条日志 <<<" >&2
    docker logs --tail 5 aippt-gateway 2>&1 | grep -E "(ppt|progress|error|Error|warn)" | tail -5 >&2 || true
    echo ">>> [系统监控] LangGraph 最近5条日志 <<<" >&2
    docker logs --tail 5 aippt-ppt-langgraph 2>&1 | grep -E "(task|progress|error|Error|warn)" | tail -5 >&2 || true
    echo ">>> [系统监控] Worker 最近5条日志 <<<" >&2
    docker logs --tail 5 aippt-ppt-worker 2>&1 | grep -E "(ppt|task|progress|error|Error|warn|execute)" | tail -5 >&2 || true
    echo "" >&2
  done
) &
MONITOR_PID=$!

# 清理函数
cleanup() {
  kill $MONITOR_PID 2>/dev/null || true
  echo "" >&2
  echo "========================================" >&2
  echo "测试结束" >&2
  END_TIME=$(date +%s)
  TOTAL=$(( END_TIME - START_TIME ))
  echo "总耗时: $(( TOTAL / 60 ))分$(( TOTAL % 60 ))秒" >&2
  echo "完整日志: $LOG_FILE" >&2
  echo "========================================" >&2
}
trap cleanup EXIT

# 启动主测试
echo "=== 启动 WebSocket 客户端 ===" >&2
echo "" >&2

exec stdbuf -oL pnpm exec tsx scripts/gateway-weixin-chat-ws-multi.ts 2>&1 | tee "$LOG_FILE" | while IFS= read -r line; do
    # 实时分析输出
    if echo "$line" | grep -q "⏳.*PPT 生成中\|进度.*%"; then
        echo ">>> [进度推送] $line" >&2
    fi
    if echo "$line" | grep -q "✓.*完成\|完成.*✓"; then
        STEP_TIME=$(date +%s)
        ELAPSED=$(( STEP_TIME - START_TIME ))
        echo ">>> [步骤完成] 已用时 ${ELAPSED}秒 - $line" >&2
    fi
    if echo "$line" | grep -q "download_url\|http.*\.pptx\|exports/"; then
        echo ">>> [成功] 🎉 检测到 PPT 下载链接！" >&2
        echo ">>> [成功] $line" >&2
    fi
    if echo "$line" | grep -qi "error\|失败\|异常\|timeout"; then
        echo ">>> [错误] ❌ $line" >&2
    fi
    if echo "$line" | grep -q "ppt-knowledge\|ppt-template\|ppt-data\|ppt-material\|ppt-presenton"; then
        echo ">>> [子Agent] 🤖 $line" >&2
    fi
    # 原输出上屏
    echo "$line"
done
