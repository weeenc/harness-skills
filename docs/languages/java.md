# Java 语言规范包

## 概述

Harness Java 语言规范包为 Java 项目提供完整的开发规范体系，基于阿里巴巴 Java 开发手册，支持 Spring Boot、Spring Cloud Alibaba、Spring MVC、Quarkus、Micronaut、Vert.x、Dropwizard、Dubbo 等框架，以及 Spring AI、Spring AI Alibaba、LangChain4j、Semantic Kernel、AgentScope、Genkit 等 AI/LLM 框架，覆盖 Maven/Gradle 构建工具。

## 基线

| 维度 | 选型 |
|------|------|
| **基线框架** | Spring Boot 3.x+ / Spring Cloud Alibaba / Spring MVC 6.x / Quarkus 3.x / Micronaut 4.x / Vert.x 4.x / Dropwizard 4.x / Dubbo 3.x / Spring AI 1.x / LangChain4j 1.x / Semantic Kernel / AgentScope Java / Genkit Java |
| **JDK 版本** | JDK 21 LTS（推荐） / JDK 17 LTS |
| **构建工具** | Maven 3.9+ / Gradle 8.x（Gradle Wrapper） |
| **测试框架** | JUnit 5 + Mockito + AssertJ |
| **覆盖率工具** | JaCoCo（核心逻辑覆盖率 ≥80%） |
| **代码规范** | 阿里巴巴 Java 开发手册 + Checkstyle + PMD |
| **架构约束** | ArchUnit |
| **安全扫描** | SpotBugs + OWASP Dependency Check |
| **数据库** | MyBatis-Plus / JPA / Hibernate Panache + Flyway（AI 框架用向量库 + 元数据存储） |

## 规则

| 规则 | 来源 |
|------|------|
| 编码规范 | `harness-java/rules/`（语言特有） |
| 工程结构 | `harness-java/rules/`（语言特有） |
| SDD-TDD 模式 | `harness-core/rules/`（跨语言通用） |
| 开发流程规范 | `harness-core/rules/`（跨语言通用） |
| 运行时可靠性 | `harness-core/rules/`（跨语言通用） |

### 编码规范要点

- 遵循阿里巴巴 Java 开发手册（黄山版）
- 类名：UpperCamelCase
- 方法名：lowerCamelCase
- 常量：UPPER_SNAKE_CASE
- 文件 ≤500 行
- 方法 ≤50 行
- 圈复杂度 ≤10

### 工程结构要点

- Maven/Gradle 多模块架构
- `controller` → `service` → `mapper` 分层（RPC 框架用 Provider/Consumer，AI 框架用 Chain/Agent/Tool）
- 领域驱动包结构（`entity` / `repository` / `service` / `controller` / `dto`）
- Controller 只做参数校验和路由，不包含业务逻辑
- Service 层承担业务逻辑，不直接操作数据库
- Mapper/Repository 层只做数据访问

## 技能

9 个技能（6 流水线 + 3 辅助），与语言无关的通用技能直接复用 `harness-core` 的模板。

## 适用项目

- Spring Boot / Spring Cloud Alibaba / Quarkus / Micronaut / Vert.x / Dropwizard / Spring MVC / Dubbo 微服务
- Spring AI / Spring AI Alibaba / LangChain4j / Semantic Kernel / AgentScope Java / Genkit Java AI 应用
- Maven 或 Gradle 多模块项目
- JDK 21 LTS 或以上