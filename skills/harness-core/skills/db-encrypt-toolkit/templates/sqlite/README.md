# SQLite 方言验证模板 —— 视图 + INSTEAD OF 触发器 + 应用层加解密

> 对应 Oracle 模板 `templates/oracle/`，语法按 SQLite 改写。
> 运行：`sqlite3 test.db < 00_setup.sql`（01-03 同理；`sqlite3 test.db ".timer on"` 可看性能计时）。
> SQLite 3.35+ 支持 `RETURNING`；3.45+ 无内置 AES（无 `DBMS_CRYPTO`/`AES_ENCRYPT`）。

## SQLite 的特殊性（与其它模板的关键差异）

| 能力 | SQLite |
|---|---|
| INSTEAD OF 触发器（视图上） | ✅ **支持**——写路径（INSERT/UPDATE/DELETE 拆分落 A1+A2）完整可用 |
| 内置加密函数 | ❌ 无 AES/SHA → **加密必须由应用层完成**（写入密文、读取后解密） |
| 视图上普通 BEFORE/AFTER 触发器 | ❌ 只允许 INSTEAD OF（尝试建普通触发器应报错 = 符合预期） |
| TRUNCATE | ❌ 无此语句（用 `DELETE FROM` 替代） |
| RETURNING | ✅ 3.35+ |
| FOR UPDATE | 不需要（SQLite 单写者模型，无行锁概念） |
| 存储过程 / DBMS_OUTPUT | ❌ 无 → 验证脚本=普通 SQL + 结果集输出，预期失败点靠 "报错=符合预期" 人工对照 |
| 定时任务 | 应用侧调度（GUI 应用无常驻 DB 进程） |

**结论定位**：SQLite 路线 = **"INSTEAD OF 拆分存储 + 应用层加解密"**（半透明：DML 拆分自动化，加解密在应用）；适合嵌入式单写者场景（移动端/桌面/边缘）。
读写分离的典例协议：应用 `INSERT` 明文？——不行。演示模板中 `tb_sensitive` 视图的 `f1` 列就是密文列（不透明）。若要"应用写明文、读明文"的近乎透明体验，需应用封装：写时应用先 `AES.encrypt(f1)` 再 INSERT，读时应用 `AES.decrypt(f1)`。

## 文件

| 文件 | 对应 Oracle | 说明 |
|---|---|---|
| `00_setup.sql` | 00 | 拆分表 + 同名视图 + 3 个 INSTEAD OF 触发器 + 索引 + 造数 |
| `01_verify_dml.sql` | 01 | INSERT/UPDATE/DELETE/RETURNING/直写旁路/视图普通触发器（报错点已标注） |
| `02_verify_query.sql` | 02 | JOIN/GROUP BY/HAVING/模糊/大小写/EXPLAIN QUERY PLAN/PRAGMA 字典 |
| `03_verify_perf.sql` | 03 | .timer 计时：批量写入经视图 vs 直写（含造数 SQL） |
| `README.md` | — | 本文件 |

## 判定标准（预期）

| 验证点 | 预期 |
|---|---|
| INSERT/UPDATE/DELETE（带/不带列名） | ✅ INSTEAD OF 拆分落 A1+A2 |
| UPDATE … RETURNING | ✅ 3.35+ |
| 视图上建普通见证触发器（BEFORE） | ❌ 报错=符合预期 |
| TRUNCATE | ❌ 语句不存在 |
| 模糊 LIKE 密文列 | ⚠️ 0 命中 → 走 `tb_sensitive_p.fn` 辅助列 |
| 解密读 | ⚠️ 应用层解密（SQL 层无解密函数） |
| 性能 | 视图 DML 损耗=触发器开销+应用加密时间；嵌入式场景通常可忽略 |

> ⚠️ 无真实 SQLite 环境时本模板未实测（语法按 SQLite 3.35+ 编写）；验证点输出真实结果供回填。