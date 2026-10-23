# 架构约束门禁 — `scripts/arch-check.sh`

## 一、用途

跑 `{{ARCH_TEST_CMD}}`（如 ArchUnit / go-arch-lint / 自定义依赖检查脚本）校验
**模块依赖方向、分层是否越级**（如 controller 不得依赖 repository、domain 不得依赖 infra）。
架构是"铁律层"：违规不修复不合并，且通常**降级人工评审**比降级其他门禁更宽松——因为
架构约束最有价值的部分恰恰是 code review 时的人为判断，工具只是第一道网。

## 二、调用方式

```bash
bash .harness/scripts/arch-check.sh [change-id]     # 单参脚本，第二参即 change-id
# 等价总入口： harness-gate.sh arch-check <change-id>
```

## 三、运行原理（纯线性分支，一次只走一条）

```
ARCH_TEST_CMD 未配置/="未验证"
  → [DEGRADED] arch-check 工具未安装（ARCH_TEST_TOOL），架构约束降级人工评审（依据 .harness/rules/工程结构.md 铁律）  rc=2
首词命令不在 PATH
  → [DEGRADED] arch-check 命令不可用（…首词未安装），…降级人工评审                                        rc=2
bootstrap-tools.sh check arch 失败（如 ArchUnit 依赖未在构建文件中声明）
  → [DEGRADED] arch-check 底层依赖未就绪——架构约束降级人工评审；缺失项与合入指引：…check arch          rc=2
真跑 eval "$ARCH_TEST_CMD" 失败
  → [FAIL] 架构约束违规（依赖方向 / 分层越级）                                                            rc=1
通过
  → [PASS] 架构约束通过                                                                                  rc=0
```

## 四、如何出结果

- stdout 单一结论行（上述任一），无中间噪音。
- 退出码 0/1/2/3 归一约定。
- 带 change-id → `report.sh arch-check <id> "rc=$rc"` → `gate-arch-check.md`
  （DEGRADED 时该文件供评审人写明"已人工评审通过"的复核结论关账）。

## 五、结果不满足时如何报错

| 情形 | 表现 | 处理 |
|---|---|---|
| 真实违规 | `[FAIL] 架构约束违规…` + rc=1 | 按 `rules/工程结构.md` 铁律修复依赖方向/分层 |
| 工具/依赖缺失 | `[DEGRADED] …降级人工评审` + rc=2 | **强制人工评审**（依据工程结构铁律），评审结论追加进证据文件 |
| 参数错误（经 harness-gate） | rc=3 + 用法提示 | 修正调用 |

> 语义差异提醒：arch 的 rc=2 是**"人工评审兜底"而非"跳过"**——降级路径明说"依据
> .harness/rules/工程结构.md 铁律"，评审人是门禁的一部分，不是可省略项。

## 六、与其他文件的关系

- 规则依据：`.harness/rules/工程结构.md`（降级时的评审铁律）
- 前置依赖：`bootstrap-tools.sh check arch`
- 调用方：CI / unit-test-ci-<lang> 门禁（hooks 出口不含 arch，避免每轮回复全量跑架构检查）
- 证据：`report.sh` → `gate-arch-check.md`