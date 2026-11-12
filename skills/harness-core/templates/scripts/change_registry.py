"""Resolve change cards from Git snapshots; no working-tree fallback."""
import re
import subprocess

ID = re.compile(r"(?:C|WS)-[0-9]+")


def git(repo, *args):
    return subprocess.check_output(["git", "-C", str(repo), *args], text=True,
                                   encoding="utf-8", stderr=subprocess.PIPE).strip()


def card_errors(repo, message, revision=None):
    # The index is the exact content commit-msg will commit; CI uses each commit tree.
    if revision:
        paths = git(repo, "ls-tree", "-r", "--name-only", revision, ".harness/changes").splitlines()
    else:
        paths = git(repo, "ls-files", "--cached", "--", ".harness/changes").splitlines()
    cards = {}
    for path in paths:
        match = re.fullmatch(r"\.harness/changes/((?:C|WS)-[0-9]+)/(change|workspace-change)\.md", path)
        if not match:
            continue
        change_id, kind = match.groups()
        expected = "workspace-change" if change_id.startswith("WS-") else "change"
        if kind != expected:
            continue
        text = git(repo, "show", f"{revision or ''}:{path}")
        front = re.match(r"\A---\s*\n(.*?)\n---(?:\n|$)", text, re.S)
        ids = [value.strip().strip("\"'") for value in re.findall(r"^id:[ \t]*(.*)$", front[1], re.M)] if front else []
        cards[change_id] = ids == [change_id]
    # A primary ID is the first ID in the message. Other IDs may be historical
    # references (e.g. a revert); they must not replace the primary tracking card.
    match = re.search(r"(?<![\w-])((?:C|WS)-[0-9]+)(?![\w-])", message)
    if not match:
        return []  # Format validator reports this.
    change_id = match[1]
    if not cards.get(change_id):
        source = revision or "暂存区"
        return [f"主变更 {change_id} 缺少有效变更卡（{source}）；先创建并 git add 对应卡片，目录与 frontmatter id 必须一致"]
    return []


def requires_change(repo, revision=None):
    """Enable tracking from the snapshot or its parent; deleting cards cannot bypass it."""
    if revision:
        revisions = git(repo, "rev-list", "--parents", "-n", "1", revision).split()
    else:
        if git(repo, "ls-files", "--cached", "--", ".harness/changes"):
            return True
        # Preserve optional IDs for projects that have never adopted change cards.
        from pathlib import Path
        if (Path(repo) / ".harness/changes").is_dir():
            return True
        head = subprocess.run(["git", "-C", str(repo), "rev-parse", "--verify", "HEAD"], capture_output=True, text=True)
        revisions = [head.stdout.strip()] if head.returncode == 0 else []
    return any(git(repo, "ls-tree", "--name-only", rev, ".harness/changes") for rev in revisions)
