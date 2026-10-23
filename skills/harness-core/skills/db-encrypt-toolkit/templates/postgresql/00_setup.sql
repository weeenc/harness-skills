-- 00_setup.sql  PostgreSQL 版 —— 视图+触发器+定时任务加密 初始化
-- 运行：psql -U <user> -d <db> -v ON_ERROR_STOP=off -f 00_setup.sql
-- 权限：CREATE EXTENSION pgcrypto 需超级用户/相应权限；无则用明文占位函数（见注释）
-- 提示：演示密钥仅用于验证；生产必须 KMS/HSM + 国密 SM4 场景改 pgcrypto 为加密密钥独立管理

\set ON_ERROR_STOP off

-- ---------- 0. 清理残留 ----------
DROP VIEW  IF EXISTS tb_sensitive;
DROP TRIGGER IF EXISTS trg_ts_iof ON tb_sensitive;
DROP TABLE  IF EXISTS tb_sensitive_c CASCADE;
DROP TABLE  IF EXISTS tb_sensitive_p CASCADE;
DROP TABLE  IF EXISTS tb_sensitive_bak CASCADE;
DROP TABLE  IF EXISTS tb_dept CASCADE;
DROP FUNCTION IF EXISTS enc_pkg_enc(text);
DROP FUNCTION IF EXISTS enc_pkg_dec(text);
DROP FUNCTION IF EXISTS enc_pkg_hsh(text);

-- ---------- 1. 加密扩展与函数（AES-256-CBC + SHA-256） ----------
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION enc_pkg_enc(p_plain text) RETURNS text AS $$
DECLARE
  v_key bytea := decode('00112233445566778899AABBCCDDEEFF00112233445566778899AABBCCDDEEFF','hex');
  v_iv  bytea := decode('000102030405060708090A0B0C0D0E0F','hex');
BEGIN
  RETURN encode(encrypt_iv(convert_to(coalesce(p_plain,''),'UTF8'), v_key, v_iv, 'aes-cbc/pad:pkcs'), 'hex');
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION enc_pkg_dec(p_cipher text) RETURNS text AS $$
DECLARE
  v_key bytea := decode('00112233445566778899AABBCCDDEEFF00112233445566778899AABBCCDDEEFF','hex');
  v_iv  bytea := decode('000102030405060708090A0B0C0D0E0F','hex');
BEGIN
  RETURN convert_from(decrypt_iv(decode(coalesce(p_cipher,''),'hex'), v_key, v_iv, 'aes-cbc/pad:pkcs'),'UTF8');
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION enc_pkg_hsh(p_plain text) RETURNS text AS $$
DECLARE
  v_key bytea := decode('00112233445566778899AABBCCDDEEFF00112233445566778899AABBCCDDEEFF','hex');
BEGIN
  -- 防篡改：HMAC-SHA256（带密钥），比纯 digest 更稳
  RETURN encode(hmac(convert_to(coalesce(p_plain,''),'UTF8'), v_key, 'sha256'), 'hex');
END $$ LANGUAGE plpgsql;

-- ---------- 2. 底层拆分表 A1/A2（对应 Oracle 模板 TB_SENSITIVE_C / _P） ----------
CREATE TABLE tb_sensitive_c (
  id        int PRIMARY KEY,
  f1_cipher text NOT NULL,          -- 密文（hex）
  f2        int,
  f1_h      text                    -- 防篡改哈希
);
CREATE TABLE tb_sensitive_p (
  id        int PRIMARY KEY,
  f1_plain  text NOT NULL,          -- 明文（作普通索引/排序/模糊兜底）
  fn        text                    -- 辅助列（本例 = upper(f1_plain)）
);

-- ---------- 3. 模拟原表 + 洗数（历史数据加密，窗口内可先直写两表） ----------
CREATE TABLE tb_sensitive (id int PRIMARY KEY, f1 text, f2 int);
INSERT INTO tb_sensitive VALUES (1, 'hello-postgres', 100), (2, 'Alice-in-PG', 200),
                                (3, 'Bob', 300), (4, 'Carol', 400);
ALTER TABLE tb_sensitive RENAME TO tb_sensitive_bak;   -- 原表隐藏

INSERT INTO tb_sensitive_c (id, f1_cipher, f2, f1_h)
SELECT id, enc_pkg_enc(f1), f2, enc_pkg_hsh(f1) FROM tb_sensitive_bak;
INSERT INTO tb_sensitive_p (id, f1_plain, fn)
SELECT id, f1, upper(f1) FROM tb_sensitive_bak;
COMMIT;

-- ---------- 4. 同名视图（应用 SQL 入口；f1 = 解密列） ----------
CREATE OR REPLACE VIEW tb_sensitive AS
SELECT c.id, enc_pkg_dec(c.f1_cipher) AS f1, c.f2 FROM tb_sensitive_c c;

-- ---------- 5. INSTEAD OF 触发器：拆分落 A1+A2 ----------
CREATE OR REPLACE FUNCTION trg_ts_iof_fn() RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO tb_sensitive_c (id, f1_cipher, f2, f1_h)
    VALUES (NEW.id, enc_pkg_enc(NEW.f1), NEW.f2, enc_pkg_hsh(NEW.f1));
    INSERT INTO tb_sensitive_p (id, f1_plain, fn)
    VALUES (NEW.id, NEW.f1, upper(NEW.f1));
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE tb_sensitive_c SET f1_cipher = enc_pkg_enc(NEW.f1), f2 = NEW.f2, f1_h = enc_pkg_hsh(NEW.f1)
     WHERE id = OLD.id;
    UPDATE tb_sensitive_p SET f1_plain = NEW.f1, fn = upper(NEW.f1) WHERE id = OLD.id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    DELETE FROM tb_sensitive_c WHERE id = OLD.id;
    DELETE FROM tb_sensitive_p WHERE id = OLD.id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ts_iof
INSTEAD OF INSERT OR UPDATE OR DELETE ON tb_sensitive
FOR EACH ROW EXECUTE FUNCTION trg_ts_iof_fn();

-- ---------- 6. 索引（辅助列兜底；解密列无法索引） ----------
CREATE INDEX idx_ts_p_fn ON tb_sensitive_p (fn);
CREATE INDEX idx_ts_p_f1 ON tb_sensitive_p (f1_plain);
CREATE INDEX idx_ts_c_f2 ON tb_sensitive_c (f2);

-- ---------- 7. 关联表（02 使用） ----------
CREATE TABLE tb_dept (dept_id int PRIMARY KEY, dept_name text);
INSERT INTO tb_dept VALUES (10, 'IT'), (20, 'HR');

-- ---------- 8. 自检：视图读出应为明文 ----------
SELECT 'setup-ok' AS status, count(*) AS rows_via_view FROM tb_sensitive;

-- ---------- 9. pg_cron 定时任务示例（可选扩展，仅注释参考） ----------
-- 场景：A2.f1_plain 若残留明文需定时加密；或密文列重建（轮换密钥）
-- SELECT cron.schedule('encrypt-job', '*/5 * * * *',
--   $$ UPDATE tb_sensitive_c c SET f1_cipher = enc_pkg_enc(p.f1_plain), f1_h = enc_pkg_hsh(p.f1_plain)
--      FROM tb_sensitive_p p WHERE c.id = p.id AND c.f1_cipher IS DISTINCT FROM enc_pkg_enc(p.f1_plain) $$);