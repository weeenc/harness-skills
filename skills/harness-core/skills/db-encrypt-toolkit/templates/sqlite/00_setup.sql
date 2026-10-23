-- 00_setup.sql  SQLite 版 —— 视图 + INSTEAD OF 触发器 初始化（应用层加解密配合）
-- 运行：sqlite3 test.db < 00_setup.sql
-- 说明：SQLite 无内置 AES/SHA；f1_cipher / f1_h 由应用层生成后传入。
--       本脚本演示阶段用占位密文（hex(randomblob(...))），仅验证「触发器拆分」链路正确性。

.bail off

-- ---------- 0. 清理 ----------
DROP TRIGGER IF EXISTS trg_ts_iof_i;
DROP TRIGGER IF EXISTS trg_ts_iof_u;
DROP TRIGGER IF EXISTS trg_ts_iof_d;
DROP VIEW   IF EXISTS tb_sensitive;
DROP TABLE  IF EXISTS tb_sensitive_c;
DROP TABLE  IF EXISTS tb_sensitive_p;
DROP TABLE  IF EXISTS tb_sensitive_bak;
DROP TABLE  IF EXISTS tb_dept;

-- ---------- 1. 拆分表 A1/A2 ----------
CREATE TABLE tb_sensitive_c (
  id        INTEGER PRIMARY KEY,
  f1_cipher TEXT NOT NULL,      -- 应用层密文（如 AES-GCM base64）；演示占位
  f2        INTEGER,
  f1_h      TEXT                -- 应用层防篡改哈希（如 HMAC-SHA256）；演示占位
);
CREATE TABLE tb_sensitive_p (
  id       INTEGER PRIMARY KEY,
  f1_plain TEXT NOT NULL,       -- 明文（索引/排序/模糊兜底；等同 A2）
  fn       TEXT                 -- 辅助列（upper(f1_plain)）
);

-- ---------- 2. 模拟原表 + 改名隐藏 + 洗数 ----------
CREATE TABLE tb_sensitive (id INTEGER PRIMARY KEY, f1 TEXT, f2 INTEGER);
INSERT INTO tb_sensitive VALUES (1, 'hello-sqlite', 100), (2, 'Alice-in-SQLite', 200),
                                (3, 'Bob', 300), (4, 'Carol', 400);
ALTER TABLE tb_sensitive RENAME TO tb_sensitive_bak;

-- 洗数：占位密文（应用真实方案用 AES 密文）；辅助列照搬可索引
INSERT INTO tb_sensitive_c (id, f1_cipher, f2, f1_h)
SELECT id, hex(randomblob(16)), f2, hex(randomblob(8)) FROM tb_sensitive_bak;
INSERT INTO tb_sensitive_p (id, f1_plain, fn)
SELECT id, f1, upper(f1) FROM tb_sensitive_bak;

-- ---------- 3. 同名视图（应用 SQL 入口；f1=密文列，读后由应用解密） ----------
CREATE VIEW tb_sensitive AS
SELECT id, f1_cipher AS f1, f2 FROM tb_sensitive_c;

-- ---------- 4. INSTEAD OF 触发器：拆分落 A1+A2 ----------
CREATE TRIGGER trg_ts_iof_i INSTEAD OF INSERT ON tb_sensitive
BEGIN
  INSERT INTO tb_sensitive_c (id, f1_cipher, f2, f1_h)
  VALUES (new.id, hex(randomblob(16)), new.f2, hex(randomblob(8)));
  INSERT INTO tb_sensitive_p (id, f1_plain, fn)
  VALUES (new.id, new.f1, upper(new.f1));
END;

CREATE TRIGGER trg_ts_iof_u INSTEAD OF UPDATE ON tb_sensitive
BEGIN
  -- 注：INSTEAD OF UPDATE 无条件按 :NEW.* 重写 A2 明文列；若业务常「只改普通列」，
  --     建议触发器按列分支（仅更新被改列）或应用自行处理，避免明文列被 :NEW.F1(密文) 覆盖。
  UPDATE tb_sensitive_c SET f1_cipher = hex(randomblob(16)), f2 = new.f2, f1_h = hex(randomblob(8))
   WHERE id = old.id;
  UPDATE tb_sensitive_p SET f1_plain = new.f1, fn = upper(new.f1) WHERE id = old.id;
END;

CREATE TRIGGER trg_ts_iof_d INSTEAD OF DELETE ON tb_sensitive
BEGIN
  DELETE FROM tb_sensitive_c WHERE id = old.id;
  DELETE FROM tb_sensitive_p WHERE id = old.id;
END;

-- ---------- 5. 索引（辅助列兜底） ----------
CREATE INDEX idx_ts_p_fn ON tb_sensitive_p (fn);
CREATE INDEX idx_ts_p_f1 ON tb_sensitive_p (f1_plain);
CREATE INDEX idx_ts_c_f2 ON tb_sensitive_c (f2);

-- ---------- 6. 关联表（02 使用） ----------
CREATE TABLE tb_dept (dept_id INTEGER PRIMARY KEY, dept_name TEXT);
INSERT INTO tb_dept VALUES (10, 'IT'), (20, 'HR');

-- ---------- 7. 自检：视图行数与明文辅助表对照 ----------
SELECT 'setup-ok' AS status, count(*) AS rows_in_view FROM tb_sensitive;
SELECT id, f1_plain, fn AS sample_plain FROM tb_sensitive_p ORDER BY id LIMIT 2;