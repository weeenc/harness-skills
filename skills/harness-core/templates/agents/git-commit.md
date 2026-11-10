<!-- harness:git-commit:start -->
## Git 提交约定

- 每次提交前读取 `.harness/rules/git-branch-and-commit.md`。
- 首行采用 `<type>(<scope>): <subject>`；type 保留英文标准值，scope 可使用模块英文名，subject 使用中文描述，允许 API、类名等技术标识。示例：`fix(process): C-014 修复员工导入校验`。
- 使用 `.harness/changes/` 时，message 必须包含对应的 C-数字 或 WS-数字 变更 ID。
- 将候选 message 写入文件，执行 `python3 .harness/scripts/check-commit-message.py --message-file <文件>`，通过后再 `git commit -F <文件>`。
- 克隆后运行 `python3 .harness/scripts/install-commit-policy.py`。提交后及 CI 执行 `sh .harness/scripts/ci-commit-check.sh`；失败须修正，不绕过校验。
- merge/revert/squash 等提交也适用。跨仓操作在每个目标仓分别执行。CI 接入、历史基线和升级边界见 `.harness/scripts/commit-policy.md`。
<!-- harness:git-commit:end -->
