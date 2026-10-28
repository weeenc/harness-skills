---
name: unit-test-write{{LANG_TAG}}
stage: ③ 单元测试编写
description: 为实现代码编写 {{LANGUAGE}} 单元测试，核心逻辑覆盖率 ≥80%，覆盖 AC 与边界
---

# 单元测试编写技能（unit-test-write）— {{LANGUAGE}} 版

> **产物定位**：按 `.harness/changes/README.md` 执行。旧项目缺少该文件时按下述模式分支处理，不阻断 legacy 流程。`artifact_mode: compact` 使用六阶段 `report.md`；有 `report_ref` 时读取共享报告，由协调者汇总写入，子仓只维护执行卡和本地运行摘要，完整需求/AC/审批读取 workspace_ref。只更新目标章节，保留其他阶段与人工记录。无 compact 标记的旧卡沿用 diagnosis.md 与既有测试记录；不自动迁移或删除历史文件。

> **流水线阶段**: ③ 第三步
> **输入**: ② 阶段的实现代码 + change.md
> **出口门禁**: 测试通过 · 静态检查零新增告警 · 核心逻辑覆盖率 ≥80% · 覆盖全部 AC、边界与降级路径
> **测试框架**: {{TEST_FRAMEWORK}}

### 核心规则（一句话摘要）

> **每条 AC 至少一个测试，每条降级路径一个专门测试，核心覆盖率 ≥80%。禁止只测 happy path。**

---

## 1. 职责

你是测试驱动质量的工程师。你的职责分两段：编码前让失败测试先存在，编码后补齐边界、降级、回归测试。目标不是为覆盖率而测，而是验证每条 AC 与每个边界、每条降级路径真实成立。

---

## 2. 前置检查

1. **定位目标 change**（按 `.harness/rules/变更定位规则.md`）：
   - 扫描 `.harness/changes/*/change.md`，过滤 `status: testing`
   - 用户已指定 `<id>` → 校验该 change 状态是否为 `testing`，否则报错
   - 恰好 1 个 → 自动选中
   - 0 个 → 报错：无处于 `testing` 状态的 change，退回 ② coding-skill
   - ≥ 2 个 → **列出候选清单（id + 标题 + 摘要），停下请用户选择**，不得擅自默认取第一个
2. 验证 `change.md` 的 `status: testing` 与编码阶段交付物一致
3. 缺前置 → 退回 ② coding-skill

---

## 3. 工作流程

### Step 1: 梳理测试矩阵
从 `change.md`（默认）或 `.harness/iterations/<id>/test/design.md`（若走迭代协议）提取所有 AC 与边界情况，建立"测试点 → 测试用例"映射表，确保无遗漏。

### Step 2: 分层测试
| 层级 | 内容 |
|------|------|
| Spec Tests | 每条 AC 的 happy path / 核心行为 |
| Boundary Tests | 空/零值、极值、并发、重复执行；**性质类**：对称/交换律（排序、归一化、会话 ID 拼接等函数**必测反序输入**）、幂等性（closeOnce/开关重入/重复执行）、往返一致性（编码↔解码、归一↔解析） |
| Failure/Fallback Tests | 依赖故障时的降级逻辑（超时/限频/API 不可用） |
| Regression Tests | 已修复 bug / 历史故障回归 |

### Step 3: 编写测试
- 命名: `{{TEST_NAMING}}`
- 用 {{TEST_FRAMEWORK}} + {{MOCK_LIB}}，断言用 {{ASSERT_LIB}}
- 每个测试**单一断言意图**，Arrange-Act-Assert 三段清晰
- **降级逻辑必须实测**，不满足于"应该能处理"

### Step 4: Mock 原则
- Mock 外部依赖（LLM、第三方 API、数据库、缓存）
- **禁止 Mock 自己写的业务类**（那样测的是 Mock 不是逻辑）
- 用 {{MOCK_LIB}} 提供可控的故障场景（超时、异常、空返回）

### Step 5: 覆盖率核验
- 跑 `.harness/scripts/coverage.sh <change-id>`（内部为 `{{COV_CMD}}`，核心逻辑 ≥80%，阈值可在 `.harness/gate-config.json` 调整）；脚本不存在则退化为 `{{COV_CMD}}` 直接执行
- 覆盖率不足 → 补测试，而非降低标准
- 纯 getter/setter/配置类可豁免
- 结果经 `report.sh` 更新 `changes/.runtime/<id>/gate-coverage.md`，命令、版本、覆盖率和 rc 汇总到目标 `report.md` 的③章节；工具未安装时脚本输出 `[DEGRADED]`（**无法测量覆盖率**）——必须在 change.md 显式记录该降级

### Step 5.5: 阶段出口全量门禁复核
- 跑 `.harness/scripts/harness-gate.sh check-style all <change-id>`（内部 `{{LINT_CMD}}`）——**零新增告警**（**含本阶段新增的全部测试文件**；本阶段是 vet 的最后一道门禁，测试文件里的死代码/自赋值等由 vet 兜住，AC-1 类"零新增告警"门槛以此为准），经 `report.sh` 落盘
- 跑 `.harness/scripts/harness-gate.sh static-analysis <change-id>`（内部 `{{VET_CMD}}`）
- 跑 `{{TEST_CMD}} {{RACE_DETECT_ARG}}` 检测竞态（{{RACE_DETECT_ARG}} 为空可跳过，在 change.md 标注待 amd64 CI 验证）
- 任一检测结果为 PASS 或显式 `[DEGRADED]`（须人工核对并签名）后才允许出阶段

### Step 6: 诊断辅助
如果遇到无法稳定复现的 Bug 或非确定性故障，建议运行 `/diagnosing-bugs` 进行 6 阶段诊断。
诊断结论更新到目标 `report.md` 的②章节；复现日志放 `changes/.runtime/<id>/`，不新建独立诊断文档（legacy 沿用原文件）。

---

## 4. 测试质量红线

- ❌ 只测 happy path，边界靠注释"应该能处理"
- ❌ 断言空泛（`assertTrue` 当主断言）
- ❌ 测试间相互依赖、有顺序耦合
- ❌ Mock 自己写的类
- ✅ 每条 AC 至少一个测试
- ✅ 每个边界情况至少一个测试
- ✅ 降级逻辑有专门测试

---

## 5. 完成标志

`{{LINT_CMD}}`（涉及包）零新增告警 + `{{TEST_CMD}} {{RACE_DETECT_ARG}}` + `{{COV_CMD}}` 全绿 + 覆盖率达标（门禁命令事实源为 `.harness/scripts/`，最新运行摘要已落到 `.runtime/`，测试结论与证据摘要已写入目标 `report.md` 的③章节） → 更新 `change.md` 状态 `testing → reviewing`，进入 ④ 专家评审。
---


