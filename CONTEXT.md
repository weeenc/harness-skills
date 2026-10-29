# 项目术语表（CONTEXT.md）

> 本技能包的共享上下文，记录项目特有的术语、约定、目录结构。
> 供 AI 在对话和开发中保持一致的语义理解。

## 项目概述

**harness-skills** 是一套开箱即用的 Harness Engineering 跨语言开发流水线技能包，支持 Java / Python / Go / Rust / PHP / Frontend 六种语言，涵盖 Spring Boot、Spring Cloud Alibaba、Spring MVC、Quarkus、Micronaut、Vert.x、Dropwizard、Dubbo、Spring AI、Spring AI Alibaba、AgentScope Java、LangChain4j、Semantic Kernel、Genkit Java、Django、FastAPI、Flask、Tornado、TensorFlow、PyTorch、Keras、scikit-learn、XGBoost、Hugging Face Transformers、LangChain、LangGraph、CrewAI、PydanticAI、SmolAgents、OpenAI Agents SDK、Gin、go-zero、Echo、Fiber、Chi、Beego、Go-Kit、Go-Kratos、Gorilla Mux、Kitex、Hertz、Iris、Macaron、Tango、GoFrame、LangChainGo、Google ADK-Go、cloudwego eino、tRPC-Agent-Go、Firebase Genkit、Anyi、Axum、Actix Web、Rocket、Warp、Poem、Loco、Salvo、Tauri、Iced、egui、Dioxus、Candle、Burn、tch-rs、ort、rlx-models、ADK-Rust、Blockcell、vLLM、Laravel、Laravel AI SDK、Neuron AI、LLPhant、Prism、PocketFlow PHP、Cognesy Instructor PHP、Papiai、ThinkPHP、Hyperf、Yii / Yii 3、Workerman、webman、CodeIgniter (CI) / Slim、WordPress、WooCommerce、Drupal、Joomla、phpcms、dedecms、discuz、Phalcon、CakePHP、Craft CMS、October CMS、OpenCart、GravCMS、Symfony2、Yaf、Swoole、React、Vue、Angular、Svelte、Next.js、Nuxt 等 120+ 主流框架和 Maven、Gradle、pip、poetry、uv、go mod、npm、pnpm、yarn、Vite、Webpack、Angular CLI、cargo、composer 等主流构建工具。

## 项目边界

本项目仅维护 skill 定义、配套规则与模板，以及使用和维护文档。PRD 平台实现与资料、专栏文章、分享产物位于同级 `prd-ingestion/` 项目。根目录没有 npm 构建或插件发布流程；门禁脚本和 hooks 的源模板位于 `skills/harness-core/templates/`。

## 术语表

| 术语 | 含义 | 备注 |
|------|------|------|
| Harness | 人类设计约束、AI 写代码、机器验证的开发方法论 | |
| Owner Agent | 应用负责人智能体，编排 6 阶段流水线 | 模板在 `skills/harness-core/templates/agents/owner.md` |
| SDD-TDD | 规格驱动开发 + 测试驱动开发 | 先写规格 → 测试 → 代码 |
| AC | 验收条件（Acceptance Criteria） | 每条 AC 对应一个测试 |
| 垂直切片 | 一次只做一个 Red-Green-Refactor 循环，不批量 | |
| 战争迷雾 | 只规划当前层，下一层做标记，迷雾层不碰 | |
| 工作空间协调层 | 位于多个独立 Git 仓库之上的编排层，记录 repo-map、workspace change、契约版本与联合门禁 | 不复制仓库级 Harness 规则 |
| workspace change | 跨仓库需求的整体变更卡，关联多个仓库的 local change | 只有 required 仓库和联合验证都完成才算 done |
| local change | 某个独立 Git 仓库内执行 6 阶段流水线的变更卡 | 通过 workspace change 关联 |
| 契约单一来源 | 前后端共同引用的带版本 API/事件/数据契约 | mock、实现和 E2E 必须引用同一版本 |

## 目录结构

```text
harness-skills/
├── skills/
│   ├── apply-harness/
│   ├── install-skill/
│   ├── harness-core/            # 通用技能、规则及参数化模板
│   ├── harness-front/
│   ├── harness-golang/
│   ├── harness-java/
│   ├── harness-python/
│   └── harness-rust/
├── docs/                       # skill 使用说明、方法论及维护资料
├── .gitignore
├── CONTEXT.md
└── README.md
```

## 语言支持

> 当前实际提供五个语言包；PHP 的入口检测与说明已存在，但 `skills/harness-php/` 目录尚缺失。表中 PHP 为待补齐项。

| 语言 | 目录 | 支持框架 | 构建工具 |
|------|------|---------|---------|
| Java | `skills/harness-java/` | Spring Boot / Spring Cloud Alibaba / Spring MVC / Quarkus / Micronaut / Vert.x / Dropwizard / Dubbo / Spring AI / LangChain4j / Semantic Kernel / AgentScope / Genkit | Maven / Gradle |
| Python | `skills/harness-python/` | Django / FastAPI / Flask / Tornado / TensorFlow / PyTorch / Keras / scikit-learn / XGBoost / LangChain / LangGraph / CrewAI / PydanticAI / Hugging Face Transformers / OpenAI Agents SDK | pip / Poetry / uv |
| Go | `skills/harness-golang/` | Gin / go-zero / Echo / Fiber / Chi / Beego / Go-Kit / Go-Kratos / Gorilla Mux / Kitex / Hertz / Iris / GoFrame / LangChainGo / eino / ADK-Go / Genkit / Anyi | go mod |
| Rust | `skills/harness-rust/` | Axum / Actix Web / Rocket / Warp / Poem / Loco / Salvo / Tauri / Iced / egui / Dioxus / Candle / Burn / tch-rs / ort / rlx-models / ADK-Rust / Blockcell / vLLM | cargo |
| PHP（待补齐） | `skills/harness-php/`（尚缺失） | Laravel / Laravel AI SDK / Neuron AI / LLPhant / Prism / PocketFlow PHP / Cognesy Instructor PHP / Papiai / ThinkPHP / Hyperf / Yii / Yii 3 / Workerman / webman / CodeIgniter (CI) / Slim / WordPress / WooCommerce / Drupal / Joomla / phpcms / dedecms / discuz / Phalcon / CakePHP / Craft CMS / October CMS / OpenCart / GravCMS / Symfony2 / Yaf / Swoole | composer |
| Frontend | `skills/harness-front/` | Vue 3 / React / Angular / Svelte / Next.js / Nuxt | Vite / Webpack / Angular CLI |

## 6 阶段流水线

```
① harnessing  →  ② coding-skill  →  ③ unit-test-write  →  ④ expert-reviewer  →  ⑤ unit-test-ci  →  ⑥ deploy-verify
```

## 多仓库工作空间

多个独立 Git 仓库保持各自的 `.harness/`、Git 历史和本地门禁；工作空间协调层通过 `repo-map.yaml`、workspace change 和联合门禁编排全栈需求。相关技能为 `repo-discovery` 与 `workspace-orchestrator`。

初始化入口为协调层一次 `apply-harness`：发现仓库、生成协调资产、逐仓初始化、分别注册、统一汇总。重复调用默认检查与补缺，保留本地定制；一个子仓失败不重建其他仓库。单独从子仓调用时范围仅限该仓库。

---

> **使用方式**: AI 在对话开始时优先读取此文件以快速建立上下文。
> **技能注册**: `apply-harness` 自动执行 `install-skill` 的统一注册流程；已有项目拉取后或注册失败时可单独调用。Codex 新入口使用项目 `.agents/skills/`，按当前作用域比较项目与个人入口；同内容复用，同名不同内容报告冲突，不自动改动个人安装。
> 发现新术语或决策时，应同步更新此文件。
