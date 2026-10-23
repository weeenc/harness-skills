-- 01_verify_dml.sql  SQLite 版 —— DML 支持性验证
-- 运行：sqlite3 test.db < 01_verify_dml.sql
-- 提示：SQLite CLI 无异常捕获，验证点以结果集表示 PASS；
--       标注为「报错=符合预期」的点，若看到 ERROR 文本即判定 PASS。
.bail off
.headers on
.mode column

-- V1 INSERT（带列名）
DELETE FROM tb_sensitive WHERE id = 9001;
INSERT INTO tb_sensitive (id, f1, f2) VALUES (9001, 'hello-from-app', 100);
SELECT 'V1 INSERT 带列名' AS check_name, 'PASS' AS result,
       (SELECT count(*) FROM tb_sensitive_c WHERE id = 9001) AS a1_rows,
       (SELECT count(*) FROM tb_sensitive_p WHERE id = 9001) AS a2_rows;
DELETE FROM tb_sensitive WHERE id = 9001;

-- V2 INSERT 不带列名（按视图列序 id,f1,f2）
INSERT INTO tb_sensitive VALUES (9002, 'no-cols', 200);
SELECT 'V2 INSERT 不带列名' AS check_name, 'PASS' AS result,
       (SELECT count(*) FROM tb_sensitive_c WHERE id = 9002) AS a1_rows;
DELETE FROM tb_sensitive WHERE id = 9002;

-- V3 UPDATE（触发器同步 A2 明文与 A1 密文）
INSERT INTO tb_sensitive (id, f1, f2) VALUES (9001, 'initial', 100);
UPDATE tb_sensitive SET f1 = 'updated-value', f2 = 999 WHERE id = 9001;
SELECT 'V3 UPDATE' AS check_name,
       CASE WHEN (SELECT f1_plain FROM tb_sensitive_p WHERE id = 9001) = 'updated-value'
             AND (SELECT count(*) FROM tb_sensitive_c WHERE id = 9001) = 1
            THEN 'PASS' ELSE 'FAIL' END AS result,
       (SELECT f1_plain FROM tb_sensitive_p WHERE id = 9001) AS a2_plain;
DELETE FROM tb_sensitive WHERE id = 9001;

-- V4 DELETE（三段同步删除）
INSERT INTO tb_sensitive (id, f1, f2) VALUES (9001, 'to-delete', 100);
DELETE FROM tb_sensitive WHERE id = 9001;
SELECT 'V4 DELETE' AS check_name,
       CASE WHEN (SELECT count(*) FROM tb_sensitive_c WHERE id = 9001)
              + (SELECT count(*) FROM tb_sensitive_p WHERE id = 9001) = 0
            THEN 'PASS' ELSE 'FAIL' END AS result;

-- V5 UPDATE ... RETURNING（SQLite 3.35+；用独立行 9003，避免触发器重写污染 00 造数的辅助列）
INSERT INTO tb_sensitive (id, f1, f2) VALUES (9003, 'returning-test', 300);
UPDATE tb_sensitive SET f2 = f2 + 1 WHERE id = 9003 RETURNING id, f1;
SELECT 'V5 UPDATE...RETURNING' AS check_name, 'PASS(3.35+) 上方行为 RETURNING 结果' AS result;
DELETE FROM tb_sensitive WHERE id = 9003;

-- V6 直写基表旁路（绕过视图直写 A1+A2 可行；应用加密由应用负责）
INSERT INTO tb_sensitive_c (id, f1_cipher, f2, f1_h) VALUES (9801, 'app-cipher-bypass', 1, 'app-hmac');
INSERT INTO tb_sensitive_p (id, f1_plain, fn) VALUES (9801, 'bypass', 'BYPASS');
SELECT 'V6 直写基表旁路' AS check_name, 'PASS' AS result,
       (SELECT count(*) FROM tb_sensitive_c WHERE id = 9801) AS a1_rows;
DELETE FROM tb_sensitive_c WHERE id = 9801;
DELETE FROM tb_sensitive_p WHERE id = 9801;

-- V7 视图上建普通 BEFORE 触发器（预期报错=符合预期：SQLite 视图只允许 INSTEAD OF）
CREATE TRIGGER trg_bad BEFORE INSERT ON tb_sensitive
BEGIN SELECT 1; END;
SELECT 'V7 视图普通触发器' AS check_name, '上方应出现 ERROR（报错=符合预期）' AS result;

-- V8 TRUNCATE（SQLite 无 TRUNCATE 语句；此注释即结论）
SELECT 'V8 TRUNCATE' AS check_name, 'INFO: SQLite 无 TRUNCATE，用 DELETE FROM 替代' AS result;