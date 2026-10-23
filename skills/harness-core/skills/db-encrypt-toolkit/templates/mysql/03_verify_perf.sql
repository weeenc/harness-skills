-- 03_verify_perf.sql  MySQL/MariaDB 版 —— 性能对比（写入/查询/过滤/批量）
-- 运行：mysql -u <user> -p <db> < 03_verify_perf.sql
-- 计时：UNIX_TIMESTAMP(NOW(3))*1000 毫秒粗略对比；生产以真实压测为准
DELIMITER $$
DROP PROCEDURE IF EXISTS perf_check$$
CREATE PROCEDURE perf_check()
BEGIN
  DECLARE v_n INT DEFAULT 1000;
  DECLARE v_i INT DEFAULT 0;
  DECLARE v_t0 BIGINT; DECLARE v_t1 BIGINT;
  DECLARE v_a BIGINT DEFAULT 0; DECLARE v_b BIGINT DEFAULT 0;
  DECLARE v_dummy INT;

  -- P1 写入对比：直写基表(A1+A2 两条) vs 经视图（列映射视图单条 INSERT + 应用自带加密）
  DELETE FROM tb_sensitive WHERE id BETWEEN 11000 AND 13000;
  SET v_t0 = UNIX_TIMESTAMP(NOW(3))*1000;
  SET v_i = 0;
  WHILE v_i < v_n DO
    SET v_i = v_i + 1;
    INSERT INTO tb_sensitive_c (id, f1_cipher, f2, f1_h)
    VALUES (11000 + v_i, HEX(AES_ENCRYPT(CONCAT('p1-', v_i), @crypt_key)), v_i, HEX(SHA2(CONCAT('p1-', v_i), 256)));
    INSERT INTO tb_sensitive_p (id, f1_plain, fn) VALUES (11000 + v_i, CONCAT('p1-', v_i), UPPER(CONCAT('p1-', v_i)));
  END WHILE;
  SET v_t1 = UNIX_TIMESTAMP(NOW(3))*1000; SET v_a = v_t1 - v_t0;

  SET v_t0 = UNIX_TIMESTAMP(NOW(3))*1000;
  SET v_i = 0;
  WHILE v_i < v_n DO
    SET v_i = v_i + 1;
    INSERT INTO tb_sensitive (id, f1, f2) VALUES (12000 + v_i, HEX(AES_ENCRYPT(CONCAT('p1-', v_i), @crypt_key)), v_i);
  END WHILE;
  SET v_t1 = UNIX_TIMESTAMP(NOW(3))*1000; SET v_b = v_t1 - v_t0;
  SELECT CONCAT('[PERF] P1 写入 ', v_n, ' 行: 直写基表=', v_a, ' ms, 经视图=', v_b, ' ms (慢 ',
                ROUND(v_b / NULLIF(v_a, 0), 1), 'x)') AS result;
  DELETE FROM tb_sensitive WHERE id BETWEEN 11000 AND 13000;

  -- P2 查询对比：解密读（表达式视图） vs 直查明文表
  SET v_n = 5000; SET v_i = 0;
  WHILE v_i < v_n DO
    SET v_i = v_i + 1;
    INSERT INTO tb_sensitive_c (id, f1_cipher, f2, f1_h)
    VALUES (21000 + v_i, HEX(AES_ENCRYPT(CONCAT('q2-', v_i), @crypt_key)), v_i, HEX(SHA2(CONCAT('q2-', v_i), 256)));
    INSERT INTO tb_sensitive_p (id, f1_plain, fn) VALUES (21000 + v_i, CONCAT('q2-', v_i), UPPER(CONCAT('q2-', v_i)));
  END WHILE;

  SET v_t0 = UNIX_TIMESTAMP(NOW(3))*1000;
  SELECT COUNT(*) INTO v_dummy FROM v_ts_readable WHERE f2 BETWEEN 21001 AND 21000 + v_n;
  SET v_t1 = UNIX_TIMESTAMP(NOW(3))*1000; SET v_a = v_t1 - v_t0;

  SET v_t0 = UNIX_TIMESTAMP(NOW(3))*1000;
  SELECT COUNT(*) INTO v_dummy FROM tb_sensitive_p WHERE id BETWEEN 21001 AND 21000 + v_n;
  SET v_t1 = UNIX_TIMESTAMP(NOW(3))*1000; SET v_b = v_t1 - v_t0;
  SELECT CONCAT('[PERF] P2 查询 ', v_n, ' 行: 视图解密读=', v_a, ' ms, 直查明文=', v_b, ' ms (慢 ',
                ROUND(v_a / NULLIF(v_b, 0), 1), 'x)') AS result;
  DELETE FROM tb_sensitive WHERE id BETWEEN 21000 AND 26000;

  -- P3 过滤对比：密文等值（需全表解密后的才可比 → 不走索引） vs 辅助列（索引）
  SET v_n = 5000; SET v_i = 0;
  WHILE v_i < v_n DO
    SET v_i = v_i + 1;
    INSERT INTO tb_sensitive_c (id, f1_cipher, f2, f1_h)
    VALUES (31000 + v_i, HEX(AES_ENCRYPT(CONCAT('q3-', v_i), @crypt_key)), v_i, HEX(SHA2(CONCAT('q3-', v_i), 256)));
    INSERT INTO tb_sensitive_p (id, f1_plain, fn) VALUES (31000 + v_i, CONCAT('q3-', v_i), UPPER(CONCAT('q3-', v_i)));
  END WHILE;
  SET v_t0 = UNIX_TIMESTAMP(NOW(3))*1000;
  SET v_i = 0;
  WHILE v_i < 200 DO
    SET v_i = v_i + 1;
    SELECT COUNT(*) INTO v_dummy FROM v_ts_readable WHERE f1 = 'q3-1';
  END WHILE;
  SET v_t1 = UNIX_TIMESTAMP(NOW(3))*1000; SET v_a = v_t1 - v_t0;

  SET v_t0 = UNIX_TIMESTAMP(NOW(3))*1000;
  SET v_i = 0;
  WHILE v_i < 200 DO
    SET v_i = v_i + 1;
    SELECT COUNT(*) INTO v_dummy FROM tb_sensitive_p WHERE fn = 'Q3-1';
  END WHILE;
  SET v_t1 = UNIX_TIMESTAMP(NOW(3))*1000; SET v_b = v_t1 - v_t0;
  SELECT CONCAT('[PERF] P3 过滤 200 次: 解密列=', v_a, ' ms, 辅助列索引=', v_b, ' ms (慢 ',
                ROUND(v_a / NULLIF(v_b, 0), 1), 'x)') AS result;
  DELETE FROM tb_sensitive WHERE id BETWEEN 31000 AND 36000;

  -- P4 批量 UPDATE（经视图逐行）
  SET v_n = 500; SET v_i = 0;
  WHILE v_i < v_n DO
    SET v_i = v_i + 1;
    INSERT INTO tb_sensitive_c (id, f1_cipher, f2, f1_h)
    VALUES (41000 + v_i, HEX(AES_ENCRYPT(CONCAT('p4-', v_i), @crypt_key)), v_i, HEX(SHA2(CONCAT('p4-', v_i), 256)));
    INSERT INTO tb_sensitive_p (id, f1_plain, fn) VALUES (41000 + v_i, CONCAT('p4-', v_i), UPPER(CONCAT('p4-', v_i)));
  END WHILE;
  SET v_t0 = UNIX_TIMESTAMP(NOW(3))*1000;
  SET v_i = 0;
  WHILE v_i < v_n DO
    SET v_i = v_i + 1;
    UPDATE tb_sensitive SET f2 = f2 + 1 WHERE id = 41000 + v_i;
  END WHILE;
  SET v_t1 = UNIX_TIMESTAMP(NOW(3))*1000;
  SELECT CONCAT('[PERF] P4 批量 UPDATE ', v_n, ' 行经视图(逐行): ', v_t1 - v_t0, ' ms — 若超阈值确认红线: 批量必须直写基表') AS result;
  DELETE FROM tb_sensitive WHERE id BETWEEN 41000 AND 42000;

  SELECT 'P1/P2/P3/P4 结果已输出，请回填判定表' AS result;
END$$
DELIMITER ;
CALL perf_check();
DROP PROCEDURE perf_check;