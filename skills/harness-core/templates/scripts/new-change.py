#!/usr/bin/env python3
"""Reserve the next local ID and create its card (standard library only)."""
import argparse
from contextlib import contextmanager
import json
import os
from pathlib import Path
import re
import subprocess
import sys
sys.dont_write_bytecode = True
from change_registry import git


@contextmanager
def allocation_lock(path):
    with path.open("a+b") as lock:
        if os.name == "nt":
            import msvcrt
            lock.seek(0, os.SEEK_END)
            if lock.tell() == 0:
                lock.write(b"0")
                lock.flush()
            lock.seek(0)
            msvcrt.locking(lock.fileno(), msvcrt.LK_LOCK, 1)
            try:
                yield
            finally:
                lock.seek(0)
                msvcrt.locking(lock.fileno(), msvcrt.LK_UNLCK, 1)
        else:
            import fcntl
            fcntl.flock(lock, fcntl.LOCK_EX)
            try:
                yield
            finally:
                fcntl.flock(lock, fcntl.LOCK_UN)


def create(repo, prefix, title, workspace_card=None):
    repo = repo.resolve()
    if Path(git(repo, "rev-parse", "--show-toplevel")).resolve() != repo:
        raise ValueError("必须指定独立 Git 仓库根目录")
    if not title.strip() or "\n" in title:
        raise ValueError("标题必须为非空单行文本")
    workspace = None
    if workspace_card:
        workspace_card = workspace_card.resolve()
        text = workspace_card.read_text(encoding="utf-8")
        match = re.match(r"\A---\s*\nid: (WS-[0-9]+)\s*\n", text)
        if prefix != "C" or not match or workspace_card.parent.name != match[1]:
            raise ValueError("workspace-card 必须是有效的 WS 变更卡，且只用于 C 执行卡")
        workspace = match[1]
    common = Path(git(repo, "rev-parse", "--git-common-dir"))
    if not common.is_absolute():
        common = repo / common
    pattern = re.compile(r"(?<![\w-])" + prefix + r"-([0-9]+)(?![0-9])")
    with allocation_lock(common / "harness-change.lock"):
        counter = common / f"harness-next-{prefix}"
        numbers = [int(counter.read_text())] if counter.exists() else [0]
        # Reserve historical message IDs too, even where a card was never created.
        history = git(repo, "log", "--all", "--format=%B") if git(repo, "rev-list", "--all") else ""
        numbers += [int(n) for n in pattern.findall(history)]
        for line in git(repo, "worktree", "list", "--porcelain").splitlines():
            if line.startswith("worktree "):
                root = Path(line[9:]) / ".harness/changes"
                numbers += [int(m[1]) for p in root.glob(prefix + "-*") if (m := pattern.match(p.name))]
        # Include cards on other branches even when no message references them.
        for ref in git(repo, "for-each-ref", "--format=%(refname)", "refs/heads", "refs/remotes").splitlines():
            names = git(repo, "ls-tree", "--name-only", ref + ":.harness/changes") if subprocess.run(
                ["git", "-C", str(repo), "cat-file", "-e", ref + ":.harness/changes"], capture_output=True).returncode == 0 else ""
            numbers += [int(m[1]) for name in names.splitlines() if (m := pattern.match(name))]
        number = max(numbers) + 1
        change_id = f"{prefix}-{number:03d}"
        folder = repo / ".harness/changes" / change_id
        folder.mkdir(parents=True, exist_ok=False)
        counter.write_text(str(number))
        name = "workspace-change.md" if prefix == "WS" else "change.md"
        fields = f"id: {change_id}\nstatus: analyzing\nartifact_mode: compact\n"
        if workspace:
            fields += f"workspace_change: {workspace}\nworkspace_ref: {json.dumps(os.path.relpath(workspace_card, folder))}\nreport_ref: {json.dumps(os.path.relpath(workspace_card.with_name('report.md'), folder))}\n"
        if prefix == "WS":
            fields += "pipeline_mode: workspace_once\nstage: harnessing\nrepos: []\n"
        card = folder / name
        card.write_text(f"---\n{fields}---\n\n# {change_id} {title}\n\n## 需求与验收\n\n待填写需求范围、验收条件和实施授权。\n", encoding="utf-8")
        return card


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--prefix", choices=["C", "WS"], required=True)
    parser.add_argument("--title", required=True)
    parser.add_argument("--workspace-card", type=Path)
    args = parser.parse_args()
    try:
        print(create(args.repo, args.prefix, args.title, args.workspace_card))
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        print(f"ERROR 创建变更卡失败：{exc}", file=sys.stderr)
        sys.exit(2)
