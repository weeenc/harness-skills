# 一键应用 Harness — apply-harness

> **技能标识**: `apply-harness`
> **使用场景**: 在新项目初始化 Harness 开发规范体系

## 它做什么？

在任意项目根目录执行此命令，自动检测项目语言、框架与构建工具，生成 `.harness/` 目录（含 Owner Agent 定义、规则、技能、变更追踪、领域知识库）。

## 支持的语言和框架

| 语言 | 框架检测（部分） | 构建工具 |
|------|----------------|---------|
| Java | Spring Boot / Quarkus / Micronaut / Vert.x / Dropwizard / Spring MVC / Dubbo / Spring Cloud Alibaba / Spring AI / LangChain4j / Semantic Kernel / AgentScope Java / Genkit Java | Maven / Gradle |
| Python | Django / FastAPI / Flask / Tornado / TensorFlow / PyTorch / LangChain / LangGraph / CrewAI / PydanticAI / SmolAgents / OpenAI Agents SDK | pip / poetry / uv |
| Go | Gin / go-zero / Echo / Fiber / Chi / Beego / Go-Kit / Go-Kratos / Kitex / Hertz / Iris / GoFrame / LangChainGo / eino / ADK-Go / Genkit / Anyi | go mod |
| Rust | Axum / Actix Web / Rocket / Warp / Poem / Loco / Salvo / Tauri / Iced / egui / Dioxus / Candle / Burn / tch-rs / ort / ADK-Rust / vLLM | cargo |
| PHP | Laravel / Laravel AI SDK / Neuron AI / LLPhant / Prism / ThinkPHP / Hyperf / Yii / Workerman / webman / CodeIgniter / Slim / WordPress / WooCommerce / Drupal / Joomla / phpcms / discuz / Phalcon / CakePHP / Symfony2 / Swoole | composer |
| Frontend | Vue 3 / React / Angular / Svelte / Next.js / Nuxt | npm / pnpm / yarn |

## 工作流程

### Step 1: 检测项目语言与框架

扫描项目根目录特征文件，按优先级检测语言、框架和构建工具。支持 120+ 主流框架。

### Step 2: 读取项目名称

从 `pom.xml` / `go.mod` / `Cargo.toml` / `package.json` / `composer.json` / `pyproject.toml` 等文件读取项目名称。

### Step 3: 渲染 Owner Agent

将 `harness-core/templates/agents/owner.md` 参数化渲染，生成 `.harness/agents/owner.md`。

### Step 4: 复制规则文件

- 从 `harness-core/rules/` 复制通用规则（SDD-TDD 模式、开发流程规范、变更定位规则、运行时可靠性）
- 从 `harness-{lang}/rules/` 复制语言特有规则（编码规范、工程结构）

### Step 5: 渲染技能模板 + 复制技能文件

- 从 `harness-core/skills/` 渲染 10 个流水线/辅助技能模板
- 复制语言包专属技能（如 `java-code-review`、`spring-api-convention` 等）

### Step 6: 创建变更追踪目录

创建 `.harness/changes/` 目录结构，用于后续变更管理。

## 约束

- ❌ 禁止修改已存在的 `.harness/` 内容（除非用户明确要求覆盖）
- ❌ 禁止在检测到多语言时擅自选择
- ✅ 如果 `.harness/` 已存在，输出提示并询问是否覆盖

## 相关文档

- [安装技能](install-skill.md) — 执行 `/apply-harness` 后运行 `/install-skill` 注册斜杠命令