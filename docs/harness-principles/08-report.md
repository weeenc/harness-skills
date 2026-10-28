# 门禁运行摘要 — `scripts/report.sh`

`report.sh` 将最新退出码摘要写入 `.harness/changes/.runtime/<id>/gate-<gate>.md`，不修改持久报告。阶段结束由技能将关键证据写入 report.md；全栈由协调者更新共享报告，旧卡仍兼容原独立报告。

## 调用

```bash
bash .harness/scripts/report.sh coverage C-001 'rc=0'
```

脚本退出码表示记录是否成功，不是门禁结果。调用方必须继续透传真实门禁 rc；不能以 report.sh 返回 0 证明检查通过。

| 参数/情况 | 行为 |
|---|---|
| 显式 ID | 必须有 change.md 或 workspace-change.md；不创建虚构卡片 |
| 未给 ID、唯一活动卡 | 自动选择；跳过 _TEMPLATE |
| 未给 ID、无活动卡 | 提示未生成摘要，返回 0 |
| 未给 ID、多活动卡 | 返回 3，要求显式 ID，禁止取第一项 |
| gate/ID 非法、显式卡片不存在 | 返回 3 |
| 无法写入 | 返回非零 |

## 固定文件与结果状态

每个门禁只更新同一个本地文件，采用临时写入后替换；正常执行不会累积 run-* 目录。自动补充 changes/.gitignore 的 `/.runtime/` 规则，保留其他规则。不复制源码和 diff，不覆盖旧 gate 文件或人工报告。

| 传入 rc | 摘要状态 |
|---|---|
| 0 | PASS |
| 1 | FAIL |
| 2 | DEGRADED |
| 其他、缺失或格式错误 | ERROR |

摘要包含时间、ID、rc 和备注，不包含完整命令或 stdout。阶段报告还必须补齐真实命令、被测代码版本/dirty 范围、关键计数或断言、限制和人工确认。人工复核写持久报告，不追加在自动更新的运行文件里。原始日志按需保存在运行区或稳定制品中。

## 读取与兼容

活动任务先读 `.runtime/<id>/gate-*.md`；不存在时可查旧 `<id>/gate-*.md`，但历史结果不能作为本次执行证据。复盘与跨成员交接读取持久阶段报告，不依赖另一台机器的临时文件。详见 [变更管理](../change-management.md)。
