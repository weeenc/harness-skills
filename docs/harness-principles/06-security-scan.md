# 安全扫描门禁 — `scripts/security-scan.sh`

## 一、用途

两个维度：**① 依赖漏洞扫描**（`{{SECURITY_CMD}}`，如 npm audit / mvn dependency-check /
pip-audit）+ **② 内置硬编码凭据扫描**（不依赖任何工具，纯 grep 兜底）。
主要面向 AI 高频失误场景：**往代码里塞 password/secret/api_key 字面量**。

## 二、调用方式

```bash
bash .harness/scripts/security-scan.sh [change-id]   # 单参脚本，第二参即 change-id
# 等价总入口： harness-gate.sh security-scan <change-id>
```

## 三、运行原理

**维度 1：依赖漏洞扫描**（`{{SECURITY_CMD}}`）——三分支：

1. 命令已配置且可用 → 真跑：失败 `[FAIL] 依赖漏洞扫描发现风险`（`failed=1`）；通过 `[OK] 依赖漏洞扫描通过`；
2. 命令已配置但底层依赖没就绪（`bootstrap-tools.sh check sec` rc≠0）→ `[DEGRADED] …降级人工核对；缺失项与合入指引：…check sec`（`degraded=1`）；
3. 未配置/不可用 → `[DEGRADED] 依赖漏洞扫描未配置或不可用…降级人工核对（依赖版本一致、禁快照版本）`（`degraded=1`）。

**维度 2：硬编码凭据扫描**（内置，无需工具）——

- 范围：`git ls-files` 过滤源码扩展名（java/go/py/rs/php/js/ts/jsx/tsx/vue/properties/yml/yaml）；
  **逐文件传参 + 空列表短路**（`[ -n "$SEC_FILES" ]`）——防止空仓库/非 git 目录时 while 循环
  读空 stdin 挂起（这是本脚本的已知易踩坑，已显式防住）。
- 正则：`password|secret|api[-_]?key 后跟 = "非$"`（引号后排除 `$`，即排除模板串），再过滤
  掉 `${…}`、getenv、os.environ、System.getenv 与 example/mock 占位。
- 命中 → 打印前 20 处 + `[FAIL] 发现疑似硬编码凭据`（`failed=1`）；
  无命中 `[OK] 未发现硬编码凭据`；无文件可扫 `[OK] 无待扫描文件（git 未跟踪源码或仓库为空）`。

## 四、如何出结果

- 退出码合成：`failed` → rc=1；否则 `degraded` → rc=2；否则 rc=0。
- 结论三段式：`[DEGRADED] security-scan 存在降级维度，需人工核对` → exit 2；
  `[FAIL] security-scan 未通过` → exit 1；`[PASS] security-scan 通过` → exit 0。
- 带 change-id → `report.sh security-scan <id> "rc=$rc"` → `gate-security-scan.md`。

## 五、结果不满足时如何报错

| 情形 | 表现 | 处理 |
|---|---|---|
| 凭据硬编码 | `[FAIL] 疑似硬编码凭据`（含文件:行号，前 20 处）+ rc=1 | 改用环境变量/密钥管理，删除字面量 |
| 依赖漏洞 | `[FAIL] 依赖漏洞扫描发现风险（CMD）` + rc=1 | 按漏洞报告升级/修复依赖 |
| 扫描工具缺失 | `[DEGRADED] 两维度任一降级` + rc=2 | 人工核对（依赖版本一致、禁快照版本）；装依赖后可复跑 |
| 无 git 仓库/无源码 | `[OK] 无待扫描文件`，漏洞维度按配置决定 | 安全维度弱化是可接受形态（空仓库没得扫，不算红灯） |

> 关键差异：安全扫描的"降级"（rc=2）永远不该悄悄放行——凭据/漏洞是红线，DEGRADED 的
> 正确读法是"工具没全，但人必须核对过这两点才能过"。

## 六、与其他文件的关系

- 前置依赖：`bootstrap-tools.sh check sec`
- 调用方：`stop.sh`（每轮回复出口）、`gemini/session-end.sh`（会话出口）、CI/unit-test-ci 门禁
- 入口转发：`harness-gate.sh security-scan`
- 证据：`report.sh` → `gate-security-scan.md`