# 门禁底层依赖体检/自举 — `scripts/bootstrap-tools.sh`

## 一、用途

回答「**这个门禁现在到底能不能真跑**」。它是所有 gate 脚本的前置检查：门禁要跑 checkstyle、
JaCoCo、AssertJ、Spring Boot Actuator…先确认这些依赖在不在——**不在就显式降级，而不是让
构建失败被误判成风格违规**。也回答你上一个问题：Checkstyle/JaCoCo/AssertJ 不是"一个脚本解决了"，
是脚本**只检测声明、输出合入指引（GUIDE），绝不替你改 pom.xml/build.gradle**——改构建文件是
规范流程（harness-standard）的职责。

## 二、调用方式

```bash
bash .harness/scripts/bootstrap-tools.sh [check|install] [gate]
# MODE: check（默认，只检测） | install（tools 类自动安装）
# gate: all（默认） | lint | vet | cov | arch | sec
```

各 gate 脚本在检测前的标准调用（例）：

```bash
"$(dirname "${BASH_SOURCE[0]}")/bootstrap-tools.sh" check lint   # check-style / static-analysis 用
"$(dirname "${BASH_SOURCE[0]}")/bootstrap-tools.sh" check cov    # coverage 用
"$(dirname "${BASH_SOURCE[0]}")/bootstrap-tools.sh" check arch   # arch-check 用
"$(dirname "${BASH_SOURCE[0]}")/bootstrap-tools.sh" check sec    # security-scan 用
```

## 三、运行原理

1. **锚定项目根**：`cd "$(dirname "${BASH_SOURCE[0]}")/../.."`——不依赖 cwd，hooks/子目录调用同基准。
2. **三类依赖，三种处理策略**（`apply-harness` 渲染时按项目语言/构建工具把清单填进
   `RUNNERS` / `TOOLS` / `PROJECT` 三个数组，勿手改）：

| 类别 | 是什么 | check 模式 | install 模式 |
|---|---|---|---|
| `runners` | 构建/运行器（mvn / ./gradlew / npm / go / python…） | `command -v` 检测，`[MISS]` 输出手动安装指引 | **不自动装**（动系统级工具链风险大，只给指引） |
| `tools` | 可安全自动装的独立工具（npm i -D / pip install / go install…） | `[MISS]` 给安装命令 | 自动执行 `eval "$install_cmd"`，失败 `[FAIL]` 提示手动 |
| `project` | 项目内【声明】组件（checkstyle/jacoco/pmd/spotbugs 插件、assertj、spring-boot-starter-actuator、devDependencies） | `grep -q` 探测构建文件（pom.xml/build.gradle/package.json…）是否声明；未声明 `[GUIDE]` 输出合入指引 | **绝不自动改写构建文件**（副作用不可控，属规范流程范畴） |

3. **gate 过滤**：每项带 gates 标签（如 `lint,vet`），`wanted()` 按 `GATE` 参数匹配——
   只查本次门禁需要的依赖，避免无关缺失误伤（如跑 coverage 不因 checkstyle 没声明而失败）。

## 四、如何出结果（stdout 标记与退出码）

| 标记 | 含义 | 计入 |
|---|---|---|
| `[OK]` | 运行器/工具可用，或组件已在构建文件中声明 | checked |
| `[MISS]` | 运行器/工具未安装（install 模式尝试自动装） | miss |
| `[GUIDE]` | 项目组件未在构建文件声明（给了合入指引） | manual |
| `[FAIL]` | install 模式自动安装失败（提示手动执行） | miss |

结尾汇总：`== 体检完成: N 项检查, X 项缺失, Y 项待人工合入 ==`

| 退出码 | 含义 |
|---|---|
| 0 | 所查依赖全部就绪，门禁可以真跑 |
| 1 | 存在缺失（runners/tools 未装；install 模式可修复 tools 类） |
| 2 | 存在**待人工合入的项目组件**（此时该 gate 无法真实执行） |
| 3 | 项目根定位失败（cd 出错） |

> 退出码优先级：`miss>0` 且 `manual>0` → 1（缺失更紧急，先装工具）。

## 五、结果不满足时如何报错（下游怎么用）

gate 脚本拿到 rc≠0 时**不假设失败原因**，统一走降级路径：

```bash
if ! "$(dirname "${BASH_SOURCE[0]}")/bootstrap-tools.sh" check cov >/dev/null 2>&1; then
  echo "[DEGRADED] coverage 底层依赖未就绪（如 JaCoCo 插件未在 pom.xml 声明）——无法测量覆盖率，该门禁降级人工核对；缺失项与合入指引：bash .harness/scripts/bootstrap-tools.sh check cov"
  rc=2
fi
```

即：**依赖缺失 → 该门禁显式降级（rc=2）+ 给出一键复检命令**，人工按 `[GUIDE]` 指引把组件
合入构建文件、重新 install 后再跑——绝不静默跳过，也不把"工具装不上"误判成"代码违规"。

## 六、与其他文件的关系

- 清单填充：`apply-harness` 渲染时按 `{{DEP_RUNNERS}}` / `{{DEP_TOOLS}}` / `{{DEP_PROJECT}}` 占位符生成
- 调用方：`check-style.sh`（lint）、`static-analysis.sh`（vet/lint）、`coverage.sh`（cov）、
  `arch-check.sh`（arch）、`security-scan.sh`（sec）
- 人肉入口：`docs/harness-usage.md` 第 1 节（接入后 `check all` / `install all` 体检）