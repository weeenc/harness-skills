# Frontend 语言规范包

## 概述

Harness Frontend 语言规范包为前端项目提供完整的开发规范体系，基于 TypeScript 严格模式，支持 Vue 3、React、Angular、Svelte、Next.js、Nuxt 等主流前端框架，覆盖 Vite、Webpack、Angular CLI、Turbopack 等构建工具。

## 基线

| 维度 | 选型 |
|------|------|
| **基线框架** | Vue 3.4+ / React 18+ / Angular 18+ / Svelte 5.x / Next.js 15.x / Nuxt 4.x |
| **构建工具** | Vite 5.x / Webpack 5.x / Angular CLI 18+ / Turbopack |
| **测试框架** | Vitest / Jest / Jasmine + Karma（按框架选择） |
| **覆盖率工具** | c8 / istanbul（核心逻辑覆盖率 ≥80%） |
| **代码规范** | ESLint 扁平配置 + Prettier + TypeScript strict 模式 |
| **状态管理** | Pinia / Redux / Zustand / NgRx（按框架选择） |
| **路由** | Vue Router 4.x / React Router 6.x / Angular Router 18+ |
| **HTTP 请求** | Axios（封装） |

## 规则

| 规则 | 来源 |
|------|------|
| 编码规范 | `harness-front/rules/`（语言特有） |
| 工程结构 | `harness-front/rules/`（语言特有） |
| 运行时可靠性 | `harness-front/rules/`（前端特有，覆盖通用版） |
| SDD-TDD 模式 | `harness-core/rules/`（跨语言通用） |
| 开发流程规范 | `harness-core/rules/`（跨语言通用） |

> **注意**: 前端项目的 `运行时可靠性.md` 使用 `harness-front` 的前端特有版本（覆盖通用版），包含前端特有的加载态、错误处理、权限控制等。

### 编码规范要点

- Vue 3 组合式 API（`<script setup>` 语法）
- TypeScript strict 模式，禁止 `any`
- 组件名：PascalCase
- 文件 ≤400 行
- 组件 ≤200 行
- 函数 ≤30 行
- 禁止 Magic Number 和内联样式
- 组件必须使用 `defineProps` + `defineEmits` 显式声明

### 工程结构要点

- 基于构建工具的标准目录结构（Vite / Webpack / Angular CLI）
- 页面组件放在 `pages/` 或 `views/`（Next.js 用 `app/` 或 `pages/` 目录）
- 通用组件放在 `components/`
- 路由层做权限校验
- API 调用封装在 `api/` 或 `services/` 模块，不直接在组件中写请求
- 状态管理集中管理（Pinia / Redux / Zustand / NgRx）

## 技能

9 个技能（6 流水线 + 3 辅助），与语言无关的通用技能直接复用 `harness-core` 的模板。

## 适用项目

- Vue 3 / React / Angular / Svelte / Next.js / Nuxt 项目
- Vite / Webpack / Angular CLI 构建的前端项目
- 需要严格类型安全和代码规范的前端项目