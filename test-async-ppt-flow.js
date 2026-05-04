/**
 * 测试 PPT 异步任务流程（Gateway → LangGraph 异步任务）
 * 用法: node test-async-ppt-flow.js
 */

const BASE_URL = "http://127.0.0.1:8000";
const TOPIC = "河南农产品通过B2C直销到消费者手中的可行性分析";

async function sleep(seconds) {
  return new Promise(r => setTimeout(r, seconds * 1000));
}

async function submitJob(topic, slideCount) {
  console.log(`📤 提交任务: ${topic} (${slideCount}页)`);
  const res = await fetch(`${BASE_URL}/v1/ppt/jobs`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      topic,
      slide_count: slideCount,
      audience: "企业管理层和技术团队",
      user_message: "生成PPT",
      materialize: true,
    }),
  });

  const data = await res.json();
  console.log(`✅ 任务已提交: taskId=${data.task_id}, pollInterval=${data.poll_interval_seconds}s`);
  return data;
}

async function pollStatus(taskId, pollInterval) {
  console.log(`\n🔄 开始轮询状态...\n`);
  const startTime = Date.now();
  let lastStep = "";

  while (true) {
    const res = await fetch(`${BASE_URL}/v1/ppt/jobs/${taskId}/status`);
    const status = await res.json();

    // 仅在步骤变化时输出，避免刷屏
    if (status.current_step !== lastStep) {
      lastStep = status.current_step;
      const elapsed = Math.floor((Date.now() - startTime) / 1000);
      console.log(
        `[${String(elapsed).padStart(3)}s] ` +
        `进度: ${String(status.progress).padStart(3)}% | ` +
        `步骤: ${status.current_step}`
      );
    }

    // 完成
    if (status.is_completed) {
      const elapsed = Math.floor((Date.now() - startTime) / 1000);
      console.log(`\n🎉 任务完成！`);
      console.log(`   总耗时: ${elapsed} 秒`);
      console.log(`   PPT 页数: ${status.slide_count}`);
      console.log(`   下载地址: ${status.download_url}`);
      return status;
    }

    // 失败
    if (status.is_failed) {
      console.log(`\n❌ 任务失败: ${status.error}`);
      return status;
    }

    await sleep(pollInterval);
  }
}

async function main() {
  console.log("=".repeat(60));
  console.log("PPT 异步任务流程测试");
  console.log("=".repeat(60) + "\n");

  try {
    // Step 1: 提交任务
    const submitResult = await submitJob(TOPIC, 15);

    // Step 2: 轮询状态
    await pollStatus(submitResult.task_id, submitResult.poll_interval_seconds);

    console.log("\n" + "=".repeat(60));
    console.log("测试通过！异步任务 + 轮询模式工作正常 ✅");
    console.log("=".repeat(60));
  } catch (e) {
    console.error("\n❌ 测试失败:", e.message);
    process.exit(1);
  }
}

main();
