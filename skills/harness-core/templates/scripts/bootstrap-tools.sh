#!/usr/bin/env bash
# 门禁底层依赖体检/自举 — bootstrap-tools.sh [check|install] [gate]
#
# 职责边界（重要——本脚本不修改项目构建配置，也不"安装" Maven/Gradle 插件或库）：
#   runners : 构建/运行器（mvn / ./gradlew / npm / go / python / pip / cargo / composer 等）。
#             必需基础，缺失时给出手动安装指引（脚本不自动装，避免动系统级工具链）。
#   tools   : 可安全自动安装的独立工具（npm install -D / pip install / go install / rustup add /
#             cargo install 类）。check 模式检测，install 模式自动执行安装命令。
#   project : 项目内【声明】组件——Maven/Gradle 插件（checkstyle/jacoco/pmd/spotbugs…）、
#             测试与运行库（assertj、spring-boot-starter-actuator…）、package.json devDependencies。
#             只能检测是否已在构建文件中声明 + 输出合入指引，绝不自动改写 pom.xml / build.gradle /
#             package.json / composer.json（自动改构建配置的副作用不可控，属于规范流程范畴）。
#
# gate 参数：all（默认，检查全部依赖）| lint | vet | cov | arch | sec
#   每个依赖项声明自己的消费 gate（逗号分隔），单 gate 只查相关项，避免无关缺失误伤。
#
# 退出码: 0=所查依赖全部就绪
#         1=存在缺失（runners/tools 未装；install 模式可修复，tools 类自动装）
#         2=存在待人工合入的项目组件（指引已输出；此时该 gate 无法真实执行，应显式降级而非误判违规）
set -uo pipefail

# 锚定项目根（不依赖 cwd：hooks / 外部绝对路径/子目录调用时保持同一基准）
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 3

MODE="${1:-check}"
GATE="${2:-all}"

# ---------- 依赖清单（apply-harness 渲染时按项目语言/构建工具填充，勿手改） ----------
# runners 格式: 命令名（command -v 检测）
RUNNERS=({{DEP_RUNNERS}})
# tools 格式:  gates|name|install_cmd
TOOLS=(
{{DEP_TOOLS}}
)
# project 格式: gates|name|file|probe|合入指引
PROJECT=(
{{DEP_PROJECT}}
)

wanted() { # $1=gates 标签串, 匹配参数 GATE
  [ "$GATE" = "all" ] && return 0
  case ",$1," in
    *,"$GATE",*|*,all,*) return 0 ;;
  esac
  return 1
}

miss=0        # 缺失数（可修复）
manual=0      # 待人工合入数
checked=0

echo "== 门禁依赖体检（gate: $GATE, 模式: $MODE） =="

# ---------- runners ----------
echo "-- 运行器"
for r in "${RUNNERS[@]:-}"; do
  [ -n "$r" ] || continue
  checked=$((checked+1))
  if command -v "$r" >/dev/null 2>&1; then
    echo "[OK] 运行器 $r 可用"
  else
    echo "[MISS] 运行器 $r 未安装——请先安装（如 Maven: brew install maven / apt install maven / 官方 zip 解压加 PATH）"
    miss=$((miss+1))
  fi
done

# ---------- tools ----------
echo "-- 独立工具（install 模式自动安装）"
for t in "${TOOLS[@]:-}"; do
  [ -n "$t" ] || continue
  IFS='|' read -r tg name cmd <<< "$t"
  wanted "$tg" || continue
  checked=$((checked+1))
  if command -v "$name" >/dev/null 2>&1; then
    echo "[OK] 工具 $name 可用"
  elif [ "$MODE" = "install" ]; then
    echo "-- 安装 $name: $cmd"
    if eval "$cmd" >/dev/null 2>&1; then
      echo "[OK] 工具 $name 已安装"
    else
      echo "[FAIL] 工具 $name 安装失败（exit=$?）——请手动执行: $cmd"
      miss=$((miss+1))
    fi
  else
    echo "[MISS] 工具 $name 未安装（自动安装: $cmd）"
    miss=$((miss+1))
  fi
done

# ---------- project ----------
echo "-- 项目内声明组件（只检测 + 指引，不自动改写构建配置）"
for p in "${PROJECT[@]:-}"; do
  [ -n "$p" ] || continue
  IFS='|' read -r tg name file probe guide <<< "$p"
  wanted "$tg" || continue
  checked=$((checked+1))
  if [ -f "$file" ] && grep -q -- "$probe" "$file" 2>/dev/null; then
    echo "[OK] $name 已在 $file 中声明"
  else
    echo "[GUIDE] $name 未在 $file 中声明 → $guide"
    manual=$((manual+1))
  fi
done

echo "== 体检完成: $checked 项检查, $miss 项缺失, $manual 项待人工合入 =="

rc=0
[ "$miss" -gt 0 ] && rc=1
[ "$manual" -gt 0 ] && rc=2
[ "$miss" -gt 0 ] && [ "$manual" -gt 0 ] && rc=1   # 缺失更紧急
exit "$rc"