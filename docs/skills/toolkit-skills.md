# 工具包技能（Toolkit Skills）

> 这些技能是**自动注入**的工具包，由流水线技能在需要时按需调用，不是独立的斜杠命令。

## 列表

| 工具包 | 说明 |
|--------|------|
| `database-migration-toolkit` | 数据库迁移——迁移模板、回滚脚本、数据回填辅助、兼容性检查模板 |
| `eventbus-toolkit` | 事件总线——同步/异步事件、事务事件、事件追踪、事件总线配置 |
| `excel-toolkit` | Excel 工具——模板导出（填充+样式）、大数据量分批导出（SXSSF）、导入校验、动态列/合并单元格 |
| `http-client-toolkit` | HTTP 客户端——连接池管理、超时三件套、重试（指数退避）、熔断降级、负载均衡、traceId 透传 |
| `k8s-release-toolkit` | K8s 发布——Deployment 模板、HPA 配置、探针模板、灰度发布策略、回滚检查脚本 |
| `kafka-toolkit` | Kafka 工具——消费者封装（幂等消费/重试/DLQ）、生产者封装（确认/重试）、监控指标 |
| `logging-toolkit` | 日志工具——MDC traceId 自动注入、日志脱敏（配置化规则）、动态日志级别、日志文件策略 |
| `oss-toolkit` | 对象存储——统一接口（上传/下载/删除/预签名URL）、分片上传/断点续传、图片处理、CDN 刷新 |
| `performance-toolkit` | 性能诊断——诊断脚本、火焰图分析、GC 分析、慢 SQL 分析、线程 dump 分析模板 |
| `redis-cache-wrapper` | 多级缓存——穿透/击穿/雪崩防护、分布式锁、本地缓存 + Redis 双级缓存 |
| `rocketmq-toolkit` | RocketMQ 工具——事务消息（半消息+反查）、顺序消息、延迟消息、重试/DLQ |
| `scheduler-toolkit` | 分布式调度——分布式锁调度、任务幂等、失败重试、执行记录、手动触发/暂停/恢复 |
| `security-toolkit` | 安全工具——脱敏/加密工具、输入校验框架、鉴权模板、日志脱敏、安全配置 |

## Java 框架专属技能

| 技能 | 说明 |
|------|------|
| `java-code-review` | Java 代码评审（阿里巴巴规范 + 框架特有约定） |
| `spring-api-convention` | Spring Boot API 接口约定（RESTful 规范、异常处理、参数校验） |
| `mybatis-toolkit` | MyBatis 工具（代码生成、分页、批量操作、多数据源） |
| `openfeign-toolkit` | OpenFeign 工具（接口定义、熔断、日志、请求拦截） |

## 调用机制

这些工具包技能不是由用户直接通过斜杠命令调用的，而是由流水线技能（`coding-skill`、`arch-review` 等）在检测到项目使用了对应技术栈时，自动注入到上下文中的。

例如：
- 检测到 `pom.xml` 包含 `mybatis-spring-boot-starter` → 自动注入 `mybatis-toolkit`
- 检测到 `pom.xml` 包含 `spring-kafka` → 自动注入 `kafka-toolkit`
- 检测到 `application.yml` 包含 `redis` 配置 → 自动注入 `redis-cache-wrapper`