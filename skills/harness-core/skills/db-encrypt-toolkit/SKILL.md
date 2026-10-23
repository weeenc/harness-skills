---
name: db-encrypt-toolkit
stage: 组件封装（数据库安全）
description: 数据库敏感字段加密方案生成器——支持 15+ 数据库（Oracle/PG/MySQL/SQLServer/SQLite/TiDB/CockroachDB/OceanBase/Aurora/Spanner/Hive/Trino/Snowflake/BigQuery/Redshift/国产库），自动分诊「视图+触发器+定时任务」与「协议代理」两条路线，输出验证脚本与实施清单
---

# 数据库敏感字段加密方案生成器（db-encrypt-toolkit）

## 1. 职责

针对密评 / 等保场景的敏感字段存储加密需求，输入**目标数据库 + 敏感字段清单 + 业务 SQL 样本**，输出：

1. 路线选型结论（能力矩阵分诊 → 视图+触发器+定时任务 / 协议代理 / 应用层加密）；
2. 对应方言的**验证脚本**（跑出 支持/不支持/性能数据）；
3. 实施与回滚清单（阶段 0-5）。

**禁止不判断数据库能力就直接生成 SQL。** 不同数据库对「视图 INSTEAD OF 触发器 / 可更新视图 / 内置加密函数 / 定时任务」的支持完全不同，先分诊再动手。

## 2. 触发方式

| 方式 | 说明 |
|------|------|
| 独立命令 | `/db-encrypt <数据库> [表名] [敏感字段,...]` |
| 示例 | `/db-encrypt oracle T_USER name,phone,idcard` |
| 自动加载 | 无（按需调用） |

- 未给数据库类型 → 先询问；给不出时默认按 Oracle 生成并标注"需按实测调整"。
- 未给敏感字段 → 自动识别常见敏感列（name/phone/idcard/email/account/address…），给出候选清单让用户确认。

## 3. 前置条件

- 目标数据库类型（支持 15+，见 Step 1 矩阵）
- 敏感字段清单
- **业务 SQL 样本**（用于红线判定；尽量覆盖 INSERT/UPDATE/DELETE/聚合/批量/TRUNCATE）

## 4. 工作流程

### Step 1: 能力分诊（按矩阵评级）

| 评级 | 数据库 | 走法 |
|---|---|---|
| 🟢 A | Oracle / PostgreSQL / SQL Server / SQLite / 人大金仓 KingbaseES | 路线 A：同名视图 + INSTEAD OF 触发器 + 定时任务加密 |
| 🟡 B | MySQL / MariaDB / OceanBase / Amazon Aurora / 达梦 DM8 / GaussDB- openGauss | 有条件：先跑方言验证脚本，确认"简单可更新视图"边界后再做 |
| 🔴 C | TiDB(iDB) / CockroachDB / Google Spanner / Hive / Presto-Trino / Snowflake / BigQuery / Redshift | 视图路线不可行 → 转协议代理或应用层加密，输出需求说明书模板 |

> 完整矩阵（INS-OF 触发器 / 可更新视图 / 内置加密 / 原生调度 / 备注）见
> `templates/oracle/方案讨论.md` 第 3 节，分诊时引用该表并说明依据。

### Step 2: 红线判定（命中即降级）

对照 7 条通用红线逐条过业务 SQL 样本：

1. 加密字段参与 `SUM/AVG/BETWEEN/ORDER BY/JOIN 键`（数值/金额类）；
2. 批处理 DML（MERGE、INSERT..SELECT 大批量、定期全量 UPDATE）；
3. TRUNCATE 依赖（DDL 拦不住）；
4. 外键引用链（视图不能建/被建 FK）；
5. `rowid / 闪回 / FOR UPDATE / RETURNING` 强依赖；
6. 数据字典工具强依赖（ETL/ORM 自动 DDL）；
7. 数据量大、写入高频的表。

命中任意一条 → 该表降级走协议代理 / 应用层加密，并给出理由。

### Step 3: 生成方言验证脚本

- **Oracle（基准）**：使用本技能包**自带模板** `templates/oracle/`（`00_setup.sql` 表拆分+同名视图+INSTEAD OF 触发器；`01_verify_dml.sql` 支持性；`02_verify_query.sql` 谓词下推/数据字典；`03_verify_perf.sql` 性能对比；`README.md` 运行说明与判定表），按下方替换规则改为实际表结构后交付。
- **其余方言**：直接从下方**方言模板清单**取现成模板（00-03 判定点与 Oracle 一一对应），再按 Step 3.5 替换规则定制；🔴 类不生成 SQL，输出协议代理需求说明书。

| 方言模板目录 | 覆盖数据库 | 与 Oracle 的关键差异（均已写入各 README） |
|---|---|---|
| `templates/oracle/` | Oracle、达梦 DM8、OceanBase(Oracle 模式) | 基准（`DBMS_CRYPTO` + INSTEAD OF + `DBMS_SCHEDULER`） |
| `templates/postgresql/` | PostgreSQL、人大金仓 KingbaseES、openGauss、Aurora PostgreSQL | `DBMS_CRYPTO`→`pgcrypto`；输出→`RAISE NOTICE`；调度→`pg_cron` |
| `templates/sqlserver/` | SQL Server、Azure SQL | 内置 `ENCRYPTBYPASSPHRASE/HASHBYTES(SHA2_256)`；`RETURNING`→`OUTPUT`；`FOR UPDATE`→`UPDLOCK`；调度→SQL Agent |
| `templates/mysql/` | MySQL、MariaDB、OceanBase(MySQL 模式)、Aurora MySQL | **无 INSTEAD OF** → 验证可更新视图边界 + `AES_ENCRYPT/AES_DECRYPT` + `EVENT`；结论：写透明加密不可行 |
| `templates/sqlite/` | SQLite（嵌入式单写者） | 无内置 AES → INSTEAD OF 拆分 + 应用层加解密；无 TRUNCATE/FOR UPDATE |

> 复用红线：CockroachDB / TiDB / Spanner / Hive / Trino / Snowflake / BigQuery / Redshift 不支持 INSTEAD OF 或视图 DML → 一律走协议代理需求说明书，不取上述模板。

### Step 3.5: 模板替换规则（templates/oracle/ → 目标库）

| 模板占位 | 替换为 | 注意 |
|---|---|---|
| `TB_SENSITIVE`（原表/同名视图） | 业务表名 | 视图名=原表名；同步替换 `TRG_TS_IOF` 触发器名、`IDX_TS_*` 索引名 |
| 列 `ID / F1 / F2` | 实际主键 / 敏感列 / 普通列 | 敏感列多个 → 触发器内每个敏感列配套 `enc()`+`hsh()`；辅助列 `FN=UPPER(F1)` 按业务规则定义 |
| `enc_pkg` 密钥与算法 | 生产 KMS/HSM + 国密 SM4 | 默认 AES-256-CBC 仅演示；禁用 ECB |
| 01-03 的判定结果 | 实测回填 | 每个验证点输出 `[PASS]/[FAIL]+ORA 码` 原样记录，回填 README 判定表 |

> 模板即文档：`templates/` 为验证脚本与文档的唯一权威（原仓库 docs 文档中心已并入技能包并清理），所有改动只发生在本技能包内。

### Step 4: 输出交付物

1. 选型结论一页纸（评级 + 红线命中情况 + 推荐路线与理由）；
2. 验证脚本或协议代理需求说明书；
3. 实施/回滚清单（阶段 0-5：红线判定 → 方言验证 → 结构设计 → 加密与密钥 → 不停机上线 → 回归与回滚）。

## 5. 配套参考

| 参考 | 位置 |
|---|---|
| **技能包自带 Oracle 验证模板（安装即用）** | `templates/oracle/`（本技能包目录内） |
| 其余方言模板（PG/SQLServer/MySQL/SQLite 各 5 件） | `templates/<dialect>/`（本技能包目录内，覆盖/复用关系见 Step 3 清单） |
| 跨库方案 + 矩阵（15+ 库能力矩阵） | `templates/oracle/方案讨论.md`（第 3 节） |
| 双路线对比 Excel | 桌面 `技术路线对比-视图+触发器+定时任务与协议代理.xlsx`（C 列=协议代理，D 列=视图路线） |

## 6. 边界与纪律

- **不产出生产密钥**：脚本内密钥仅演示，生产必须 KMS/HSM + 轮换；算法默认禁用 ECB。
- **不代替密评机构**：算法/合规细则由测评机构判定，技能只保证方案结构与可验证性。
- **不做迁移执行**：只交付脚本与清单，由用户在有备份的环境执行。
- **结论以实测为准**：验证脚本的输出（SUPPORTED/UNSUPPORTED、性能数据）是决策依据，矩阵只是先验预判。


> - 需求/方案来源：敏感字段加密双路线对比（视图+触发器+定时任务 vs 协议代理）——桌面 Excel《技术路线对比-视图+触发器+定时任务与协议代理.xlsx》、Oracle 实测验证脚本（00-03）与 15+ 库能力矩阵《方案讨论.md》（原 `docs/oracle-view-trigger-encryption/` 已并入本技能包 `templates/` 并清理，本技能包为唯一权威）