# Harness Engineering 技能包文档

> 开箱即用的 Harness Engineering 跨语言开发流水线技能包 — 文档中心
>
> 本目录维护技能使用说明、方法论与技能演进资料。PRD 平台资料和专栏文章已迁至同级 `prd-ingestion/` 项目。

## 文档与技能定义的边界

`skills/**/SKILL.md` 是安装和运行时的唯一事实源，决定 AI 工具能够加载的技能内容；本目录是面向人的说明、索引和原理资料。两者内容出现差异时，以 `SKILL.md` 为准。

`docs/skills/` 下的文件用于快速了解技能用途、输入输出和使用场景，不参与 `/apply-harness` 或 `/install-skill` 的安装扫描。

## 目录

- [Harness Engineering 总览](harness-overview.md) — 核心概念
- [Owner Agent](owner-agent.md) — 应用负责人智能体
- [SDD-TDD 方法论](sdd-tdd.md) — 规格驱动 + 测试驱动
- [6 阶段流水线](6-stage-pipeline.md) — 从需求到交付
- [变更管理](change-management.md) — 状态机与文档模板
- [语言规范](languages/) — 各语言编码标准
- [技能说明](skills/README.md) — 面向使用者的技能用途与维护边界
- [🚀 实际项目落地使用手册（操作清单）](harness-usage.md) — 真项目接入/日常开发/发布收口/配置变更/故障排查/卸载，含命令与预期输出
- [⚙️ 门禁体系原理（每个脚本一篇）](harness-principles/00-overview.md) — scripts/hooks 逐个拆解：用途/原理/调用链（hook 如何触发→检测→出结果→报错）
- [脚手架架构图](arch/06-脚手架架构设计.svg) — skill 入口、核心模板与语言包的关系

## 归档资料

这些文档记录已完成的吸收工作和历史规划，供追溯使用；日常接入和技能运行不依赖它们。

- [归档资料](archive/README.md)
- [吸收清单](archive/absorb-list.md)
- [吸收落地使用指南](archive/absorb-usage-guide.md)
- [Skill 开发清单](archive/skill-development-roadmap.md)

## 核心概念

| 文档 | 说明 |
|------|------|
| [Harness Engineering 总览](harness-overview.md) | 什么是 Harness、核心哲学、6 阶段流水线概览 |
| [Owner Agent](owner-agent.md) | 应用负责人智能体——流水线的编排者 |
| [SDD-TDD 方法论](sdd-tdd.md) | 规格驱动 + 测试驱动——三层关系与工作模式 |
| [6 阶段流水线](6-stage-pipeline.md) | 从需求到交付的完整流水线，阶段门禁与状态机 |
| [变更管理](change-management.md) | 变更状态机、文档模板、追踪机制 |

## 流水线技能

| 阶段 | 技能 | 文档 |
|------|------|------|
| ① 需求分析 | `harnessing` | [文档](skills/harnessing.md) |
| ② 编码实现 | `coding-skill` | [文档](skills/coding-skill.md) |
| ③ 单元测试编写 | `unit-test-write` | [文档](skills/unit-test-write.md) |
| ④ 专家评审 | `expert-reviewer` | [文档](skills/expert-reviewer.md) |
| ⑤ CI 门禁 | `unit-test-ci` | [文档](skills/unit-test-ci.md) |
| ⑥ 部署验证 | `deploy-verify` | [文档](skills/deploy-verify.md) |

## 辅助技能

| 技能 | 用途 | 文档 |
|------|------|------|
| `harness-me` | 需求打磨入口 | [文档](skills/harness-me.md) |
| `harnessing` | 需求拷问引擎 | [文档](skills/harnessing.md) |
| `diagnosing-bugs` | Bug 诊断 | [文档](skills/diagnosing-bugs.md) |
| `handoff` | 上下文交接 | [文档](skills/handoff.md) |
| `arch-review` | 架构体检 | [文档](skills/arch-review.md) |
| `domain-modeling` | 领域语言维护 | [文档](skills/domain-modeling.md) |
| `research` | 外部事实查证 | [文档](skills/research.md) |
| `resolving-merge-conflicts` | 解决合并冲突 | [文档](skills/resolving-merge-conflicts.md) |
| `db-encrypt-toolkit` | 数据库敏感字段加密方案生成（15+ 库，视图+触发器 / 协议代理分诊） | [文档](skills/db-encrypt-toolkit.md) |

## 跨语言治理技能（harness-*）

| 技能 | 用途 | 文档 |
|------|------|------|
| `harness-status` | 变更状态总览 | [文档](skills/harness-status.md) |
| `harness-loop-run` | 自主收敛循环引擎 | [文档](skills/harness-loop-run.md) |
| `harness-quality` | 质量闸门与报告 | [文档](skills/harness-quality.md) |
| `harness-relate` | 变更关系链管理 | [文档](skills/harness-relate.md) |
| `harness-e2e` | 端到端测试 | [文档](skills/harness-e2e.md) |
| `harness-db-design` | 数据库设计 | [文档](skills/harness-db-design.md) |
| `harness-api-mock` | API Mock 数据生成 | [文档](skills/harness-api-mock.md) |
| `harness-refactor` | 重构 | [文档](skills/harness-refactor.md) |
| `harness-retro` | 迭代复盘 | [文档](skills/harness-retro.md) |
| `harness-ship` | 发布工作流 | [文档](skills/harness-ship.md) |
| `harness-changelog` | 变更日志维护 | [文档](skills/harness-changelog.md) |
| `harness-standard` | 规范库管理 | [文档](skills/harness-standard.md) |
| `repo-discovery` | 多仓库发现与需求路由 | [文档](skills/repo-discovery.md) |
| `workspace-orchestrator` | 跨仓全栈变更编排 | [文档](skills/workspace-orchestrator.md) |
| `legacy-bootstrap` | 老系统冷启动（submodule/清洗/采访稿） | [文档](skills/legacy-bootstrap.md) |
| `knowledge-health` | 知识健康检查（重复/冲突/失效链接） | [文档](skills/knowledge-health.md) |

## 初始化技能

| 技能 | 用途 | 文档 |
|------|------|------|
| `apply-harness` | 一键应用 Harness 开发规范 | [文档](skills/apply-harness.md) |
| `install-skill` | 注册技能到当前 AI 工具 | [文档](skills/install-skill.md) |

## 多仓库工作空间

| 文档 | 说明 |
|------|------|
| [独立 Git 仓库的全栈开发支持](skills/multi-repo-development.md) | coordinator、仓库级 Harness、契约和联合门禁的落地方式 |

## 工具包技能（自动注入）

| 技能 | 说明 |
|------|------|
| `database-migration-toolkit` | 数据库迁移模板与回滚 |
| `eventbus-toolkit` | 事件总线封装 |
| `excel-toolkit` | Excel 导入导出 |
| `http-client-toolkit` | HTTP 客户端连接池与重试 |
| `k8s-release-toolkit` | K8s 发布与灰度 |
| `kafka-toolkit` | Kafka 生产消费封装 |
| `logging-toolkit` | 日志脱敏与 MDC traceId |
| `oss-toolkit` | 对象存储统一接口 |
| `performance-toolkit` | 性能诊断工具 |
| `redis-cache-wrapper` | 多级缓存防护 |
| `rocketmq-toolkit` | RocketMQ 事务消息 |
| `scheduler-toolkit` | 分布式调度 |
| `security-toolkit` | 安全脱敏与鉴权 |

详见 [工具包技能总览](skills/toolkit-skills.md) | Java 框架专属技能（`java-code-review`、`spring-api-convention`、`mybatis-toolkit`、`openfeign-toolkit`）

## 语言规范

| 语言 | 基线规范 | 文档 |
|------|---------|------|
| Java | 阿里巴巴 Java 开发手册 + Spring Boot | [文档](languages/java.md) |
| Python | PEP 8 + Google Style + Flask/FastAPI | [文档](languages/python.md) |
| Go | Go Code Review + Uber Style + go-zero/Gin | [文档](languages/golang.md) |
| Rust | Rustfmt + Clippy 严格模式 + Axum/Actix Web | [文档](languages/rust.md) |
| PHP（语言包待补齐，当前仅有说明与入口参数） | PSR-12 + PHPStan level 8 + Laravel/ThinkPHP | [文档](languages/php.md) |
| Frontend | Vue 3 + TypeScript 严格模式 + Vite | [文档](languages/frontend.md) |
