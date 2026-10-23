# PHP 语言规范包

> 当前状态：本文件保留 PHP 规范设计；入口技能已包含 PHP 检测与参数，但当前项目缺少 `skills/harness-php/` 及其规则文件。下文是规范目标，完整使用前需补齐语言包。

## 概述

Harness PHP 语言规范包为 PHP 项目提供完整的开发规范体系，基于 PHP-FIG 建议（PSR-12）与 PHPStan 静态分析，支持 Laravel、ThinkPHP、Hyperf、Yii / Yii 3、Workerman、CodeIgniter (CI) / Slim、Phalcon、CakePHP、Symfony2、Yaf、Swoole、webman 等 Web/网络框架，WordPress、WooCommerce、Drupal、Joomla、phpcms、dedecms、discuz、Craft CMS、October CMS、OpenCart、GravCMS 等 CMS/电商系统，以及 Laravel AI SDK、Neuron AI、LLPhant、Prism、PocketFlow PHP、Cognesy Instructor PHP、Papiai 等 AI/LLM 框架。

## 基线

| 维度 | 选型 |
|------|------|
| **基线框架** | PHP 8.2+ / Laravel / ThinkPHP / Hyperf / Yii / Yii 3 / Workerman / CodeIgniter (CI) / Slim / Phalcon / CakePHP / Symfony2 / Yaf / Swoole / WordPress / Drupal / Laravel AI SDK / LLPhant / Prism |
| **构建工具** | composer install（composer.json + PSR-4 autoload） |
| **测试框架** | PHPUnit（核心逻辑覆盖率 ≥80%） |
| **覆盖率工具** | phpunit --coverage-text |
| **代码规范** | phpstan level 8 + php-cs-fixer |
| **架构约束** | phpstan 架构约束 + 自定义检查 |
| **安全扫描** | composer audit |
| **数据库** | Doctrine ORM / Eloquent + 迁移 |

## 规则

| 规则 | 来源 |
|------|------|
| 编码规范 | `harness-php/rules/`（语言特有） |
| 工程结构 | `harness-php/rules/`（语言特有） |
| SDD-TDD 模式 | `harness-core/rules/`（跨语言通用） |
| 开发流程规范 | `harness-core/rules/`（跨语言通用） |
| 运行时可靠性 | `harness-core/rules/`（跨语言通用） |

### 编码规范要点

- 遵循 PSR-12 + strict_types + 强类型宣言
- 命名规范：`camelCase`（方法）、`PascalCase`（类）、`snake_case`（数据库列）
- 错误处理：异常捕获明确，禁止空 catch 吞错
- 类型安全：PHPStan level 8，禁止 `@var` 掩盖类型问题
- 文件 ≤400 行
- 方法 ≤40 行
- 依赖注入：构造器注入优先，避免静态 facade 滥用

### 工程结构要点

- 标准 PHP 工程布局（`app/`、`public/`、`src/`、`tests/`、`config/`、`database/`）
- 遵循框架约定：Laravel `app/`、Symfony `src/`、ThinkPHP `app/`、Hyperf `app/` 分层
- Controller 薄、Service 承载业务、Model 数据访问（依赖单向）
- HTTP 处理：Laravel / ThinkPHP / Hyperf 路由 → Controller → Service
- CMS/电商：WordPress hooks（动作/过滤器）、Drupal 模块 hooks、WooCommerce 插件扩展
- AI/LLM：Laravel AI SDK / LLPhant / Prism Agent 编排，PocketFlow / Papiai 流程框架

## 技能

10 个流水线/辅助技能由 `apply-harness` 从 `harness-core/skills/` 模板渲染（唯一事实源），PHP 语言包不维护同名副本；语言特有内容承载在 `rules/` 中。

## 适用项目

- Laravel / ThinkPHP / Hyperf / Yii / Yii 3 / CodeIgniter (CI) / Slim / Phalcon / CakePHP / Symfony2 / Yaf Web 应用
- Workerman / Swoole / webman 常驻与协程高性能服务
- WordPress / WooCommerce / Drupal / Joomla / phpcms / dedecms / discuz / Craft CMS / October CMS / OpenCart / GravCMS CMS 与电商站点
- Laravel AI SDK / Neuron AI / LLPhant / Prism / PocketFlow PHP / Cognesy Instructor PHP / Papiai AI 应用
- PHP 8.2+ 项目