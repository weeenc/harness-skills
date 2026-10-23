# 门禁总入口 — `scripts/harness-gate.sh`

## 一、用途

唯一对外门禁入口：**一个命令、五个门禁、统一退出码**。hooks、技能模板、CI、人肉调用都通过它
触发门禁，不直接调底层 gate 脚本（保持调用路径单一，后续换工具/加 gate 只改这一处 + 对应脚本）。

## 二、调用方式

```bash
bash .harness/scripts/harness-gate.sh <gate> [file|all] [change-id]
# gate: check-style | static-analysis | coverage | arch-check | security-scan
```

| 参数 | 含义 |
|---|---|
| `gate`（必填） | 要跑的门禁名；未知名称 → stderr 列出可选值并 `exit 3` |
| `[file\|all]` | 仅 check-style / static-analysis 用；`file`=单文件增量，`all`=全量（static-analysis 无单文件模式，恒为 all） |
| `[change-id]` | 证据落盘目录；coverage/arch-check/security-scan 是单参脚本，**第二参可直接当 change-id 传**（如 `harness-gate.sh coverage c1` 两参调用） |

## 三、运行原理（参数转发表）

脚本只用 `BASH_SOURCE` 锚定 `.harness/` 根（**不依赖 cwd**，hooks/子目录/CI 调用都同一基准），
然后 `exec` 直接把参数转发给对应 gate 脚本，退出码天然透传：

| 调用 | 实际执行 |
|---|---|
| `harness-gate.sh check-style <target> <id>` | `check-style.sh <target> <id>` |
| `harness-gate.sh static-analysis <x> <id>` | `static-analysis.sh all <id>`（第二参位置被挤到 change-id；`${3:-${2:-}}` 兼容两参） |
| `harness-gate.sh coverage <id>` | `coverage.sh <id>`（`${3:-${2}}` 两参直接用第二参） |
| `harness-gate.sh arch-check <id>` | `arch-check.sh <id>` |
| `harness-gate.sh security-scan <id>` | `security-scan.sh <id>` |
| 其他 | stderr 报错，`exit 3` |

## 四、触发链路（谁调它）

| 调用方 | 场景 | 示例 |
|---|---|---|
| `stop.sh`（Claude/Codex Stop hook） | 每轮回复结束全量 | `harness-gate.sh check-style all <id>` |
| `gemini/session-end.sh`（SessionEnd hook） | 会话结束全量 | `harness-gate.sh check-style`（无 id 也可） |
| `opencode` 插件 | session.idle 出口 | `harness-gate.sh check-style all` |
| 各 `<lang>` 技能（coding/unit-test-ci/deploy-verify…） | 阶段出口/CI 门禁 | `harness-gate.sh <gate> all <id>` |
| 人肉 | 手工复核某门禁 | `harness-gate.sh coverage c1` |

## 五、如何出结果

- **stdout**：被委托 gate 脚本的全部输出（原样透传，含 `[FAIL]` / `[DEGRADED]` / `[PASS]` 标记）。
- **退出码**：即被委托脚本的退出码（见 00-overview 第三节约定：0 通过 / 1 违规 / 2 降级 / 3 用法错误）。
- **证据**：被委托脚本末尾（有 change-id 时）自动调 `report.sh` 落盘 `gate-<gate>.md`（见 [08-report.md](08-report.md)）。

## 六、结果不满足时如何报错

gate 本身不自行判断对错——它保证：**参数错误立即报错（rc=3 + 可选门禁列表）**；
**门禁失败信号原样穿透**（rc=1/2 + stdout 红灯文本），由调用方（hooks 层）决定是注入提示、
block 工具调用还是报 CI 失败。所以：

- 写错 gate 名 → `exit 3`，stderr：`未知门禁: xxx（可选: check-style | static-analysis | coverage | arch-check | security-scan）`
- 门禁真实失败 → rc≠0（1 或 2），调用方按退出码区分「违规」与「降级」：
  - hooks 层把 rc=1 记为红灯（强制修复），rc=2 记为需人工核对（显式降级不静默跳过）；
  - CI/技能把任一 rc≠0 视为不过。

## 七、与其他文件的关系

- 被委托：`scripts/{check-style,static-analysis,coverage,arch-check,security-scan}.sh`
- 证据：`scripts/report.sh`
- 配置：`.harness/gate-config.json`（coverage 阈值等，由各 gate 脚本自行读取）