# Rust 语言规范包

## 概述

Harness Rust 语言规范包为 Rust 项目提供完整的开发规范体系，基于 Rust API Guidelines 与 Rust 官方风格指南（Rustfmt / Clippy），支持 Axum、Actix Web、Rocket、Warp、Poem、Loco、Salvo 等 Web 框架，Candle、Burn、tch-rs、ort、rlx-models 等 AI/深度学习框架，Tauri、Iced、egui、Dioxus 等桌面/UI 框架，以及 ADK-Rust、Blockcell、vLLM 等 Agent/推理框架。

## 基线

| 维度 | 选型 |
|------|------|
| **基线框架** | Rust 1.75+ / Axum / Actix Web / Rocket / Warp / Poem / Loco / Salvo / Tauri / Iced / egui / Dioxus / Candle / Burn / tch-rs / ort / rlx-models / ADK-Rust / Blockcell / vLLM |
| **构建工具** | cargo build（cargo 工作区） |
| **测试框架** | cargo test + rstest / mockall |
| **覆盖率工具** | cargo llvm-cov（核心逻辑覆盖率 ≥80%） |
| **代码规范** | cargo fmt + cargo clippy -- -D warnings |
| **架构约束** | 自定义模块检查（cargo clippy + crate 边界） |
| **安全扫描** | cargo audit |
| **数据库** | SQLx / Diesel / SeaORM + sqlx-cli 迁移 |

## 规则

| 规则 | 来源 |
|------|------|
| 编码规范 | `harness-rust/rules/`（语言特有） |
| 工程结构 | `harness-rust/rules/`（语言特有） |
| SDD-TDD 模式 | `harness-core/rules/`（跨语言通用） |
| 开发流程规范 | `harness-core/rules/`（跨语言通用） |
| 运行时可靠性 | `harness-core/rules/`（跨语言通用） |

### 编码规范要点

- 遵循 Rustfmt 默认格式 + Clippy 严格模式
- 命名规范：snake_case（函数/变量）、CamelCase（类型）、SCREAMING_SNAKE_CASE（常量）
- 错误处理：用 `Result<T, E>` + `thiserror` / `anyhow`，避免裸 `unwrap()` / `expect()`
- 所有权/借用：合理使用引用与生命周期，避免不必要的 `clone()`
- 文件 ≤600 行
- 函数 ≤50 行
- 禁止在库代码中使用 `unsafe`（除非有安全注释与验证）

### 工程结构要点

- 标准 Rust 工程布局（`src/`、`tests/`、`benches/`、`examples/`）
- `mod` 划分清晰，公开 API 最小化（`pub use` 收敛）
- 依赖注入通过泛型/trait 显式传递
- trait 定义在消费方（consumer-side trait）
- HTTP 处理：Axum Router → Handler / Actix App → Handler / Rocket 路由 → Controller
- 深度学习/LLM：Candle / Burn / tch-rs / ort / rlx-models 训练与推理管线
- 桌面应用：Tauri Rust Core + 前端 WebView，或 Iced / egui / Dioxus 纯 Rust UI

## 技能

10 个流水线/辅助技能由 `apply-harness` 从 `harness-core/skills/` 模板渲染（唯一事实源），Rust 语言包不维护同名副本；语言特有内容承载在 `rules/` 中。

## 适用项目

- Axum / Actix Web / Rocket / Warp / Poem / Loco / Salvo Web 服务
- Candle / Burn / tch-rs / ort / rlx-models 深度学习与 LLM 推理应用
- ADK-Rust / Blockcell Agent 应用、vLLM 推理服务
- Tauri / Iced / egui / Dioxus 桌面与跨平台 UI 项目
- Rust 1.75+ 高性能后端服务