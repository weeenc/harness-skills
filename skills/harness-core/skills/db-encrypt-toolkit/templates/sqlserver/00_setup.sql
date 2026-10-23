-- 00_setup.sql  SQL Server 版 —— 视图+触发器+定时任务加密 初始化
-- 运行：sqlcmd -S <server> -U <user> -i 00_setup.sql （或 SSMS 打开执行）
-- 提示：ENCRYPTBYPASSPHRASE 为演示级（口令派生密钥）；生产建议使用 SQL Server 证书/对称密钥或应用侧 KMS，
--       禁用硬编码口令；演示密钥仅用于验证
SET NOCOUNT ON;
GO

-- ---------- 0. 清理残留（先删触发器再删视图/表） ----------
IF OBJECT_ID('dbo.trg_ts_iof_i','TR') IS NOT NULL DROP TRIGGER dbo.trg_ts_iof_i;
IF OBJECT_ID('dbo.trg_ts_iof_u','TR') IS NOT NULL DROP TRIGGER dbo.trg_ts_iof_u;
IF OBJECT_ID('dbo.trg_ts_iof_d','TR') IS NOT NULL DROP TRIGGER dbo.trg_ts_iof_d;
IF OBJECT_ID('dbo.tb_sensitive','V') IS NOT NULL DROP VIEW dbo.tb_sensitive;
IF OBJECT_ID('dbo.tb_sensitive_c','U') IS NOT NULL DROP TABLE dbo.tb_sensitive_c;
IF OBJECT_ID('dbo.tb_sensitive_p','U') IS NOT NULL DROP TABLE dbo.tb_sensitive_p;
IF OBJECT_ID('dbo.tb_sensitive_bak','U') IS NOT NULL DROP TABLE dbo.tb_sensitive_bak;
IF OBJECT_ID('dbo.tb_dept','U') IS NOT NULL DROP TABLE dbo.tb_dept;
IF OBJECT_ID('dbo.enc_pkg_enc','FN') IS NOT NULL DROP FUNCTION dbo.enc_pkg_enc;
IF OBJECT_ID('dbo.enc_pkg_dec','FN') IS NOT NULL DROP FUNCTION dbo.enc_pkg_dec;
IF OBJECT_ID('dbo.enc_pkg_hsh','FN') IS NOT NULL DROP FUNCTION dbo.enc_pkg_hsh;
GO

-- ---------- 1. 加密函数（口令派生加密 + SHA2_256 防篡改哈希） ----------
CREATE FUNCTION dbo.enc_pkg_enc(@plain nvarchar(max))
RETURNS varbinary(max)
AS
BEGIN
  RETURN ENCRYPTBYPASSPHRASE(N'demo-key-please-change', @plain);
END;
GO

CREATE FUNCTION dbo.enc_pkg_dec(@cipher varbinary(max))
RETURNS nvarchar(max)
AS
BEGIN
  RETURN CONVERT(nvarchar(max), DECRYPTBYPASSPHRASE(N'demo-key-please-change', @cipher));
END;
GO

CREATE FUNCTION dbo.enc_pkg_hsh(@plain nvarchar(max))
RETURNS varbinary(32)
AS
BEGIN
  RETURN HASHBYTES('SHA2_256', @plain);
END;
GO

-- ---------- 2. 底层拆分表 A1/A2 ----------
CREATE TABLE dbo.tb_sensitive_c (
  id        int NOT NULL PRIMARY KEY,
  f1_cipher varbinary(max) NOT NULL,   -- 密文
  f2        int,
  f1_h      varbinary(32)              -- 防篡改哈希
);
CREATE TABLE dbo.tb_sensitive_p (
  id        int NOT NULL PRIMARY KEY,
  f1_plain  nvarchar(200) NOT NULL,    -- 明文（索引/排序/模糊兜底）
  fn        nvarchar(200)              -- 辅助列（upper(f1_plain)）
);
GO

-- ---------- 3. 模拟原表 + 改名隐藏 + 洗数 ----------
CREATE TABLE dbo.tb_sensitive (id int PRIMARY KEY, f1 nvarchar(200), f2 int);
INSERT INTO dbo.tb_sensitive VALUES (1, N'hello-sqlserver', 100), (2, N'Alice-in-SS', 200),
                                    (3, N'Bob', 300), (4, N'Carol', 400);
EXEC sp_rename 'dbo.tb_sensitive', 'tb_sensitive_bak';
GO

INSERT INTO dbo.tb_sensitive_c (id, f1_cipher, f2, f1_h)
SELECT id, dbo.enc_pkg_enc(f1), f2, dbo.enc_pkg_hsh(f1) FROM dbo.tb_sensitive_bak;
INSERT INTO dbo.tb_sensitive_p (id, f1_plain, fn)
SELECT id, f1, UPPER(f1) FROM dbo.tb_sensitive_bak;
GO

-- ---------- 4. 同名视图（应用 SQL 入口；f1 = 解密列） ----------
CREATE VIEW dbo.tb_sensitive AS
SELECT c.id, dbo.enc_pkg_dec(c.f1_cipher) AS f1, c.f2
FROM dbo.tb_sensitive_c c;
GO

-- ---------- 5. INSTEAD OF 触发器：拆分落 A1+A2（INSERT/UPDATE/DELETE 各一） ----------
CREATE TRIGGER dbo.trg_ts_iof_i ON dbo.tb_sensitive
INSTEAD OF INSERT AS
BEGIN
  SET NOCOUNT ON;
  INSERT INTO dbo.tb_sensitive_c (id, f1_cipher, f2, f1_h)
  SELECT id, dbo.enc_pkg_enc(f1), f2, dbo.enc_pkg_hsh(f1) FROM inserted;
  INSERT INTO dbo.tb_sensitive_p (id, f1_plain, fn)
  SELECT id, f1, UPPER(f1) FROM inserted;
END;
GO

CREATE TRIGGER dbo.trg_ts_iof_u ON dbo.tb_sensitive
INSTEAD OF UPDATE AS
BEGIN
  SET NOCOUNT ON;
  UPDATE c SET f1_cipher = dbo.enc_pkg_enc(i.f1), f2 = i.f2, f1_h = dbo.enc_pkg_hsh(i.f1)
  FROM dbo.tb_sensitive_c c JOIN inserted i ON c.id = i.id;
  UPDATE p SET f1_plain = i.f1, fn = UPPER(i.f1)
  FROM dbo.tb_sensitive_p p JOIN inserted i ON p.id = i.id;
END;
GO

CREATE TRIGGER dbo.trg_ts_iof_d ON dbo.tb_sensitive
INSTEAD OF DELETE AS
BEGIN
  SET NOCOUNT ON;
  DELETE c FROM dbo.tb_sensitive_c c JOIN deleted d ON c.id = d.id;
  DELETE p FROM dbo.tb_sensitive_p p JOIN deleted d ON p.id = d.id;
END;
GO

-- ---------- 6. 索引（辅助列兜底；解密列无法索引） ----------
CREATE INDEX idx_ts_p_fn ON dbo.tb_sensitive_p (fn);
CREATE INDEX idx_ts_p_f1 ON dbo.tb_sensitive_p (f1_plain);
CREATE INDEX idx_ts_c_f2 ON dbo.tb_sensitive_c (f2);
GO

-- ---------- 7. 关联表（02 使用） ----------
CREATE TABLE dbo.tb_dept (dept_id int PRIMARY KEY, dept_name nvarchar(100));
INSERT INTO dbo.tb_dept VALUES (10, N'IT'), (20, N'HR');
GO

-- ---------- 8. 自检：视图读出应为明文 ----------
SELECT 'setup-ok' AS status, COUNT(*) AS rows_via_view FROM dbo.tb_sensitive;
GO

-- ---------- 9. SQL Agent 定时任务示例（仅注释参考；生产需配置作业权限） ----------
-- 轮换密钥重建密文 / 残留明文补加密：
--   UPDATE c SET f1_cipher = dbo.enc_pkg_enc(p.f1_plain), f1_h = dbo.enc_pkg_hsh(p.f1_plain)
--   FROM dbo.tb_sensitive_c c JOIN dbo.tb_sensitive_p p ON c.id = p.id;
--   EXEC msdb.dbo.sp_add_job @job_name=N'encrypt-refresh', ...;
--   EXEC msdb.dbo.sp_add_jobschedule @job_name=N'encrypt-refresh', @freq_type=4, @freq_interval=1, ...;