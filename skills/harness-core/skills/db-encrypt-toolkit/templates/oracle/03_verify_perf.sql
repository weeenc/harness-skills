-- =====================================================================
-- 03_verify_perf.sql  性能对比骨架（写入 / 查询 / 过滤 / 批量更新）
-- 前置：先执行 00_setup.sql。可重复执行，开头自造 5000 行、结尾清理。
-- 说明：此处为可控小规模对比，用于建立「口径」；生产结论必须按真实数据量压测。
-- =====================================================================

SET SERVEROUTPUT ON

-- ---------- 造 5000 行数据（ID 5001..10000） ----------
DECLARE
  v_i NUMBER;
  v_t NUMBER;
BEGIN
  v_t := DBMS_UTILITY.GET_CPU_TIME;
  DELETE FROM TB_SENSITIVE_C WHERE ID > 1000;
  DELETE FROM TB_SENSITIVE_P WHERE ID > 1000;
  FOR v_i IN 5001..10000 LOOP
    INSERT INTO TB_SENSITIVE_C (ID, F1_CIPHER, F2, F1_H)
    VALUES (v_i, enc_pkg.enc('perf' || v_i), v_i, enc_pkg.hsh('perf' || v_i));
    INSERT INTO TB_SENSITIVE_P (ID, F1_PLAIN, FN)
    VALUES (v_i, 'perf' || v_i, 'PERF' || v_i);
  END LOOP;
  COMMIT;
  DBMS_STATS.GATHER_TABLE_STATS(USER, 'TB_SENSITIVE_C');
  DBMS_STATS.GATHER_TABLE_STATS(USER, 'TB_SENSITIVE_P');
  DBMS_OUTPUT.PUT_LINE('[DATA] 造数完成, 耗时=' || (DBMS_UTILITY.GET_CPU_TIME - v_t) / 100 || ' s, 行数=5000');
END;
/

-- ---------- P1. 写入对比：直写基表 vs 经视图（INSTEAD OF 触发器） ----------
DECLARE
  v_t0a    NUMBER;   -- 基线计时起点
  v_t_base NUMBER;   -- 直写基表结束时刻
  v_t0     NUMBER;   -- 视图写入计时起点
  v_t_view NUMBER;   -- 视图写入结束时刻
  v_i      NUMBER;
  v_n      CONSTANT NUMBER := 500;   -- 每个场景写入行数
BEGIN
  -- 基线：直写 A1+A2（应用直连底层，无触发器）
  v_t0a := DBMS_UTILITY.GET_CPU_TIME;
  FOR v_i IN 11001..11000 + v_n LOOP
    INSERT INTO TB_SENSITIVE_C (ID, F1_CIPHER, F2, F1_H)
    VALUES (v_i, enc_pkg.enc('p1-' || v_i), v_i, enc_pkg.hsh('p1-' || v_i));
    INSERT INTO TB_SENSITIVE_P (ID, F1_PLAIN, FN)
    VALUES (v_i, 'p1-' || v_i, 'P1-' || v_i);
  END LOOP;
  v_t_base := DBMS_UTILITY.GET_CPU_TIME;

  -- 被测：经同名视图（每行触发 INSTEAD OF + 2 次加密 + 2 次 INSERT）
  v_t0 := DBMS_UTILITY.GET_CPU_TIME;
  FOR v_i IN 12001..12000 + v_n LOOP
    INSERT INTO TB_SENSITIVE (ID, F1, F2) VALUES (v_i, 'p1-' || v_i, v_i);
  END LOOP;
  v_t_view := DBMS_UTILITY.GET_CPU_TIME;

  DBMS_OUTPUT.PUT_LINE('[PERF] P1 写入 ' || v_n || ' 行: 直写基表=' ||
    (v_t_base - v_t0a) / 100 || ' s, 经视图=' || (v_t_view - v_t0) / 100 || ' s (慢 ' ||
    ROUND( (v_t_view - v_t0) / GREATEST(v_t_base - v_t0a, 1), 1) || 'x)');
  ROLLBACK;
END;
/

-- ---------- P2. 查询对比：解密读 vs 明文直读（全表 5000 行） ----------
DECLARE
  v_t0 NUMBER;
  v_t1 NUMBER;
  v_x  VARCHAR2(200);
BEGIN
  v_t0 := DBMS_UTILITY.GET_CPU_TIME;
  FOR r IN (SELECT F1 FROM TB_SENSITIVE WHERE ID BETWEEN 5001 AND 10000) LOOP
    v_x := r.F1;
  END LOOP;
  v_t1 := DBMS_UTILITY.GET_CPU_TIME;
  DBMS_OUTPUT.PUT_LINE('[PERF] P2a 视图解密读 5000 行: ' || (v_t1 - v_t0) / 100 || ' s');

  v_t0 := DBMS_UTILITY.GET_CPU_TIME;
  FOR r IN (SELECT F1_PLAIN FROM TB_SENSITIVE_P WHERE ID BETWEEN 5001 AND 10000) LOOP
    v_x := r.F1_PLAIN;
  END LOOP;
  v_t1 := DBMS_UTILITY.GET_CPU_TIME;
  DBMS_OUTPUT.PUT_LINE('[PERF] P2b 明文直读 5000 行: ' || (v_t1 - v_t0) / 100 || ' s');
END;
/

-- ---------- P3. 过滤对比：解密列全扫 vs 辅助列索引 ----------
-- 注意：FN 在 A2 明文表 TB_SENSITIVE_P（视图 TB_SENSITIVE 无 FN，从视图查会 ORA-00904）；
--       P3a/P3b 命中行数必须对等（各 1 行），耗时差才可归因于扫描方式。
DECLARE
  v_t0 NUMBER;
  v_t1 NUMBER;
  v_c  NUMBER;
BEGIN
  v_t0 := DBMS_UTILITY.GET_CPU_TIME;
  SELECT COUNT(*) INTO v_c FROM TB_SENSITIVE WHERE F1 = 'perf5001';
  v_t1 := DBMS_UTILITY.GET_CPU_TIME;
  DBMS_OUTPUT.PUT_LINE('[PERF] P3a 解密列过滤(全扫) 命中=' || v_c || ', 耗时=' || (v_t1 - v_t0) / 100 || ' s');

  v_t0 := DBMS_UTILITY.GET_CPU_TIME;
  SELECT COUNT(*) INTO v_c FROM TB_SENSITIVE_P WHERE FN = 'PERF5001';
  v_t1 := DBMS_UTILITY.GET_CPU_TIME;
  DBMS_OUTPUT.PUT_LINE('[PERF] P3b 辅助列过滤(索引) 命中=' || v_c || ', 耗时=' || (v_t1 - v_t0) / 100 || ' s');
END;
/

-- ---------- P4. 批量 UPDATE：经视图 vs 直写基表 ----------
DECLARE
  v_t0 NUMBER;
  v_t1 NUMBER;
  v_i  NUMBER;
  v_n  CONSTANT NUMBER := 500;
BEGIN
  v_t0 := DBMS_UTILITY.GET_CPU_TIME;
  FOR v_i IN 5001..5000 + v_n LOOP
    UPDATE TB_SENSITIVE SET F1 = 'upd-v' || v_i WHERE ID = v_i;
  END LOOP;
  v_t1 := DBMS_UTILITY.GET_CPU_TIME;
  DBMS_OUTPUT.PUT_LINE('[PERF] P4a 经视图逐行 UPDATE ' || v_n || ' 行: ' || (v_t1 - v_t0) / 100 || ' s');
  ROLLBACK;  -- 回滚 P4a，P4b 从原始数据起测（否则在脏数据上计时）

  v_t0 := DBMS_UTILITY.GET_CPU_TIME;
  FOR v_i IN 5001..5000 + v_n LOOP
    UPDATE TB_SENSITIVE_C SET F1_CIPHER = enc_pkg.enc('upd-d' || v_i), F1_H = enc_pkg.hsh('upd-d' || v_i) WHERE ID = v_i;
    UPDATE TB_SENSITIVE_P SET F1_PLAIN = 'upd-d' || v_i, FN = UPPER('upd-d' || v_i) WHERE ID = v_i;
  END LOOP;
  v_t1 := DBMS_UTILITY.GET_CPU_TIME;
  DBMS_OUTPUT.PUT_LINE('[PERF] P4b 直写基表逐行 UPDATE ' || v_n || ' 行: ' || (v_t1 - v_t0) / 100 || ' s');
  ROLLBACK;
END;
/

-- ---------- 收尾：清理造数 ----------
BEGIN
  DELETE FROM TB_SENSITIVE_C WHERE ID > 1000;
  DELETE FROM TB_SENSITIVE_P WHERE ID > 1000;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('[DONE] 03_verify_perf.sql 完成，大数据已清理');
END;
/