# SQL Server 方言验证模板 —— 视图 + 触发器 + 定时任务加密

> 对应 Oracle 模板 `templates/oracle/`，语法按 T-SQL 改写。
> 运行：SQL Server Management Studio 打开执行，或 `sqlcmd -S <server> -U <user> -P <pwd> -i 00_setup.sql`（01-03 同理）。

## 与 Oracle 模板的差异

| Oracle | SQL Server |
|---|---|
| `DBMS_CRYPTO` 加密包 | 内置 `ENCRYPTBYPASSPHRASE / DECRYPTBYPASSPHRASE`（2008+，含随机 salt 的握手密文） |
| `DBMS_CRYPTO.HASH(SHA256)` | `HASHBYTES('SHA2_256', ...)` |
| 包 `enc_pkg` | DB 级标量函数 `dbo.enc_pkg_enc / dbo.enc_pkg_dec / dbo.enc_pkg_hsh` |
| `DBMS_OUTPUT.PUT_LINE` | `PRINT` |
| `UTL_I18N` 字节转换 | 不需要（函数原生处理 NVARCHAR/VARBINARY） |
| `:NEW / :OLD` | `inserted / deleted` 伪表 |
| 单个 INSTEAD OF 触发器三动作 | 拆 3 个触发器（`trg_ts_iof_i/u/d`），多行 UPDATE 用 `JOIN inserted` |
| UPDATE … RETURNING | `OUTPUT` 子句（视图+INSTEAD OF 下行为需实测） |
| SELECT … FOR UPDATE | `SELECT … WITH (UPDLOCK)` |
| MERGE | `MERGE`（目标必须为表，视图预期不支持） |
| TRUNCATE 视图 | 不可 TRUNCATE 视图（需 TRUNCATE 基表） |
| `DBMS_SCHEDULER` 定时任务 | SQL Server Agent（示例注释） |
| 包体编译方式 | 存储过程/函数无需 `CREATE PACKAGE`，直接 `CREATE FUNCTION`；脚本用 `GO` 分批 |

## 文件

| 文件 | 对应 Oracle | 说明 |
|---|---|---|
| `00_setup.sql` | 00 | 加密函数 + 表拆分 + 同名视图 + 3 个 INSTEAD OF 触发器 + 索引 + 造数 |
| `01_verify_dml.sql` | 01 | INSERT/UPDATE/DELETE/OUTPUT/UPDLOCK/MERGE/TRUNCATE/旁路直写/视图普通触发器，每点 PRINT [PASS]/[FAIL] |
| `02_verify_query.sql` | 02 | JOIN/GROUP BY/HAVING/模糊/大小写/SHOWPLAN 对比/数据字典 |
| `03_verify_perf.sql` | 03 | 写入×2 / 查询×2 / 过滤×2 / 批量更新计时 |

## 判定标准（预期）

| 验证点 | 预期 |
|---|---|
| INSERT（带/不带列名）、UPDATE、DELETE | ✅ INSTEAD OF 触发器拆分落 A1+A2 |
| UPDATE … OUTPUT | ⚠️ 实测（INSTEAD OF 触发器视图下 OUTPUT 行为） |
| SELECT … WITH (UPDLOCK) | ⚠️ 实测（应可锁底层基表行） |
| MERGE INTO 视图 | ❌ 预期 ORA 等价错（目标必须是表）→ 走应用层拆分 |
| TRUNCATE 视图 | ❌ 预期失败（DDL 不可覆盖） |
| 视图上建普通触发器 | ❌ 只能 INSTEAD OF |
| 模糊/大小写走解密列 | ⚠️ 可跑但全扫 → 走 `tb_sensitive_p.fn` 辅助列 |
| 性能 | 写入慢（触发器+按行加密）、批量必须直写基表 |

> ⚠️ 无真实 SQL Server 环境时本模板未实测；各验证点均打印真实 PASS/FAIL 供回填。