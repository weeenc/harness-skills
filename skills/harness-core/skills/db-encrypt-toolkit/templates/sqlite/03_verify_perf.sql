-- 03_verify_perf.sql  SQLite 版 —— 性能对比（.timer 计时，批写入经视图 vs 直写）
-- 运行：sqlite3 test.db ".timer on" && sqlite3 test.db < 03_verify_perf.sql
--       （或 sqlite3 test.db "PRAGMA cache_size=-20000; .timer on; .read 03_verify_perf.sql"）
-- 说明：SQLite 无存储过程/内联计时；用 sqlite3 CLI 的 .timer 看每条 .read 总耗时。
--       结果仅供参考；嵌入式单写者场景通常瓶颈在应用加密而非 SQL 层。
.bail on
.headers on
.mode column

-- 造数：直写基表基线（一次事务批量 INSERT A1+A2，模拟"绕过视图直写"）
BEGIN;
INSERT INTO tb_sensitive_c (id, f1_cipher, f2, f1_h)
WITH RECURSIVE seq(x) AS (SELECT 1 UNION ALL SELECT x+1 FROM seq WHERE x < 5000)
SELECT 11000 + x, hex(randomblob(16)), x, hex(randomblob(8)) FROM seq;
INSERT INTO tb_sensitive_p (id, f1_plain, fn)
WITH RECURSIVE seq(x) AS (SELECT 1 UNION ALL SELECT x+1 FROM seq WHERE x < 5000)
SELECT 11000 + x, 'p1-' || x, upper('p1-' || x) FROM seq;
COMMIT;
SELECT 'P1a 直写基表 5000 行' AS check_name, count(*) AS rows FROM tb_sensitive_c;

-- 被测：经视图批量 INSERT（逐行触发 INSTEAD OF → 拆分+占位密文生成）
-- 注意：经视图的 id 必须与上面直写区间（11000..15999）不相交，否则 UNIQUE 冲突
BEGIN;
INSERT INTO tb_sensitive (id, f1, f2)
WITH RECURSIVE seq(x) AS (SELECT 1 UNION ALL SELECT x+1 FROM seq WHERE x < 5000)
SELECT 16000 + x, 'p1-' || x, x FROM seq;
COMMIT;
SELECT 'P1b 经视图 5000 行' AS check_name, count(*) AS rows FROM tb_sensitive_c WHERE id >= 16000;

-- P2 解密读对比无法做（无解密函数）；查询对比：视图(密文) vs 辅助列(索引/明文)
EXPLAIN QUERY PLAN SELECT count(*) FROM tb_sensitive WHERE f1 = 'p1-1';
EXPLAIN QUERY PLAN SELECT count(*) FROM tb_sensitive_p WHERE fn = 'P1-1';

-- 清理
DELETE FROM tb_sensitive WHERE id BETWEEN 11000 AND 21000;
SELECT 'P1/P2 完成：请对照 .timer 输出的两段总耗时回填判定表' AS result;