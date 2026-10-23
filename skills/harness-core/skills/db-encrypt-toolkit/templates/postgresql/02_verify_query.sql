-- 02_verify_query.sql  PostgreSQL 版 —— 查询类验证（JOIN/分组/模糊/执行计划/字典/rowid）
-- 运行：psql -U <user> -d <db> -f 02_verify_query.sql
-- 前提：已执行 00_setup.sql

\set ON_ERROR_STOP off

-- Q1 简单全列查询（解密读）
SELECT 'Q1 解密读' AS check_name, count(*) AS n, min(f1) AS sample FROM tb_sensitive;

-- Q2 JOIN 关联（与 TB_DEPT 关联）
SELECT d.dept_name, s.id, s.f1
  FROM tb_sensitive s JOIN tb_dept d ON (s.f2 / 100) = (d.dept_id / 10)
 ORDER BY s.id LIMIT 5;
SELECT 'Q2 JOIN 关联' AS check_name, count(*) AS n FROM tb_sensitive s JOIN tb_dept d ON true;

-- Q3 GROUP BY / HAVING 在普通列 f2（索引可下推）
SELECT 'Q3 group普通列' AS check_name, f2, count(*) AS c FROM tb_sensitive GROUP BY f2 HAVING count(*) > 0 ORDER BY f2;

-- Q4 GROUP BY 敏感列 f1（解密列聚合：语法可行，全表解密后聚合，无法下推）
SELECT 'Q4 group敏感列' AS check_name, f1, count(*) AS c FROM tb_sensitive GROUP BY f1 ORDER BY f1;

-- Q5 模糊查询：视图解密列 LIKE（可跑但全表扫）
SELECT 'Q5 模糊-解密列' AS check_name, count(*) AS n FROM tb_sensitive WHERE f1 LIKE '%hello%';
-- Q5b 模糊查询：辅助列 fn（走索引；fn 在 A2 明文表 tb_sensitive_p，视图无 fn）
SELECT 'Q5b 模糊-辅助列' AS check_name, count(*) AS n FROM tb_sensitive_p WHERE fn LIKE '%HELLO%';

-- Q6 大小写：解密列 UPPER() 之间的对比（不可下推）
SELECT 'Q6 大小写-解密列' AS check_name, count(*) AS n FROM tb_sensitive WHERE upper(f1) = 'HELLO-POSTGRES';
SELECT 'Q6b 大小写-辅助列' AS check_name, count(*) AS n FROM tb_sensitive_p WHERE fn = 'HELLO-POSTGRES';

-- Q7 执行计划对比（关键证据：谓词到底推不推；先收集统计信息）
ANALYZE tb_sensitive_c;
ANALYZE tb_sensitive_p;
EXPLAIN (FORMAT TEXT) SELECT * FROM tb_sensitive WHERE f1 = 'hello-postgres';
EXPLAIN (FORMAT TEXT) SELECT * FROM tb_sensitive_p WHERE fn = 'HELLO-POSTGRES';
SELECT ((SELECT count(*) FROM pg_indexes WHERE tablename='tb_sensitive_p') > 0) AS fn_index_exists;

-- Q8 rowid/ctid：视图行定位（PG 视图无真实 rowid，ctid 指向视图内部表）
SELECT 'Q8 ctid' AS check_name, ctid, id, f1 FROM tb_sensitive ORDER BY id LIMIT 3;

-- Q9 数据字典视角（ETL/报表工具看到的是视图结构）
SELECT column_name, data_type
  FROM information_schema.columns
 WHERE table_name = 'tb_sensitive'
 ORDER BY ordinal_position;

-- Q10 参考：nullable 与注释提示（视图列 COALESCE 影响索引）
COMMENT ON VIEW tb_sensitive IS '数据字典说明：f1 为解密列(只读性弱/无索引)；排序/过滤/模糊请用辅助列 fn 或 f1_plain';