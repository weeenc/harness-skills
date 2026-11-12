# 中文提交校验

安装依赖 Git、Python 3（标准库），Shell hook 需 POSIX sh（Windows 可用 Git Bash）。

## 本地安装与升级

`apply-harness` 部署规则、脚本、`.harness/git-hooks/commit-msg` 和 `.harness/git-commit.md` 后执行：

```sh
python3 .harness/scripts/install-commit-policy.py
```

安装器向根 AGENTS.md 追加提交约定块，保留其他内容；已有约定块不同则报告冲突，不替换。确认既有文字无矛盾后再运行。保留其他 hooksPath 和启用的 hooks，遇到冲突须将校验调用合并到已有 commit-msg；不得禁用其他钩子。Git hooks 与 AI 宿主的 `.harness/hooks/` 是不同机制。

基线 `.harness/commit-policy-base` 首次取目标仓当前 HEAD；没有任何提交的仓库使用 `ROOT`，检查首个及后续全部提交。重复安装/升级不移动基线。基线文件需提交版本控制，不从模板或其他仓复制 SHA。无 Git 的协调目录只部署资产，标记待启用，不自动 git init。

新克隆需要重新安装本地 hooks。仅运行 install-skill 不升级这些规则、脚本或 Git 配置。升级按文件比较并合并本地定制；同时同步已授权范围内的项目技能注册副本。

## CI

在检出完整历史之后、构建之前执行并将非零退出码设为失败：

```sh
sh .harness/scripts/ci-commit-check.sh
```

默认检查基线之后至 HEAD 的全部提交，包含 merge 和侧分支。需要指定范围时，由可信 CI 配置传入：

```sh
COMMIT_CHECK_BASE=<祖先提交SHA> COMMIT_CHECK_HEAD=<待检查提交SHA> sh .harness/scripts/ci-commit-check.sh
```

基线缺失、无效引用、非祖先基线或浅克隆导致历史缺失均失败；不要用 HEAD 动态重写基线。空仓/没有新增提交明确报告 0 条，不能冒充提交后验证。首次启用之前的历史不追溯修改。

`harness-gate.sh` 在各门禁之前执行提交检查，`harness-gate.sh commit-message` 可单独检查。协调层联合门禁应先检查协调仓，再调用各子仓门禁。远端 Codeup/GitHub/GitLab 等需实际接入该命令并配置必需门禁；生成脚本不代表远端已启用。已存在的项目 CI 应按实际平台配置接入，不生成猜测的流水线文件。

## 规则边界

检查 `<type>(<scope>): <subject>`、subject 含中文、不以句号结尾；使用 `.harness/changes/` 时检查 message 含 C-数字 或 WS-数字。类型保留英文标准值，技术标识可保留英文。中文是否准确仍需评审，机器不能仅凭汉字判断语义。

merge/revert/squash/fixup 不豁免，需改写默认英文信息；例如 `chore(merge): WS-014 合并提交校验改进`。检查不修改历史、不验证分支名称。返回码 0=通过、1=违规、2=执行失败（均须阻断），命令用法错误也返回非零。

## 变更编号与卡片关联

- `C-*` 是仓库级变更 ID，`WS-*` 是协调仓工作空间变更 ID；两者独立分配，不要求数字相同。同一需求的实现、测试、修复、合并提交复用原卡 ID；无关需求必须新建卡片，不能按提交次数递增或复用他人的编号。
- 新建前先搜索已有卡片和需求，确认是否属于已有变更。新需求统一执行 `python3 .harness/scripts/new-change.py --prefix C --title "需求标题"`；协调仓跨仓需求使用 `--prefix WS`。子仓可加 `--workspace-card <协调仓卡片路径>` 自动写入关联，再由协调仓登记 `repos[].local_change`。
- 分配器取本仓已有卡片、分支卡片、所有本地可见 refs 的提交信息和本机已预留序号的最大值加一；至少三位补零。使用 Git 公共目录锁防止同机 worktree 并发撞号；失败可留空号，禁止回收。远端或不同克隆之间不共享锁，协作前须同步 refs，合并时复核同 ID 是否对应同一需求，必要时重编号并同步引用。
- 使用变更卡管理时，提交信息中第一个 `C-*` 或 `WS-*` 是本次主变更 ID，必须对应本仓 `.harness/changes/<ID>/change.md`（C）或 `workspace-change.md`（WS），目录名与 frontmatter 的唯一 `id` 必须完全一致。正文之后的其他编号仅作为历史关联，例如回滚目标；不会代替主卡。子仓以本地 C 卡为主 ID，跨仓 WS 关系写入卡片。
- 填好卡片后先 `git add`。提交前校验与 commit-msg 读取暂存区；CI 读取每条提交自身的树。仅存在于工作目录、提交后补建、目录和 ID 不一致的卡片不能通过。存在性校验不判断需求语义，评审仍须核对改动是否属于主卡，不能拿任意现有卡凑数。
- `.harness/change-card-policy-base` 是首次启用卡片检查时固定的历史兼容基点；它的祖先提交只运行原格式检查，其余提交必须有卡。原 `.harness/commit-policy-base` 保持不变；禁止移动任一基点绕过检查。空仓使用 `ROOT`，从首条提交校验。不为历史无卡编号补造需求，不改写历史提交。

旧项目的带后缀卡片目录（例如 `C-001-example`）不会自动迁移。新卡统一使用纯编号目录；继续修改旧需求前，先按授权范围对齐其目录、frontmatter ID 和引用，再提交。编号分配时仍预留这些旧目录的数字。未采用 `.harness/changes/` 的项目可省略编号；已采用的项目不能通过删除卡片目录让当前提交免检。

编号分配器使用 Python 标准库文件锁：POSIX 使用 flock，Windows 使用 msvcrt。锁仅协调共享 Git 公共目录的本机 worktree，不提供跨克隆或跨机器的集中编号服务。
