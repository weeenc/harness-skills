# Oracle 实测验证脚本 —— 「视图 + 触发器 + 定时任务加密」路线

> 配套文档：同目录 `方案讨论.md`（完整方案与结论）。
> 用途：在目标 Oracle 环境跑出「支持 / 不支持 / 性能数据」，回答 Excel 中 5 条待验证项：
> ① 数据库适配 ② 复杂语句适配性 ③ 关联查询 ④ 加密过程是否停服务 ⑤ group by / having / 索引。

## 文件清单与运行顺序

| 文件 | 作用 | 运行命令（SQL*Plus） |
|---|---|---|
| `00_setup.sql` | 初始化：加密函数包 + 表拆分 + 同名视图 + INSTEAD OF 触发器 + 索引 | `@00_setup.sql` |
| `01_verify_dml.sql` | DML/DDL 支持性验证（INSERT/UPDATE/DELETE/RETURNING/FOR UPDATE/MERGE/TRUNCATE/直连） | `@01_verify_dml.sql` |
| `02_verify_query.sql` | 查询类验证（JOIN / GROUP BY / HAVING / 模糊 / 大小写 / 谓词下推 / 数据字典 / rowid） | `@02_verify_query.sql` |
| `03_verify_perf.sql` | 性能对比（写入x2 / 查询x2 / 过滤x2 / 批量更新），输出耗时供记录 | `@03_verify_perf.sql` |

建议执行：`SET SERVEROUTPUT ON` 后再 `@` 各脚本；均可在同一会话连续执行（01/02/03 自带数据重置）。

## 方言模板索引（Oracle 之外的库）

本目录是 **Oracle 基准模板**（也是仓库文档中心）。其余方言的可执行模板集成在技能包 `db-encrypt-toolkit` 内
（`skills/harness-core/skills/db-encrypt-toolkit/templates/<dialect>/`，00-03 判定点与 Oracle 一一对应）：

| 模板目录 | 覆盖数据库 | 关键差异 |
|---|---|---|
| `templates/oracle/` | Oracle、达梦 DM8、OceanBase(Oracle 模式) | 基准（本目录，双份同步） |
| `templates/postgresql/` | PostgreSQL、人大金仓 KingbaseES、openGauss、Aurora PostgreSQL | `pgcrypto` + `RAISE NOTICE` + `pg_cron` |
| `templates/sqlserver/` | SQL Server、Azure SQL | `ENCRYPTBYPASSPHRASE/HASHBYTES` + `OUTPUT` + `UPDLOCK` + SQL Agent |
| `templates/mysql/` | MySQL、MariaDB、OceanBase(MySQL 模式)、Aurora MySQL | **无 INSTEAD OF**：可更新视图边界验证 + `AES_*` + `EVENT`（写透明加密不可行） |
| `templates/sqlite/` | SQLite（嵌入式） | 无内置 AES：INSTEAD OF 拆分 + 应用层加解密 |

> 🔴 类（TiDB / CockroachDB / Spanner / Hive / Trino / Snowflake / BigQuery / Redshift）：不支持 INSTEAD OF 或视图 DML，
> 一律走协议代理需求说明书，不取上方模板。

## 运行前提（权限）

- `CREATE TABLE / CREATE VIEW / CREATE TRIGGER / CREATE PROCEDURE`
- `EXECUTE ON sys.dbms_crypto`（加密包用；生产密评环境改为 KMS/HSM 密钥管理，脚本内为演示密钥）
- `ALTER TABLE ... RENAME`（模拟原表隐藏）

## 判定标准速查（预期结论，实测为准）

| # | 验证点 | 预期 | 说明 |
|---|---|---|---|
| D1 | INSERT（带/不带列名） | SUPPORTED | INSTEAD OF 触发器拆分落 A1+A2 |
| D2 | UPDATE / DELETE | SUPPORTED | 同上 |
| D3 | UPDATE ... RETURNING | 实测 | 带 INSTEAD OF 触发器时行为受限 |
| D4 | SELECT ... FOR UPDATE | 实测 | 多基表锁定范围放大 |
| D5 | MERGE INTO 视图 | 预期受限 | 视情况 ORA-38106/38107 等，脚本如实报错 |
| D6 | TRUNCATE 视图 | 预期 UNSUPPORTED | TRUNCATE 是 DDL，INSTEAD OF 拦不住 |
| D7 | 基表/视图上建普通 BEFORE 触发器 | 预期 ORA-38069 | 视图只能 INSTEAD OF |
| Q1 | JOIN 关联查询 | SUPPORTED | 语义正确性 OK |
| Q2 | GROUP BY / HAVING（普通列） | SUPPORTED | 性能取决于是否命中底层索引 |
| Q3 | GROUP BY 敏感列（解密列） | 可跑但全表解密聚合 | 谓词 / 分组无法下推 |
| Q4 | LIKE 模糊查询走视图 F1 | 可跑但全表扫 | 密文不可 LIKE；靠 A2.FN 辅助列 |
| Q5 | 索引生效验证 | 看执行计划 | FN（辅助列）走索引、F1（解密列）走全扫 |
| P1 | 写入性能（视图 vs 直写基表） | 预期视图 2~5x 慢 | 触发器 + 加解密开销 |
| P2 | 查询性能（解密读 vs 明文直读） | 预期明显更慢 | 逐行 DBMS_CRYPTO 解密 |
| P3 | 过滤性能（解密列 vs 辅助列索引） | 预期数量级差距 | 下推 vs 全扫 |
| P4 | 批量 UPDATE 经视图 | 预期不可接受 | 批处理应直写基表 |

> 重要：本环境无法连接 Oracle，脚本未在真实库执行；所有「预期」需在目标库实测后回填，
> 脚本保证的是把每条 SQL 的真实结果（成功或 ORA-xxxxx）如实打印出来。

## 注意事项

1. 密钥硬编码仅用于演示；生产密评用 KMS / HSM / 国密 SM4，换算法只改 `enc_pkg` 内部。
2. `DBMS_CRYPTO` 需 `GRANT EXECUTE ON sys.dbms_crypto TO <user>;`。
3. 01/02/03 脚本开头均会重置演示数据，可反复执行。
4. 性能数据写入 `03_verify_perf.sql` 输出的表格，按需记录回 Excel「需调研验证内容」。