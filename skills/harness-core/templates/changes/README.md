# 变更产物协议

本协议只约束 `changes/` 内的需求过程产物。wiki、tech、rules、领域知识回流和其他目录继续按原有规则维护。

## 默认：一个需求，两份持久文档

新变更在卡片 frontmatter 写 `artifact_mode: compact`。只实例化需要的模板，不要把整个 `_TEMPLATE/` 复制为需求目录。

| 场景 | 提交 Git 的需求文档 |
|---|---|
| 单独前端、后端或单仓全栈 | `<id>/change.md` + `<id>/report.md` |
| 多仓全栈 | 协调仓 `<WS-ID>/workspace-change.md` + `<WS-ID>/report.md`；每个参与仓仅 `<C-ID>/change.md` 执行卡 |

变更卡保留需求、AC、设计约束、审批、状态、关联和下一步；`report.md` 按六阶段记录实际结果。先创建卡片，产生阶段结论时再创建报告，未执行阶段写“未执行”，不得填预期成功。复杂需求在 changes 内也默认使用此协议；只有用户明确要求额外专题报告时才拆分。changes 之外的可选 iterations 协议仍按原逻辑选用和维护。

| 阶段 | 在 `report.md` 中保存 |
|---|---|
| ① 需求分析 | 需求/审批引用、范围和关键决策 |
| ② 编码实现 | 实现范围、设计调整、诊断结论、独立复核和待办 |
| ③ 单元测试 | AC→测试映射、真实命令、结果、覆盖率和限制 |
| ④ 专家评审 | 审查范围、Spec/Standards 双轴结果、问题处理与结论 |
| ⑤ CI 与质量门禁 | 具名门禁、联合 E2E/契约、质量对账与人工确认 |
| ⑥ 部署验证与归档 | 环境、版本、冒烟、traceId/断言、回滚、交付及知识回流清单 |

不再自动新建 `review.md`、`verify.md`、`archive.md`、`quality-report.md`、`diagnosis.md`、`api-mock.md`、`e2e.md`、`handoff.md`、`gate-*.md` 等同级过程文档。阶段切换更新已有章节，不生成交接文件；真正跨会话交接才按需写 `.runtime/<id>/handoff.md`，团队需要的阻塞与下一步仍写回卡片。

## 全栈报告只汇总一次

子仓执行卡必须保留 `id`、`status`、`artifact_mode: compact`、`workspace_change`、`workspace_ref`、`report_ref`。引用均相对执行卡所在目录；`report_ref` 指向协调仓的 `report.md`，不要填绝对机器路径。实际路径由协调者计算，不照抄示例。

子仓技能读取 `report_ref`，将执行结果交给协调者；只有协调者更新共享报告，按仓库标明命令、版本和结果。子仓保留本地状态镜像以兼容 hooks，不另建 `repo-execution.md` 或重复评审/部署报告。`review-check` 根据执行卡引用检查共享报告，不要求复制本地 `review.md`；引用缺失或工作空间 ID 不匹配必须报错。

## 运行数据不作为需求文档

所有原始 evidence、日志、临时快照、截图、完整命令输出和会话交接写到 `changes/.runtime/<id>/evidence/<stage>/` 或该变更的 `.runtime/<id>/` 固定文件，由 `changes/.gitignore` 中的 `/.runtime/` 忽略。每个阶段使用稳定文件名覆盖最新结果，不创建 `run-*` 时间戳目录，也不要在 `<id>/evidence/` 下写运行产物。`report.md` 只保留可独立阅读的摘要和关键证据。

- `report.sh` 只更新 `.runtime/<id>/gate-<gate>.md` 的最新退出码摘要，不改持久报告、不保存整份 diff，也不创建时间戳目录。重复检查不会增加文件数量。
- 阶段结束时，执行者将真实命令、时间、代码版本（有未提交内容时说明 dirty 范围）、退出码、关键计数/断言和结论写入 `report.md` 对应章节；不能只链接本地临时文件作为唯一证据。保留关键失败原因、修复结果和人工确认；重跑时更新当前结果，避免无限追加重复流水。
- 完整历史证据确需共享时，保存到稳定 CI/制品地址并在报告记录摘要与校验值。尚未提交的源码、唯一备份或人工记录不得因在运行目录中就自动删除。清理是独立操作，不由安装器或阶段切换触发。
- 需要代码快照时，同一代码状态只保存一次，再由各次检查引用；不得为每个门禁重复复制前后端全部 diff。代码与门禁配置属于被测输入，报告和运行输出不应反复进入快照。
- 机器结果只有 rc=0 为 PASS；rc=1 为 FAIL，rc=2 为 DEGRADED，其余/缺失返回码为 ERROR。减少文档不减少门禁，也不把降级算作通过。

## 历史兼容

没有 `artifact_mode: compact` 的既有卡片按 legacy 处理：保留其独立评审/验证/归档报告，不自动重写或删除。技能读取 compact 的阶段报告，或 legacy 的原报告；最新门禁读取 `.runtime/<id>/gate-*.md`，缺失时才读取旧 `<id>/gate-*.md`，历史结果不能冒充本次执行。

旧卡转 compact 必须是明确的迁移任务：合并各阶段结论、人工签名、关键失败、知识回流和稳定证据链接，校验引用，再标记 `artifact_mode: compact`。全栈迁移同时补齐子仓引用。仅运行 `/install-skill` 不会升级项目内脚本和协议；更新本项目受影响的技能、脚本与模板时也必须保留本地适配。

`_TEMPLATE/review.md`、`verify.md`、`archive.md` 保留给 legacy 使用，新卡只用 `change.md` / `workspace-change.md` / `local-change.md` 与 `report.md`。iterations 协议的选用与维护照旧；不因精简 changes 自动迁移其他目录。
