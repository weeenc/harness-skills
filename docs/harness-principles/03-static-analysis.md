# 静态缺陷分析 — `scripts/static-analysis.sh`

## 一、用途

全量深度门禁：跑 `{{VET_CMD}}`（缺陷检查维度，如 spotbugs/PMD 的 defect 检查/`go vet`）找出
**逻辑缺陷**（区别于 check-style 只管风格）。只在出口时机跑（Stop/会话结束/CI），无单文件模式。
覆盖率与架构维度分别由 `coverage.sh` / `arch-check.sh` 承担，互不重叠。

## 二、调用方式

```bash
bash .harness/scripts/static-analysis.sh [all] [change-id]    # all 为固定值
# 等价总入口： harness-gate.sh static-analysis all <change-id>
# 两参兼容： harness-gate.sh static-analysis <change-id>
```

## 三、运行原理（两个维度的降级判定）

**维度 1：VET 命令**（`{{VET_CMD}}`）——分支按序：

1. `VET_CMD` 未配置（空 / `未验证`）→ `[DEGRADED] static-analysis 静态分析命令未配置或不可用` → `degraded=1`；
2. 命令不可用（首词不在 PATH）→ 同上降级；
3. 底层依赖未就绪（`bootstrap-tools.sh check vet` rc≠0）→ `[DEGRADED] …底层依赖未就绪…一键复检指引`；
4. 真跑 `eval "$VET_CMD"` 失败 → `[FAIL] xxx 发现静态缺陷` → `failed=1`；
5. 通过 → `[OK] xxx 通过`。

**维度 2：LINT 的缺陷维度**（`{{LINT_CMD}}`，如 PMD/SpotBugs/staticcheck 已含在 check-style
全量里跑过）——为避免重复执行，**此处不重跑，只做可用性检查**：
`LINT_CMD` 未配置/不可用/依赖未就绪 → `[DEGRADED] 依赖的 LINT_TOOL 未安装…缺陷检查降级人工核对`。
（真实缺陷检查结果以 `check-style.sh all` 为准。）

## 四、如何出结果

- 退出码合成：`failed` → rc=1；否则 `degraded` → rc=2；否则 rc=0。
- 结论三段式输出（与脚本一一对应）：
  - `[DEGRADED] static-analysis 存在降级维度，需人工核对` → exit 2
  - `[FAIL] static-analysis 未通过` → exit 1
  - `[PASS] static-analysis 通过` → exit 0
- 带 change-id → 末尾 `report.sh static-analysis <id> "rc=$rc"` 落盘证据。

## 五、结果不满足时如何报错

与 check-style 完全同构（三层呈现）：

| 层 | 表现 |
|---|---|
| 脚本层 | stdout 红灯/降级文本 + `exit 1/2` |
| hooks 层 | Stop/SessionEnd 汇总进出口消息（`stop.sh` 把 rc 逐条列出；`session-end.sh` 按 `\bFAIL\b`/`\bDEGRADED\b` 冠以【红灯】/【降级】头部） |
| 证据层 | `gate-static-analysis.md` 落盘 rc 与状态 |

**降级 ≠ 通过**：任一维度 DEGRADED 就是 rc=2，人工按指引装依赖后复跑，才能拿到 rc=0。

## 六、与其他文件的关系

- 前置依赖：`bootstrap-tools.sh check vet` / `check lint`
- 调用方：`stop.sh`、`gemini/session-end.sh`、CI/unit-test-ci 门禁（均经 `harness-gate.sh static-analysis`）
- 证据：`report.sh` → `gate-static-analysis.md`