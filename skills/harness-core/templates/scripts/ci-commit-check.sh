#!/bin/sh
# CI 可设置 COMMIT_CHECK_BASE/COMMIT_CHECK_HEAD；未设置时检查启用基线以来所有提交。
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
if [ -n "${COMMIT_CHECK_BASE:-}" ]; then
  exec python3 "$repo/.harness/scripts/check-commit-message.py" --repo "$repo" --range --base "$COMMIT_CHECK_BASE" --head "${COMMIT_CHECK_HEAD:-HEAD}"
fi
exec python3 "$repo/.harness/scripts/check-commit-message.py" --repo "$repo" --range --head "${COMMIT_CHECK_HEAD:-HEAD}"
