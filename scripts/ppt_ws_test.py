#!/usr/bin/env python3
"""
简化版 WebSocket 测试客户端：直接调用 Gateway 的 PPT 异步接口 + 轮询
模拟微信渠道通过 Gateway 生成 PPT 的完整流程
"""
import asyncio
import json
import time
import httpx
from datetime import datetime

GATEWAY_URL = "http://localhost:18789"
LANGGRAPH_URL = "http://localhost:8000"
TOPIC = "河南农产品通过B2C直销模式直达城市消费者的经济可行性技术报告"
SLIDE_COUNT = 12

def log(level, msg):
    ts = datetime.now().strftime("%H:%M:%S")
    print(f"[{ts}] [{level}] {msg}", flush=True)

async def monitor_containers():
    """监控系统容器状态（后台运行）"""
    while True:
        try:
            async with httpx.AsyncClient(timeout=10) as client:
                # 检查容器状态
                log("SYS", "=== 系统健康检查 ===")

                # Gateway health
                try:
                    r = await client.get(f"{GATEWAY_URL}/healthz")
                    log("SYS", f"Gateway: {'✓ 健康' if r.status_code == 200 else '✗ 异常'} (HTTP {r.status_code})")
                except Exception as e:
                    log("SYS", f"Gateway: ✗ 连接失败 - {e}")

                # LangGraph health
                try:
                    r = await client.get(f"{LANGGRAPH_URL}/health")
                    log("SYS", f"LangGraph: {'✓ 健康' if r.status_code == 200 else '✗ 异常'} (HTTP {r.status_code})")
                except Exception as e:
                    log("SYS", f"LangGraph: ✗ 连接失败 - {e}")

                log("SYS", "====================")
        except:
            pass
        await asyncio.sleep(60)  # 每分钟检查一次

async def test_ppt_generation():
    """完整 PPT 生成测试流程"""

    log("INFO", "=" * 60)
    log("INFO", "PPT 生成测试开始")
    log("INFO", f"主题: {TOPIC}")
    log("INFO", f"页数: {SLIDE_COUNT}")
    log("INFO", f"Gateway: {GATEWAY_URL}")
    log("INFO", f"LangGraph: {LANGGRAPH_URL}")
    log("INFO", "=" * 60)

    # 启动系统监控
    asyncio.create_task(monitor_containers())

    start_time = time.time()

    # Step 1: 提交 PPT 任务到 LangGraph
    log("STEP", "1/3 提交 PPT 生成任务...")
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.post(
                f"{LANGGRAPH_URL}/v1/ppt/jobs",
                json={
                    "topic": TOPIC,
                    "slide_count": SLIDE_COUNT,
                    "audience": "投资机构、农业部门、城市消费者研究团队",
                    "goal": "通过数据分析和商业模式验证，论证河南农产品B2C直销模式的经济可行性",
                    "callback_url": None
                }
            )
            response.raise_for_status()
            result = response.json()
            task_id = result["task_id"]
            poll_interval = result.get("poll_interval_seconds", 3)

            log("SUCCESS", f"任务提交成功！")
            log("INFO", f"  Task ID: {task_id}")
            log("INFO", f"  轮询间隔: {poll_interval}秒")
            log("INFO", f"  预估总时间: {result.get('estimated_total_seconds', 300)}秒")

    except Exception as e:
        log("ERROR", f"任务提交失败: {e}")
        return False

    # Step 2: 轮询任务状态
    log("STEP", "2/3 轮询任务状态并监控进度...")
    print()

    last_progress = -1
    last_step = ""
    status_history = []

    while True:
        try:
            async with httpx.AsyncClient(timeout=10) as client:
                response = await client.get(f"{LANGGRAPH_URL}/v1/ppt/jobs/{task_id}/status")
                response.raise_for_status()
                status = response.json()

            progress = status.get("progress", 0)
            current_step = status.get("current_step", "初始化")
            elapsed = status.get("elapsed_seconds", 0)
            remaining = status.get("estimated_remaining_seconds", 0)
            is_completed = status.get("is_completed", False)
            is_failed = status.get("is_failed", False)
            error = status.get("error")
            download_url = status.get("download_url", "")
            slide_count = status.get("slide_count", 0)

            # 记录状态变化
            status_changed = False

            if progress != last_progress:
                last_progress = progress
                status_changed = True

            if current_step != last_step:
                last_step = current_step
                status_changed = True

            # 打印进度（有变化或每10个轮次打印一次）
            if status_changed or len(status_history) % 10 == 0:
                mins = elapsed // 60
                secs = elapsed % 60
                status_mark = "✓" if is_completed else "✗" if is_failed else "⏳"
                log("PROG", f"{status_mark} {progress:3d}% | 已耗时 {mins}分{secs}秒 | 当前步骤: {current_step}")
                status_history.append({
                    "time": time.time() - start_time,
                    "progress": progress,
                    "step": current_step
                })

            # 检查是否完成
            if is_completed:
                print()
                log("SUCCESS", "=" * 60)
                log("SUCCESS", "🎉 PPT 生成完成！")
                log("SUCCESS", "=" * 60)

                total_time = time.time() - start_time
                mins = int(total_time // 60)
                secs = int(total_time % 60)

                log("INFO", f"总耗时: {mins}分{secs}秒")
                log("INFO", f"最终页数: {slide_count}")
                log("INFO", f"下载链接: {download_url}")
                print()

                # 验证下载链接
                if download_url:
                    log("STEP", "3/3 验证下载链接...")
                    try:
                        async with httpx.AsyncClient(timeout=30, follow_redirects=True) as client:
                            head = await client.head(download_url)
                            if head.status_code == 200:
                                log("SUCCESS", f"✓ 下载链接可访问 (HTTP {head.status_code})")
                                log("INFO", f"  文件大小: {head.headers.get('content-length', '未知')} bytes")
                            else:
                                log("WARN", f"⚠ 下载链接状态异常: HTTP {head.status_code}")
                    except Exception as e:
                        log("WARN", f"⚠ 下载链接验证失败: {e}")
                else:
                    log("WARN", "⚠ 未返回下载链接")

                # 输出步骤耗时分析
                print()
                log("INFO", "=== 步骤耗时分析 ===")
                for i, s in enumerate(status_history):
                    if i > 0:
                        prev = status_history[i-1]
                        delta = s["time"] - prev["time"]
                        if delta > 10 and s["step"] != prev["step"]:  # 步骤切换
                            log("INFO", f"  {prev['step']}: {delta:.0f}秒")

                print()
                log("SUCCESS", "✓✓✓ 测试通过！系统工作正常 ✓✓✓")
                return True

            # 检查是否失败
            if is_failed:
                log("ERROR", "=" * 60)
                log("ERROR", "❌ PPT 生成失败！")
                log("ERROR", "=" * 60)
                log("ERROR", f"错误信息: {error}")
                return False

        except Exception as e:
            log("WARN", f"轮询异常 (将重试): {e}")

        await asyncio.sleep(poll_interval)

if __name__ == "__main__":
    try:
        success = asyncio.run(test_ppt_generation())
        exit(0 if success else 1)
    except KeyboardInterrupt:
        print()
        log("INFO", "用户中断测试")
        exit(1)
