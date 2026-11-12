#!/usr/bin/env python3
"""Validate a Git message or every new commit in a CI range (Python standard library)."""
import argparse
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.dont_write_bytecode = True
from change_registry import card_errors, requires_change

HEADER = re.compile(r"(?:feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)\([^\s():]+\): (\S.*)")
HAN = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\U00020000-\U000323af]")
CHANGE = re.compile(r"(?<![\w-])(?:WS|C)-[0-9]+(?![\w-])")


def errors(message, require_change=True):
    lines = message.strip().splitlines()
    match = HEADER.fullmatch(lines[0]) if lines else None
    if not match:
        return ["首行必须为 <type>(<scope>): <中文描述>，例如 fix(process): C-014 修复导入校验"]
    subject = match.group(1)
    result = []
    if not HAN.search(subject):
        result.append("subject 必须包含中文描述；type、scope 或正文中的中文不能替代中文 subject")
    if subject.endswith((".", "。")):
        result.append("subject 不以句号结尾")
    if require_change and not CHANGE.search(message):
        result.append("提交信息必须包含变更 ID（C-数字 或 WS-数字，可放正文或 footer）")
    return result


def git(repo, *args):
    return subprocess.check_output(["git", "-C", str(repo), *args], text=True, encoding="utf-8", errors="strict", stderr=subprocess.PIPE).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--message-file", type=Path)
    mode.add_argument("--range", action="store_true", help="检查 base..head，包含 merge commit")
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--base", help="起始提交（不含）；默认读取 .harness/commit-policy-base")
    parser.add_argument("--head", default="HEAD")
    args = parser.parse_args()
    try:
        legacy = set()
        if args.message_file:
            messages = [(str(args.message_file), args.message_file.read_text(encoding="utf-8"), None)]
        else:
            if git(args.repo, "rev-parse", "--is-shallow-repository") == "true":
                raise ValueError("CI 需要完整 Git 历史，当前为浅克隆")
            base = args.base or (args.repo / ".harness/commit-policy-base").read_text().strip()
            if not base:
                raise ValueError("提交检查基线为空")
            # ROOT is only created when enabling the policy in a repository with no commits.
            if base == "ROOT" and args.head == "HEAD" and not git(args.repo, "rev-list", "--all"):
                commits = []
            else:
                head_sha = git(args.repo, "rev-parse", "--verify", "--end-of-options", args.head + "^{commit}")
                if base == "ROOT":
                    commits = git(args.repo, "rev-list", "--reverse", head_sha).splitlines()
                else:
                    base_sha = git(args.repo, "rev-parse", "--verify", "--end-of-options", base + "^{commit}")
                    subprocess.run(["git", "-C", str(args.repo), "merge-base", "--is-ancestor", base_sha, head_sha], check=True, capture_output=True)
                    commits = git(args.repo, "rev-list", "--reverse", f"{base_sha}..{head_sha}").splitlines()
            # Separate, immutable activation point: keep the original format baseline.
            card_base = (args.repo / ".harness/change-card-policy-base").read_text().strip()
            if card_base == "ROOT":
                legacy = set()
            else:
                if not re.fullmatch(r"[0-9a-f]{40,64}", card_base):
                    raise ValueError("变更卡校验基线必须为固定 commit SHA 或 ROOT")
                git(args.repo, "rev-parse", "--verify", card_base + "^{commit}")
                if commits:
                    subprocess.run(["git", "-C", str(args.repo), "merge-base", "--is-ancestor", card_base, head_sha], check=True, capture_output=True)
                legacy = set(git(args.repo, "rev-list", card_base).splitlines())
            messages = [(sha[:12], git(args.repo, "show", "-s", "--format=%B", sha), sha) for sha in commits]
        failed = False
        for label, message, revision in messages:
            issues = errors(message, requires_change(args.repo, revision))
            if revision not in legacy:
                issues += card_errors(args.repo, message, revision)
            for error in issues:
                print(f"FAIL {label}: {error}", file=sys.stderr)
                failed = True
        if not failed:
            print(f"PASS 提交信息检查：{len(messages)} 条")
        return 1 if failed else 0
    except (OSError, UnicodeError, ValueError, subprocess.CalledProcessError) as exc:
        print(f"ERROR 提交信息检查失败：{exc}；CI 必须拉取完整历史并提供有效基线，禁止跳过检查", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
