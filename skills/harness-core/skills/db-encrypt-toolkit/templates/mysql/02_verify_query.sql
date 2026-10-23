-- 02_verify_query.sql  MySQL/MariaDB 版 —— 查询类验证（JOIN/分组/模糊/执行计划/字典）
-- 运行：mysql -u <user> -p <db> < 02_verify_query.sql
-- 前提：已执行 00_setup.sql

-- Q1 解密读（经表达式视图，读路径正确）
SELECT 'Q1 解密读' AS check_name, COUNT(*) AS n, MIN(f1) AS sample FROM v_ts_readable;

-- Q2 JOIN 关联（与 TB_DEPT；视图/表均可 join）
SELECT d.dept_name, s.id, s.f1
FROM v_ts_readable s JOIN tb_dept d ON (s.f2 / 100) = (d.dept_id / 10)
ORDER BY s.id;
SELECT 'Q2 JOIN 关联' AS check_name, COUNT(*) AS n FROM v_ts_readable s JOIN tb_dept d ON 1 = 1;

-- Q3 GROUP BY / HAVING 在普通列 f2（可下推）
SELECT 'Q3 group普通列' AS check_name, f2, COUNT(*) AS c
FROM tb_sensitive_c GROUP BY f2 HAVING COUNT(*) > 0 ORDER BY f2;

-- Q4 GROUP BY 敏感列（解密表达式聚合：语法可行、全表解密）
SELECT 'Q4 group敏感列' AS check_name, f1, COUNT(*) AS c
FROM v_ts_readable GROUP BY f1 ORDER BY f1;

-- Q5 模糊查询：密文列 LIKE（预期 0 命中 → 证明密文不可模糊检索）
SELECT 'Q5 模糊-密文列' AS check_name, COUNT(*) AS n FROM tb_sensitive WHERE f1 LIKE '%hello%';
-- Q5b 模糊查询：辅助列 fn（预期命中）
SELECT 'Q5b 模糊-辅助列' AS check_name, COUNT(*) AS n FROM tb_sensitive_p WHERE fn LIKE '%HELLO%';

-- Q6 大小写：解密表达式 UPPER() 对比（语义可行、不可下推）
SELECT 'Q6 大小写-解密表达式' AS check_name, COUNT(*) AS n FROM v_ts_readable WHERE UPPER(f1) = 'HELLO-MYSQL';
SELECT 'Q6b 大小写-辅助列' AS check_name, COUNT(*) AS n FROM tb_sensitive_p WHERE fn = 'HELLO-MYSQL';

-- Q7 执行计划对比（谓词下推证据）
EXPLAIN FORMAT=JSON
SELECT * FROM tb_sensitive WHERE f1 = 'hello-mysql';          -- 密文等值：全扫
EXPLAIN FORMAT=JSON
SELECT * FROM tb_sensitive_p WHERE fn = 'HELLO-MYSQL';        -- 辅助列：预期使用 idx_ts_p_fn

-- Q8 数据字典视角（ETL 工具看到 tb_sensitive=视图，列=f1(密文)）
SELECT table_name, column_name, data_type, ordinal_position
FROM information_schema.columns
WHERE table_schema = DATABASE() AND table_name = 'tb_sensitive'
ORDER BY ordinal_position;