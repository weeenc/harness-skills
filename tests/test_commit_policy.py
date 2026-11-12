#!/usr/bin/env python3
"""Exercise real Git hooks and CI ranges without changing project history."""
import importlib.util
from pathlib import Path
import shutil
import subprocess
import tempfile
import sys
sys.dont_write_bytecode = True
import unittest

ROOT = Path(__file__).resolve().parents[1] / "skills/harness-core/templates"
SPEC = importlib.util.spec_from_file_location("policy", ROOT / "scripts/check-commit-message.py")
POLICY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(POLICY)


class MessageTests(unittest.TestCase):
    def test_chinese_with_technical_identifiers(self):
        self.assertEqual([], POLICY.errors("fix(process): C-014 修复 API 导入校验"))

    def test_body_and_footer_ids(self):
        self.assertEqual([], POLICY.errors("docs(api): 更新 API 示例\n\nChange: WS-014"))

    def test_english_subject_rejected_even_with_chinese_scope_or_body(self):
        for message in ["fix(流程): C-014 fix import", "fix(api): fix import\n\nC-014 中文正文"]:
            with self.subTest(message=message):
                self.assertTrue(POLICY.errors(message))

    def test_invalid_format_id_and_punctuation(self):
        for message in ["", "fix: C-014 修复导入", "other(api): C-014 修复导入", "fix(api): 修复导入",
                        "fix(api): C-014 修复导入。", "fix(api): C-014 修复导入.",
                        "fixup! fix(api): C-014 修复导入", "Merge branch 'dev'", "Revert something"]:
            with self.subTest(message=message):
                self.assertTrue(POLICY.errors(message))


class GitTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="commit-policy-")
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.git("init", "-q")
        self.git("config", "user.name", "Policy Test")
        self.git("config", "user.email", "policy@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        self.git("config", "core.hooksPath", ".harness/git-hooks")
        # Legacy baseline intentionally contains English and is excluded from CI checks.
        self.git("commit", "--allow-empty", "-qm", "legacy English baseline")
        card = self.repo / ".harness/changes/C-014/change.md"
        card.parent.mkdir(parents=True)
        card.write_text("---\nid: C-014\n---\n测试卡\n", encoding="utf-8")
        self.git("add", ".harness/changes")
        self.git("commit", "-qm", "legacy card")
        self.base = self.git("rev-parse", "HEAD").stdout.strip()
        for rel in [".harness/scripts/change_registry.py", ".harness/scripts/new-change.py", ".harness/scripts/check-commit-message.py", ".harness/scripts/install-commit-policy.py",
                    ".harness/scripts/ci-commit-check.sh", ".harness/git-hooks/commit-msg"]:
            dst = self.repo / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / rel.removeprefix(".harness/"), dst)

        (self.repo / ".harness/rules").mkdir()
        shutil.copy2(ROOT.parent / "rules/git-branch-and-commit.md", self.repo / ".harness/rules/git-branch-and-commit.md")
        shutil.copy2(ROOT / "agents/git-commit.md", self.repo / ".harness/git-commit.md")
        self.run_command("python3", ".harness/scripts/install-commit-policy.py")

    def run_command(self, *args, success=True):
        result = subprocess.run(args, cwd=self.repo, text=True, capture_output=True)
        if success:
            self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        else:
            self.assertNotEqual(0, result.returncode, result.stdout + result.stderr)
        return result

    def git(self, *args, success=True):
        return self.run_command("git", *args, success=success)

    def test_hook_rejects_english_and_accepts_chinese(self):
        self.git("commit", "--allow-empty", "-qm", "fix(api): C-014 fix import", success=False)
        self.assertEqual(self.base, self.git("rev-parse", "HEAD").stdout.strip())
        self.git("commit", "--allow-empty", "-qm", "fix(api): C-014 修复导入")
        self.assertIn("1 条", self.run_command("sh", ".harness/scripts/ci-commit-check.sh").stdout)

    def test_ci_detects_bypass(self):
        self.git("-c", "core.hooksPath=/dev/null", "commit", "--allow-empty", "-qm", "fix(api): C-014 fix import")
        result = self.run_command("sh", ".harness/scripts/ci-commit-check.sh", success=False)
        self.assertIn("subject 必须包含中文", result.stderr)

    def test_legacy_excluded_and_empty_range_visible(self):
        self.assertIn("0 条", self.run_command("sh", ".harness/scripts/ci-commit-check.sh").stdout)

    def test_missing_base_and_nonancestor_fail(self):
        script = ".harness/scripts/check-commit-message.py"
        self.run_command("python3", script, "--range", "--base", "missing-ref", success=False)
        self.git("checkout", "--orphan", "unrelated")
        self.git("commit", "--allow-empty", "-qm", "chore(test): C-014 创建独立历史")
        self.run_command("python3", script, "--range", success=False)

    def test_merge_side_branch_commits_are_checked(self):
        self.git("checkout", "-b", "mainline")
        self.git("commit", "--allow-empty", "-qm", "chore(test): C-014 更新主线")
        self.git("checkout", "-b", "side", self.base)
        self.git("-c", "core.hooksPath=/dev/null", "commit", "--allow-empty", "-qm", "fix(api): C-014 English side commit")
        self.git("checkout", "mainline")
        self.git("merge", "--no-ff", "side", "-m", "chore(merge): C-014 合并测试分支")
        self.run_command("sh", ".harness/scripts/ci-commit-check.sh", success=False)

    def test_installer_preserves_other_hooks(self):
        self.git("config", "core.hooksPath", "custom-hooks")
        self.run_command("python3", ".harness/scripts/install-commit-policy.py", success=False)
        self.assertEqual("custom-hooks", self.git("config", "core.hooksPath").stdout.strip())
        self.git("config", "--unset", "core.hooksPath")
        hook = self.repo / ".git/hooks/pre-commit"
        hook.write_text("#!/bin/sh\nexit 0\n")
        hook.chmod(0o755)
        self.run_command("python3", ".harness/scripts/install-commit-policy.py", success=False)
        self.assertTrue(hook.exists())


    def test_reinstall_preserves_baseline_and_custom_agents(self):
        agents = self.repo / "AGENTS.md"
        agents.write_text("# 团队自定义约定\n\n" + agents.read_text())
        before = agents.read_bytes()
        self.git("commit", "--allow-empty", "-qm", "docs(test): C-014 更新说明")
        self.run_command("python3", ".harness/scripts/install-commit-policy.py")
        self.assertEqual(before, agents.read_bytes())
        self.assertEqual(self.base, (self.repo / ".harness/commit-policy-base").read_text().strip())
        agents.write_text(agents.read_text().replace("中文描述", "定制中文约定"))
        customized = agents.read_bytes()
        self.run_command("python3", ".harness/scripts/install-commit-policy.py", success=False)
        self.assertEqual(customized, agents.read_bytes())

    def test_empty_repository_checks_first_commit(self):
        empty = self.repo / "empty"
        empty.mkdir()
        shutil.copytree(self.repo / ".harness", empty / ".harness")
        (empty / ".harness/commit-policy-base").unlink()
        (empty / ".harness/change-card-policy-base").unlink()
        old = self.repo
        self.repo = empty
        self.git("init", "-q")
        self.git("config", "user.name", "Test")
        self.git("config", "user.email", "test@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        self.run_command("python3", ".harness/scripts/install-commit-policy.py")
        self.assertEqual("ROOT", (empty / ".harness/commit-policy-base").read_text().strip())
        self.assertIn("0 条", self.run_command("sh", ".harness/scripts/ci-commit-check.sh").stdout)
        self.git("add", ".harness/changes")
        self.git("commit", "--allow-empty", "-qm", "chore(test): C-014 初始化项目")
        self.assertIn("1 条", self.run_command("sh", ".harness/scripts/ci-commit-check.sh").stdout)
        self.repo = old

    def test_no_git_and_symlink_do_not_modify_other_locations(self):
        agents = self.repo / "AGENTS.md"
        agents.unlink()
        target = self.repo / "custom.md"
        target.write_text("保留")
        agents.symlink_to(target)
        self.run_command("python3", ".harness/scripts/install-commit-policy.py", success=False)
        self.assertEqual("保留", target.read_text())
        nogit = Path(self.temp.name) / "nested"
        shutil.copytree(self.repo / ".harness", nogit / ".harness")
        result = subprocess.run(["python3", str(nogit / ".harness/scripts/install-commit-policy.py")], capture_output=True)
        self.assertNotEqual(0, result.returncode)
        self.assertFalse((nogit / "AGENTS.md").exists())

    def test_shallow_clone_fails_even_with_root_baseline(self):
        self.git("commit", "--allow-empty", "-qm", "docs(test): C-014 更新说明")
        shallow = self.repo / "shallow"
        self.run_command("git", "clone", "--depth", "1", self.repo.as_uri(), str(shallow))
        shutil.copytree(self.repo / ".harness", shallow / ".harness", dirs_exist_ok=True)
        (shallow / ".harness/commit-policy-base").write_text("ROOT\n")
        result = subprocess.run(["sh", str(shallow / ".harness/scripts/ci-commit-check.sh")], capture_output=True, text=True)
        self.assertEqual(2, result.returncode)
        self.assertIn("浅克隆", result.stderr)

    def test_gate_stops_before_business_checks(self):
        gate = self.repo / ".harness/scripts/harness-gate.sh"
        shutil.copy2(ROOT / "scripts/harness-gate.sh", gate)
        check = self.repo / ".harness/scripts/check-style.sh"
        check.write_text("#!/bin/sh\ntouch business-check-ran\n")
        check.chmod(0o755)
        self.git("-c", "core.hooksPath=/dev/null", "commit", "--allow-empty", "-qm", "fix(api): C-014 English")
        self.run_command("bash", str(gate), "check-style", success=False)
        self.assertFalse((self.repo / "business-check-ran").exists())

    def test_change_id_optional_without_change_directory(self):
        # A separate repo with no tracked or working-tree changes directory.
        empty = self.repo / "no-cards"
        empty.mkdir()
        shutil.copytree(self.repo / ".harness", empty / ".harness")
        shutil.rmtree(empty / ".harness/changes")
        for name in ["commit-policy-base", "change-card-policy-base"]:
            (empty / ".harness" / name).unlink()
        self.repo = empty
        self.git("init", "-q")
        self.git("config", "user.name", "Test")
        self.git("config", "user.email", "test@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        self.run_command("python3", ".harness/scripts/install-commit-policy.py")
        self.git("commit", "--allow-empty", "-qm", "docs(test): 更新说明")
        self.run_command("sh", ".harness/scripts/ci-commit-check.sh")


    def test_unstaged_missing_and_mismatched_card_rejected(self):
        message = "fix(test): C-999 修复测试"
        card = self.repo / ".harness/changes/C-999/change.md"
        self.git("commit", "--allow-empty", "-qm", message, success=False)
        card.parent.mkdir()
        card.write_text("---\nid: C-999\n---\n")
        self.git("commit", "--allow-empty", "-qm", message, success=False)
        card.write_text("---\nid: C-998\n---\n")
        self.git("add", str(card))
        self.git("commit", "--allow-empty", "-qm", message, success=False)
        card.write_text("---\nid: C-999\n---\n")
        self.git("add", str(card))
        self.git("commit", "-qm", message)
        self.run_command("sh", ".harness/scripts/ci-commit-check.sh")

    def test_ci_uses_each_commit_not_current_tree(self):
        self.git("-c", "core.hooksPath=/dev/null", "commit", "--allow-empty", "-qm", "fix(test): C-999 无卡提交")
        card = self.repo / ".harness/changes/C-999/change.md"
        card.parent.mkdir()
        card.write_text("---\nid: C-999\n---\n")
        self.git("add", str(card))
        self.git("commit", "-qm", "docs(test): C-999 后补卡片")
        result = self.run_command("sh", ".harness/scripts/ci-commit-check.sh", success=False)
        self.assertIn("主变更 C-999", result.stderr)

    def test_primary_id_cannot_be_rescued_by_other_id(self):
        self.git("commit", "--allow-empty", "-qm", "fix(test): C-999 修复测试\n\n关联 C-014", success=False)
        self.git("commit", "--allow-empty", "-qm", "revert(test): C-014 回滚历史 C-999")

    def test_workspace_card_and_repeated_commits(self):
        card = self.repo / ".harness/changes/WS-001/workspace-change.md"
        card.parent.mkdir()
        card.write_text("---\nid: WS-001\n---\n")
        self.git("add", str(card))
        for _ in range(2):
            self.git("commit", "--allow-empty", "-qm", "docs(test): WS-001 更新说明")
        self.run_command("sh", ".harness/scripts/ci-commit-check.sh")

    def test_allocator_reserves_history_and_parallel_worktrees(self):
        self.git("-c", "core.hooksPath=/dev/null", "commit", "--allow-empty", "-qm", "fix(test): C-021 历史无卡")
        script = str(self.repo / ".harness/scripts/new-change.py")
        result = self.run_command("python3", script, "--prefix", "C", "--title", "新需求")
        self.assertIn("C-022/change.md", result.stdout)
        other = self.repo / "other"
        self.git("worktree", "add", "--detach", str(other))
        commands = [["python3", script, "--repo", str(root), "--prefix", "C", "--title", "并发需求"] for root in [self.repo, other]]
        processes = [subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) for cmd in commands]
        outputs = [p.communicate() for p in processes]
        self.assertEqual([0, 0], [p.returncode for p in processes], outputs)
        self.assertEqual({"C-023", "C-024"}, {Path(out.strip()).parent.name for out, _ in outputs})

    def test_card_activation_preserves_historical_format_checks(self):
        self.git("-c", "core.hooksPath=/dev/null", "commit", "--allow-empty", "-qm", "fix(test): C-021 历史无卡")
        activation = self.git("rev-parse", "HEAD").stdout.strip()
        (self.repo / ".harness/change-card-policy-base").write_text(activation + "\n")
        self.run_command("sh", ".harness/scripts/ci-commit-check.sh")
        self.git("-c", "core.hooksPath=/dev/null", "commit", "--allow-empty", "-qm", "fix(test): C-022 新提交无卡")
        self.run_command("sh", ".harness/scripts/ci-commit-check.sh", success=False)


    def test_deleting_cards_cannot_disable_id_requirement(self):
        self.git("rm", "-r", ".harness/changes")
        self.git("commit", "-qm", "docs(test): 删除卡片", success=False)
        self.git("-c", "core.hooksPath=/dev/null", "commit", "-qm", "docs(test): 删除卡片")
        result = self.run_command("sh", ".harness/scripts/ci-commit-check.sh", success=False)
        self.assertIn("必须包含变更 ID", result.stderr)

    def test_ci_tracking_requirement_ignores_working_directory(self):
        self.git("-c", "core.hooksPath=/dev/null", "commit", "--allow-empty", "-qm", "docs(test): 缺少编号")
        shutil.rmtree(self.repo / ".harness/changes")
        result = self.run_command("sh", ".harness/scripts/ci-commit-check.sh", success=False)
        self.assertIn("必须包含变更 ID", result.stderr)

    def test_duplicate_frontmatter_id_rejected(self):
        card = self.repo / ".harness/changes/C-014/change.md"
        card.write_text("---\nid: C-014\nid: wrong\n---\n")
        self.git("add", str(card))
        self.git("commit", "-qm", "docs(test): C-014 重复键", success=False)

    def test_allocator_reserves_legacy_slug_and_workspace_link(self):
        (self.repo / ".harness/changes/C-040-legacy").mkdir()
        script = ".harness/scripts/new-change.py"
        result = self.run_command("python3", script, "--prefix", "WS", "--title", "工作空间")
        workspace = Path(result.stdout.strip())
        result = self.run_command("python3", script, "--prefix", "C", "--title", "执行卡", "--workspace-card", str(workspace))
        card = Path(result.stdout.strip())
        self.assertEqual("C-041", card.parent.name)
        self.assertIn("workspace_change: WS-001", card.read_text())
        self.assertIn("../WS-001/workspace-change.md", card.read_text())
        self.assertIn("执行卡", card.read_text(encoding="utf-8"))

    def test_missing_card_baseline_and_reinstall_preservation(self):
        path = self.repo / ".harness/change-card-policy-base"
        before = path.read_bytes()
        self.git("commit", "--allow-empty", "-qm", "docs(test): C-014 更新说明")
        self.run_command("python3", ".harness/scripts/install-commit-policy.py")
        self.assertEqual(before, path.read_bytes())
        path.unlink()
        self.run_command("sh", ".harness/scripts/ci-commit-check.sh", success=False)


    def test_legacy_optional_id_not_affected_by_later_adoption(self):
        # The fixture's initial commit predates adoption of change cards.
        initial = self.git("rev-list", "--max-parents=0", "HEAD").stdout.strip()
        self.git("checkout", "-b", "before-cards", initial)
        self.git("-c", "core.hooksPath=/dev/null", "commit", "--allow-empty", "-qm", "docs(test): 当时尚未采用变更卡")
        historical = self.git("rev-parse", "HEAD").stdout.strip()
        card = self.repo / ".harness/changes/C-001/change.md"
        card.parent.mkdir(parents=True, exist_ok=True)
        card.write_text("---\nid: C-001\n---\n")
        self.git("add", str(card))
        self.git("-c", "core.hooksPath=/dev/null", "commit", "-qm", "docs(test): C-001 采用变更卡")
        (self.repo / ".harness/commit-policy-base").write_text(initial + "\n")
        (self.repo / ".harness/change-card-policy-base").write_text(self.git("rev-parse", "HEAD").stdout.strip() + "\n")
        self.run_command("sh", ".harness/scripts/ci-commit-check.sh")


if __name__ == "__main__":
    unittest.main(verbosity=2)
