# 覆盖率门禁 — `scripts/coverage.sh`

## 一、用途

跑 `{{COV_CMD}}`（如 `go test -cover` / mvn jacoco:report / jest --coverage）并判定
**核心逻辑覆盖率 ≥ 阈值**（默认 80%，可在 `.harness/gate-config.json` 的 `coverage_threshold` 覆盖）。
核心难点不是"跑命令"，而是**从五花八门的工具输出里可靠地抠出总覆盖率数字**——本脚本为此实现了
汇总行锚定 + 启发式回退两级解析。

## 二、调用方式

```bash
bash .harness/scripts/coverage.sh [change-id]
# 等价总入口： harness-gate.sh coverage <change-id>（两参/三参兼容）
```

## 三、运行原理

1. **读阈值**：存在 `gate-config.json` 则 `node -e` 读 `coverage_threshold || 80`（解析失败回退 80）。
2. **可用性分支**（与其余 gate 同构）：
   - `COV_CMD` 未配置/命令不可用 → `[DEGRADED] 无法测量覆盖率，该门禁降级人工核对（依据 unit-test-write 的 AC 覆盖清单）` → rc=2；
   - 底层依赖未就绪（`bootstrap-tools.sh check cov` rc≠0，如 **JaCoCo 插件未在 pom.xml 声明**）→ 同上降级 + 一键复检指引 ← 这正是"JaCoCo 需要装依赖"的正确落点：脚本只检测声明，不替你改 pom.xml。
3. **真跑命令**：`OUT="$(eval "$COV_CMD" 2>&1)"`，打印尾部 25 行给人看。
4. **命令失败**（rc≠0）→ `[FAIL] 执行失败或未达标` → rc=1（若工具已内嵌阈值判定如 `go test -cover`，以命令结果为准）。
5. **命令成功 → 解析百分比**（两级）：
   - **汇总行锚定**：优先匹配输出里 `coverage:` / `All files` / `TOTAL` / `Statements` / `总覆盖率`
     开头的行（含 `%` 或不含 `%` 都行，兼容 go/jest/coverage.py），取第一个数字 → `ANCHORED=1`。
     —— 避免 jest/pytest 表格类工具把**首行单文件百分比误当合计**；
   - **启发式回退**：无汇总行 → 取输出里第一个 `NN%`，并输出
     `[WARN] 未匹配到汇总行（coverage:/All files/TOTAL），按输出首个百分比启发式判定`；
   - **数字都没有** → `[DEGRADED] 无法从命令输出解析覆盖率百分比…请按报告人工核对` → rc=2。
6. **判定**：`awk` 比较 `PCT < THRESHOLD` → 低于阈值 `[FAIL] 覆盖率 N% 低于阈值 80%` rc=1；
   否则 `[PASS] 覆盖率 N% 达标（阈值判定以 TOOL 报告为准）` rc=0。

## 四、如何出结果

- stdout：`[PASS] / [FAIL] / [DEGRADED] / [WARN]` + 数值与阈值（人可直接复核）。
- 退出码：0 达标 / 1 未达标 / 2 无法测量（显式降级）/ 3 用法错误。
- 带 change-id → `report.sh coverage <id> "rc=$rc"` → `gate-coverage.md`。

## 五、结果不满足时如何报错

| 情形 | 表现 | 处理 |
|---|---|---|
| 覆盖率 < 阈值 | `[FAIL] 覆盖率 62% 低于阈值 80%` + rc=1 | 补测试，CI/出口不过 |
| 命令执行失败 | `[FAIL] 执行失败或未达标（rc=N）` + rc=1 | 先看日志是构建坏还是真不达标 |
| 工具没装/依赖缺 | `[DEGRADED] …无法测量覆盖率…` + rc=2 | 按指引装依赖（JaCoCo 等），**绝不静默跳过，也不误判违规** |
| 解析不出数字 | `[DEGRADED] …请按 COV_TOOL 报告人工核对` + rc=2 | 人肉读报告确认达标后，在持久 report.md 的③/⑤章节追加复核结论 |

## 六、与其他文件的关系

- 配置：`.harness/gate-config.json` → `coverage_threshold`
- 前置依赖：`bootstrap-tools.sh check cov`
- 调用方：`unit-test-ci-<lang>` 技能 / CI（coverage 只在此处全量跑，hooks 出口不含它，避免每轮回复都跑测试）
- 证据：`report.sh` → `gate-coverage.md`
> 新版 report.sh 将 gate 摘要写在 changes/.runtime/<id>/，重复检查只更新固定文件。阶段结束将关键证据与人工确认写 report.md，不提交临时摘要；旧报告保留兼容。详见 [运行摘要协议](08-report.md)。
