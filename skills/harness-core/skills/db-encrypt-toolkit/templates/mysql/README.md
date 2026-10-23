# MySQL / MariaDB 方言验证模板 —— 加密路线的"可更新视图边界"验证

> **重要差异**：MySQL/MariaDB **没有 INSTEAD OF 触发器**，因此 Oracle 模板的"写时透明加密"（INSERT 由触发器拆分+加密）**无法实现**。本模板的定位是 🟡B 级：**验证可更新视图边界** + 演示"SQL 显式加密函数 + EVENT 定时任务"变体，用实测结论决定是否需要协议代理/应用层加密。
> 运行：`mysql -u <user> -p -h <host> <db> < 00_setup.sql`（01 有存储过程，用 `mysql < 01_verify_dml.sql`；`.sql` 内已含 DELIMITER 处理）。

## 与 Oracle 模板的差异（MySQL 视角）

| Oracle | MySQL / MariaDB |
|---|---|
| `DBMS_CRYPTO` | 内置 `AES_ENCRYPT / AES_DECRYPT`（8.0 默认块模式 `aes-128-ecb`，可用 `SET block_encryption_mode='aes-256-cbc'` 调整） |
| `DBMS_CRYPTO.HASH(SHA256)` | `SHA2(str, 256)` |
| 包 `enc_pkg` | 三条 SQL 表达式：`HEX(AES_ENCRYPT(...)) / AES_DECRYPT(UNHEX(...),...) / HEX(SHA2(...))`（或包装成存储函数） |
| INSTEAD OF 触发器 | ❌ **不存在** → 写时透明加密不可行（核心结论） |
| `:NEW / :OLD` | 触发器伪行（仅表可用 `NEW/OLD`；视图上不能建触发器） |
| 同名视图承载 DML | 仅"列映射式可更新视图"可 DML，但写入的必须是**密文**（不透明） |
| `DBMS_SCHEDULER` 定时任务 | `EVENT`（需 `event_scheduler=ON`、`SUPER` 权限） |
| `EXPLAIN PLAN + DBMS_XPLAN` | `EXPLAIN [FORMAT=JSON] SELECT ...` |
| 匿名块输出 | 存储过程 + `SELECT '...'`（无匿名块） |

## 文件

| 文件 | 说明 |
|---|---|
| `00_setup.sql` | 拆分表 + 同名视图（列映射可更新版 + 表达式解密版各一）+ AES/SHA2 表达式 + EVENT 示例 + 造数 |
| `01_verify_dml.sql` | 存过 `verify_dml`：10 条验证（列映射视图 DML / 表达式视图 DML / JOIN 视图 DML / TRUNCATE / 直写 / 视图造触发器 / FOR UPDATE），逐条 [PASS]/[FAIL] |
| `02_verify_query.sql` | JOIN / GROUP BY / HAVING / 模糊（密文 LIKE 失效演示）/ 大小写 / EXPLAIN 对比 / 信息模式字典 |
| `03_verify_perf.sql` | 写入×2 / 查询×2 / 过滤×2 / 批量更新计时（UNIX_TIMESTAMP(NOW(3)) 毫秒） |
| `README.md` | 本文件 |

## 判定标准（预期结论）

| 验证点 | 预期 | 含义 |
|---|---|---|
| 列映射视图 INSERT/UPDATE/DELETE | ✅ | 单表可更新视图可 DML，但值=密文（不透明） |
| 表达式视图（f1=解密函数）INSERT | ❌ 不可更新列 | 证明"透明读+透明写"无法兼得 |
| JOIN / 聚合视图 DML | ❌ | 可更新视图边界 |
| TRUNCATE 视图 | ❌ | DDL 不可覆盖 |
| 视图上建触发器 | ❌ | MySQL 不支持 |
| 模糊 LIKE 密文列 | ⚠️ 永不匹配 | 必须走 tb_sensitive_p 辅助列或应用层 |
| 结论输出 | — | 命中 2/4/6 → 转协议代理或应用层加密 |

> ⚠️ 无真实 MySQL 环境时本模板未实测；各验证点输出真实结果供回填。OceanBase(MySQL 模式)、Aurora MySQL 与本模板一致（差异见各自文档）。