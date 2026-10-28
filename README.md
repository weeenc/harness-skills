# harness-skills

> 开箱即用的 Harness Engineering 跨语言开发流水线技能包（支持 Java / Python / Go / Rust / PHP / Frontend）
>
> 参考 [mattpocock/skills](https://github.com/mattpocock/skills) 的 SKILL.md 体系开发

> 本项目维护 skill 定义、规则、模板及使用文档。PRD 平台资料、专栏文章和分享产物已迁至同级 `prd-ingestion/` 项目。

独立 Git 仓库的全栈工作空间通过 `repo-discovery` 与 `workspace-orchestrator` 协调：前端、后端继续各自维护 Harness，工作空间层记录仓库映射、跨仓变更、契约版本和联合门禁。

## 什么是 Harness Engineering？

Harness 是一个**人类设计约束、AI 写代码、机器验证**的开发方法论。核心是 **Owner Agent**（应用负责人智能体），它编排 6 阶段流水线：

```
① harnessing  →  ② coding-skill  →  ③ unit-test-write  →  ④ expert-reviewer  →  ⑤ unit-test-ci  →  ⑥ deploy-verify
```

## 快速开始

```bash
# 在任意项目根目录执行
npx skills@latest add git@github.com:weeenc/harness-skills.git

# 在 AI 对话中键入
/apply-harness
```

安装完成后，在 `.harness/` 目录下已注册 30+ 个技能，通过斜杠命令驱动 6 阶段流水线：

```bash
# ① 需求分析 — 打磨需求，生成规格说明书
/harnessing

# ② 编码实现 — 按 AC 列表逐个实现，垂直切片
/coding-skill

# ③ 单测编写 — 为核心逻辑编写单元测试（覆盖率 ≥80%）
/unit-test-write

# ④ 专家评审 — 双轴并行子智能体评审（Spec 匹配 + 规范合规），0 个 🔴 才放行
/expert-reviewer

# ⑤ CI 门禁 — 机械化执行静态分析 + 竞态检测 + 架构约束 + 全量测试
/unit-test-ci

# ⑥ 部署验证 — 冒烟测试、健康检查、关键链路验证、回滚确认
/deploy-verify
```

> 每个技能完成后，自动进入下一个阶段。遇到 Bug 可用 `/diagnosing-bugs`，需要切换上下文时用 `/handoff`，定期运行 `/arch-review` 做架构体检。

AI 自动检测项目语言与框架（Java / Python / Go / Rust / PHP / Frontend，支持 Spring Boot / Spring Cloud Alibaba / Dubbo / Quarkus / Django / FastAPI / TensorFlow / PyTorch / LangChain / Gin / Beego / GoFrame / Kitex / Axum / Actix Web / Laravel / ThinkPHP / Symfony / React / Vue / Angular / Next.js 等 80+ 主流框架和构建工具），生成 `.harness/` 目录：
- **Owner Agent** — 应用负责人智能体（灵魂，定义你是谁、怎么工作）
- **Rules** — 5 条规则（SDD-TDD / 编码规范 / 工程结构 / 开发流程 / 运行时可靠性）
- **Skills** — 30+ 个技能（6 流水线 + 3 通用辅助 + 3 场景辅助 + 18 封装组件 + 2 领域专家）
- **Changes** — 默认每需求一张变更卡 + 一份六阶段 report.md；全栈仅协调层汇总，子仓保留执行卡，运行数据放被忽略的 changes/.runtime/（[协议与兼容说明](docs/change-management.md)）
- **Wiki** — 领域知识库模板
- **CONTEXT.md** — 共享语言机制（AI 与人类间的术语表）

## 支持的语言

> 当前目录中包含 Java、Python、Go、Rust、Frontend 五个语言包。入口技能和下表仍包含 PHP 检测与参数说明，但 `skills/harness-php/` 尚缺失，PHP 配套规则需补齐后才能完整使用。

| 语言 | 支持框架 | 构建工具 | 测试框架 | 代码规范 |
|------|---------|---------|---------|---------|
| **Java** | Spring Boot / Spring Cloud Alibaba / Spring MVC / Quarkus / Micronaut / Vert.x / Dropwizard / Dubbo / Spring AI / Spring AI Alibaba / LangChain4j / Semantic Kernel / AgentScope Java / Genkit Java | Maven / Gradle | JUnit 5 + Mockito | p3c-pmd + PMD |
| **Python** | Django / FastAPI / Flask / Tornado / TensorFlow / PyTorch / Keras / scikit-learn / XGBoost / LangChain / LangGraph / CrewAI / PydanticAI / Hugging Face Transformers / OpenAI Agents SDK | pip / Poetry / uv | pytest（Django 用 TestCase） | flake8 + mypy + black |
| **Go** | Gin / go-zero / Echo / Fiber / Chi / Beego / Go-Kit / Go-Kratos / Gorilla Mux / Kitex / Hertz / Iris / Macaron / Tango / GoFrame / LangChainGo / eino / ADK-Go / tRPC-Agent-Go / Genkit / Anyi | go mod | go test + testify | golangci-lint + go vet |
| **Rust** | Axum / Actix Web / Rocket / Warp / Poem / Loco / Salvo / Tauri / Iced / egui / Dioxus / Candle / Burn / tch-rs / ort / rlx-models / ADK-Rust / Blockcell / vLLM | cargo | cargo test + rstest | clippy + rustfmt |
| **PHP** | Laravel / Laravel AI SDK / Neuron AI / LLPhant / Prism / PocketFlow PHP / Cognesy Instructor PHP / Papiai / ThinkPHP / Hyperf / Yii / Yii 3 / Workerman / webman / CodeIgniter (CI) / Slim / WordPress / WooCommerce / Drupal / Joomla / phpcms / dedecms / discuz / Phalcon / CakePHP / Craft CMS / October CMS / OpenCart / GravCMS / Symfony2 / Yaf / Swoole | composer | PHPUnit | phpstan + php-cs-fixer |
| **Frontend** | Vue 3 / React / Angular / Svelte / Next.js / Nuxt | Vite / Webpack / Angular CLI | Vitest / Jest / Jasmine | ESLint + Prettier |

## 技能清单

| 技能 | 阶段 | 一句话摘要                                                      |
|------|------|------------------------------------------------------------|
| `/install-skill` | 技能注册 | 手动将 `.harness/skills/` 下的技能注册到当前 AI 工具（19+ 主流工具），使斜杠命令立即可用 |
| `/harness-me` | 需求打磨 | 一场"灵魂拷问"式对话，帮你把模糊需求打磨到可落地                                  |
| `/harnessing` | ① 需求分析 | 规格构建、AC 可测试、边界 ≥3；一次只问一个问题，沿决策树推进，输出需求总结卡片 |
| `/coding-skill` | ② 编码实现 | 先写失败测试 → 最小实现 → 重构，垂直切片不批量                                 |
| `/unit-test-write` | ③ 单测编写 | 每条 AC 一个测试，覆盖率 ≥80%，不测 happy path                          |
| `/expert-reviewer` | ④ 专家评审 | 双轴并行子智能体评审（Spec + Standards 独立派发），0 个 🔴 才放行              |
| `/unit-test-ci` | ⑤ CI 门禁 | 机械化执行，任一检查失败即红灯                                            |
| `/deploy-verify` | ⑥ 部署验证 | "CI 绿"≠"线上可用"，确认健康检查+链路+回滚                                 |
| `/domain-modeling` | 通用辅助 | 主动维护领域模型，术语敲定当场写 CONTEXT.md / ADR                          |
| `/research` | 通用辅助 | 对一手来源调研，结果落 wiki                                           |
| `/resolving-merge-conflicts` | 通用辅助 | 解决 git merge/rebase 冲突，保留双方意图                              |
| `/diagnosing-bugs` | Bug 诊断 | 先建反馈循环再猜原因，6 阶段严谨流程                                        |
| `/handoff` | 上下文交接 | 压缩对话上下文为交接文档，无缝续接                                          |
| `/arch-review` | 架构体检 | 扫描浅模块，生成 Mermaid 报告，逐一打磨                                   |

### 封装组件技能（18 个，即插即用）

| 技能 | 领域 | 一句话摘要 |
|------|------|------------|
| `/redis-cache-wrapper` | 缓存 | 多级缓存封装（穿透/击穿/雪崩防护、分布式锁、热 key 探测） |
| `/database-migration-toolkit` | 数据库迁移 | 迁移模板、回滚脚本、数据回填辅助、兼容性检查 |
| `/kafka-toolkit` | 消息中间件 | 消费者封装（幂等/重试/DLQ）、生产者封装、Lag 监控 |
| `/k8s-release-toolkit` | K8s 部署 | Deployment/HPA/探针/灰度发布/回滚检查脚本 |
| `/performance-toolkit` | 性能诊断 | 一键诊断脚本、火焰图采集、GC 分析、慢 SQL 分析、线程 dump |
| `/security-toolkit` | 安全 | 脱敏/加密工具、输入校验、鉴权中间件、日志脱敏、安全配置 |
| `/rocketmq-toolkit` | 消息中间件 | 事务消息（半消息+反查）、顺序消息、延迟消息、DLQ |
| `/http-client-toolkit` | HTTP 调用 | 连接池管理、超时三件套、重试/熔断/负载均衡、traceId 透传 |
| `/logging-toolkit` | 日志 | MDC traceId 自动注入、日志脱敏、动态级别 API、文件策略 |
| `/scheduler-toolkit` | 分布式调度 | 分布式锁调度、任务幂等、补偿机制、控制台 API |
| `/oss-toolkit` | 对象存储 | 统一接口、分片上传/断点续传、图片处理、CDN 刷新 |
| `/excel-toolkit` | Excel | 模板导出、大数据量分批、导入校验、动态列/合并单元格 |
| `/eventbus-toolkit` | 事件总线 | 同步/异步事件、事务事件、事件追踪持久化 |
| `/java-code-review` | Java 并发 | 线程池工厂、锁模板、重试模板、限流模板、异步模板 |
| `/spring-api-convention` | Spring API | 统一响应体、全局异常处理、幂等注解、分页工具、traceId 链路 |
| `/mybatis-toolkit` | MyBatis | 通用分页、乐观锁、逻辑删除、自动填充、数据权限、批量操作 |
| `/openfeign-toolkit` | OpenFeign | 统一超时、错误解码器、重试、traceId/鉴权拦截器、熔断集成 |
| `/db-encrypt-toolkit` | 数据库安全 | 15+ 数据库敏感字段加密方案生成器：视图+触发器+定时任务 / 协议代理自动分诊，生成方言验证脚本与实施清单 |

## 核心设计理念

1. **Owner Agent 是灵魂** — 它定义"你是谁、怎么工作、怎么决策"
2. **方法论跨语言通用** — SDD-TDD、6 阶段流水线、变更状态机、人机协同协议
3. **技术栈语言特有** — 编码规范、工程结构、工具链按语言独立
4. **一键迁移** — 在任意项目执行 `/apply-harness` 即可应用完整规范
5. **垂直切片** — 一次只做一个 Red-Green-Refactor 循环，不批量
6. **战争迷雾** — 只规划当前层，下一层做标记，迷雾层不碰

## 项目结构

```text
harness-skills/
├── skills/
│   ├── apply-harness/             # 入口技能：检测技术栈并生成 .harness/
│   ├── install-skill/             # 将技能注册到 AI 工具
│   ├── harness-core/
│   │   ├── SKILL.md               # 核心骨架说明
│   │   ├── agents/                # 技能界面配置
│   │   ├── rules/                 # 跨语言流程与治理规则
│   │   ├── skills/                # 流水线、辅助与工具包技能
│   │   └── templates/             # Owner、Wiki、变更、迭代、门禁脚本与 hooks
│   ├── harness-java/              # Java 规则与 4 个框架专属技能
│   ├── harness-python/            # Python 规则与参数
│   ├── harness-golang/            # Go 规则与参数
│   ├── harness-rust/              # Rust 规则与参数
│   └── harness-front/             # 前端规则与参数
├── docs/
│   ├── README.md                  # 文档索引
│   ├── harness-usage.md           # 实际项目落地使用手册
│   ├── harness-principles/        # 门禁脚本与 hooks 原理
│   ├── skills/                    # 各技能使用说明
│   ├── languages/                 # 各语言规范说明
│   ├── arch/                      # 脚手架架构图
│   └── archive/                   # 已完成工作的记录与历史规划
├── .gitignore
├── CONTEXT.md                     # 项目共享上下文
└── README.md
```

## 学习路径

建议按以下顺序阅读文档：

1. **[Harness Engineering 总览](docs/harness-overview.md)** — 了解核心概念和哲学
2. **[Owner Agent](docs/owner-agent.md)** — 了解应用负责人智能体
3. **[SDD-TDD 方法论](docs/sdd-tdd.md)** — 了解规格驱动 + 测试驱动开发
4. **[6 阶段流水线](docs/6-stage-pipeline.md)** — 了解完整流水线
5. **[变更管理](docs/change-management.md)** — 了解变更状态机
6. **语言规范** — 选择你的语言：[Java](docs/languages/java.md) / [Python](docs/languages/python.md) / [Go](docs/languages/golang.md) / [Rust](docs/languages/rust.md) / [PHP](docs/languages/php.md) / [Frontend](docs/languages/frontend.md)
7. **各技能文档** — 查看 [技能说明索引](docs/skills/README.md)

> 📖 **完整文档中心**: [docs/README.md](docs/README.md)

