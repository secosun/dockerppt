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

### 2. LLM 调用失败

检查:
- API Key 是否正确
- 网络是否能访问模型服务
- 环境变量名称是否正确

### 3. PPT 生成超时

- 增加 `OPENCLAW_AGENT_EXECUTOR_TIMEOUT_MS` (建议 ≥ 1200000)
- 检查 LLM 响应速度
- 确认 `slide_count` 不超过合理范围 (建议 ≤ 50)

## 目录结构

```
aippt/
├── docker-compose.yml       # 统一部署配置
├── .env.example             # 环境变量示例
├── README.md                # 本文档
├── openclawcluster/         # OpenClaw Gateway + Agent
├── presenton/               # Presenton PPT 渲染引擎
└── peip_inference_interface/  # PPT 多智能体推理引擎
```
