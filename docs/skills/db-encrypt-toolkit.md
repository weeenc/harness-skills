# db-encrypt-toolkit 使用说明

> 数据库敏感字段加密方案生成器 —— 密评 / 等保场景下，为 **15+ 数据库**自动分诊「视图+触发器+定时任务」与「协议代理」两条路线，输出方言验证脚本与实施清单。
> 仓库文档：本文件（人类可读使用说明）｜ 技能本体：`skills/harness-core/skills/db-encrypt-toolkit/SKILL.md`（含 Step 1-4 完整流程）

---

## 1. 概述

### 1.1 它解决什么问题

"敏感字段加密"（姓名、手机号、身份证、银行卡、邮箱、地址…）在**不同数据库**上的实现能力天差地别：

- Oracle / PostgreSQL / SQL Server 支持**视图 INSTEAD OF 触发器** → 可做"写时透明加密 + 读时解密"；
- MySQL 家族**没有 INSTEAD OF** → 同名视图无法透明拦截写入，"写透明加密"路线直接不可行；
- TiDB / CockroachDB / Spanner / Snowflake / BigQuery / Redshift 等分布式与云数仓**不支持视图 DML** → 只能走协议代理或应用层加密。

把一套 Oracle SQL 复制到别的库跑，第一句 `DBMS_CRYPTO` 就会报错。本技能的**核心原则：先分诊，再动手，禁止不判断数据库能力就直接生成 SQL。**

### 1.2 输入 → 输出

| 输入 | 输出 |
|---|---|
| 目标数据库类型（15+） | ① 路线选型结论一页纸（评级 + 红线命中 + 推荐路线与理由） |
| 敏感字段清单（如 `name,phone,idcard`） | ② 对应方言的验证脚本（实测 支持/不支持/性能数据 后回填判定表） |
| 业务 SQL 样本（INSERT/UPDATE/DELETE/聚合/批量/TRUNCATE） | ③ 实施 / 回滚清单（阶段 0-5） |

---

## 2. 快速开始（3 步）

```text
/db-encrypt oracle T_USER name,phone,idcard        ← ① 一句话发起
```

| 步骤 | 发生什么 | 产物 |
|---|---|---|
| 1. 能力分诊 | 按 Step 1 矩阵查目标库评级（🟢A / 🟡B / 🔴C） | 评级 + 路线结论 |
| 2. 红线判定 | 7 条红线逐条过业务 SQL，命中即降级 | 命中清单 + 降级理由 |
| 3. 取模板定制 | 🟢/🟡 从技能包 `templates/<dialect>/` 取方言模板，按替换规则改为实际表结构 | 00-03 验证脚本 + 实施清单 |

> 🔴 类数据库（TiDB / CockroachDB / Spanner / Hive / Trino / Snowflake / BigQuery / Redshift）不取模板，直接输出**协议代理需求说明书**（6 项：语法覆盖 / 性能压测 / 高可用 / 复杂 SQL 适配 / 密钥管理 / 直连旁路明文核查）。

---

## 3. 触发方式与参数

| 参数 | 必填 | 说明 |
|---|---|---|
| `<数据库>` | 是 | 见第 4 节支持清单；未给 → 先询问，给不出默认按 Oracle 生成并标注"需按实测调整" |
| `[表名]` | 否 | 默认用模板占位 `TB_SENSITIVE`，替换规则改名为实际表名 |
| `[敏感字段,...]` | 否 | 默认自动识别常见敏感列（name/phone/idcard/email/account/address…）给出候选清单让你确认 |

自动加载：**无**（`/db-encrypt` 是独立命令，按需调用，不进流水线自动注入）。

---

## 4. 能力分诊矩阵（15+ 数据库）

| 评级 | 数据库 | 走法 |
|---|---|---|
| 🟢 **A** | Oracle、PostgreSQL、SQL Server、SQLite、人大金仓 KingbaseES | 路线 A：同名视图 + INSTEAD OF 触发器 + 定时任务加密 |
| 🟡 **B** | MySQL、MariaDB、OceanBase、Amazon Aurora、达梦 DM8、GaussDB·openGauss | 有条件：先跑方言验证脚本，确认"简单可更新视图"边界后再做 |
| 🔴 **C** | TiDB(iDB)、CockroachDB、Google Spanner、Hive、Presto·Trino、Snowflake、BigQuery、Redshift | 视图路线不可行 → 协议代理或应用层加密，输出需求说明书 |

> 完整矩阵（INS-OF 触发器 / 可更新视图 / 内置加密 / 原生调度 / 备注，逐库列举）见技能包 `templates/oracle/方案讨论.md` 第 3 节 —— 分诊时引用该表并说明依据。

---

## 5. 红线判定（命中即降级）

对照 7 条通用红线逐条过业务 SQL 样本，命中**任意一条** → 该表降级走协议代理 / 应用层加密，并给出理由：

1. 加密字段参与 `SUM/AVG/BETWEEN/ORDER BY/JOIN 键`（数值/金额类）——解密列无法用索引，全扫；
2. 批处理 DML（MERGE、INSERT..SELECT 大批量、定期全量 UPDATE）——写入经解密放大 5-20×；
3. TRUNCATE 依赖——DDL 拦不住，密文表可被直清；
4. 外键引用链——视图不能建 FK / 被 FK 引用；
5. `rowid / 闪回 / FOR UPDATE / RETURNING` 强依赖——视图层语义与基表不一致；
6. 数据字典工具强依赖（ETL/ORM 自动 DDL）——视图会骗过工具推断；
7. 数据量大、写入高频的表——性能不可接受。

> 性能先验结论（详见 `templates/oracle/03_verify_perf.sql` 实测）：查询 ≈ 原表（明文副本列照搬索引）；写入慢 **5-20×**、存储与日志放大 **2-3×**；批量必须直写基表旁路。

---

## 6. 方言模板导航（技能包自带，安装即用）

模板根：`skills/harness-core/skills/db-encrypt-toolkit/templates/<dialect>/`，每套 **5 件**：`00_setup.sql` / `01_verify_dml.sql` / `02_verify_query.sql` / `03_verify_perf.sql` / `README.md`（00-03 判定点与 Oracle 一一对应，可横向比较）。

| 模板目录 | 覆盖数据库 | 与 Oracle 的关键差异（各 README 有详表） |
|---|---|---|
| `templates/oracle/` | Oracle、达梦 DM8、OceanBase(Oracle 模式) | **基准**：`DBMS_CRYPTO` + INSTEAD OF + `DBMS_SCHEDULER`；另含 `方案讨论.md` 跨库主文档 |
| `templates/postgresql/` | PostgreSQL、人大金仓 KingbaseES、openGauss、Aurora PostgreSQL | `DBMS_CRYPTO`→`pgcrypto`；输出→`RAISE NOTICE`；调度→`pg_cron` |
| `templates/sqlserver/` | SQL Server、Azure SQL | 内置 `ENCRYPTBYPASSPHRASE/HASHBYTES(SHA2_256)`；`RETURNING`→`OUTPUT`；`FOR UPDATE`→`UPDLOCK`；调度→SQL Agent |
| `templates/mysql/` | MySQL、MariaDB、OceanBase(MySQL 模式)、Aurora MySQL | **无 INSTEAD OF** → 验证可更新视图边界 + `AES_ENCRYPT/AES_DECRYPT` + `EVENT`；结论：写透明加密不可行 |
| `templates/sqlite/` | SQLite（嵌入式单写者） | 无内置 AES → INSTEAD OF 拆分 + **应用层加解密**；无 TRUNCATE / FOR UPDATE |

每套模板内部结构（以 oracle 为例）：

| 文件 | 作用 | 关键验证点 |
|---|---|---|
| `00_setup.sql` | 拆分表 + 同名视图 + INSTEAD OF 触发器 + 索引 + 造数 | 末尾自检 `SELECT 'setup-ok', COUNT(*)` |
| `01_verify_dml.sql` | DML 支持性 | INSERT 带/不带列名、UPDATE+防篡改哈希、DELETE、RETURNING、FOR UPDATE、MERGE、TRUNCATE、直写基表旁路、视图上建普通触发器（报错=符合预期） |
| `02_verify_query.sql` | 查询下推与数据字典 | JOIN / GROUP BY / HAVING / 模糊 / 大小写 / EXPLAIN（解密列全扫 vs 辅助列索引）/ 字典 / rowid / 闪回 |
| `03_verify_perf.sql` | 性能对比 | P1 写入、P2 解密读、P3 过滤、P4 批量 UPDATE（经视图 vs 直写基表） |
| `README.md` | 运行说明 + 判定表 | 每个验证点预期结果；实测 `[PASS]/[FAIL]+错误码` 后回填 |

---

## 7. 模板替换规则（`templates/oracle/` → 目标库）

| 模板占位 | 替换为 | 注意 |
|---|---|---|
| `TB_SENSITIVE`（原表/同名视图） | 业务表名 | 视图名 = 原表名；同步替换触发器名 `TRG_TS_IOF`、索引名 `IDX_TS_*` |
| 列 `ID / F1 / F2` | 实际主键 / 敏感列 / 普通列 | 敏感列多个 → 每个敏感列配套 `enc()`+`hsh()`；辅助列 `FN=UPPER(F1)` 按业务规则定义 |
| `enc_pkg` 密钥与算法 | 生产 KMS/HSM + 国密 SM4 | 默认 AES-256-CBC 仅演示；**禁用 ECB** |
| 01-03 判定结果 | 实测回填 | 每个验证点输出 `[PASS]/[FAIL]+ORA 码` 原样记录，回填 README 判定表 |

> **模板即文档**：`templates/` 是验证脚本与文档的唯一权威，所有改动只发生在技能包内 —— 安装到任何项目、不依赖本仓库路径即可使用。

---

## 8. 端到端示例（Oracle）

`/db-encrypt oracle T_USER name,phone,idcard` 的典型产出：

```sql
-- 00_setup 核心（示意）：原表 T_USER 隐藏为 T_USER_C 密文表 + 同名视图承载应用 SQL
CREATE OR REPLACE VIEW T_USER (ID, NAME, PHONE) AS
  SELECT c.ID, enc_pkg.dec(c.NAME_CIPHER), enc_pkg.dec(c.PHONE_CIPHER) FROM T_USER_C c;

-- INSTEAD OF 触发器自动分流：应用 INSERT/UPDATE/DELETE 照写视图，落库即密文
-- 辅助列 FN=UPPER(NAME) 承接大小写不敏感查询（视图解密列无法进索引）
```

交付物三件套：
1. **选型结论一页纸**：`oracle → 🟢A`、红线命中情况、推荐路线与理由；
2. **验证脚本 4 份**：`00_setup / 01_verify_dml / 02_verify_query / 03_verify_perf`，附运行前提（`DBMS_CRYPTO` 权限、免密登录等）与判定标准；
3. **实施/回滚清单**：阶段 0-5 —— 红线判定 → 方言验证 → 结构设计 → 加密与密钥 → 不停机上线 → 回归与回滚。

---

## 9. 输出交付物清单

| 交付物 | 内容 | 何时 |
|---|---|---|
| 选型结论一页纸 | 评级 + 红线命中 + 推荐路线与理由 | 每次调用 |
| 方言验证脚本（00-03 + README） | 支持性 / 查询下推 / 性能对比 | 🟢A、🟡B |
| 协议代理需求说明书（6 项） | 语法覆盖 / 性能压测 / 高可用 / 复杂 SQL 适配 / 密钥管理 / 直连旁路明文核查 | 🔴C |
| 实施 / 回滚清单（阶段 0-5） | 见上 | 每次调用 |

---

## 10. 边界与纪律

- **不产出生产密钥**：脚本内密钥仅演示，生产必须 KMS/HSM + 轮换；算法默认禁用 ECB；
- **不代替密评机构**：算法/合规细则由测评机构判定，技能只保证方案结构与可验证性；
- **不做迁移执行**：只交付脚本与清单，由你在有备份的环境执行；
- **结论以实测为准**：验证脚本的输出（SUPPORTED/UNSUPPORTED、性能数据）是决策依据，矩阵只是先验预判；
- **明文窗口期**：视图解密列禁止套 `CASE WHEN 密文 IS NOT NULL THEN 解密 ELSE 明文 END`（索引失效）；二选一：窗口内走明文副本列，或视图恒定解密列。

---

## 11. 常见问题（FAQ）

| 问题 | 回答 |
|---|---|
| 我的库是 MySQL，能"写透明加密"吗？ | 不能。MySQL 无 INSTEAD OF 触发器，同名视图拦不住写入。模板会实测证明边界：列映射视图可 DML、表达式解密/JOIN/聚合视图不可 DML。走"应用层加密"或协议代理 |
| SQLite 怎么加密？ | SQL 层无 AES。INSTEAD OF 触发器照常拆分落库，密文由应用层生成/解密（半透明路线），参考 `templates/sqlite/` |
| 加密字段要模糊查询/排序/求和？ | 判定为红线 → 降级。或靠辅助列（FN=UPPER(F1) 索引）承担部分场景；数值聚合类必须绕道 |
| 性能怎么样？ | 查询 ≈ 原表；写入慢 5-20×、放大 2-3×；批量 DML 直写基表旁路 |
| 数据字典工具会破坏方案吗？ | 会。运用 DBMS_METADATA/ORM 生成 DDL 会把视图当表重建，命中红线 6 → 降级 |
| 模板和文档会漂移吗？ | 不会。`templates/` 是唯一权威（单份），无第二副本 |
| 多处改动怎么同步？ | 只需同步 SKILL.md 的两份拷贝（仓库版 `skills/.../` 与注册版 `.reasonix/skills/`），规则已写入 SKILL.md |

---

## 12. 变更记录

| 版本 | 变更 |
|---|---|
| v1.1.1 | 🐛 修复辅助列引用 bug（依据《验证工作记录》实测报告）：oracle 02 Q5b/Q6b/Q7b + 03 P3b、postgresql 02 Q5b/Q6b/Q7b + 03 P3、sqlserver 02 Q5b/Q6b/Q7b + 03 P3 原写 `FROM 视图 WHERE FN`（视图仅 3 列无 FN → ORA-00904 / column does not exist / Invalid column name），全部改为 `FROM A2 明文表 _P WHERE FN`；同步修口径（oracle 03 造数 FN 一一对应、PG 03 P3 两侧各命中 1 行）、oracle 03 P4a/P4b 间补 ROLLBACK、oracle 03 与 PG 02/03 补统计信息（GATHER_TABLE_STATS / ANALYZE） |
| v1.1 | 🆕 新增 4 套方言模板（postgresql / sqlserver / mysql / sqlite，各 5 件）；SKILL.md 升级为 15+ 库模板导航表；docs 文档中心并入技能包 `templates/` 并清理 `docs/oracle-view-trigger-encryption/`；补充「来源 & 作者」 |
| v1.0 | Oracle 基准模板（00-03 + README + 方案讨论）+ 双路线对比 Excel（协议代理 C 列 / 视图路线 D 列） |

---

## 13. 关联文档

| 位置 | 内容 |
|---|---|
| `skills/harness-core/skills/db-encrypt-toolkit/SKILL.md` | 技能本体：Step 1 分诊 → Step 2 红线 → Step 3 模板 → Step 3.5 替换 → Step 4 交付 |
| `skills/harness-core/skills/db-encrypt-toolkit/templates/<dialect>/` | 5 套方言验证模板（oracle 含 `方案讨论.md` 跨库主文档） |
| 桌面 `技术路线对比-视图+触发器+定时任务与协议代理.xlsx` | 双路线对比（C 列=协议代理，D 列=视图路线）；修改前备份在 `tmp/xlsx_backup_before_proxy.xlsx` |
