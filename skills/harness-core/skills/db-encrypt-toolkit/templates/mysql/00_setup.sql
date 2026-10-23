-- 00_setup.sql  MySQL/MariaDB 版 —— 加密路线初始化（可更新视图边界 + SQL 显式加密）
-- 运行：mysql -u <user> -p <db> < 00_setup.sql
-- 前提：有 CREATE/ALTER/DROP/EVENT 权限；EVENT 需 event_scheduler=ON
-- 演示密钥仅用于验证；生产用密钥管理服务，禁用硬编码
SET @crypt_key = 'demo-key-32-characters-0000';   -- 注：AES_ENCRYPT 按 block_encryption_mode 取前 16/24/32 字节
SET block_encryption_mode = 'aes-256-cbc';        -- 8.0+；MariaDB 需确认支持，否则去掉此行用默认模式
SET FOREIGN_KEY_CHECKS = 0;

DROP VIEW IF EXISTS tb_sensitive;
DROP TABLE IF EXISTS tb_sensitive_c;
DROP TABLE IF EXISTS tb_sensitive_p;
DROP TABLE IF EXISTS tb_sensitive_bak;
DROP TABLE IF EXISTS tb_dept;
DROP EVENT IF EXISTS ev_encrypt_refresh;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------- 1. 拆分表 A1/A2 ----------
CREATE TABLE tb_sensitive_c (
  id        INT PRIMARY KEY,
  f1_cipher VARCHAR(4096) NOT NULL,     -- 密文（HEX(AES_ENCRYPT(...)) 文本形式）
  f2        INT,
  f1_h      CHAR(64)                    -- 防篡改 SHA2-256
) ENGINE=InnoDB;
CREATE TABLE tb_sensitive_p (
  id       INT PRIMARY KEY,
  f1_plain VARCHAR(200) NOT NULL,       -- 明文（索引/排序/模糊兜底）
  fn       VARCHAR(200)                 -- 辅助列（upper(f1_plain)）
) ENGINE=InnoDB;

-- ---------- 2. 模拟原表 + 改名隐藏 + 洗数（历史数据加密） ----------
CREATE TABLE tb_sensitive (id INT PRIMARY KEY, f1 VARCHAR(200), f2 INT) ENGINE=InnoDB;
INSERT INTO tb_sensitive VALUES (1, 'hello-mysql', 100), (2, 'Alice-in-MySQL', 200),
                                (3, 'Bob', 300), (4, 'Carol', 400);
RENAME TABLE tb_sensitive TO tb_sensitive_bak;

-- 洗数：密文 + 防篡改哈希 + 明文辅助列（历史明文在此窗口存在，上线后按红线要求清理/保护）
INSERT INTO tb_sensitive_c (id, f1_cipher, f2, f1_h)
SELECT id, HEX(AES_ENCRYPT(f1, @crypt_key)), f2, HEX(SHA2(f1, 256)) FROM tb_sensitive_bak;
INSERT INTO tb_sensitive_p (id, f1_plain, fn)
SELECT id, f1, UPPER(f1) FROM tb_sensitive_bak;

-- ---------- 3. 同名视图（两个版本，均供 01 验证） ----------
-- 3a. 列映射式可更新视图：f1 直接就是密文（可 DML 但不透明）
CREATE VIEW tb_sensitive AS
SELECT id, f1_cipher AS f1, f2 FROM tb_sensitive_c;

-- 3b. 表达式解密视图（只读，DML 预期失败）：证明"透明写"在 MySQL 视图路线不可行
CREATE VIEW v_ts_readable AS
SELECT id, CAST(AES_DECRYPT(UNHEX(f1_cipher), @crypt_key) AS CHAR) AS f1, f2 FROM tb_sensitive_c;

-- ---------- 4. 索引（辅助列；密文/解密列无可用索引） ----------
CREATE INDEX idx_ts_p_fn ON tb_sensitive_p (fn);
CREATE INDEX idx_ts_p_f1 ON tb_sensitive_p (f1_plain);
CREATE INDEX idx_ts_c_f2 ON tb_sensitive_c (f2);

-- ---------- 5. 关联表（02 使用）；造数后做视图层自检 ----------
CREATE TABLE tb_dept (dept_id INT PRIMARY KEY, dept_name VARCHAR(100));
INSERT INTO tb_dept VALUES (10, 'IT'), (20, 'HR');

-- 自检：读视图（密文形态）与明文辅助表对照
SELECT 'setup-ok' AS status, COUNT(*) AS rows_in_view, MIN(f1) AS sample_cipher FROM tb_sensitive;
SELECT 'plain-check' AS status, id, f1_plain FROM tb_sensitive_p ORDER BY id LIMIT 2;

-- ---------- 6. EVENT 定时任务示例（需 event_scheduler=ON；仅注释参考） ----------
-- 场景：A2 明文补加密 / 密钥轮换重建密文
-- CREATE EVENT ev_encrypt_refresh
--   ON SCHEDULE EVERY 5 MINUTE
--   DO UPDATE tb_sensitive_c c
--      JOIN tb_sensitive_p p ON c.id = p.id
--         SET c.f1_cipher = HEX(AES_ENCRYPT(p.f1_plain, @crypt_key)),
--             c.f1_h      = HEX(SHA2(p.f1_plain, 256))
--      WHERE c.f1_h <> HEX(SHA2(p.f1_plain, 256));
-- SET GLOBAL event_scheduler = ON;   -- 需 SUPER 权限