# 发布工作流 — harness-ship

> **技能标识**: `harness-ship`
> **使用场景**: "正式发布一版"——测试 → 版本 → tag → CI/CD，全程可追溯
> ⚠️ **发布是不可逆·外发操作，永远留人确认**。关键节点（版本号确定、tag 推送、生产触发）必须人类确认后才执行

## 它做什么？

把已完成验证的 change 汇总为一次**正式发布**：测试全绿 → 版本号递增 → 更新 CHANGELOG → 打 git tag → 触发 CI/CD 发布流水线。每一步都产出可追溯证据。

## 什么时候用？

- 有已完成验证（`status: done`）的 change 需要对外发布
- 迭代/里程碑收口，需要 bump 版本号并打 tag
- 需要触发 CI/CD 发布流水线到测试/生产环境

## 前置检查（全部满足才继续）

- [ ] 待发布 change 全部 `status: done`（`/harness-status` 确认）
- [ ] `/unit-test-ci` 门禁全绿（或该次发布验证已通过）
- [ ] `/harness-quality` 报告已落盘且有**人类放行签字**
- [ ] CHANGELOG 已汇总本次变更（可用 `/harness-changelog`）
- [ ] 数据库迁移（若有）已按 `database-migration-toolkit` 执行完毕且可回滚

任一不满足 → 停止，列出缺口清单交人类。

## 核心机制

### 执行流程

```
Step 1: 版本号决策（留人）→ 候选版本 + 变更摘要呈现给人类，确认后才继续
Step 2: bump VERSION（机器执行）→ 更新版本文件，提交 chore(C-NNN): bump version to <ver>
Step 3: 更新 CHANGELOG → 追加新版本条目（链接到 review.md/verify.md）
Step 4: 打 tag（留人确认推送）→ git tag -a v<ver> -m ...，确认后 git push origin v<ver>
Step 5: 触发 CI/CD（留人确认）→ 记录触发回执（job URL / 退出码）
Step 6: 验证与收尾 → /deploy-verify 冒烟 + verify.md 记录 + 更新 TECH-DEBT.md
```

### 版本号决策

按项目约定（`编码规范.md` / CHANGELOG 头部）确定本次版本号，建议用 **SemVer**（主.次.补丁），结合 break 变更/新功能/修复判定。

## 不可逆操作清单（每题必须人类 yes/no）

| 操作 | 确认点 |
|------|--------|
| 版本号确定 | 候选版本呈现给人类 |
| tag 推送 | `git push origin v<ver>` 前确认 |
| 生产发布触发 | 调用发布入口前确认 |
| 生产放量 | 比例/时间由人类决策 |

**不自动推进生产环境放量**——生产放量比例/时间由人类决定。

## 回滚预案

- 每次发布记录**回滚点**：上一个 tag + 数据库回滚脚本
- 发布失败/线上异常 → 按预案回滚到上一 tag，记录到 verify.md，不掩盖
- 回滚后回到 `verifying` 状态，定位根因再重发（`diagnosing-bugs`）

## 为什么需要它？

| 问题 | 解法 |
|------|------|
| 发布流程靠人肉记忆，漏步骤 | 标准六步流程 + 前置清单 |
| 版本/tag 乱，无法回溯 | 全程留证 + 回滚点记录 |
| AI 擅自发布不可逆操作 | 不可逆操作逐项留人确认 |
| 上线出问题不知道回滚到哪 | 每次发布记录回滚点（tag + 迁移脚本） |

## 完成标志

- 版本文件已 bump、CHANGELOG 已更新、tag 已推送（留人确认后）
- CI/CD 已触发并记录回执，发布后冒烟通过
- verify.md 已记录版本号/时间/回滚点

## 与相邻技能

| 场景 | 归属 |
|------|------|
| 发布流程 | **本技能**（`/harness-ship`） |
| 发布后冒烟/健康检查 | `/deploy-verify` |
| CHANGELOG 汇总 | `/harness-changelog` |
| 质量放行签字 | `/harness-quality` |
| 回滚/线上异常定位 | `diagnosing-bugs` |