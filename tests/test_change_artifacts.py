"""Validate change artifact behavior in isolated single- and multi-repo projects."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1] / "skills/harness-core/templates"
LEGACY_REVIEW = """# Review
审查范围: src/app.py
## Spec 轴报告
### 🔴 严重问题
无。
## Standards 轴报告
### 🔴 严重问题
无。
"""
COMPACT_REVIEW = """# Report
## ③ 单元测试
人工确认: 保留此内容
## ④ 专家评审
review_status: complete
审查范围: src/app.py
### Spec 轴报告（需求匹配）
#### 🔴 严重问题
无。
### Standards 轴报告
#### 🔴 严重问题
无。
## ⑤ CI 与质量门禁
尚未执行
"""


class ChangeArtifactsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.install(self.root)

    def install(self, root):
        scripts = root / ".harness/scripts"
        scripts.mkdir(parents=True)
        for name in ("report.sh", "review-check.sh"):
            shutil.copy2(SOURCE / "scripts" / name, scripts / name)

    def card(self, ident="C-1", mode="compact", extra="", root=None, workspace=False):
        root = root or self.root
        directory = root / ".harness/changes" / ident
        directory.mkdir(parents=True, exist_ok=True)
        name = "workspace-change.md" if workspace else "change.md"
        mode_line = f"artifact_mode: {mode}\n" if mode else ""
        (directory / name).write_text(
            f"---\nid: {ident}\nstatus: reviewing\n{mode_line}{extra}---\n# Change\n"
        )
        return directory

    def run_script(self, name, *args, root=None):
        return subprocess.run(
            ["bash", str((root or self.root) / ".harness/scripts" / name), *args],
            cwd=self.root, capture_output=True, text=True,
        )

    def assert_rc(self, result, rc=0):
        self.assertEqual(result.returncode, rc, result.stdout + result.stderr)

    def test_repeated_gates_do_not_grow_tracked_artifacts_or_touch_manual_report(self):
        directory = self.card()
        (directory / "report.md").write_text(COMPACT_REVIEW)
        (directory.parent / ".gitignore").write_text("/custom-cache/\n")
        original = {p.name: p.read_bytes() for p in directory.iterdir()}
        for _ in range(12):
            for gate in ("check-style", "coverage", "security-scan"):
                self.assert_rc(self.run_script("report.sh", gate, "C-1", "rc=0"))
        self.assertEqual(original, {p.name: p.read_bytes() for p in directory.iterdir()})
        runtime = directory.parent / ".runtime/C-1"
        self.assertEqual(len(list(runtime.iterdir())), 3)
        ignore = (directory.parent / ".gitignore").read_text()
        self.assertIn("/custom-cache/", ignore)
        self.assertEqual(ignore.count("/.runtime/"), 1)
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        ignored = subprocess.run(
            ["git", "check-ignore", ".harness/changes/.runtime/C-1/gate-coverage.md"],
            cwd=self.root, capture_output=True,
        )
        self.assertEqual(ignored.returncode, 0)
        self.assertEqual(subprocess.run(
            ["git", "check-ignore", ".harness/changes/C-1/report.md"],
            cwd=self.root, capture_output=True,
        ).returncode, 1)

    def test_gate_codes_preserve_failures_degradation_and_errors(self):
        self.card()
        for note, status in [("rc=0", "PASS"), ("rc=1", "FAIL"), ("rc=2", "DEGRADED"),
                             ("rc=3", "ERROR"), ("rc=124 timeout", "ERROR"),
                             ("rc=-9 killed", "ERROR"), ("missing", "ERROR"),
                             ("rc=0bogus", "ERROR")]:
            with self.subTest(note=note):
                self.assert_rc(self.run_script("report.sh", "coverage", "C-1", note))
                text = (self.root / ".harness/changes/.runtime/C-1/gate-coverage.md").read_text()
                self.assertIn(f"- 状态: {status}\n", text)

    def test_no_change_does_not_create_a_phantom_change(self):
        self.assert_rc(self.run_script("report.sh", "coverage"))
        self.assertFalse((self.root / ".harness/changes").exists())
        self.assert_rc(self.run_script("report.sh", "coverage", "C-missing", "rc=0"), 3)

    def test_ambiguous_change_is_not_selected(self):
        self.card("C-1")
        self.card("C-2")
        self.assert_rc(self.run_script("report.sh", "coverage"), 3)
        self.assertFalse((self.root / ".harness/changes/.runtime").exists())

    def test_unique_change_is_selected_and_template_is_skipped(self):
        self.card("C-1")
        self.card("_TEMPLATE")
        self.assert_rc(self.run_script("report.sh", "coverage", "", "rc=0"))
        self.assertTrue((self.root / ".harness/changes/.runtime/C-1/gate-coverage.md").exists())

    def test_path_traversal_and_invalid_gate_are_rejected(self):
        self.card()
        self.assert_rc(self.run_script("report.sh", "coverage", "../outside", "rc=0"), 3)
        self.assert_rc(self.run_script("report.sh", "../outside", "C-1", "rc=0"), 3)
        self.assert_rc(self.run_script("review-check.sh", "../outside"), 3)

    def test_legacy_report_is_read_and_existing_evidence_is_preserved(self):
        directory = self.card(mode="")
        (directory / "review.md").write_text(LEGACY_REVIEW)
        old = directory / "gate-coverage.md"
        old.write_text("Historical evidence\n人工签字\n")
        self.assert_rc(self.run_script("review-check.sh", "C-1"))
        self.assert_rc(self.run_script("report.sh", "coverage", "C-1", "rc=1"))
        self.assertEqual(old.read_text(), "Historical evidence\n人工签字\n")

    def test_compact_single_repo_review_works_from_any_cwd(self):
        directory = self.card()
        (directory / "report.md").write_text(COMPACT_REVIEW)
        self.assert_rc(self.run_script("review-check.sh", "C-1"))
        self.assertFalse((directory / "review.md").exists())

    def test_pending_template_cannot_pass_review(self):
        directory = self.card()
        shutil.copy2(SOURCE / "changes/_TEMPLATE/report.md", directory / "report.md")
        self.assert_rc(self.run_script("review-check.sh", "C-1"), 1)

    def test_only_review_stage_counts_and_compact_never_uses_stale_legacy(self):
        directory = self.card()
        (directory / "review.md").write_text(LEGACY_REVIEW)
        (directory / "report.md").write_text(COMPACT_REVIEW.replace("## ④ 专家评审", "## ② 编码实现"))
        self.assert_rc(self.run_script("review-check.sh", "C-1"), 1)
        (directory / "report.md").unlink()
        self.assert_rc(self.run_script("review-check.sh", "C-1"), 1)

    def test_missing_axis_and_unreferenced_findings_fail(self):
        directory = self.card()
        for text in [COMPACT_REVIEW.replace("### Standards 轴报告", "### Other"),
                     COMPACT_REVIEW.replace("无。", "- 有严重问题"),
                     COMPACT_REVIEW.replace("#### 🔴 严重问题", "#### Findings")]:
            (directory / "report.md").write_text(text)
            self.assert_rc(self.run_script("review-check.sh", "C-1"), 1)
        (directory / "report.md").write_text(COMPACT_REVIEW.replace("无。", "- src/app.py:L20 AC-1 不完整"))
        # A structurally complete report may contain findings; the skill decides pass/fail.
        self.assert_rc(self.run_script("review-check.sh", "C-1"))

    def test_full_stack_uses_one_shared_report_without_local_copies(self):
        workspace = self.card("WS-1", workspace=True)
        (workspace / "report.md").write_text(COMPACT_REVIEW)
        for repo in ("frontend", "backend"):
            root = self.root / repo
            self.install(root)
            directory = root / ".harness/changes/C-1"
            ref = os.path.relpath(workspace / "report.md", directory)
            self.card(root=root, extra=f"workspace_change: WS-1\nreport_ref: {ref}\n")
            self.assert_rc(self.run_script("review-check.sh", "C-1", root=root))
            self.assert_rc(self.run_script("report.sh", "coverage", "C-1", "rc=0", root=root))
            self.assertEqual([p.name for p in directory.iterdir()], ["change.md"])
        self.assert_rc(self.run_script("review-check.sh", "WS-1"))
        self.assertEqual((workspace / "report.md").read_text(), COMPACT_REVIEW)

    def test_wrong_workspace_or_missing_reference_never_falls_back(self):
        workspace = self.card("WS-1", workspace=True)
        (workspace / "report.md").write_text(COMPACT_REVIEW)
        directory = self.card(extra="workspace_change: WS-2\nreport_ref: ../WS-1/report.md\n")
        (directory / "review.md").write_text(LEGACY_REVIEW)
        self.assert_rc(self.run_script("review-check.sh", "C-1"), 1)
        self.card(extra="workspace_change: WS-1\n")
        self.assert_rc(self.run_script("review-check.sh", "C-1"), 1)


if __name__ == "__main__":
    unittest.main()
