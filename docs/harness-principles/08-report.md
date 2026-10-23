# 门禁证据落盘 — `scripts/report.sh`

## 一、用途

把一次门禁执行的结果写成**可对账审计的 markdown 证据**：
`.harness/changes/<id>/gate-<gate>.md`。`harness-status` / `harness-quality` / `harness-retro`
都靠这些文件做阶段对账——**没有证据，等于没跑门禁**。

## 二、调用方式

```bash
bash .harness/scripts/report.sh <gate> [change-id] [备注...]
# 备注约定：rc=<数字> 会被解析为门禁退出码（见四）；其他文本进"备注"栏
```

每个 gate 脚本末尾统一这样调（rc 透传）：

```bash
"$(dirname "${BASH_SOURCE[0]}")/report.sh" "$GATE_NAME" "$CHANGE_ID" "rc=$rc" >/dev/null 2>&1 || true
```

> `|| true`：证据落盘失败不阻塞门禁本身（门禁结果以退出码为准，证据是审计附加物）。

## 三、运行原理

1. **解析 gate / change-id / 备注**。
2. **自动选 change**：change-id 缺省时，在 `.harness/changes/*/change.md` 里找第一个
   `status:` 为 `coding|testing|reviewing|ci|verifying` 的变更目录（流程中才记录，已关单的不记）。
   找不到 → stderr `[report] 未找到流程中的 change，证据未落盘` 并 `exit 0`（不是错误，只是没证据可挂）。
3. **落盘**：`mkdir -p changes/<id>` 后写 `gate-<gate>.md`，内容模板见四。

## 四、输出（证据文件结构）

```markdown
# 门禁证据: check-style

- 变更: `c1`
- 时间: 2026-10-11 12:00:00
- 结果: rc=1
- 状态: **FAIL（红灯，禁止进入下一阶段）**
- 备注: rc=1

> 本文件由 .harness/scripts/report.sh 自动生成，供对账审计；人工复核结论请追加在下方。
```

状态映射（由 rc 决定）：

| rc | 状态行 |
|---|---|
| 2 | `**DEGRADED（工具未安装，降级人工核对）**` |
| 1 | `**FAIL（红灯，禁止进入下一阶段）**` |
| 其余/未知 | `PASS`（备注缺省 rc=unknown 时也能落盘） |

## 五、结果不满足时如何报错

- **不满足 = 证据文件里 rc≠0**：对账工具读 `gate-<gate>.md` 的 `- 结果:` 与 `- 状态:` 行，
  发现 FAIL/DEGRADED 即判定该阶段未通过（DEGRADED 需人工在文件下方追加复核结论才能算关账）。
- report.sh 自身**不报错**（退出码恒 0）：找不到 change、写盘失败都只 stderr 提示，
  避免证据系统本身成为门禁噪音。数据正确性靠调用方传入的 `rc=` 保证。

## 六、与其他文件的关系

- 调用方：5 个 gate 脚本末尾 + `stop.sh`/`session-end.sh`（经 harness-gate 转发）
- 产物：`.harness/changes/<id>/gate-<gate>.md`
- 消费方：`harness-status`（进度）、`harness-quality`（质量）、`harness-retro`（回顾审计）