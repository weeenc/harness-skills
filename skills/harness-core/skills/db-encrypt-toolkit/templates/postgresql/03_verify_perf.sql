-- 03_verify_perf.sql  PostgreSQL 版 —— 性能对比（写入/查询/过滤/批量）
-- 运行：psql -U <user> -d <db> -f 03_verify_perf.sql
-- 注：clock_timestamp() 毫秒计时；结果仅供参考，生产以真实压测为准

\set ON_ERROR_STOP off
\timing off

-- P1 写入对比：直写基表(A1+A2 两条 INSERT，等价触发器工作量，无触发器开销) vs 经视图(INSTEAD OF + 加密)
DO $$
DECLARE
  v_n int := 1000;
  v_t0 timestamp; v_t1 timestamp; v_base interval; v_view interval;
BEGIN
  -- 基线：直写
  v_t0 := clock_timestamp();
  FOR v_i IN 11001..11000+v_n LOOP
    INSERT INTO tb_sensitive_c (id, f1_cipher, f2, f1_h)
    VALUES (v_i, enc_pkg_enc('p1-'||v_i), v_i, enc_pkg_hsh('p1-'||v_i));
    INSERT INTO tb_sensitive_p (id, f1_plain, fn)
    VALUES (v_i, 'p1-'||v_i, upper('p1-'||v_i));
  END LOOP;
  v_t1 := clock_timestamp(); v_base := v_t1 - v_t0;

  -- 被测：经视图
  v_t0 := clock_timestamp();
  FOR v_i IN 12001..12000+v_n LOOP
    INSERT INTO tb_sensitive (id, f1, f2) VALUES (v_i, 'p1-'||v_i, v_i);
  END LOOP;
  v_t1 := clock_timestamp(); v_view := v_t1 - v_t0;

  RAISE NOTICE '[PERF] P1 写入 % 行: 直写基表=% ms, 经视图=% ms (慢 %x)',
    v_n, extract(epoch from v_base)*1000, extract(epoch from v_view)*1000,
    round(extract(epoch from v_view)/nullif(extract(epoch from v_base),0),1);
  DELETE FROM tb_sensitive WHERE id BETWEEN 11000 AND 13000;
END $$;

-- P2 查询对比：解密读（逐行 pgcrypto） vs 直查明文表
DO $$
DECLARE
  v_n int := 5000; v_t0 timestamp; v_t1 timestamp; v_a interval; v_b interval; v_dummy text;
BEGIN
  -- 造数（直写最快）
  FOR v_i IN 21001..21000+v_n LOOP
    INSERT INTO tb_sensitive_c (id, f1_cipher, f2, f1_h) VALUES (v_i, enc_pkg_enc('q2-'||v_i), v_i, enc_pkg_hsh('q2-'||v_i));
    INSERT INTO tb_sensitive_p (id, f1_plain, fn) VALUES (v_i, 'q2-'||v_i, upper('q2-'||v_i));
  END LOOP;

  v_t0 := clock_timestamp();
  SELECT count(*) INTO v_dummy FROM tb_sensitive WHERE f2 BETWEEN 21001 AND 21000+v_n;
  v_t1 := clock_timestamp(); v_a := v_t1 - v_t0;

  v_t0 := clock_timestamp();
  SELECT count(*) INTO v_dummy FROM tb_sensitive_p WHERE id BETWEEN 21001 AND 21000+v_n;
  v_t1 := clock_timestamp(); v_b := v_t1 - v_t0;

  RAISE NOTICE '[PERF] P2 查询 % 行: 视图解密读=% ms, 直查明文=% ms (慢 %x)',
    v_n, extract(epoch from v_a)*1000, extract(epoch from v_b)*1000,
    round(extract(epoch from v_a)/nullif(extract(epoch from v_b),0),1);
  DELETE FROM tb_sensitive WHERE id BETWEEN 21000 AND 26000;
END $$;

-- P3 过滤对比：解密列 WHERE（全扫+逐行解密） vs 辅助列 WHERE（索引）
ANALYZE tb_sensitive_c;
ANALYZE tb_sensitive_p;
DO $$
DECLARE
  v_n int := 5000; v_t0 timestamp; v_t1 timestamp; v_a interval; v_b interval; v_dummy text;
  v_key text;
BEGIN
  FOR v_i IN 31001..31000+v_n LOOP
    INSERT INTO tb_sensitive_c (id, f1_cipher, f2, f1_h) VALUES (v_i, enc_pkg_enc('q3-'||v_i), v_i, enc_pkg_hsh('q3-'||v_i));
    INSERT INTO tb_sensitive_p (id, f1_plain, fn) VALUES (v_i, 'q3-'||v_i, upper('q3-'||v_i));
  END LOOP;
  v_key := 'q3-31001';  -- 命中 1 行，与解密列侧对等（两侧各 1 行才可比扫描方式）

  v_t0 := clock_timestamp();
  FOR v_i IN 1..200 LOOP
    PERFORM 1 FROM tb_sensitive WHERE f1 = v_key;
  END LOOP;
  v_t1 := clock_timestamp(); v_a := v_t1 - v_t0;

  v_t0 := clock_timestamp();
  FOR v_i IN 1..200 LOOP
    PERFORM 1 FROM tb_sensitive_p WHERE fn = upper(v_key);
  END LOOP;
  v_t1 := clock_timestamp(); v_b := v_t1 - v_t0;

  RAISE NOTICE '[PERF] P3 过滤 200 次: 解密列=% ms, 辅助列索引=% ms (慢 %x)',
    extract(epoch from v_a)*1000, extract(epoch from v_b)*1000,
    round(extract(epoch from v_a)/nullif(extract(epoch from v_b),0),1);
  DELETE FROM tb_sensitive WHERE id BETWEEN 31000 AND 36000;
END $$;

-- P4 批量 UPDATE 经视图（红线场景演示：批处理应直写基表）
DO $$
DECLARE v_n int := 500; v_t0 timestamp; v_t1 timestamp; v_el interval;
BEGIN
  FOR v_i IN 41001..41000+v_n LOOP
    INSERT INTO tb_sensitive_c (id, f1_cipher, f2, f1_h) VALUES (v_i, enc_pkg_enc('p4-'||v_i), v_i, enc_pkg_hsh('p4-'||v_i));
    INSERT INTO tb_sensitive_p (id, f1_plain, fn) VALUES (v_i, 'p4-'||v_i, upper('p4-'||v_i));
  END LOOP;
  v_t0 := clock_timestamp();
  FOR v_i IN 1..v_n LOOP
    UPDATE tb_sensitive SET f2 = f2 + 1 WHERE id = 41000 + v_i;
  END LOOP;
  v_t1 := clock_timestamp(); v_el := v_t1 - v_t0;
  RAISE NOTICE '[PERF] P4 批量 UPDATE % 行经视图(逐行触发): % ms — 若超阈值则确认红线:批量必须直写基表', v_n, extract(epoch from v_el)*1000;
  DELETE FROM tb_sensitive WHERE id BETWEEN 41000 AND 42000;
END $$;

-- 汇总输出
SELECT 'P1 写入直比 / P2 解密读 / P3 过滤索引 / P4 批量更新 结果已输出，请回填判定表' AS perf_note;