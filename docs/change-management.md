# 变更管理

新需求默认采用 `artifact_mode: compact`。精简范围是 `.harness/changes/` 的过程产物；wiki、tech、rules、领域知识回流及其他目录仍按原有逻辑维护。

## 单仓：一张卡片，一份六阶段报告

前端、后端、单仓全栈统一使用：

```text
.harness/changes/
├── README.md                  # 所有技能共用的产物协议
├── .gitignore                 # /.runtime/
├── C-001-example/
│   ├── change.md              # 需求、AC、设计约束、审批、状态、下一步
│   └── report.md              # 六阶段结果，包含评审、验证及归档
└── .runtime/C-001-example/     # 日志、门禁最新摘要、按需交接；不提交
```

只在创建需求时实例化卡片，产生阶段结论时再创建 report.md。不要把整个 `_TEMPLATE/` 复制到需求目录，不为每次检查创建新报告。

| report.md 章节 | 记录内容 |
|---|---|
| ① 需求分析 | 需求/AC 的卡片引用、审批与决策 |
| ② 编码实现 | 实现范围、调整、根因诊断、独立复核 |
| ③ 单元测试 | AC→测试、命令、版本、时间、结果、覆盖率 |
| ④ 专家评审 | 审查范围、独立 Spec/Standards 双轴、发现与处理 |
| ⑤ CI 与质量门禁 | 具名检查、质量对账、契约/E2E、人工确认 |
| ⑥ 部署验证与归档 | 环境/版本、冒烟/traceId/断言、回滚、交付、知识回流 |

更新一个阶段时保留其他章节与人工确认，重跑只更新当前结果并保留关键失败和修复结论，不无限追加流水。未执行、失败、降级应如实记录，精简文件不改变门禁标准。

状态仍由卡片驱动：

```text
draft → analyzing → coding → testing → reviewing → ci → verifying → done
```

## 多仓全栈：只汇总一套阶段报告

```text
协调仓/.harness/changes/WS-001/
├── workspace-change.md
└── report.md
前端仓/.harness/changes/C-001-front/change.md
后端仓/.harness/changes/C-001-back/change.md
```

子仓执行卡写 `artifact_mode: compact`、`workspace_change`、`workspace_ref` 和 `report_ref`，相对路径以卡片目录为基准。它保留本地 id/status 供 hooks 识别、记录分工和 commit/PR；需求和审批引用工作空间卡，阶段结果引用共享报告。

各仓技能返回执行结果，只有协调者写共享 report.md，并按仓库区分命令、版本和结果。子仓的 review-check 通过 report_ref 读取工作空间报告的④章节；不复制第二份 review.md，也不使用 hooks 无法识别的 repo-execution.md。

工作空间仍使用 draft/analyzing/implementing/integrating/verifying/done 粗粒度状态，通过 stage 标记六阶段；各 required 仓库和联合验证都完成后才能 done。

## Git 与证据边界

跟踪卡片、六阶段报告、共享协议和模板；`changes/.runtime/` 由 `changes/.gitignore` 忽略。`report.sh` 每门禁只更新一个本地摘要，既不修改 report.md，也不生成时间戳 run 目录或重复 diff。阶段结束由技能把真实命令、代码版本/dirty 范围、时间、rc、关键计数和断言写入报告。

持久报告必须可独立阅读，不能把本地日志链接作为唯一证据。需要共享的完整历史输出保存到稳定 CI/制品地址，在报告保留地址和校验值；未提交源码、唯一备份和人工记录不能被自动清理。确需快照时，同一代码状态只保存一次，后续检查引用快照。

compact 不另建 review/verify/archive/quality-report/diagnosis/e2e/gate 文档。阶段切换不生成 handoff；真正换会话才按需更新 `.runtime/<id>/handoff.md`，共享待办仍回填卡片。用户明确要求额外专题报告时可以扩展。

## 旧项目兼容与更新

没有 compact 标记的历史卡片继续读取和维护原独立报告；新 report.sh 的最新门禁摘要在 `.runtime/`，旧 gate 文件作为历史证据保留。不要安装时清空 changes 或自动取消历史文件的 Git 跟踪。

新接入通过 `/apply-harness` 安装协议、模板、脚本和技能。已有项目需检查本地适配后同步这些受影响的资产，保留知识与历史；仅 `/install-skill` 是注册副本，不会升级 `.harness` 的脚本或模板。旧卡只有在显式迁移并核对阶段结论、人工签名及证据链接后才设置 compact。无需为了启用新需求的默认协议迁移所有旧需求。

## 同事拉取仓库后接入

已有 `.harness/` 随 Git 拉取后，使用 `/install-skill` 注册仓库内技能即可：它读取 `.harness/skills/`，更新当前工具的技能副本，不重新生成 changes/wiki/tech/rules。工具目录中同名技能可能被覆盖。

`/apply-harness` 是初始化/更新入口，原规则禁止未经明确授权覆盖已有 `.harness/`；不要把它当成每人拉取后的必跑初始化。确需升级时对比并合并技能、模板和脚本，保留项目适配与历史报告。新增 ignore 规则不会取消已跟踪文件的 Git 跟踪，历史清理应单独审阅。

完整协议见 [changes/README 模板](../skills/harness-core/templates/changes/README.md)。
