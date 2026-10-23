-- 01_verify_dml.sql  PostgreSQL 版 —— DML/DDL 支持性验证
-- 运行：psql -U <user> -d <db> -f 01_verify_dml.sql
-- 每个验证点输出 [PASS] 或 [FAIL]+SQLSTATE/SQLERRM，如实回填判定表
-- 前提：已执行 00_setup.sql；本脚本自带数据清理，可重复运行

-- 通用验证宏：以 DO 匿名块 + EXCEPTION 捕获实现
\set ON_ERROR_STOP off

-- V1 INSERT（带列名）
DO $$
BEGIN
  BEGIN
    INSERT INTO tb_sensitive (id, f1, f2) VALUES (9001, 'hello-from-app', 100);
    RAISE NOTICE '[PASS] V1 INSERT 带列名: SUPPORTED';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '[FAIL] V1 INSERT 带列名: % (%)', SQLERRM, SQLSTATE;
  END;
  ROLLBACK;
END $$;

-- V2 INSERT 不带列名（按视图列序 id,f1,f2）
DO $$
BEGIN
  BEGIN
    INSERT INTO tb_sensitive VALUES (9002, 'no-cols', 200);
    RAISE NOTICE '[PASS] V2 INSERT 不带列名: SUPPORTED';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '[FAIL] V2 INSERT 不带列名: % (%)', SQLERRM, SQLSTATE;
  END;
  ROLLBACK;
END $$;

-- V3 SELECT 解密读取
DO $$
DECLARE v_f1 text;
BEGIN
  INSERT INTO tb_sensitive (id, f1, f2) VALUES (9001, 'hello-from-app', 100);
  SELECT f1 INTO v_f1 FROM tb_sensitive WHERE id = 9001;
  RAISE NOTICE '[PASS] V3 SELECT 解密读: 读到 ''%'' (应=hello-from-app)', v_f1;
  ROLLBACK;
END $$;

-- V4 UPDATE（含防篡改哈希更新）
DO $$
BEGIN
  INSERT INTO tb_sensitive (id, f1, f2) VALUES (9001, 'initial', 100);
  UPDATE tb_sensitive SET f1 = 'updated-value', f2 = 999 WHERE id = 9001;
  IF (SELECT f1 FROM tb_sensitive WHERE id = 9001) = 'updated-value'
     AND (SELECT f1_h FROM tb_sensitive_c WHERE id = 9001) = enc_pkg_hsh('updated-value') THEN
    RAISE NOTICE '[PASS] V4 UPDATE: SUPPORTED 且哈希已更新';
  ELSE
    RAISE NOTICE '[FAIL] V4 UPDATE: 值或哈希不一致';
  END IF;
  ROLLBACK;
END $$;

-- V5 DELETE
DO $$
BEGIN
  INSERT INTO tb_sensitive (id, f1, f2) VALUES (9001, 'to-delete', 100);
  DELETE FROM tb_sensitive WHERE id = 9001;
  IF NOT EXISTS (SELECT 1 FROM tb_sensitive WHERE id = 9001)
     AND NOT EXISTS (SELECT 1 FROM tb_sensitive_c WHERE id = 9001)
     AND NOT EXISTS (SELECT 1 FROM tb_sensitive_p WHERE id = 9001) THEN
    RAISE NOTICE '[PASS] V5 DELETE: SUPPORTED（三段数据均已删除）';
  ELSE
    RAISE NOTICE '[FAIL] V5 DELETE: 残留数据';
  END IF;
END $$;

-- V6 UPDATE ... RETURNING（视图+INSTEAD OF 下行为实测）
DO $$
DECLARE v_ret text;
BEGIN
  BEGIN
    INSERT INTO tb_sensitive (id, f1, f2) VALUES (9001, 'before', 100);
    UPDATE tb_sensitive SET f1 = 'after-returning'
     WHERE id = 9001 RETURNING f1 INTO v_ret;
    RAISE NOTICE '[PASS] V6 UPDATE...RETURNING: SUPPORTED, 返回=%', v_ret;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '[FAIL] V6 UPDATE...RETURNING: % (%)', SQLERRM, SQLSTATE;
  END;
  ROLLBACK;
END $$;

-- V7 SELECT ... FOR UPDATE（视图锁基表行为实测）
DO $$
DECLARE v_id int;
BEGIN
  BEGIN
    INSERT INTO tb_sensitive (id, f1, f2) VALUES (9001, 'locked', 100);
    SELECT id INTO v_id FROM tb_sensitive WHERE id = 9001 FOR UPDATE;
    RAISE NOTICE '[PASS] V7 SELECT...FOR UPDATE: SUPPORTED';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '[FAIL] V7 SELECT...FOR UPDATE: % (%)', SQLERRM, SQLSTATE;
  END;
  ROLLBACK;
END $$;

-- V8 MERGE（PG=INSERT ... ON CONFLICT）：视图上预期不支持（ON CONFLICT 仅限表）
DO $$
BEGIN
  BEGIN
    INSERT INTO tb_sensitive (id, f1, f2) VALUES (9001, 'm1', 100)
    ON CONFLICT (id) DO UPDATE SET f1 = EXCLUDED.f1;
    RAISE NOTICE '[PASS] V8 ON CONFLICT 于视图: SUPPORTED（异常，需复核此结论）';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '[FAIL] V8 ON CONFLICT 于视图: % (%) — 符合预期（需转协议代理或直写基表）', SQLERRM, SQLSTATE;
  END;
  ROLLBACK;
END $$;

-- V9 TRUNCATE 视图（预期失败）
DO $$
BEGIN
  BEGIN
    EXECUTE 'TRUNCATE TABLE tb_sensitive';
    RAISE NOTICE '[PASS] V9 TRUNCATE 视图: SUPPORTED（异常，需复核）';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '[FAIL] V9 TRUNCATE 视图: % (%) — 符合预期（TRUNCATE 需落到基表，见 README 替代方案）', SQLERRM, SQLSTATE;
  END;
END $$;

-- V10 直写基表旁路（第三方直连场景：应用绕过视图直写 A1/A2 可行）
DO $$
BEGIN
  INSERT INTO tb_sensitive_c (id, f1_cipher, f2, f1_h)
  VALUES (9801, enc_pkg_enc('bypass'), 1, enc_pkg_hsh('bypass'));
  INSERT INTO tb_sensitive_p (id, f1_plain, fn) VALUES (9801, 'bypass', 'BYPASS');
  IF EXISTS (SELECT 1 FROM tb_sensitive WHERE id = 9801 AND f1 = 'bypass') THEN
    RAISE NOTICE '[PASS] V10 直写基表旁路: SUPPORTED — 注意此渠道不受触发器管控，需权限最小化';
  ELSE
    RAISE NOTICE '[FAIL] V10 直写基表旁路: 数据不一致';
  END IF;
  ROLLBACK;
END $$;

-- V11 视图上建普通 BEFORE/AFTER 触发器（预期失败：视图仅 INSTEAD OF）
DO $$
BEGIN
  BEGIN
    CREATE TRIGGER trg_bad BEFORE INSERT ON tb_sensitive
    FOR EACH ROW EXECUTE FUNCTION trg_ts_iof_fn();
    RAISE NOTICE '[PASS] V11 视图普通触发器: SUPPORTED（异常）';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '[FAIL] V11 视图普通触发器: % (%) — 符合预期（视图只能 INSTEAD OF）', SQLERRM, SQLSTATE;
  END;
END $$;

-- V12 清理演示数据
DELETE FROM tb_sensitive WHERE id BETWEEN 9001 AND 9999;
COMMIT;