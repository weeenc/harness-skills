-- 02_verify_query.sql  SQL Server 版 —— 查询类验证（JOIN/分组/模糊/执行计划/字典）
-- 运行：sqlcmd -S <server> -U <user> -i 02_verify_query.sql
-- 前提：已执行 00_setup.sql
SET NOCOUNT ON;
GO

-- Q1 简单全列查询（解密读）
SELECT 'Q1 解密读' AS check_name, COUNT(*) AS n, MIN(f1) AS sample FROM dbo.tb_sensitive;

-- Q2 JOIN 关联（与 TB_DEPT）
SELECT d.dept_name, s.id, s.f1
FROM dbo.tb_sensitive s JOIN dbo.tb_dept d ON (s.f2 / 100) = (d.dept_id / 10)
ORDER BY s.id;
SELECT 'Q2 JOIN 关联' AS check_name, COUNT(*) AS n
FROM dbo.tb_sensitive s JOIN dbo.tb_dept d ON 1 = 1;

-- Q3 GROUP BY / HAVING 在普通列 f2（可下推）
SELECT 'Q3 group普通列' AS check_name, f2, COUNT(*) AS c
FROM dbo.tb_sensitive GROUP BY f2 HAVING COUNT(*) > 0 ORDER BY f2;

-- Q4 GROUP BY 敏感列 f1（解密列聚合：语法可行、全表解密聚合、无法下推）
SELECT 'Q4 group敏感列' AS check_name, f1, COUNT(*) AS c
FROM dbo.tb_sensitive GROUP BY f1 ORDER BY f1;

-- Q5 模糊查询：视图解密列 LIKE（可跑但全扫）
SELECT 'Q5 模糊-解密列' AS check_name, COUNT(*) AS n FROM dbo.tb_sensitive WHERE f1 LIKE N'%hello%';
-- Q5b 模糊查询：辅助列 fn（走索引；fn 在 A2 明文表 tb_sensitive_p，视图无 fn）
SELECT 'Q5b 模糊-辅助列' AS check_name, COUNT(*) AS n FROM dbo.tb_sensitive_p WHERE fn LIKE N'%HELLO%';

-- Q6 大小写：解密列 UPPER()（不可下推）
SELECT 'Q6 大小写-解密列' AS check_name, COUNT(*) AS n FROM dbo.tb_sensitive WHERE UPPER(f1) = N'HELLO-SQLSERVER';
SELECT 'Q6b 大小写-辅助列' AS check_name, COUNT(*) AS n FROM dbo.tb_sensitive_p WHERE fn = N'HELLO-SQLSERVER';

-- Q7 执行计划对比（关键证据：谓词下推与否）
SET SHOWPLAN_TEXT ON;
GO
SELECT * FROM dbo.tb_sensitive WHERE f1 = N'hello-sqlserver';   -- 解密列：预期全扫
GO
SELECT * FROM dbo.tb_sensitive_p WHERE fn = N'HELLO-SQLSERVER';   -- 辅助列：预期 Index Seek
GO
SET SHOWPLAN_TEXT OFF;
GO

-- Q8 数据字典视角（ETL/报表工具看到视图结构：列与类型）
SELECT c.name AS column_name, t.name AS data_type
FROM sys.columns c
JOIN sys.types t ON c.user_type_id = t.user_type_id
WHERE c.object_id = OBJECT_ID('dbo.tb_sensitive')
ORDER BY c.column_id;

-- Q9 说明（视图列注释：f1 为解密列，无索引；过滤/排序/模糊走 fn / f1_plain）
EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'f1 为解密列(无索引)；过滤/排序/模糊请用 fn 或 f1_plain',
  @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'VIEW', @level1name=N'tb_sensitive', @level2type=N'COLUMN', @level2name=N'f1';