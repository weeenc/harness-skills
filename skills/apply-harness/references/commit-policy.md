# 提交校验初始化与升级

单仓、协调仓及每个独立子仓都执行；依赖 Git、Python 3、POSIX sh。缺依赖时明确记录未完成，不把“复制了文件”当作已启用。规则源为 harness-core/rules/git-branch-and-commit.md，保持跨语言一致。

## 部署清单

按 Step 0.1 比较目标文件，同内容跳过，不同内容保留并按已授权升级范围合并：

| 源（harness-core 下） | 目标 |
|---|---|
| rules/git-branch-and-commit.md | .harness/rules/git-branch-and-commit.md |
| templates/scripts/check-commit-message.py、ci-commit-check.sh、install-commit-policy.py、commit-policy.md | .harness/scripts/ 对应文件 |
| templates/git-hooks/commit-msg | .harness/git-hooks/commit-msg（保留执行位） |
| templates/agents/git-commit.md | .harness/git-commit.md |

单仓门禁使用已增加提交检查的 templates/scripts/harness-gate.sh；已有定制入口只合并前置检查，不整文件覆盖。协调仓不引入语言门禁，联合入口先执行本仓 ci-commit-check，再执行各子仓门禁。更新可跟踪的编排/发布/CI 技能后，按 install-skill 协议同步授权范围内的注册副本。

## 启用与复核

1. 检查根 AGENTS.md 已有指令是否与中文规范冲突，有冲突先按授权范围合并。
2. 执行 `python3 .harness/scripts/install-commit-policy.py`。脚本追加管理块并保留其他内容；已有块不同、符号链接、其他 hooksPath 或启用的 hooks 会拒绝覆盖。按现场配置将校验调用合并到既有 commit-msg，不禁用其他钩子；基线和 AGENTS 块也应保留并完成合并。
3. 仅首次启用生成 `.harness/commit-policy-base`：有历史取当前 HEAD，无提交用 `ROOT`。已有基线保持不变，模板不携带 SHA；不要通过重跑安装掩盖违规提交。无 Git 的协调目录部署后标记待启用，不自动建立仓库。
4. 用临时候选文件验证中文信息通过、英文信息失败，并检查实际 hook 路径与执行权限。运行 CI 范围检查，记录实际检查条数；安装验证不在业务仓制造测试提交。
5. 在已有 CI 的完整历史检出后接入 `sh .harness/scripts/ci-commit-check.sh`，配置非零阻断。平台未接入时明确列为待完成，不宣称远端强制校验生效。

## 升级边界

默认补缺不是整包覆盖。已有本地规则、脚本、AGENTS 和 hooks 的差异必须保留或明确合并；仅注册技能不会升级项目资产。再次安装不能重置基线，不写入个人技能目录。结果逐仓列出资产部署、AGENTS 合并、hook 启用、基线、范围检查、注册副本及远端 CI 状态。最终行为与技术边界详见部署后的 `.harness/scripts/commit-policy.md`。
