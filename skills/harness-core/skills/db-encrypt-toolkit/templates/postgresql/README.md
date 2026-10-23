# PostgreSQL 方言验证模板 —— 视图 + 触发器 + 定时任务加密

> 对应 Oracle 模板 `templates/oracle/`，语法按 PostgreSQL 改写。
> 运行：`psql -U <user> -d <db> -v ON_ERROR_STOP=off -f 00_setup.sql`（01-03 同理；`-X` 避免把 .psqlrc 带进来）。

## 与 Oracle 模板的差异

| Oracle | PostgreSQL |
|---|---|
| `DBMS_CRYPTO` 加密包 | `pgcrypto` 扩展（`CREATE EXTENSION IF NOT EXISTS pgcrypto;`，需超级用户或相应权限） |
| `UTL_I18N.STRING_TO_RAW / RAW_TO_CHAR` | `convert_to / convert_from(...,'UTF8')` |
| `RAWTOHEX` | `encode(...,'hex')`；解密前 `decode(...,'hex')` |
| `DBMS_CRYPTO.HASH(SHA256)` | `digest(...,'sha256')` |
| 包 `enc_pkg` | 三个独立函数 `enc_pkg_enc / enc_pkg_dec / enc_pkg_hsh`（plpgsql） |
| `DBMS_OUTPUT.PUT_LINE` | `RAISE NOTICE`（验证脚本用 `DO $$ ... $$` 匿名块） |
| `DBMS_SCHEDULER` 定时任务 | `pg_cron` 扩展（可选，示例见 00_setup.sql 末尾注释） |
| `EXPLAIN PLAN + DBMS_XPLAN` | `EXPLAIN (FORMAT TEXT)` |
| `DBMS_UTILITY.GET_CPU_TIME` | `clock_timestamp()` 差值（毫秒） |

## 文件

| 文件 | 对应 Oracle | 说明 |
|---|---|---|
| `00_setup.sql` | 00 | 加密函数（AES-256-CBC + SHA-256）+ 表拆分 + 同名视图 + INSTEAD OF 触发器 + 索引 + 造数 |
| `01_verify_dml.sql` | 01 | INSERT/UPDATE/DELETE/RETURNING/FOR UPDATE/MERGE/TRUNCATE/旁路直写 每个点输出 [PASS]/[FAIL] |
| `02_verify_query.sql` | 02 | JOIN/GROUP BY/HAVING/模糊/大小写/EXPLAIN 对比/数据字典/rowid |
| `03_verify_perf.sql` | 03 | 写入×2 / 查询×2 / 过滤×2 / 批量更新计时 |

## 判定标准（预期）

| 验证点 | 预期 |
|---|---|
| INSERT（带/不带列名） | ✅ INSTEAD OF 触发器拆分落 A1+A2 |
| UPDATE / DELETE（RETURNING 触发器中可用） | ✅ |
| UPDATE 视图 … RETURNING | ⚠️ 实测（PG 视图 + INSTEAD OF 下 RETURNING 行为） |
| SELECT … FOR UPDATE | ⚠️ 实测（PG 视图 FOR UPDATE 需 `FOR UPDATE OF` 显式锁定基表列） |
| MERGE（INSERT … ON CONFLICT / ON CONFLICT DO UPDATE） | ⚠️ 对视图不可行（ON CONFLICT 仅限单表） |
| TRUNCATE 视图 | ❌ `TRUNCATE` 不能作用于视图 |
| 视图上建普通 BEFORE/AFTER 触发器 | ❌ PG 视图只允许 INSTEAD OF 触发器 |
| 模糊查询走视图解密列 | ⚠️ 可跑但全表扫（密文不可 LIKE）→ 走 `tb_sensitive_p.fn` 辅助列 |
| 索引生效 | `fn`（辅助列）走索引、解密列 `f1` 走全扫（看 EXPLAIN） |
| 性能 | 写入慢约 5-20×（触发器+加密）、查询解密读慢（逐行 pgcrypto）、批量必须直写基表 |

> ⚠️ 无真实 PostgreSQL 环境时本模板未实测；各验证点均打印真实 PASS/FAIL 供回填。