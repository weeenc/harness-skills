# Go 语言规范包

## 概述

Harness Go 语言规范包为 Go 项目提供完整的开发规范体系，基于 Go Code Review Comments 和 Uber Go Style Guide，支持 Gin、go-zero、Echo、Fiber、Chi、Beego、Go-Kit、Go-Kratos、Gorilla Mux、Kitex、Hertz、Iris、GoFrame 等框架，以及 LangChainGo、eino、ADK-Go、Firebase Genkit 等 AI/LLM 框架。

## 基线

| 维度 | 选型 |
|------|------|
| **基线框架** | Go 1.22+ / Gin / go-zero / Echo / Fiber / Chi / Beego / Go-Kit / Go-Kratos / Gorilla Mux / Kitex / Hertz / Iris / Macaron / Tango / GoFrame / LangChainGo / Google ADK-Go / cloudwego eino / tRPC-Agent-Go / Firebase Genkit / Anyi |
| **构建工具** | go build / Makefile / go mod |
| **测试框架** | go test + testify |
| **覆盖率工具** | go test -cover（核心逻辑覆盖率 ≥80%） |
| **代码规范** | golangci-lint + go vet |
| **架构约束** | goimports + 自定义检查 |
| **安全扫描** | gosec |
| **数据库** | GORM / sqlx + golang-migrate |

## 规则

| 规则 | 来源 |
|------|------|
| 编码规范 | `harness-golang/rules/`（语言特有） |
| 工程结构 | `harness-golang/rules/`（语言特有） |
| SDD-TDD 模式 | `harness-core/rules/`（跨语言通用） |
| 开发流程规范 | `harness-core/rules/`（跨语言通用） |
| 运行时可靠性 | `harness-core/rules/`（跨语言通用） |

### 编码规范要点

- 遵循 Go Code Review Comments + Uber Go Style Guide
- 命名规范：驼峰（首字母大小写决定可见性）
- 接口名：`-er` 后缀（Reader、Writer）
- 文件 ≤800 行
- 函数 ≤50 行
- 每个 `case` 默认 `break`
- 错误处理：always check errors

### 工程结构要点

- 标准 Go 项目布局（`/cmd`、`/internal`、`/pkg`）
- `internal` 目录隔离内部实现
- 依赖注入通过构造函数显式传递
- 接口在消费者侧定义（consumer-side interface）
- HTTP 处理：Gin / Echo / Fiber / Chi / Iris / Macaron / Tango / Hertz 路由，或 go-zero REST 风格
- 微服务间通信：gRPC（go-zero）/ Kitex RPC / Go-Kit / Go-Kratos 标准布局
- Web 框架：Beego / GoFrame 全栈 MVC

## 技能

9 个技能（6 流水线 + 3 辅助），与语言无关的通用技能直接复用 `harness-core` 的模板。

## 适用项目

- Gin / go-zero / Echo / Fiber / Chi / Beego / Go-Kit / Go-Kratos / Gorilla Mux / Kitex / Hertz / Iris / GoFrame 微服务
- LangChainGo / eino / ADK-Go / Firebase Genkit / Anyi LLM/AI Agent 应用
- Go 1.22+ 项目
- 高性能后端服务