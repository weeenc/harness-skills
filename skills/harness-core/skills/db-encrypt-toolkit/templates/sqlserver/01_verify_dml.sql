-- 01_verify_dml.sql  SQL Server 版 —— DML/DDL 支持性验证
-- 运行：sqlcmd -S <server> -U <user> -i 01_verify_dml.sql （或 SSMS 执行）
-- 每个验证点输出 [PASS] 或 [FAIL]+错误文本，如实回填判定表
-- 前提：已执行 00_setup.sql；脚本自带清理，可重复运行
SET NOCOUNT ON;
GO

-- V1 INSERT（带列名）
BEGIN TRY
  INSERT INTO dbo.tb_sensitive (id, f1, f2) VALUES (9001, N'hello-from-app', 100);
  PRINT '[PASS] V1 INSERT 带列名: SUPPORTED';
END TRY
BEGIN CATCH
  PRINT '[FAIL] V1 INSERT 带列名: ' + ERROR_MESSAGE();
END CATCH
ROLLBACK;  -- 回滚本验证点
GO

-- V2 INSERT 不带列名（按视图列序 id,f1,f2）
BEGIN TRY
  INSERT INTO dbo.tb_sensitive VALUES (9002, N'no-cols', 200);
  PRINT '[PASS] V2 INSERT 不带列名: SUPPORTED';
END TRY
BEGIN CATCH
  PRINT '[FAIL] V2 INSERT 不带列名: ' + ERROR_MESSAGE();
END CATCH
ROLLBACK;
GO

-- V3 SELECT 解密读取
DECLARE @v_f1 nvarchar(200);
BEGIN TRY
  INSERT INTO dbo.tb_sensitive (id, f1, f2) VALUES (9001, N'hello-from-app', 100);
  SELECT @v_f1 = f1 FROM dbo.tb_sensitive WHERE id = 9001;
  PRINT '[PASS] V3 SELECT 解密读: 读到 <<[' + ISNULL(@v_f1, N'<NULL>') + ']>> (应=hello-from-app)';
END TRY
BEGIN CATCH
  PRINT '[FAIL] V3 SELECT 解密读: ' + ERROR_MESSAGE();
END CATCH
ROLLBACK;
GO

-- V4 UPDATE（含防篡改哈希更新）
DECLARE @v_chk int;
BEGIN TRY
  INSERT INTO dbo.tb_sensitive (id, f1, f2) VALUES (9001, N'initial', 100);
  UPDATE dbo.tb_sensitive SET f1 = N'updated-value', f2 = 999 WHERE id = 9001;
  SELECT @v_chk = COUNT(*) FROM dbo.tb_sensitive s
    JOIN dbo.tb_sensitive_c c ON c.id = s.id
   WHERE s.id = 9001 AND s.f1 = N'updated-value' AND c.f1_h = dbo.enc_pkg_hsh(N'updated-value');
  IF @v_chk = 1
    PRINT '[PASS] V4 UPDATE: SUPPORTED 且哈希已更新';
  ELSE
    PRINT '[FAIL] V4 UPDATE: 值或哈希不一致';
END TRY
BEGIN CATCH
  PRINT '[FAIL] V4 UPDATE: ' + ERROR_MESSAGE();
END CATCH
ROLLBACK;
GO

-- V5 DELETE
DECLARE @v_left int;
BEGIN TRY
  INSERT INTO dbo.tb_sensitive (id, f1, f2) VALUES (9001, N'to-delete', 100);
  DELETE FROM dbo.tb_sensitive WHERE id = 9001;
  SELECT @v_left = COUNT(*) FROM (
    SELECT id FROM dbo.tb_sensitive WHERE id = 9001
    UNION ALL SELECT id FROM dbo.tb_sensitive_c WHERE id = 9001
    UNION ALL SELECT id FROM dbo.tb_sensitive_p WHERE id = 9001) x;
  IF @v_left = 0
    PRINT '[PASS] V5 DELETE: SUPPORTED（三段均删除）';
  ELSE
    PRINT '[FAIL] V5 DELETE: 残留 ' + CAST(@v_left AS varchar) + ' 段';
END TRY
BEGIN CATCH
  PRINT '[FAIL] V5 DELETE: ' + ERROR_MESSAGE();
END CATCH
-- 保留删除结果
GO

-- V6 UPDATE ... OUTPUT（对应 Oracle RETURNING；视图+INSTEAD OF 行为实测）
DECLARE @v_ret nvarchar(200);
BEGIN TRY
  INSERT INTO dbo.tb_sensitive (id, f1, f2) VALUES (9001, N'before', 100);
  UPDATE dbo.tb_sensitive SET f1 = N'after-output'
   OUTPUT inserted.f1 INTO @v_ret
   WHERE id = 9001;
  PRINT '[PASS] V6 UPDATE...OUTPUT: SUPPORTED, 返回=' + ISNULL(@v_ret, N'<NULL>');
END TRY
BEGIN CATCH
  PRINT '[FAIL] V6 UPDATE...OUTPUT: ' + ERROR_MESSAGE();
END CATCH
ROLLBACK;
GO

-- V7 SELECT ... WITH (UPDLOCK)（对应 FOR UPDATE）
BEGIN TRY
  INSERT INTO dbo.tb_sensitive (id, f1, f2) VALUES (9001, N'locked', 100);
  SELECT id FROM dbo.tb_sensitive WITH (UPDLOCK) WHERE id = 9001;
  PRINT '[PASS] V7 SELECT...UPDLOCK: SUPPORTED';
END TRY
BEGIN CATCH
  PRINT '[FAIL] V7 SELECT...UPDLOCK: ' + ERROR_MESSAGE();
END CATCH
ROLLBACK;
GO

-- V8 MERGE INTO 视图（目标必须为表，预期失败，作为降级证据）
BEGIN TRY
  MERGE INTO dbo.tb_sensitive AS t
  USING (SELECT 9001 AS id, N'm' AS f1, 100 AS f2) AS s ON t.id = s.id
  WHEN MATCHED THEN UPDATE SET f1 = s.f1
  WHEN NOT MATCHED THEN INSERT (id, f1, f2) VALUES (s.id, s.f1, s.f2);
  PRINT '[PASS] V8 MERGE 于视图: SUPPORTED（异常，需复核）';
END TRY
BEGIN CATCH
  PRINT '[FAIL] V8 MERGE 于视图: ' + ERROR_MESSAGE() + ' — 符合预期（MERGE 目标须为表，转应用层/直写基表）';
END CATCH
ROLLBACK;
GO

-- V9 TRUNCATE 视图（DDL 不可覆盖，预期失败）
BEGIN TRY
  TRUNCATE TABLE dbo.tb_sensitive;
  PRINT '[PASS] V9 TRUNCATE 视图: SUPPORTED（异常，需复核）';
END TRY
BEGIN CATCH
  PRINT '[FAIL] V9 TRUNCATE 视图: ' + ERROR_MESSAGE() + ' — 符合预期（需 TRUNCATE 基表并重建/重导）';
END CATCH
GO

-- V10 直写基表旁路（第三方直连场景：绕过视图可行）
BEGIN TRY
  INSERT INTO dbo.tb_sensitive_c (id, f1_cipher, f2, f1_h) VALUES (9801, dbo.enc_pkg_enc(N'bypass'), 1, dbo.enc_pkg_hsh(N'bypass'));
  INSERT INTO dbo.tb_sensitive_p (id, f1_plain, fn) VALUES (9801, N'bypass', N'BYPASS');
  IF EXISTS (SELECT 1 FROM dbo.tb_sensitive WHERE id = 9801 AND f1 = N'bypass')
    PRINT '[PASS] V10 直写基表旁路: SUPPORTED — 此渠道不受触发器管控，需权限最小化';
  ELSE
    PRINT '[FAIL] V10 直写基表旁路: 数据不一致';
END TRY
BEGIN CATCH
  PRINT '[FAIL] V10 直写基表旁路: ' + ERROR_MESSAGE();
END CATCH
ROLLBACK;
GO

-- V11 视图上建普通触发器（预期失败：只能 INSTEAD OF）
BEGIN TRY
  CREATE TRIGGER dbo.trg_bad ON dbo.tb_sensitive AFTER INSERT AS SELECT 1;
  PRINT '[PASS] V11 视图普通触发器: SUPPORTED（异常）';
END TRY
BEGIN CATCH
  PRINT '[FAIL] V11 视图普通触发器: ' + ERROR_MESSAGE() + ' — 符合预期（视图只能 INSTEAD OF）';
END CATCH
GO

-- V12 清理演示数据
DELETE FROM dbo.tb_sensitive WHERE id BETWEEN 9001 AND 9999;
GO