-- 02_verify_query.sql  SQLite 版 —— 查询类验证（JOIN/分组/模糊/执行计划/字典）
-- 运行：sqlite3 test.db < 02_verify_query.sql
-- 前提：已执行 00_setup.sql
.bail off
.headers on
.mode column

-- Q1 简单全列查询（f1=密文列，应用层解密）
SELECT 'Q1 视图查询' AS check_name, count(*) AS n, min(f1) AS sample_cipher FROM tb_sensitive;

-- Q2 JOIN 关联（与 TB_DEPT）
SELECT 'Q2 JOIN 关联' AS check_name, count(*) AS n
FROM tb_sensitive s JOIN tb_dept d ON (s.f2 / 100) = (d.dept_id / 10);

-- Q3 GROUP BY / HAVING 在普通列 f2
SELECT 'Q3 group普通列' AS check_name, f2, count(*) AS c
FROM tb_sensitive GROUP BY f2 HAVING count(*) > 0 ORDER BY f2;

-- Q4 GROUP BY 敏感列 f1（密文列：可聚合但无业务意义 → 结论走 tb_sensitive_p）
SELECT 'Q4 group敏感列(密文)' AS check_name, count(*) AS n FROM tb_sensitive GROUP BY f1;

-- Q5 模糊查询：密文列 LIKE（0 命中 → 证明密文不可模糊检索）
SELECT 'Q5 模糊-密文列' AS check_name, count(*) AS n FROM tb_sensitive WHERE f1 LIKE '%hello%';
-- Q5b 模糊查询：辅助列 fn（命中）
SELECT 'Q5b 模糊-辅助列' AS check_name, count(*) AS n FROM tb_sensitive_p WHERE fn LIKE '%HELLO%';

-- Q6 大小写：辅助列 fn（解密列不可下推）
SELECT 'Q6 大小写-辅助列' AS check_name, count(*) AS n FROM tb_sensitive_p WHERE fn = 'HELLO-SQLITE';

-- Q7 执行计划对比（谓词下推证据）
SELECT 'Q7 计划-密文等值(全扫)' AS check_name;
EXPLAIN QUERY PLAN SELECT * FROM tb_sensitive WHERE f1 = 'x';
SELECT 'Q7b 计划-辅助列(索引)' AS check_name;
EXPLAIN QUERY PLAN SELECT * FROM tb_sensitive_p WHERE fn = 'HELLO-SQLITE';

-- Q8 数据字典视角（视图列形态）
SELECT 'Q8 视图列' AS check_name, name, type
FROM pragma_table_info('tb_sensitive') ORDER BY cid;
SELECT 'Q8b 辅助列' AS check_name, name, type
FROM pragma_table_info('tb_sensitive_p') ORDER BY cid;