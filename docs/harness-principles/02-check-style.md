# 代码风格门禁 — `scripts/check-style.sh`

## 一、用途

两种模式扮演两个角色：

| 模式 | 触发时机 | 角色 |
|---|---|---|
| `check-style.sh <file>`（单文件增量） | 每次写文件后（PostToolUse/AfterTool） | **快检**：行数、尾随空白、TODO/FIXME、硬编码凭据，秒级出红灯 |
| `check-style.sh all [id]`（全量深度） | Stop/会话结束/技能出口/CI | **深度**：跑 `{{LINT_CMD}}`（checkstyle 等）+ 全量行数扫描 + 证据落盘 |

## 二、调用方式

```bash
bash .harness/scripts/check-style.sh <file>            # 单文件增量（hooks 用）
bash .harness/scripts/check-style.sh all <change-id>   # 全量深度（Stop/CI 用）
# 等价总入口： harness-gate.sh check-style <file|all> [change-id]
```

渲染时按语言注入：`LINT_CMD`（如 mvn checkstyle:check）、`LINT_TOOL`（如 checkstyle）、
`FILE_LIMIT`（默认 800 行）。

## 三、运行原理

**单文件增量（`check_file()`）**——任何语言通用，按序检查，任一失败立即 rc=1：

1. 文件存在？不存在 → `[FAIL] 文件不存在`
2. 行数 ≤ `FILE_LIMIT`？超了 → `[FAIL] 单文件行数超限: X 共 N 行（上限 800）`
3. 尾随空白 → `[FAIL] 尾随空白:` + 命中位置（前 5 处，输出不丢弃）
4. 行首 TODO/FIXME/XXX/HACK → `[FAIL] 未清理的 TODO/FIXME:`（简单启发式）
5. 硬编码凭据 `password/secret/api_key = "..."` → `[FAIL] 疑似硬编码凭据`（排除 `${…}`、getenv、
   os.environ、System.getenv 等环境变量引用）

通过则 `[OK] xxx 通过增量检查（N 行）`。随后若 `LINT_CMD` 可用，补跑一次全量 lint——
**失败只 `[WARN]` 不阻断**（可能是存量问题，深度清零交给出口门禁）。

**全量深度（`check_all()`）**——三段，任一失败累计 `failed=1`：

1. **深度 lint**（LINT_CMD）：
   - `LINT_CMD` 未配置/命令不可用 → `[DEGRADED]`（rc=2 路径，降级人工核对）；
   - 底层依赖未就绪（`bootstrap-tools.sh check lint` rc≠0）→ `[DEGRADED]` + 一键复检指引，
     避免"缺 checkstyle 插件导致的 BUILD FAILURE 被误判为风格违规"；
   - 真跑 `eval "$LINT_CMD"` 失败 → `[FAIL] …检测到违规`。
2. **全量行数上限扫描**：`git ls-files`（排除 `.harness/` 与 vendor/node_modules/target/dist/build/.venv）逐文件超限 → `[FAIL]`。
3. 汇总：`failed` → rc=1；否则 `degraded` → rc=2；否则 `[PASS] check-style 全量通过` → rc=0。

## 四、如何出结果

- stdout 统一 `[OK]/[FAIL]/[DEGRADED]/[WARN]` 标记 + 命中位置（行号），hooks 层按
  `\b(FAIL|DEGRADED)\b` 判红灯。
- 退出码 0/1/2/3（见 00-overview 约定）。
- 全量模式带 change-id → 末尾自动 `report.sh check-style <id> "rc=$rc"` 落盘证据。

## 五、结果不满足时如何报错（三层呈现）

| 层 | 表现 |
|---|---|
| **脚本层** | stdout 红灯文本 + `exit 1`（或降级 `exit 2`） |
| **hooks 层** | PostToolUse/AfterTool 把红灯注入 additionalContext（AI 下一轮必看到）；Stop/SessionEnd 汇总 rc 注入出口消息 |
| **证据层** | `gate-check-style.md` 记 `rc=1 → **FAIL（红灯，禁止进入下一阶段）**` |

增量模式的"只提示不阻断"是有意设计：写文件就该流畅，红灯靠上下文驱动 AI 自己修；
真正的**强制闸门在出口/CI**（Stop hook 与 unit-test-ci 门禁全量时 rc≠0 即不过）。

## 六、与其他文件的关系

- 前置依赖：`bootstrap-tools.sh check lint`（防 BUILD FAILURE 误判）
- 调用方：`post-tool-use.sh` / `gemini/after-tool.sh`（增量）、`stop.sh` / `gemini/session-end.sh`
  / CI（全量）、Cline/OpenCode 插件的 afterTool（增量）
- 入口转发：`harness-gate.sh check-style`
- 证据：`report.sh` → `gate-check-style.md`