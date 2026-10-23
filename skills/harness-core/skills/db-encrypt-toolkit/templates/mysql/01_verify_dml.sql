-- 01_verify_dml.sql  MySQL/MariaDB 版 —— 可更新视图边界 + DML 支持性验证
-- 运行：mysql -u <user> -p <db> < 01_verify_dml.sql
-- 方式：存储过程 verify_dml + SQLEXCEPTION handler，逐条输出 [PASS]/[FAIL]/[INFO]
-- 前提：已执行 00_setup.sql（需 @crypt_key 会话变量与两个视图存在）
DELIMITER $$
DROP PROCEDURE IF EXISTS verify_dml$$
CREATE PROCEDURE verify_dml()
BEGIN
  DECLARE v_err VARCHAR(500);
  DECLARE v_stage VARCHAR(120);
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
      GET DIAGNOSTICS CONDITION 1 v_err = MESSAGE_TEXT;
      SELECT CONCAT('[FAIL] ', v_stage, ': ', v_err) AS result;
    END;

  -- V1 INSERT 列映射视图（值=密文，语义上可行）
  SET v_stage = 'V1 INSERT 列映射视图';
  START TRANSACTION;
    DELETE FROM tb_sensitive WHERE id = 9001;
    INSERT INTO tb_sensitive (id, f1, f2) VALUES (9001, HEX(AES_ENCRYPT('hello-from-app', @crypt_key)), 100);
    SELECT CONCAT('[PASS] ', v_stage, ': SUPPORTED（写入的是密文，应用需自行加密）') AS result;
  ROLLBACK;

  -- V2 INSERT 表达式解密视图（预期失败：不可更新列）→ 证明透明写不可行
  SET v_stage = 'V2 INSERT 表达式解密视图';
  START TRANSACTION;
    INSERT INTO v_ts_readable (id, f1, f2) VALUES (9002, 'plain-attempt', 200);
    SELECT CONCAT('[PASS] ', v_stage, ': SUPPORTED（异常，需复核）') AS result;
  ROLLBACK;

  -- V3 INSERT ... 显式调用 AES 加密（SQL 内完成加密，等价"SQL 显式加密"变体）
  SET v_stage = 'V3 INSERT 显式AES加密';
  START TRANSACTION;
    INSERT INTO tb_sensitive (id, f1, f2) VALUES (9003, HEX(AES_ENCRYPT('explicit', @crypt_key)), 300);
    SELECT CONCAT('[PASS] ', v_stage, ': SUPPORTED（HEX(AES_ENCRYPT(...)) 封装）') AS result;
  ROLLBACK;

  -- V4 UPDATE 列映射视图
  SET v_stage = 'V4 UPDATE 列映射视图';
  START TRANSACTION;
    INSERT INTO tb_sensitive (id, f1, f2) VALUES (9001, HEX(AES_ENCRYPT('initial', @crypt_key)), 100);
    UPDATE tb_sensitive SET f1 = HEX(AES_ENCRYPT('updated-value', @crypt_key)) WHERE id = 9001;
    IF (SELECT COUNT(*) FROM tb_sensitive_c WHERE id = 9001 AND f1_h = HEX(SHA2('updated-value', 256))) = 0 THEN
      -- 哈希需应用/定时任务同步更新（本路线无触发器可自动维护）
      SELECT CONCAT('[PASS] ', v_stage, ': SUPPORTED（注意 f1_h 需同步更新，否则防篡改失效）') AS result;
    ELSE
      SELECT CONCAT('[PASS] ', v_stage, ': SUPPORTED 且哈希同步') AS result;
    END IF;
  ROLLBACK;

  -- V5 DELETE 列映射视图
  SET v_stage = 'V5 DELETE 列映射视图';
  START TRANSACTION;
    INSERT INTO tb_sensitive (id, f1, f2) VALUES (9001, HEX(AES_ENCRYPT('to-delete', @crypt_key)), 100);
    DELETE FROM tb_sensitive WHERE id = 9001;
    IF (SELECT COUNT(*) FROM tb_sensitive_c WHERE id = 9001) = 0 THEN
      SELECT CONCAT('[PASS] ', v_stage, ': SUPPORTED（基表已删）') AS result;
    ELSE
      SELECT CONCAT('[FAIL] ', v_stage, ': 残留数据') AS result;
    END IF;
  ROLLBACK;

  -- V6 RETURNING（MySQL 无 RETURNING；记录结论性输出）
  SET v_stage = 'V6 UPDATE RETURNING';
  SELECT CONCAT('[INFO] ', v_stage, ': MySQL 无 RETURNING 语法（MariaDB 10.5+ 有 INSERT..RETURNING）；返回新值需先 UPDATE 再 SELECT') AS result;

  -- V7 SELECT ... FOR UPDATE（视图锁基表）
  SET v_stage = 'V7 SELECT FOR UPDATE';
  START TRANSACTION;
    INSERT INTO tb_sensitive (id, f1, f2) VALUES (9001, HEX(AES_ENCRYPT('locked', @crypt_key)), 100);
    SELECT id FROM tb_sensitive WHERE id = 9001 FOR UPDATE;
    SELECT CONCAT('[PASS] ', v_stage, ': SUPPORTED（可锁定视图底层基表行）') AS result;
  ROLLBACK;

  -- V8 JOIN 视图 DML（预期失败：不可更新视图）
  SET v_stage = 'V8 JOIN 视图 DML';
  PREPARE s FROM 'CREATE OR REPLACE VIEW v_ts_join AS SELECT c.id, c.f1_cipher AS f1 FROM tb_sensitive_c c JOIN tb_sensitive_p p ON c.id = p.id';
  EXECUTE s; DEALLOCATE PREPARE s;
  START TRANSACTION;
    INSERT INTO v_ts_join (id, f1) VALUES (9101, 'x');
    SELECT CONCAT('[PASS] ', v_stage, ': SUPPORTED（异常，需复核）') AS result;
  ROLLBACK;

  -- V9 聚合视图 DML（预期失败）
  SET v_stage = 'V9 聚合视图 DML';
  PREPARE s FROM 'CREATE OR REPLACE VIEW v_ts_agg AS SELECT f2, COUNT(*) c FROM tb_sensitive_c GROUP BY f2';
  EXECUTE s; DEALLOCATE PREPARE s;
  START TRANSACTION;
    INSERT INTO v_ts_agg (f2, c) VALUES (999, 1);
    SELECT CONCAT('[PASS] ', v_stage, ': SUPPORTED（异常，需复核）') AS result;
  ROLLBACK;

  -- V10 TRUNCATE 视图（预期失败）
  SET v_stage = 'V10 TRUNCATE 视图';
  START TRANSACTION;
    TRUNCATE TABLE tb_sensitive;
    SELECT CONCAT('[PASS] ', v_stage, ': SUPPORTED（异常，需复核）') AS result;
  ROLLBACK;

  -- V11 视图上建触发器（预期失败：MySQL 视图不支持触发器）
  SET v_stage = 'V11 视图上建触发器';
  START TRANSACTION;
    CREATE TRIGGER trg_bad BEFORE INSERT ON tb_sensitive FOR EACH ROW SET @x = 1;
    SELECT CONCAT('[PASS] ', v_stage, ': SUPPORTED（异常，需复核）') AS result;
  ROLLBACK;

  -- V12 直写基表旁路（第三方直连可行）
  SET v_stage = 'V12 直写基表旁路';
  START TRANSACTION;
    INSERT INTO tb_sensitive_c (id, f1_cipher, f2, f1_h) VALUES (9801, HEX(AES_ENCRYPT('bypass', @crypt_key)), 1, HEX(SHA2('bypass', 256)));
    INSERT INTO tb_sensitive_p (id, f1_plain, fn) VALUES (9801, 'bypass', 'BYPASS');
    IF (SELECT COUNT(*) FROM tb_sensitive_c WHERE id = 9801) = 1 THEN
      SELECT CONCAT('[PASS] ', v_stage, ': SUPPORTED — 直连渠道不受管控，需权限最小化') AS result;
    ELSE
      SELECT CONCAT('[FAIL] ', v_stage, ': 数据不一致') AS result;
    END IF;
  ROLLBACK;
END$$
DELIMITER ;
CALL verify_dml();
DROP PROCEDURE verify_dml;