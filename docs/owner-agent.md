# Owner Agent — 应用负责人智能体

## 什么是 Owner Agent？

**Owner Agent** 是 Harness 体系的核心——它是"应用负责人"的 AI 化身，持有项目身份、规则、技能和上下文，编排整个 6 阶段流水线。

Owner Agent 的定义文件位于 `.harness/agents/owner.md`，由 `apply-harness` 技能在初始化时根据项目参数自动渲染生成。

## Owner Agent 的职责

### 1. 身份持有

Owner Agent 知道"我是谁"：

- 项目名称
- 语言和技术栈
- 构建工具和测试框架
- 代码规范和架构约束工具

### 2. 规则裁决

它持有全部 5 条规则，在流水线每个阶段对照规则校验输出：

- 编码规范是否遵守？
- 工程结构是否合规？
- SDD-TDD 模式是否遵循？
- 开发流程是否跳步？
- 运行时可靠性是否满足？

### 3. 流水线编排

它是 6 阶段流水线的调度者：

```
你 → 一句话需求 → Owner Agent
                    ↓
             ① harnessing  →  规格卡
                    ↓
             ② coding-skill      →  实现代码
                    ↓
             ③ unit-test-write   →  测试套件
                    ↓
             ④ expert-reviewer   →  评审报告
                    ↓
             ⑤ unit-test-ci      →  门禁结果
                    ↓
             ⑥ deploy-verify     →  验证报告
                    ↓
              交付
```

### 4. 上下文维护

维护 `.harness/CONTEXT.md` 共享语言机制，确保多轮对话中术语一致。

## 参数化模板

Owner Agent 是**参数化模板**渲染的产物。`apply-harness` 技能检测项目语言后，将模板中的占位符替换为实际值：

| 参数 | 示例（Java） |
|------|-------------|
| `{{PROJECT_NAME}}` | `my-app` |
| `{{LANGUAGE}}` | `Java` |
| `{{LANGUAGE_DESC}}` | `Java、Spring Boot、多模块 Maven 架构` |
| `{{LANGUAGE_RUNTIME}}` | `JDK 21 LTS` |
| `{{FRAMEWORK_VER}}` | `Spring Boot 3.x+` |
| `{{BUILD_TOOL}}` | `Maven 3.9+` |
| `{{TEST_FRAMEWORK}}` | `JUnit 5 + Mockito + AssertJ` |
| `{{COV_TOOL}}` | `JaCoCo` |
| `{{LINT_TOOL}}` | `Checkstyle + PMD + SpotBugs` |
| `{{ARCH_TEST_TOOL}}` | `ArchUnit` |
| `{{DB_ACCESS}}` | `MyBatis-Plus / JPA + Flyway` |

## 与普通 AI 助手的区别

| 维度 | 普通 AI 助手 | Owner Agent |
|------|------------|-------------|
| 身份 | 通用，每次对话重新建立 | 持有项目身份，持久化 |
| 规则 | 随上下文消失 | 5 条规则持久存储在 `.harness/rules/` |
| 流程 | 无固定流程 | 6 阶段流水线，不可跳步 |
| 追溯 | 聊天记录 | 变更卡 + 评审报告 + 验证报告 |
| 术语 | 每次重新定义 | CONTEXT.md 持久积累 |