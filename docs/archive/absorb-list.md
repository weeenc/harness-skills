# 吸收清单：《AI 驱动研发体系的实践和思考》→ 脚手架

> 来源文档：`AI 驱动研发体系的实践和思考.docx`（作者默达，淘天集团-营销&交易技术团队，Price360-KB 实践总结）
> 目标项目：harness-skills（开箱即用的 Harness Engineering 跨语言开发流水线技能包）
> 落盘日期：2026-10-03（本清单已全部落地执行，配套落地说明见 [吸收落地使用指南](absorb-usage-guide.md)）

## 总体判断

| 维度 | 结论 |
|------|------|
| 方法论契合度 | ✅ 高度契合。脚手架的 `.harness/`（Owner Agent + Rules + Skills + Changes + Wiki）正是文档所说"项目 Harness"的实例化产物 |
| 可吸收性 | 约 **80% 内容可吸收**：10 项直接新增/增强模板与技能，6 项落为文档/专栏，2 项概念映射 |
| 不吸收 | 淘天内部工具（Aone、钉钉 AI 听记、Price360-KB 业务目录 olap/briefs/outputs）——只保留机制、去掉实现 |
| 优先级 | P0（结构性缺口，直接影响生成产物质量）3 项；P1（机制增强）7 项；P2（理念文档）6 项 |

## A. 结构性缺口（P0）——当前生成产物中完全没有的部分

### A1. 机器可读迭代协议模板（文档 §64-67）

- **文档要点**：每个需求独立迭代目录，保存 `prd.md / solution.md / test/design.md / test/cases*.md / test/report.md / archive.md`；REQ/AC/TC 编号；状态/版本/依赖/证据字段固定格式；Agent 可机器检查"AC 是否有方案承接、是否有测试覆盖、用例是否对应当前方案版本"。
- **脚手架现状**：只有 `changes/_TEMPLATE/change.md`（单文件变更卡）+ review.md + verify.md，**没有** multi-file 迭代协议、没有 REQ/TC 编号体系、没有"阶段间接口"检查字段。
- **吸收动作**：新增 `skills/harness-core/templates/iterations/_TEMPLATE/`，含 `prd.md`（REQ/AC）、`solution.md`（REQ→任务/观测点映射）、`test/design.md`、`test/cases.md`（TC）、`test/report.md`（traceId/断言/证据回填）。`archive.md`（知识回流清单）不随迭代协议拆分，落于 `changes/_TEMPLATE/`（见 B2）。在 `开发流程规范.md` 中补充"阶段间接口"门禁。
- **落点**：`skills/harness-core/templates/iterations/_TEMPLATE/*`（不含 archive.md）、`skills/harness-core/rules/开发流程规范.md`
- **理由**：这是文档区别于"提示词流水线"的核心——机器可读、可对账。脚手架已有 harness-quality 的 flow→test 对账，补上 REQ/TC 体系即形成闭环。

### A2. wiki/tech 分层知识库模板 + 知识文件 Metadata（文档 §38-43、§49-56）

- **文档要点**：长期知识分两层——`wiki`（业务概念/规则/口径/角色/流程/异常）+ `tech`（跨系统链路/接口数据关系/新旧切换/废弃状态/运行态拓扑/观测方式）；**知识库不复制代码**；每个知识文件带 frontmatter：`title/category/tags/status/version/source`，正文用相对路径关联，tech 用 `wiki_ref` 反连业务知识。
- **脚手架现状**：`templates/wiki/` 只有 5 个模板（业务模型/接口协议/数据模型/架构决策/ADR-FORMAT），**没有 tech 层、没有 frontmatter 规范、没有 source 事实来源字段、没有 wiki_ref 关联机制**。
- **吸收动作**：
  - 新增 `templates/wiki/_TEMPLATE/知识文件模板.md`（带完整 frontmatter + source + 相对链接示例）；
  - 新增 `templates/tech/_TEMPLATE/链路模板.md`（跨系统链路、接口数据关系、废弃状态、观测方式，含 `wiki_ref` 字段）；
  - 新增规则 `知识库治理规则.md`："不复制代码、事实来源必填、链接用相对路径"。
- **落点**：`skills/harness-core/templates/wiki/`、`skills/harness-core/templates/tech/`、`skills/harness-core/rules/`
- **理由**：文档最可迁移的机制。"wiki=业务、tech=技术链路、不复制代码"三句话直接可固化为模板与规则。

### A3. 外部动态事实连接清单（文档 §24、§68-71）

- **文档要点**：稳定上下文进 Git，动态事实（工作项状态/测试环境/日志/数据库/配置中心）从权威系统经 MCP/CLI 实时查询，在 Agent 执行时汇合；测试绑定真实环境并回填 traceId/断言结果。
- **脚手架现状**：`运行时可靠性.md` 有可观测性要求，`verify.md` 有"可观测性"检查项，但**没有"动态事实来源清单"这一结构化概念**（工作项/环境/日志/DB/配置中心的连接方式未进模板）。
- **吸收动作**：新增模板 `templates/动态事实来源.md`（表格：事实类型 / 权威系统 / 连接方式 MCP|CLI / 使用场景），由 apply-harness 生成 `.harness/动态事实来源.md`；`verify.md` 模板增加"traceId/断言结果回填"字段。
- **落点**：`skills/harness-core/templates/动态事实来源.md`、`skills/harness-core/templates/changes/_TEMPLATE/verify.md`
- **理由**：这是"本地优先"与"实时事实"的边界机制，脚手架目前只有隐式要求、无显式清单。

## B. 机制增强（P1）——已有能力，补文档中的关键机制

### B1. 老系统冷启动流程（文档 §25-28）

- **文档要点**：老系统通过 Git submodule 关联 `src/`、raw/ 挂原始资料、设计"清洗 SKILL"从代码/文档清洗结构化知识、用采访稿（钉钉 AI 听记）补齐人脑知识；**不等待知识库完善**，在迭代中滚动完善。
- **脚手架现状**：`apply-harness` 面向新项目（语言/框架检测→生成），**没有老系统接入路径**。
- **吸收动作**：新增技能 `harness-core/skills/legacy-bootstrap/`（或并入 apply-harness 的"棕地模式"）：submodule 关联 src/、raw/ 挂载、清洗 SKILL 设计指南、采访稿→知识库工作流。
- **落点**：`skills/harness-core/skills/legacy-bootstrap/SKILL.md`
- **理由**：文档独有且高价值——"冷启动"是绝大多数真实项目的场景。

### B2. 知识飞轮 / 归档回流机制（文档 §29-32、§65）

- **文档要点**：迭代过程本身就是知识飞轮——PRD 补业务定义、方案记链路、测试校验、**归档时把确认后的长期知识回流 wiki/tech**；知识建设是产品迭代的副产物。
- **脚手架现状**：有 `harness-retro`（复盘趋势报告）和 `harness-changelog`（变更日志），但**没有"归档→知识回流 wiki/tech"机制**；`change.md` 模板有"wiki:"影响面字段但无归档动作。
- **吸收动作**：`archive.md` 模板内置"知识回流清单"（本次迭代确认了哪些业务规则→wiki、哪些链路→tech）；增强 `harness-retro` 增加"知识回流率"检查项。
- **落点**：`skills/harness-core/templates/changes/_TEMPLATE/archive.md`（知识回流清单模板）、`skills/harness-core/skills/harness-retro/SKILL.md`
- **理由**：知识飞轮是文档的核心主张，脚手架现有复盘技能只回看质量、不回看知识沉淀。

### B3. 知识健康检查（文档 §56）

- **文档要点**：定期健康检查处理迭代积累的重复、冲突、失效链接、无来源结论。
- **脚手架现状**：无对应技能。
- **吸收动作**：新增 `harness-core/skills/knowledge-health/`（扫描 wiki/tech：重复主题、冲突 status、失效相对链接、缺 source 字段）。
- **落点**：`skills/harness-core/skills/knowledge-health/SKILL.md`
- **理由**：文档明确点名的治理机制，实现成本低、机械可执行。

### B4. 公共能力依赖声明（文档 §57-63）

- **文档要点**：公共能力不复制进每个项目，通过 `skill-dependencies.json` 声明来源与兼容版本；项目 Skill 只保留业务编排；AGENTS.md（协议）/ .agents/skills（能力）/ .agents/scripts（门禁）三层分离。
- **脚手架现状**：**复制式分发**（apply-harness 把技能复制进 `.harness/skills/`），无依赖声明机制；无 `scripts/` 门禁层概念（脚本散在各技能内）。
- **吸收动作**：
  - 新增模板 `templates/skill-dependencies.json`（技能名/来源/版本/兼容性），apply-harness 生成；
  - 在 `开发流程规范.md` 或新规则中说明"协议=AGENTS.md / 能力=skills / 门禁=scripts"三层结构，与现有 Owner Agent+rules 结构映射。
- **落点**：`skills/harness-core/templates/skill-dependencies.json`、`skills/harness-core/rules/开发流程规范.md`
- **理由**：这是脚手架架构差异点（复制 vs 声明），值得作为可选增强，让团队能统一升级公共技能。

### B5. 发布后回查（文档 §71）

- **文档要点**：代码合入主干只是其中一步，之后要回查工作项和协同状态；只有代码版本、业务状态、交付证据一致，迭代才算结束。
- **脚手架现状**：`harness-ship` 有版本/tag/CI-CD/回滚，`deploy-verify` 有冒烟/健康检查，**无"回查工作项状态"步骤**。
- **吸收动作**：`harness-ship` Step 6 增加"回查工作项状态 + 协同状态，三者一致才算 done"。
- **落点**：`skills/harness-core/skills/harness-ship/SKILL.md`
- **理由**：文档明确"接口成功≠异步链路完成"的完成标准，与脚手架"CI 绿≠线上可用"理念一致，直接补一步。

### B6. 高风险动作逐次授权（文档 §72-75）

- **文档要点**：高风险动作不会因前面得到过一次概括性同意就自动执行；人负责决策、Agent 负责执行完整。
- **脚手架现状**：`owner.md` 已有"必须请示人类"清单（4.2）和"不可逆操作留人确认"（harness-ship），**已覆盖**。
- **吸收动作**：仅需在 `owner.md` 补充一句显式原则："概括性同意不构成对后续高风险动作的授权，每个高风险动作单独确认"。
- **落点**：`skills/harness-core/templates/agents/owner.md`
- **理由**：脚手架已基本覆盖，微调即可。

### B7. AI Trace 度量体系（文档 §82）

- **文档要点**：用工作项串联从需求到上线的所有 AI Trace，节点流与 step 映射，用 AI 分析需求上线质量（跨对话反复补充上下文=低效、反复纠正=Harness 待完善）。
- **脚手架现状**：`harness-retro` 有打回率/停留时长等指标，但**无"跨对话上下文补充、反复纠正"这类 AI Trace 信号**。
- **吸收动作**：`harness-retro` 指标表增加"对话内补充上下文次数、同一问题纠正次数"信号（数据源：手记/AI Trace 日志，可选）。
- **落点**：`skills/harness-core/skills/harness-retro/SKILL.md`
- **理由**：文档最前瞻的部分，先以可选指标形式进入复盘技能，平台化后可升级为独立度量技能。

## C. 理念与文章（P2）——落为 docs 文档与专栏

| # | 文档章节 | 主题 | 吸收形式 | 落点 |
|---|---------|------|---------|------|
| C1 | §6-14 | 从 AI 辅助编程到 Coding Agent 到项目 Harness 的演进（Agent = Model + Harness 公式） | 新专栏文章或并入 `docs/harness-overview.md` | 同级 `prd-ingestion/docs/articles/`（已迁出） |
| C2 | §18-21 | 真正的瓶颈是上下文，不是模型能力 | 理念文章 | 同级 `prd-ingestion/docs/articles/`（已迁出） |
| C3 | §22-24 | 本地优先：Agent + 文件夹 + Git（稳定上下文进 Git、动态事实实时查询） | 理念文章 | 同级 `prd-ingestion/docs/articles/`（已迁出） |
| C4 | §33-37 | 为什么先做文件 Wiki（文件 Wiki vs RAG vs 本体论三者的分工） | 理念文章 | 同级 `prd-ingestion/docs/articles/`（已迁出） |
| C5 | §76-81 | 共性能力与业务实践的协同边界（数据协议、质量基线、参考实现+可组合能力） | 理念文章 | 同级 `prd-ingestion/docs/articles/`（已迁出） |
| C6 | §83-88 | Harness 收缩与 FDE 角色（技术人员的未来定位） | 理念文章/README 引语 | 同级 `prd-ingestion/docs/articles/`（已迁出）、`README.md` |

> 这些内容不改变脚手架机制，但构成脚手架的"思想底座"——与现有 51 篇专栏文章并列，编号接续（column-54 起）。

## D. 不吸收 / 需谨慎处理

| 文档内容 | 处理方式 | 原因 |
|---------|---------|------|
| `price360-kb` 目录名及 `olap/ briefs/ outputs/` 业务目录 | 不照搬；脚手架保留 `.harness/` 约定，必要时在文档中做"概念映射表" | 业务特定，跨团队不可复用 |
| Aone 工作项、钉钉 AI 听记 | 抽象为"工作项平台""访谈转录工具"，保留机制去实现 | 淘天内部工具 |
| "不要尝试手动修改任何一个字" | 吸收为理念（在 C3 文章），不作为强制规则 | 脚手架是技能包不是强制平台 |
| 用 git submodule 关联 src/ | 作为 legacy-bootstrap 的可选方案，不默认启用 | 非所有团队适用 |

## 建议执行顺序

1. **第一批（P0）**：A1 迭代协议模板 → A2 wiki/tech 分层 → A3 动态事实来源清单（这三个直接改变 apply-harness 生成产物的质量）
2. **第二批（P1）**：B1 冷启动 → B2 知识飞轮 → B3 知识健康检查 → B5 发布回查 → B6 授权原则 → B7 AI Trace 指标
3. **第三批（P2）**：C1-C6 理念文章 + B4 依赖声明机制
