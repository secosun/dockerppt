# AI PPT 统一部署

一键部署完整的 AI PPT 生成系统：OpenClaw Gateway + Presenton + PPT LangGraph

## 架构概览

```
用户 → 微信/浏览器
  ↓
OpenClaw Gateway (:18789)  ← 内嵌 Agent 推理
  ↓
PPT LangGraph (:8000)      ← Presenton (:5000)
  ↓                            ↓
Redis (:6379)              Docling (:8001)
```

## 组件说明

| 服务 | 端口 | 说明 |
|------|------|------|
| **redis** | 6379 | 共享 Redis (Presenton RQ, 缓存) |
| **docling-service** | 8001 | Presenton 文档解析服务 |
| **presenton** | 5000 | PPT 渲染引擎 (MD → PPTX) |
| **ppt-langgraph** | 8000 | PPT 多智能体推理引擎 |
| **openclaw-gateway** | 18789 | OpenClaw 统一网关 (内嵌 Agent 推理) |

## 快速开始

### 0. 克隆仓库（含子模块）

本项目使用 Git Submodule 管理三个子仓库，请使用以下方式克隆：

```bash
# 方式一：一次性克隆所有子模块（推荐）
git clone --recursive git@github.com:secosun/dockerppt.git aippt
cd aippt

# 方式二：分步克隆
git clone git@github.com:secosun/dockerppt.git aippt
cd aippt
git submodule update --init --recursive

# 后续更新子模块到最新版本
git submodule update --remote --merge
```

### 子模块说明

| 子模块 | 仓库 | 说明 |
|--------|------|------|
| `openclawcluster/` | `secosun/openclawcluster.git` | OpenClaw Gateway 统一入口 |
| `peip_inference_interface/` | `secosun/pptagents.git` | PPT LangGraph 多智能体推理引擎 |
| `presenton/` | `secosun/presenton.git` | PPT 渲染引擎 (MD → PPTX) |

**布局约定**：上述三者均为 **aippt 仓库的直接子模块**，在根目录下**并列**（同级目录），由本仓库的 `.gitmodules` 统一登记。`peip_inference_interface` 与 `presenton` **不要**再作为子模块嵌套进 `openclawcluster/`（避免重复检出与路径混乱）。各子仓库若还有其它依赖，可在**各自仓库内**单独维护子模块；初始化时使用 `git submodule update --init --recursive` 会按各子仓库自己的 `.gitmodules` 继续向下拉取。

### 1. 环境配置

```bash
cp .env.example .env
# 编辑 .env，填入 LLM API Key
```

**最少配置** (必填):
- `ANTHROPIC_API_KEY` / `ANTHROPIC_AUTH_TOKEN` - Anthropic/火山引擎 API Key
- `ANTHROPIC_BASE_URL` - 兼容端点 (如 https://ark.cn-beijing.volces.com/api/coding)
- `ANTHROPIC_MODEL` - 模型名称 (如 ark-code-latest)

### 2. 构建并启动

```bash
# 构建所有镜像
docker compose build

# 后台启动
docker compose up -d

# 查看日志
docker compose logs -f
```

## 开发模式与热重载

> ⚠️ **重要经验**：直接 `docker compose up -d` 不会挂载本地代码！
> 容器运行的是镜像构建时的旧版本，本地编译不生效。

### 启用热开发模式

```bash
# 方式一：完整热开发环境（推荐）
./scripts/hot-dev-start.sh

# 方式二：仅 Gateway 启用热挂载
docker rm -f aippt-gateway
docker-compose -f docker-compose.yml -f docker-compose.hot.yml up -d openclaw-gateway
```

### 开发工作流

| 修改内容 | 生效方式 |
|---------|---------|
| Python (LangGraph/Worker) | 🔄 自动重载 (uvicorn --reload / watchmedo) |
| TypeScript (Gateway) | 手动执行 `./scripts/hot-reload-gateway.sh` 编译并重启 |

### 验证热挂载生效

```bash
# 检查容器内 dist 时间戳与本地一致
docker exec aippt-gateway ls -la /app/dist/ | head -5

# 确认 volume 挂载
docker inspect aippt-gateway | grep -E 'dist|Source' | head -5
```

### 3. 验证部署

```bash
# 检查服务健康状态
docker compose ps

# 测试 PPT 生成
curl http://localhost:8000/health
```

## 常用命令

```bash
# 启动服务
docker compose up -d

# 停止服务
docker compose down

# 停止并删除数据卷
docker compose down -v

# 查看日志
docker compose logs -f
docker compose logs -f presenton
docker compose logs -f ppt-langgraph
docker compose logs -f openclaw-gateway

# 重启单个服务
docker compose restart ppt-langgraph

# 重新构建并启动
docker compose up -d --build ppt-langgraph
```

## 端口映射

| 宿主机端口 | 容器内端口 | 服务 |
|-----------|-----------|------|
| 18789 | 18789 | OpenClaw Gateway |
| 8000 | 8000 | PPT LangGraph 推理引擎 |
| 5000 | 80 | Presenton PPT 渲染 |
| 1455 | 1455 | Codex OAuth |
| 8001 | 8001 | Presenton MCP Server |

## 服务间通信 (Docker 内网)

服务间通过 Docker 网络 `aippt-internal` 通信：

- PPT LangGraph → Presenton: `http://presenton:80`
- 所有服务 → Redis: `redis://redis:6379/0`
- Presenton → Docling: `http://docling-service:8001`

## 数据持久化

| Volume | 说明 |
|--------|------|
| `presenton-redis-data` | Presenton Redis 数据 |
| `presenton-app-data` | Presenton 应用数据 (数据库等) |
| `openclaw-gateway-config` | Gateway 配置 |
| `openclaw-workspace` | 共享工作区 |
| `ppt-outputs` | PPT 生成输出文件 |

## 开发调试

```bash
# 进入容器
docker compose exec ppt-langgraph bash
docker compose exec openclaw-gateway bash

# 手动测试 API
curl -X POST http://localhost:8000/v1/ppt/generate \
  -H "Content-Type: application/json" \
  -d '{"topic": "测试", "slide_count": 5}'
```

## 性能优化建议

1. **资源分配** - 为 Docker 分配至少 8GB 内存、4 核 CPU
2. **模型服务** - 优先使用火山引擎 Ark 或阿里云灵积，低延迟高并发
3. **Redis** - 生产环境建议独立 Redis 实例，启用持久化
4. **日志级别** - 生产环境可调整日志级别为 WARN/ERROR，减少 IO

## 故障排查

### 1. 容器启动失败

```bash
# 查看具体错误
docker compose logs ppt-langgraph
```

常见原因:
- 缺少必填环境变量 (如 API Key)
- 端口冲突 (18789/8000/5000 被占用)
- Docker 资源不足

### 2. PPT 任务卡住不执行

**问题**: Worker 未启动或任务队列异常

```bash
# 检查 Worker 状态
docker compose logs ppt-worker

# 重启 Worker
docker compose restart ppt-worker
```

### 3. LLM 调用失败

检查:
- API Key 是否正确
- 网络是否能访问模型服务
- 环境变量名称是否正确

### 4. PPT 生成超时

- 增加 `OPENCLAW_AGENT_EXECUTOR_TIMEOUT_MS` (建议 ≥ 1200000)
- 检查 LLM 响应速度
- 确认 `slide_count` 不超过合理范围 (建议 ≤ 50)

## PPT Agent 双模式生成

PPT Agent 支持两种模式：

### 模式 A: 需求收集（同步聊天）
- 多轮对话澄清 PPT 需求
- Agent 追问主题、受众、风格、页数等
- Gateway 直接响应：**生成PPT** 触发物化

### 模式 B: 异步生成（任务队列）
- 提交任务立即返回，不阻塞 HTTP
- 实时进度推送（WebSocket）
- 支持：/ 生成/

```mermaid
graph LR
    A[用户] -->|发送 "生成PPT"| B[Gateway]
    B -->|提交异步| C[LangGraph API]
    C -->|存入队列| D[Redis RQ]
    D -->|Worker执行| E[多智能体流水线]
    E -->|进度更新| F[WebSocket 推送]
    E -->|完成| F
```

---

## PPT 异步任务 API

### 提交任务
```bash
curl -X POST http://localhost:8000/v1/ppt/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "topic": "2024年度总结",
    "slide_count": 15,
    "audience": "管理层",
    "callback_url": "http://gateway:18789/gateway/api/v1/ppt/webhook/TASK_ID"
  }'
```

响应：
```json
{
  "task_id": "ppt-abc123def456",
  "status": "queued",
  "poll_interval_seconds": 3
}
```

### 查询状态
```bash
curl http://localhost:8000/v1/ppt/jobs/ppt-abc123def456/status
```

响应：
```json
{
  "task_id": "ppt-abc123def456",
  "status": "running",
  "progress": 35,
  "current_step": "匹配模板库",
  "elapsed_seconds": 45,
  "estimated_remaining_seconds": 120,
  "slide_count": 15,
  "download_url": ""
}
```

### Webhook 回调（可选）

LangGraph 完成后主动推送到 Gateway：
```bash
# 自动回调 URL 端点（可选
```

### 公网下载链接（微信 / 外网用户）

任务完成时 `download_url` 若为 `file:///app/outputs/...`，外网无法打开。请在 `.env` 中配置 **`PPT_OUTPUTS_PUBLIC_BASE_URL`**（LangGraph 服务对外的 `https://域名` 或 `http://IP:端口`，无尾斜杠），与 FastAPI 的 **`/outputs`** 静态挂载拼接后生成可分享链接。说明见 `peip_inference_interface/docs/PRESENTON_DEPLOYMENT_GUIDE.md`（§LangGraph 产物公网下载）。

---

## 开发模式

### 热重载（修改代码立即生效
```bash
# 开发模式启动（代码变更自动重启）
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# 代码变更后：
pnpm build
./openclawcluster/scripts/reload-gateway.sh
```

### 启用 Redis 会话存储（多实例部署）
在 `.env` 中配置：
```bash
# PPT 会话状态存储（支持多实例）
OPENCLAW_PPT_REDIS_URL=redis://redis:6379/0
OPENCLAW_PPT_REDIS_PREFIX=openclaw:ppt:
```

---

## 目录结构

```
aippt/
├── docker-compose.yml       # 统一部署配置
├── docker-compose.dev.yml   # 开发模式配置（热重载）
├── .env.example             # 环境变量示例
├── README.md                # 本文档
├── openclawcluster/         # OpenClaw Gateway + Agent
│   ├── PPT_SESSION_STORE.md  # PPT 会话存储架构文档
│   └── scripts/reload-gateway.sh  # Gateway 热重载脚本
├── presenton/               # Presenton PPT 渲染引擎
└── peip_inference_interface/  # PPT 多智能体推理引擎

---

## ✅ 架构验证完成

### 完成日期
2026年5月4日

### 验证内容

| 功能 | 状态 | 说明 |
|------|------|------|
| **Gateway 纯网关模式** | ✅ | 内嵌 Agent 已完全禁用 (`EMBEDDED_AGENT_DISABLED=1`) |
| **LangGraph 外部执行** | ✅ | 所有 PPT 推理通过 `ppt-langgraph:8000/v1/run-agent` |
| **Redis 会话存储** | ✅ | 支持多实例部署，任务状态持久化 |
| **异步任务 + 轮询模式** | ✅ | 同步调用阻塞问题已解决 |
| **25% 阈值进度推送** | ✅ | 通过 WebSocket 实时推送进度 |
| **用户主动进度查询** | ✅ | 发送"进度"关键字可主动查询 |
| **并行聊天支持** | ✅ | 生成期间可正常进行其他对话 |
| **防重复提交** | ✅ | 同一任务不会重复创建 |
| **完整 PPT 下载** | ✅ | 生成完成后返回可访问的下载链接 |

### PPT 生成流程

```
用户发送 "生成PPT"
    ↓
Gateway 检测 PPT 命令 → 提交异步任务至 LangGraph
    ↓
LangGraph RQ Worker (ppt-worker 容器) 开始执行
    ↓
Gateway 轮询状态 → 每达到25%阈值 → 通过 WebSocket 推送进度
    ↓
用户发送 "进度" → 立即返回当前进度（即时查询）
    ↓
生成完成 → 推送下载链接 (Presenton:5000)
```

### 容器运行清单

| 容器 | 状态 | 端口 | 职责 |
|------|------|------|------|
| `aippt-redis` | ✅ | 6379 | 共享 Redis |
| `aippt-docling` | ✅ | - | 文档解析服务 |
| `aippt-presenton` | ✅ | 5000 | PPT 渲染引擎 |
| `aippt-ppt-langgraph` | ✅ | 8000 | API + 任务提交 |
| `aippt-ppt-worker` | ✅ | - | RQ Worker 执行任务 |
| `aippt-gateway` | ✅ | 18789 | 统一 API/WebSocket 网关 |
```
