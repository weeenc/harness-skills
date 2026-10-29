# 一键应用 Harness — apply-harness

> **技能标识**: `apply-harness`
> **使用场景**: 初始化或补齐单仓项目，以及前后端独立 Git 仓库组成的全栈工作空间

## 它做什么？

在单仓根目录或全栈协调层执行一次 `/apply-harness`。单仓生成本地 `.harness/`；协调层自动发现前后端仓库，生成协调资产，再逐仓完成初始化与技能注册，不需要前端、后端、协调层各调用一次。

再次执行会检查已有结果：相同内容跳过，缺失项补齐，本地定制保留；需要更新已有内容时列出具体差异。某仓失败不重做已成功的仓库，修正后从协调层再次执行即可续跑。

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

### Step 0: 判断作用域与已有状态

发现独立 Git 仓库（包含 `.git` 文件形式的 worktree/submodule），结合已有 repo-map 确定范围。前后端分别检测技术栈；协调层不生成语言 Owner 和规则。直接在子仓调用时只处理当前仓库。详见 [全栈初始化与开发](multi-repo-development.md)。

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

### Step 5.5: 自动注册技能

复用 [install-skill](install-skill.md) 的注册流程。Codex 新入口使用项目 `.agents/skills/`；逐个作用域检查项目与个人来源，同内容复用，同名不同内容报告冲突。注册目录使用渲染后的名称，例如 `coding-skill-java`、`coding-skill-front`，避免不同语言互相覆盖。

### Step 6: 创建变更追踪目录

创建 `.harness/changes/` 产物协议、忽略规则和模板。新需求默认 compact：一张卡片 + 一份六阶段 report.md，全栈由协调层汇总、子仓保留执行卡；运行数据写 changes/.runtime/ 并忽略。旧卡不自动迁移，wiki/tech/rules 等维持原逻辑。

## 约束

- 保留已有知识、需求历史、手工规则和配置；默认补缺，不整目录覆盖。
- 独立前后端分别检测；单仓多语言且用途不明确时再询问。
- 协调层可以暂不建 Git，初始化仍可继续，但需提示协调资产尚未版本控制。
- 初始化、技能注册、门禁验证分别报告，不能把文件已生成等同于业务门禁通过。

## 相关文档

- [安装技能](install-skill.md) — 初始化自动调用；已有项目拉取后或注册失败时可单独重试
