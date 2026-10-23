-- =====================================================================
-- 00_setup.sql  「视图 + 触发器 + 定时任务加密」路线 · Oracle 实测初始化
-- 模拟 Excel 方案：原表 A 隐藏 -> 拆 A1(密文) / A2(明文+辅助列) -> 同名视图 A
-- 运行前需：EXECUTE ON sys.dbms_crypto；且当前用户可建表/视图/触发器/过程
-- 演示密钥硬编码仅用于验证；生产密评必须改 KMS/HSM + 国密 SM4
-- =====================================================================

SET SERVEROUTPUT ON

-- ---------- 0. 安全清理（可重复执行） ----------
BEGIN
  EXECUTE IMMEDIATE 'DROP VIEW TB_SENSITIVE';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE TB_SENSITIVE_C CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE TB_SENSITIVE_P CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE TB_SENSITIVE_BAK CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE TB_DEPT CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- ---------- 1. 加密辅助包（演示 AES-256-CBC；改国密只需换此处） ----------
CREATE OR REPLACE PACKAGE enc_pkg AS
  FUNCTION enc(p_plain IN VARCHAR2) RETURN VARCHAR2;  -- 输入明文，返回 hex 密文
  FUNCTION dec(p_cipher IN VARCHAR2) RETURN VARCHAR2; -- 输入 hex 密文，返回明文
  FUNCTION hsh(p_plain IN VARCHAR2) RETURN VARCHAR2;  -- 防篡改 SHA-256 hex
END enc_pkg;
/
CREATE OR REPLACE PACKAGE BODY enc_pkg AS
  c_key RAW(32) := HEXTORAW('0F0E0D0C0B0A090807060504030201001F1E1D1C1B1A19181716151413121110');
  c_iv  RAW(16) := HEXTORAW('00112233445566778899AABBCCDDEEFF');
  c_typ PLS_INTEGER := DBMS_CRYPTO.ENCRYPT_AES256
                     + DBMS_CRYPTO.CHAIN_CBC
                     + DBMS_CRYPTO.PAD_PKCS7;
  FUNCTION enc(p_plain IN VARCHAR2) RETURN VARCHAR2 IS
    v_enc RAW(4000);
  BEGIN
    v_enc := DBMS_CRYPTO.ENCRYPT(
               UTL_I18N.STRING_TO_RAW(p_plain, 'AL32UTF8'),
               c_typ, c_key, c_iv);
    RETURN RAWTOHEX(v_enc);
  END enc;
  FUNCTION dec(p_cipher IN VARCHAR2) RETURN VARCHAR2 IS
    v_raw RAW(4000);
  BEGIN
    v_raw := DBMS_CRYPTO.DECRYPT(HEXTORAW(p_cipher), c_typ, c_key, c_iv);
    RETURN UTL_I18N.RAW_TO_CHAR(v_raw, 'AL32UTF8');
  END dec;
  FUNCTION hsh(p_plain IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN RAWTOHEX(DBMS_CRYPTO.HASH(
             UTL_I18N.STRING_TO_RAW(p_plain, 'AL32UTF8'),
             DBMS_CRYPTO.HASH_SH256));
  END hsh;
END enc_pkg;
/

-- ---------- 2. 模拟原表 A（业务表，含敏感列 F1） ----------
CREATE TABLE TB_SENSITIVE (ID NUMBER PRIMARY KEY, F1 VARCHAR2(200), F2 NUMBER);
INSERT INTO TB_SENSITIVE VALUES (1, 'oracle-view-test', 100);
INSERT INTO TB_SENSITIVE VALUES (2, 'Alice-in-Oracle', 200);
INSERT INTO TB_SENSITIVE VALUES (3, 'Bob-smith', 300);
INSERT INTO TB_SENSITIVE VALUES (4, 'carol', 400);
COMMIT;

-- ---------- 3. 模拟「原表隐藏」：业务表改名，腾出同名给视图 ----------
ALTER TABLE TB_SENSITIVE RENAME TO TB_SENSITIVE_BAK;

-- ---------- 4. 拆分结构（对应 Excel：A1 密文表 / A2 明文+辅助列表） ----------
CREATE TABLE TB_SENSITIVE_C (          -- A1：密文 + 防篡改哈希
  ID         NUMBER PRIMARY KEY,
  F1_CIPHER  VARCHAR2(4000),           -- 密文（hex），由定时任务/触发器加密
  F2         NUMBER,
  F1_H       VARCHAR2(64)              -- 防篡改字段 = SHA256(F1)
);
CREATE TABLE TB_SENSITIVE_P (          -- A2：明文 + 模糊查询辅助列
  ID         NUMBER PRIMARY KEY,
  F1_PLAIN   VARCHAR2(200),            -- 明文（库内有明文，Excel 已注明）
  FN         VARCHAR2(200)             -- 辅助列：如 UPPER(F1)，给模糊/大小写查询走索引
);

-- 历史数据洗数：A1 加密入库、A2 明文 + FN 辅助列入库
INSERT INTO TB_SENSITIVE_C (ID, F1_CIPHER, F2, F1_H)
SELECT ID, enc_pkg.enc(F1), F2, enc_pkg.hsh(F1) FROM TB_SENSITIVE_BAK;
INSERT INTO TB_SENSITIVE_P (ID, F1_PLAIN, FN)
SELECT ID, F1, UPPER(F1) FROM TB_SENSITIVE_BAK;
COMMIT;

-- ---------- 5. 同名视图 A（应用看到的依旧是 TB_SENSITIVE） ----------
-- 注意：F1 是「解密列」，WHERE F1 = ... 无法下推索引（后面 02/03 会实测）
CREATE OR REPLACE VIEW TB_SENSITIVE (ID, F1, F2) AS
SELECT c.ID, enc_pkg.dec(c.F1_CIPHER), c.F2
FROM TB_SENSITIVE_C c;

-- ---------- 6. INSTEAD OF 触发器：承载视图上 DML，拆分落 A1+A2 ----------
CREATE OR REPLACE TRIGGER TRG_TS_IOF
INSTEAD OF INSERT OR UPDATE OR DELETE ON TB_SENSITIVE
FOR EACH ROW
BEGIN
  IF INSERTING THEN
    INSERT INTO TB_SENSITIVE_C (ID, F1_CIPHER, F2, F1_H)
    VALUES (:NEW.ID, enc_pkg.enc(:NEW.F1), :NEW.F2, enc_pkg.hsh(:NEW.F1));
    INSERT INTO TB_SENSITIVE_P (ID, F1_PLAIN, FN)
    VALUES (:NEW.ID, :NEW.F1, UPPER(:NEW.F1));
  ELSIF UPDATING THEN
    UPDATE TB_SENSITIVE_C
       SET F1_CIPHER = enc_pkg.enc(:NEW.F1), F2 = :NEW.F2, F1_H = enc_pkg.hsh(:NEW.F1)
     WHERE ID = :OLD.ID;
    UPDATE TB_SENSITIVE_P
       SET F1_PLAIN = :NEW.F1, FN = UPPER(:NEW.F1)
     WHERE ID = :OLD.ID;
  ELSIF DELETING THEN
    DELETE FROM TB_SENSITIVE_C WHERE ID = :OLD.ID;
    DELETE FROM TB_SENSITIVE_P WHERE ID = :OLD.ID;
  END IF;
END;
/

-- ---------- 7. 索引（辅助列兜底模糊/大小写/排序；解密列 F1 无法建索引） ----------
CREATE INDEX IDX_TS_P_FN ON TB_SENSITIVE_P (FN);
CREATE INDEX IDX_TS_P_F1 ON TB_SENSITIVE_P (F1_PLAIN);
CREATE INDEX IDX_TS_C_F2 ON TB_SENSITIVE_C (F2);

-- ---------- 8. 关联查询用到的关联表（02_verify_query.sql 使用） ----------
CREATE TABLE TB_DEPT (DEPT_ID NUMBER PRIMARY KEY, DEPT_NAME VARCHAR2(100));
INSERT INTO TB_DEPT VALUES (10, 'IT');
INSERT INTO TB_DEPT VALUES (20, 'HR');
COMMIT;

-- ---------- 9. 自检：视图读出的 F1 应为明文（解密列） ----------
SELECT 'setup-ok' AS status, COUNT(*) AS rows_via_view FROM TB_SENSITIVE;