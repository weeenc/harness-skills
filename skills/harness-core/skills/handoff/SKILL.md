---
name: handoff{{LANG_TAG}}
stage: 交接
description: 将当前对话的上下文压缩成交接文档，用于在另一个对话中无缝续接工作。
disable-model-invocation: true
---

# 上下文交接技能（Handoff）— {{LANGUAGE}} 版

> **产物定位**：按 `.harness/changes/README.md` 执行。旧项目缺少该文件时按下述模式分支处理，不阻断 legacy 流程。`artifact_mode: compact` 使用六阶段 `report.md`；有 `report_ref` 时读取共享报告，由协调者汇总写入，子仓只维护执行卡和本地运行摘要，完整需求/AC/审批读取 workspace_ref。只更新目标章节，保留其他阶段与人工记录。无 compact 标记的旧卡沿用已有 handoff.md（新交接写运行区）；不自动迁移或删除历史文件。

> 当前对话结束时，将工作上下文压缩为一份交接文档，下一个对话可以直接读取续接。

---

## 1. 何时使用

- 当前对话上下文快满了，需要开新对话
- 一个变更跨越多个编码周期
- 需要把工作交给另一个开发者或 AI 实例

---

## 2. 工作流程

### Step 1: 收集上下文

| 信息来源 | 内容 |
|---------|------|
| `.harness/changes/<id>/change.md` | 当前变更状态 |
| 目标 `report.md` 的④章节（legacy: review.md） | 最近的评审记录 |
| 对话历史 | 关键决策、未解决问题 |
| 当前代码变更 | 已修改但未提交的代码 |
| {{LINT_CMD}} / 测试结果 | 最近的运行状态 |

### Step 2: 压缩交接文档

仅实际跨会话交接时更新 `.harness/changes/.runtime/<id>/handoff.md`，确保 changes/.gitignore 含 `/.runtime/`；普通阶段切换不调用本技能。团队需共享的阻塞、决策与下一步写回变更卡，不能只存在于被忽略的交接文件。内容包含：

```markdown
# 交接文档: C-NNN

## 当前状态
- 状态: <draft/analyzing/coding/testing/reviewing/ci/verifying>
- 接续者: <下一个开发者/AI 实例>

## 已完成的工作
- [x] ...

## 未完成的工作
- [ ] ...

## 关键决策
| 决策 | 依据 | 参与人 |
|------|------|--------|

## 未解决的问题
| 问题 | 需要谁决策 | 备注 |
|------|-----------|------|

## 风险提醒
- ...

## 上下文加载指令
1. 读取 `.harness/agents/owner.md`
2. 读取 `.harness/rules/`
3. 读取本文件
4. 读取 `.harness/changes/<id>/change.md`
5. `{{BUILD_CMD}}` — 检查编译状态
6. `{{TEST_CMD}}` — 检查测试状态
7. `{{LINT_CMD}}` — 检查 lint 状态

## 断点续接命令
```bash
{{DEV_CMD}}
{{TEST_CMD}} {{RACE_DETECT_ARG}}
```
```

### Step 3: 输出总结

> 📋 交接文档已写入 `.harness/changes/.runtime/C-NNN/handoff.md`
> 新对话开始时，AI 会读取此文档续接工作。

---

## 3. 约束

- ❌ 禁止将硬编码密钥/Token/密码写入交接文档
- ❌ 禁止将对话中的无关内容写入
- ✅ 交接文档应保持简洁，只包含接续工作必需的信息
---


