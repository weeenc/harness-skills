-- =====================================================================
-- 02_verify_query.sql  查询类验证（JOIN / GROUP BY / HAVING / 模糊 / 大小写 / 索引下推 / 数据字典）
-- 前置：先执行 00_setup.sql、01_verify_dml.sql（或至少 00）。可重复执行。
-- 关键结论验证：解密列 F1 上的谓词无法下推索引；辅助列 FN 可走索引。
-- =====================================================================

SET SERVEROUTPUT ON

-- ---------- 造测试数据（直写基表，2000 行，FN=UPPER(F1_PLAIN) 一一对应） ----------
DECLARE
  v_i NUMBER;
BEGIN
  DELETE FROM TB_SENSITIVE_C WHERE ID > 1000;
  DELETE FROM TB_SENSITIVE_P WHERE ID > 1000;
  FOR v_i IN 2001..4000 LOOP
    INSERT INTO TB_SENSITIVE_C (ID, F1_CIPHER, F2, F1_H)
    VALUES (v_i, enc_pkg.enc('name' || v_i), v_i,
            enc_pkg.hsh('name' || v_i));
    INSERT INTO TB_SENSITIVE_P (ID, F1_PLAIN, FN)
    VALUES (v_i, 'name' || v_i, 'NAME' || v_i);
  END LOOP;
  COMMIT;
  DBMS_STATS.GATHER_TABLE_STATS(USER, 'TB_SENSITIVE_C');
  DBMS_STATS.GATHER_TABLE_STATS(USER, 'TB_SENSITIVE_P');
  DBMS_OUTPUT.PUT_LINE('[DATA] 已插入 2000 行测试数据');
END;
/

-- ========== Q1. 基础解密读取（正确性） ==========
SELECT ID, F1, F2 FROM TB_SENSITIVE WHERE ID <= 4 ORDER BY ID;

-- ========== Q2. JOIN 关联查询（与其它表关联） ==========
SELECT s.ID, s.F1, d.DEPT_NAME
FROM TB_SENSITIVE s
LEFT JOIN TB_DEPT d ON MOD(s.ID, 20) = d.DEPT_ID
WHERE s.ID <= 1000
  AND ROWNUM <= 5;

-- ========== Q3. GROUP BY / HAVING（普通列 F2 —— 期望正常） ==========
SELECT F2, COUNT(*) AS C
FROM TB_SENSITIVE
WHERE ID <= 1000
GROUP BY F2
HAVING COUNT(*) > 0
ORDER BY F2
FETCH FIRST 5 ROWS ONLY;

-- ========== Q4. GROUP BY 敏感列（解密列 F1 —— 语法可跑、全表解密聚合） ==========
SELECT COUNT(*) AS distinct_f1
FROM (SELECT F1 FROM TB_SENSITIVE GROUP BY F1);

-- ========== Q5. 模糊查询 LIKE（解密列 vs 辅助列） ==========
-- 注意：FN 在 A2 明文表 TB_SENSITIVE_P（视图 TB_SENSITIVE 只含 ID/F1/F2，无 FN），
--       辅助列对照组必须 FROM TB_SENSITIVE_P —— 从视图查 FN 会 ORA-00904。
SELECT 'Q5a-decrypt-col' AS case_name, COUNT(*) AS c FROM TB_SENSITIVE WHERE F1 LIKE '%name200%';
SELECT 'Q5b-aux-col'     AS case_name, COUNT(*) AS c FROM TB_SENSITIVE_P WHERE FN LIKE '%NAME200%';

-- ========== Q6. 大小写匹配（解密列 vs 辅助列） ==========
SELECT 'Q6a-decrypt-col' AS case_name, COUNT(*) AS c FROM TB_SENSITIVE WHERE UPPER(F1) = 'CAROL';
SELECT 'Q6b-aux-col'     AS case_name, COUNT(*) AS c FROM TB_SENSITIVE_P WHERE FN = 'CAROL';

-- ========== Q7. 执行计划对比：解密列谓词 vs 辅助列索引（关键证据） ==========
EXPLAIN PLAN SET STATEMENT_ID = 'q7_dec' FOR
  SELECT COUNT(*) FROM TB_SENSITIVE WHERE F1 = 'name2001';
SELECT '== Q7a 计划：F1=解密列（F1 = ...）==' AS plan_tag FROM dual;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'q7_dec', 'TYPICAL'));

EXPLAIN PLAN SET STATEMENT_ID = 'q7_aux' FOR
  SELECT COUNT(*) FROM TB_SENSITIVE_P WHERE FN = 'NAME2001';
SELECT '== Q7b 计划：FN=辅助列（FN = ...）==' AS plan_tag FROM dual;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'q7_aux', 'TYPICAL'));

-- ========== Q8. rowid（视图 rowid 语义，仅提示观察） ==========
SELECT 'Q8' AS case_name, ID, ROWID FROM TB_SENSITIVE WHERE ID = 1;

-- ========== Q9. 数据字典视角（ETL/报表工具看到的是「视图」而非物理表） ==========
SELECT 'Q9' AS case_name, COLUMN_NAME, DATA_TYPE, NULLABLE
FROM USER_TAB_COLUMNS
WHERE TABLE_NAME = 'TB_SENSITIVE'
ORDER BY COLUMN_ID;

-- ========== Q10. 闪回查询 AS OF（视图上支持性，需实测） ==========
DECLARE
  v_ok  NUMBER := 0;
  v_err VARCHAR2(300);
  v_c   NUMBER;
BEGIN
  BEGIN
    SELECT COUNT(*) INTO v_c FROM TB_SENSITIVE AS OF TIMESTAMP (SYSTIMESTAMP - INTERVAL '1' MINUTE);
    v_ok := 1;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_ok = 1 THEN
    DBMS_OUTPUT.PUT_LINE('[PASS] Q10 闪回查询: SUPPORTED n=' || v_c);
  ELSE
    DBMS_OUTPUT.PUT_LINE('[FAIL] Q10 闪回查询: 受限 -> ' || v_err);
  END IF;
END;
/

-- ========== 收尾：清理造数，恢复小数据量 ==========
BEGIN
  DELETE FROM TB_SENSITIVE_C WHERE ID > 1000;
  DELETE FROM TB_SENSITIVE_P WHERE ID > 1000;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('[DONE] 02_verify_query.sql 完成，大数据已清理');
END;
/