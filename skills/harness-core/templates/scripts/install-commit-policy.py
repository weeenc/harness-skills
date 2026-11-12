#!/usr/bin/env python3
"""Enable a deployed commit policy without replacing existing hooks or instructions."""
import subprocess
import sys
from pathlib import Path


def git(repo, *args, check=True):
    return subprocess.run(["git", "-C", str(repo), *args], check=check,
                          capture_output=True, text=True)


def install(repo):
    repo = repo.resolve()
    actual = Path(git(repo, "rev-parse", "--show-toplevel").stdout.strip()).resolve()
    if actual != repo:
        raise ValueError("目标必须是独立 Git 根，不能修改父仓库配置")
    required = [".harness/git-hooks/commit-msg", ".harness/git-commit.md",
                ".harness/rules/git-branch-and-commit.md", ".harness/scripts/check-commit-message.py",
                ".harness/scripts/ci-commit-check.sh", ".harness/scripts/change_registry.py",
                ".harness/scripts/new-change.py"]
    for name in required + ["AGENTS.md", ".harness/commit-policy-base", ".harness/change-card-policy-base"]:
        path = repo / name
        if path.is_symlink() or any(p.is_symlink() for p in path.parents if p != repo and repo in p.parents):
            raise ValueError(f"拒绝通过符号链接修改配置：{path}")
        if name in required and not path.is_file():
            raise ValueError(f"缺少模板文件：{path}")
    # Respect effective worktree/global settings as well as repository settings.
    current = git(repo, "config", "--get", "core.hooksPath", check=False).stdout.strip()
    if current and current != ".harness/git-hooks":
        raise ValueError(f"已有 core.hooksPath={current}，请合并现有钩子后接入校验，不自动覆盖")
    if not current:
        hooks = Path(git(repo, "rev-parse", "--git-path", "hooks").stdout.strip())
        if not hooks.is_absolute():
            hooks = repo / hooks
        import os
        if any(p.is_file() and not p.name.endswith(".sample") and os.access(p, os.X_OK) for p in hooks.glob("*")):
            raise ValueError("存在启用的 Git hooks，请合并后接入校验，不自动禁用")
    agents = repo / "AGENTS.md"
    before = agents.read_text(encoding="utf-8") if agents.exists() else ""
    block = (repo / ".harness/git-commit.md").read_text(encoding="utf-8").strip()
    start, end = "<!-- harness:git-commit:start -->", "<!-- harness:git-commit:end -->"
    if start in before or end in before:
        if before.count(start) != 1 or before.count(end) != 1 or before.index(end) < before.index(start):
            raise ValueError("AGENTS.md 管理块不完整或重复，请合并")
        old = before[before.index(start):before.index(end) + len(end)]
        if old != block:
            raise ValueError("AGENTS.md 提交约定存在本地差异，请按已授权升级范围合并")
    base_path = repo / ".harness/commit-policy-base"
    if base_path.exists():
        base = base_path.read_text().strip()
        if base != "ROOT":
            if not base:
                raise ValueError("已有基线为空，禁止重置以跳过历史")
            git(repo, "rev-parse", "--verify", "--end-of-options", base + "^{commit}")
            git(repo, "merge-base", "--is-ancestor", base, "HEAD")
    else:
        head = git(repo, "rev-parse", "--verify", "HEAD", check=False)
        if head.returncode == 0:
            base = head.stdout.strip()
        elif not git(repo, "rev-list", "--all").stdout.strip():
            base = "ROOT"
        else:
            raise ValueError("HEAD 无提交但仓库有其他历史，请明确启用基线")
    card_base_path = repo / ".harness/change-card-policy-base"
    if card_base_path.exists():
        card_base = card_base_path.read_text().strip()
        if card_base != "ROOT":
            import re
            if not re.fullmatch(r"[0-9a-f]{40,64}", card_base):
                raise ValueError("已有变更卡基线必须为固定 SHA，禁止重置")
            git(repo, "rev-parse", "--verify", card_base + "^{commit}")
            git(repo, "merge-base", "--is-ancestor", card_base, "HEAD")
    else:
        # New repositories check all commits; upgrades freeze the existing HEAD.
        head = git(repo, "rev-parse", "--verify", "HEAD", check=False)
        card_base = head.stdout.strip() if head.returncode == 0 else "ROOT"
    # Only write after all conflict checks have passed.
    if start not in before:
        agents.write_text(before + ("\n\n" if before else "") + block + "\n", encoding="utf-8")
    if not base_path.exists():
        base_path.write_text(base + "\n")
    if not card_base_path.exists():
        card_base_path.write_text(card_base + "\n")
    hook = repo / ".harness/git-hooks/commit-msg"
    hook.chmod(hook.stat().st_mode | 0o111)
    git(repo, "config", "--local", "core.hooksPath", ".harness/git-hooks")
    print(f"已启用中文提交校验：{repo}（保留基线 {base}）")


if __name__ == "__main__":
    try:
        install(Path(__file__).resolve().parents[2])
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        print(f"ERROR 安装未完成：{exc}", file=sys.stderr)
        sys.exit(2)
