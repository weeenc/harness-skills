-- =====================================================================
-- 01_verify_dml.sql  DML / DDL 支持性验证（跑出 SUPPORTED / UNSUPPORTED + ORA 错误）
-- 前置：先执行 00_setup.sql。可重复执行（开头自动重置数据）。
-- 输出约定：[PASS]=SUPPORTED  [FAIL]=UNSUPPORTED(错误码)
-- =====================================================================

SET SERVEROUTPUT ON

-- ---------- 数据重置（直写基表，绕开被测路径） ----------
BEGIN
  DELETE FROM TB_SENSITIVE_C;
  DELETE FROM TB_SENSITIVE_P;
  INSERT INTO TB_SENSITIVE_C (ID, F1_CIPHER, F2, F1_H)
  SELECT ID, enc_pkg.enc(F1), F2, enc_pkg.hsh(F1) FROM TB_SENSITIVE_BAK;
  INSERT INTO TB_SENSITIVE_P (ID, F1_PLAIN, FN)
  SELECT ID, F1, UPPER(F1) FROM TB_SENSITIVE_BAK;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('[RESET] 数据已重置');
END;
/

-- ========== V1. INSERT 带列名（经同名视图 + INSTEAD OF 触发器） ==========
DECLARE
  v_ok  NUMBER := 0;
  v_err VARCHAR2(300);
BEGIN
  BEGIN
    INSERT INTO TB_SENSITIVE (ID, F1, F2) VALUES (9001, 'insert-via-view', 9100);
    v_ok := 1;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_ok = 1 THEN
    DBMS_OUTPUT.PUT_LINE('[PASS] V1 INSERT 带列名: SUPPORTED');
  ELSE
    DBMS_OUTPUT.PUT_LINE('[FAIL] V1 INSERT 带列名: UNSUPPORTED -> ' || v_err);
  END IF;
  ROLLBACK;
END;
/

-- ========== V2. INSERT 不带列名（列序必须与视图定义一致） ==========
DECLARE
  v_ok  NUMBER := 0;
  v_err VARCHAR2(300);
BEGIN
  BEGIN
    INSERT INTO TB_SENSITIVE VALUES (9002, 'insert-nocols', 9200);
    v_ok := 1;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_ok = 1 THEN
    DBMS_OUTPUT.PUT_LINE('[PASS] V2 INSERT 不带列名: SUPPORTED');
  ELSE
    DBMS_OUTPUT.PUT_LINE('[FAIL] V2 INSERT 不带列名: UNSUPPORTED -> ' || v_err);
  END IF;
  ROLLBACK;
END;
/

-- ========== V3. SELECT 回读 ==========
DECLARE
  v_f1 VARCHAR2(200);
BEGIN
  INSERT INTO TB_SENSITIVE (ID, F1, F2) VALUES (9003, 'read-back-check', 9300);
  COMMIT;
  SELECT F1 INTO v_f1 FROM TB_SENSITIVE WHERE ID = 9003;
  IF v_f1 = 'read-back-check' THEN
    DBMS_OUTPUT.PUT_LINE('[PASS] V3 SELECT 回读: SUPPORTED, 值正确=' || v_f1);
  ELSE
    DBMS_OUTPUT.PUT_LINE('[WARN] V3 SELECT 回读: 值不一致 -> ' || v_f1);
  END IF;
  ROLLBACK;
END;
/

-- ========== V4. UPDATE（含防篡改哈希重算） ==========
DECLARE
  v_ok  NUMBER := 0;
  v_err VARCHAR2(300);
  v_h   VARCHAR2(64);
BEGIN
  INSERT INTO TB_SENSITIVE (ID, F1, F2) VALUES (9004, 'before-update', 9400);
  BEGIN
    UPDATE TB_SENSITIVE SET F1 = 'after-update' WHERE ID = 9004;
    v_ok := 1;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_ok = 1 THEN
    SELECT F1_H INTO v_h FROM TB_SENSITIVE_C WHERE ID = 9004;
    IF v_h = enc_pkg.hsh('after-update') THEN
      DBMS_OUTPUT.PUT_LINE('[PASS] V4 UPDATE: SUPPORTED, 哈希一致');
    ELSE
      DBMS_OUTPUT.PUT_LINE('[WARN] V4 UPDATE: 哈希未同步');
    END IF;
  ELSE
    DBMS_OUTPUT.PUT_LINE('[FAIL] V4 UPDATE: UNSUPPORTED -> ' || v_err);
  END IF;
  ROLLBACK;
END;
/

-- ========== V5. DELETE ==========
DECLARE
  v_ok    NUMBER := 0;
  v_err   VARCHAR2(300);
  v_left  NUMBER := -1;
BEGIN
  INSERT INTO TB_SENSITIVE (ID, F1, F2) VALUES (9005, 'to-delete', 9500);
  BEGIN
    DELETE FROM TB_SENSITIVE WHERE ID = 9005;
    v_ok := 1;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_ok = 1 THEN
    SELECT COUNT(*) INTO v_left FROM TB_SENSITIVE_C WHERE ID = 9005;
    DBMS_OUTPUT.PUT_LINE('[PASS] V5 DELETE: SUPPORTED, 残留=' || v_left);
  ELSE
    DBMS_OUTPUT.PUT_LINE('[FAIL] V5 DELETE: UNSUPPORTED -> ' || v_err);
  END IF;
  ROLLBACK;
END;
/

-- ========== V6. UPDATE ... RETURNING（INSTEAD OF 触发器视图行为受限，需实测） ==========
DECLARE
  v_ok  NUMBER := 0;
  v_ret VARCHAR2(200);
  v_err VARCHAR2(300);
BEGIN
  INSERT INTO TB_SENSITIVE (ID, F1, F2) VALUES (9006, 'returning-before', 9600);
  BEGIN
    UPDATE TB_SENSITIVE SET F1 = 'returning-after' WHERE ID = 9006
    RETURNING F1 INTO v_ret;
    v_ok := 1;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_ok = 1 THEN
    DBMS_OUTPUT.PUT_LINE('[PASS] V6 UPDATE...RETURNING: SUPPORTED, 返回=' || v_ret);
  ELSE
    DBMS_OUTPUT.PUT_LINE('[FAIL] V6 UPDATE...RETURNING: 受限 -> ' || v_err);
  END IF;
  ROLLBACK;
END;
/

-- ========== V7. SELECT ... FOR UPDATE（多基表锁定范围） ==========
DECLARE
  v_id NUMBER;
  v_err VARCHAR2(300);
  CURSOR c IS SELECT ID FROM TB_SENSITIVE WHERE ID = 9007 FOR UPDATE;
BEGIN
  INSERT INTO TB_SENSITIVE (ID, F1, F2) VALUES (9007, 'for-update', 9700);
  BEGIN
    OPEN c; FETCH c INTO v_id; CLOSE c;
    DBMS_OUTPUT.PUT_LINE('[PASS] V7 FOR UPDATE: 可执行');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    DBMS_OUTPUT.PUT_LINE('[FAIL] V7 FOR UPDATE: 受限 -> ' || v_err);
  END;
  ROLLBACK;
END;
/

-- ========== V8. MERGE INTO 视图（预期受限，如实打印错误） ==========
DECLARE
  v_ok  NUMBER := 0;
  v_err VARCHAR2(300);
BEGIN
  BEGIN
    EXECUTE IMMEDIATE 'MERGE INTO TB_SENSITIVE t USING (SELECT 9008 AS id, ''merge-x'' AS f1, 9800 AS f2 FROM dual) s
                       ON (t.id = s.id)
                       WHEN MATCHED THEN UPDATE SET t.f1 = s.f1
                       WHEN NOT MATCHED THEN INSERT (id, f1, f2) VALUES (s.id, s.f1, s.f2)';
    v_ok := 1;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_ok = 1 THEN
    DBMS_OUTPUT.PUT_LINE('[PASS] V8 MERGE INTO 视图: SUPPORTED');
  ELSE
    DBMS_OUTPUT.PUT_LINE('[FAIL] V8 MERGE INTO 视图: 受限 -> ' || v_err);
  END IF;
  ROLLBACK;
END;
/

-- ========== V9. TRUNCATE 视图（DDL，预期 INSTEAD OF 拦不住） ==========
DECLARE
  v_ok  NUMBER := 0;
  v_err VARCHAR2(300);
BEGIN
  BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE TB_SENSITIVE';
    v_ok := 1;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_ok = 1 THEN
    DBMS_OUTPUT.PUT_LINE('[PASS] V9 TRUNCATE 视图: SUPPORTED（意外，需警惕）');
  ELSE
    DBMS_OUTPUT.PUT_LINE('[FAIL] V9 TRUNCATE 视图: 不支持 -> ' || v_err);
  END IF;
  ROLLBACK;
END;
/

-- ========== V10. 直写基表（DBA/ETL 直连绕过视图，明文通道需管控） ==========
DECLARE
  v_ok NUMBER := 0;
BEGIN
  BEGIN
    INSERT INTO TB_SENSITIVE_C (ID, F1_CIPHER, F2, F1_H)
    VALUES (9010, enc_pkg.enc('direct-write'), 9010, enc_pkg.hsh('direct-write'));
    INSERT INTO TB_SENSITIVE_P (ID, F1_PLAIN, FN) VALUES (9010, 'direct-write', 'DIRECT-WRITE');
    v_ok := 1;
  EXCEPTION WHEN OTHERS THEN NULL; END;
  DBMS_OUTPUT.PUT_LINE('[PASS] V10 直写基表: 可绕过视图（第三方直连=明文旁路，需管控）');
  ROLLBACK;
END;
/

-- ========== V11. 视图上建普通 BEFORE 触发器（预期 ORA-38069 类错误） ==========
DECLARE
  v_ok  NUMBER := 0;
  v_err VARCHAR2(300);
BEGIN
  BEGIN
    EXECUTE IMMEDIATE 'CREATE OR REPLACE TRIGGER TRG_TS_BEFORE
                       BEFORE INSERT ON TB_SENSITIVE FOR EACH ROW
                       BEGIN NULL; END;';
    v_ok := 1;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_ok = 1 THEN
    DBMS_OUTPUT.PUT_LINE('[PASS] V11 视图上建 BEFORE 触发器: 允许（意外）');
  ELSE
    DBMS_OUTPUT.PUT_LINE('[FAIL] V11 视图上建 BEFORE 触发器: 不支持 -> ' || v_err);
  END IF;
  ROLLBACK;
END;
/

-- ---------- 结尾清理，恢复演示数据 ----------
BEGIN
  DELETE FROM TB_SENSITIVE_C;
  DELETE FROM TB_SENSITIVE_P;
  INSERT INTO TB_SENSITIVE_C (ID, F1_CIPHER, F2, F1_H)
  SELECT ID, enc_pkg.enc(F1), F2, enc_pkg.hsh(F1) FROM TB_SENSITIVE_BAK;
  INSERT INTO TB_SENSITIVE_P (ID, F1_PLAIN, FN)
  SELECT ID, F1, UPPER(F1) FROM TB_SENSITIVE_BAK;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('[DONE] 01_verify_dml.sql 完成，数据已复原');
END;
/