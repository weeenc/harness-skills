-- 03_verify_perf.sql  SQL Server 版 —— 性能对比（写入/查询/过滤/批量）
-- 运行：sqlcmd -S <server> -U <user> -i 03_verify_perf.sql
-- 注：GETDATE() 毫秒计时，粗略对比；生产以真实压测为准
SET NOCOUNT ON;
GO

-- P1 写入对比：直写基表(A1+A2 两条 INSERT) vs 经视图(INSTEAD OF + 按行加密)
DECLARE @v_n int = 1000, @v_i int = 0, @t0 datetime2, @t1 datetime2, @base_ms int, @view_ms int;
BEGIN
  SET @t0 = SYSDATETIME();
  WHILE @v_i < @v_n BEGIN
    SET @v_i = @v_i + 1;
    INSERT INTO dbo.tb_sensitive_c (id, f1_cipher, f2, f1_h) VALUES (11000 + @v_i, dbo.enc_pkg_enc(N'p1-' + CAST(@v_i AS nvarchar)), @v_i, dbo.enc_pkg_hsh(N'p1-' + CAST(@v_i AS nvarchar)));
    INSERT INTO dbo.tb_sensitive_p (id, f1_plain, fn) VALUES (11000 + @v_i, N'p1-' + CAST(@v_i AS nvarchar), N'P1-' + CAST(@v_i AS nvarchar));
  END;
  SET @t1 = SYSDATETIME(); SET @base_ms = DATEDIFF(ms, @t0, @t1);

  SET @v_i = 0; SET @t0 = SYSDATETIME();
  WHILE @v_i < @v_n BEGIN
    SET @v_i = @v_i + 1;
    INSERT INTO dbo.tb_sensitive (id, f1, f2) VALUES (12000 + @v_i, N'p1-' + CAST(@v_i AS nvarchar), @v_i);
  END;
  SET @t1 = SYSDATETIME(); SET @view_ms = DATEDIFF(ms, @t0, @t1);

  PRINT '[PERF] P1 写入 ' + CAST(@v_n AS varchar) + ' 行: 直写基表=' + CAST(@base_ms AS varchar)
      + ' ms, 经视图=' + CAST(@view_ms AS varchar) + ' ms (慢 '
      + CAST(ROUND(CAST(@view_ms AS float) / NULLIF(@base_ms, 0), 1) AS varchar) + 'x)';
  DELETE FROM dbo.tb_sensitive WHERE id BETWEEN 11000 AND 13000;
END;
GO

-- P2 查询对比：解密读（逐行解密） vs 直查明文表
DECLARE @v_n int = 5000, @v_i int = 0, @t0 datetime2, @t1 datetime2, @a_ms int, @b_ms int, @d int;
BEGIN
  WHILE @v_i < @v_n BEGIN
    SET @v_i = @v_i + 1;
    INSERT INTO dbo.tb_sensitive_c (id, f1_cipher, f2, f1_h) VALUES (21000 + @v_i, dbo.enc_pkg_enc(N'q2-' + CAST(@v_i AS nvarchar)), @v_i, dbo.enc_pkg_hsh(N'q2-' + CAST(@v_i AS nvarchar)));
    INSERT INTO dbo.tb_sensitive_p (id, f1_plain, fn) VALUES (21000 + @v_i, N'q2-' + CAST(@v_i AS nvarchar), N'Q2-' + CAST(@v_i AS nvarchar));
  END;

  SET @t0 = SYSDATETIME();
  SELECT @d = COUNT(*) FROM dbo.tb_sensitive WHERE f2 BETWEEN 21001 AND 21000 + @v_n;
  SET @t1 = SYSDATETIME(); SET @a_ms = DATEDIFF(ms, @t0, @t1);

  SET @t0 = SYSDATETIME();
  SELECT @d = COUNT(*) FROM dbo.tb_sensitive_p WHERE id BETWEEN 21001 AND 21000 + @v_n;
  SET @t1 = SYSDATETIME(); SET @b_ms = DATEDIFF(ms, @t0, @t1);

  PRINT '[PERF] P2 查询 ' + CAST(@v_n AS varchar) + ' 行: 视图解密读=' + CAST(@a_ms AS varchar)
      + ' ms, 直查明文=' + CAST(@b_ms AS varchar) + ' ms (慢 '
      + CAST(ROUND(CAST(@a_ms AS float) / NULLIF(@b_ms, 0), 1) AS varchar) + 'x)';
  DELETE FROM dbo.tb_sensitive WHERE id BETWEEN 21000 AND 26000;
END;
GO

-- P3 过滤对比：解密列 WHERE（全扫+逐行解密） vs 辅助列 WHERE（索引）
DECLARE @v_n int = 5000, @v_i int = 0, @loop int = 0, @t0 datetime2, @t1 datetime2, @a_ms int, @b_ms int, @d int, @v_key nvarchar(50);
BEGIN
  WHILE @v_i < @v_n BEGIN
    SET @v_i = @v_i + 1;
    INSERT INTO dbo.tb_sensitive_c (id, f1_cipher, f2, f1_h) VALUES (31000 + @v_i, dbo.enc_pkg_enc(N'q3-' + CAST(@v_i AS nvarchar)), @v_i, dbo.enc_pkg_hsh(N'q3-' + CAST(@v_i AS nvarchar)));
    INSERT INTO dbo.tb_sensitive_p (id, f1_plain, fn) VALUES (31000 + @v_i, N'q3-' + CAST(@v_i AS nvarchar), N'Q3-' + CAST(@v_i AS nvarchar));
  END;
  SET @v_key = N'q3-1';

  SET @t0 = SYSDATETIME();
  SET @loop = 0; WHILE @loop < 200 BEGIN
    SET @loop = @loop + 1;
    SELECT @d = COUNT(*) FROM dbo.tb_sensitive WHERE f1 = @v_key;
  END;
  SET @t1 = SYSDATETIME(); SET @a_ms = DATEDIFF(ms, @t0, @t1);

  SET @t0 = SYSDATETIME();
  SET @loop = 0; WHILE @loop < 200 BEGIN
    SET @loop = @loop + 1;
    SELECT @d = COUNT(*) FROM dbo.tb_sensitive_p WHERE fn = UPPER(@v_key);
  END;
  SET @t1 = SYSDATETIME(); SET @b_ms = DATEDIFF(ms, @t0, @t1);

  PRINT '[PERF] P3 过滤 200 次: 解密列=' + CAST(@a_ms AS varchar) + ' ms, 辅助列索引=' + CAST(@b_ms AS varchar)
      + ' ms (慢 ' + CAST(ROUND(CAST(@a_ms AS float) / NULLIF(@b_ms, 0), 1) AS varchar) + 'x)';
  DELETE FROM dbo.tb_sensitive WHERE id BETWEEN 31000 AND 36000;
END;
GO

-- P4 批量 UPDATE 经视图（红线场景演示）
DECLARE @v_n int = 500, @v_i int = 0, @t0 datetime2, @t1 datetime2, @el_ms int;
BEGIN
  WHILE @v_i < @v_n BEGIN
    SET @v_i = @v_i + 1;
    INSERT INTO dbo.tb_sensitive_c (id, f1_cipher, f2, f1_h) VALUES (41000 + @v_i, dbo.enc_pkg_enc(N'p4-' + CAST(@v_i AS nvarchar)), @v_i, dbo.enc_pkg_hsh(N'p4-' + CAST(@v_i AS nvarchar)));
    INSERT INTO dbo.tb_sensitive_p (id, f1_plain, fn) VALUES (41000 + @v_i, N'p4-' + CAST(@v_i AS nvarchar), N'P4-' + CAST(@v_i AS nvarchar));
  END;

  SET @t0 = SYSDATETIME();
  SET @v_i = 0; WHILE @v_i < @v_n BEGIN
    SET @v_i = @v_i + 1;
    UPDATE dbo.tb_sensitive SET f2 = f2 + 1 WHERE id = 41000 + @v_i;
  END;
  SET @t1 = SYSDATETIME(); SET @el_ms = DATEDIFF(ms, @t0, @t1);
  PRINT '[PERF] P4 批量 UPDATE ' + CAST(@v_n AS varchar) + ' 行经视图(逐行触发): ' + CAST(@el_ms AS varchar)
      + ' ms — 若超阈值则确认红线: 批量必须直写基表';
  DELETE FROM dbo.tb_sensitive WHERE id BETWEEN 41000 AND 42000;
END;
GO

PRINT 'P1/P2/P3/P4 结果已输出，请回填判定表';