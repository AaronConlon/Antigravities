# Antigravities

<div align="center">

**纯 Go 原生（Zero-Cgo）极轻量 Antigravity 多账号管理与切换桌面工具**

[![Go Version](https://img.shields.io/badge/Go-1.23%2B-00ADD8?logo=go&logoColor=white)](https://golang.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Windows%20%7C%20Linux-blue)](#)
[![Zero Cgo](https://img.shields.io/badge/CGO-Disabled%20(0)-success)](#)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

[产品模块规划](docs/product/) · [UI 交互设计稿 (Mockup)](docs/product/ui/mockup.html) · [初学者实战教程](docs/tutorial/)

</div>

---

## 💡 为什么选择 Antigravities？

在日常使用 Antigravity 进行 AI 辅助编程时，开发者常需要在不同账号间流转、应对突发模型限流，或在 IDE、桌面端与 CLI 工具间同步凭据。以往的解决方案多依赖重量级的 Electron 或复杂的混合技术栈。

**Antigravities** 采用纯 Go 语言与 [MyGo](https://github.com/egoist/mygo) 原生声明式桌面框架打造：
- ⚡ **严格零 Cgo（`CGO_ENABLED=0`）**：无任何 C 语言依赖或编译器包袱，秒级构建，极简跨平台分发。
- 🖥 **原生绘制与极低开销**：告别 Chromium / Node.js 运行时，纯 Go 原生绘制，常驻内存仅 ~20MB，启动瞬时就绪（<100ms）。
- 🎨 **macOS 原生美学**：常驻系统菜单栏托盘，搭配 macOS Vibrancy 毛玻璃材质 Flyout 弹窗与呼吸状态指示灯。
- 🔒 **工业级安全与一致性**：凭据文件原子落盘（防断电破坏）、修改 VS Code 存储前自动生成 `.bak` 备份并使用事务保护。

---

## ✨ 核心特性

- **Google OAuth 2.0 PKCE 认证管理**：桌面端免 Client Secret 泄露风险，本地动态回环服务器拦截回调，到期前（15分钟）静默自动刷新 Token。
- **细粒度模型配额监控**：实时解析 Gemini 2.5 Pro、Flash 以及 Claude 模型配额水线，后台低频巡检并附带 Jitter 随机抖动防风控。
- **全场景客户端切换**：
  - **Antigravity IDE**：注入 VS Code 全局存储 `state.vscdb`（纯 Go SQLite 驱动），清理旧版 UserID 脏数据。
  - **Antigravity 经典桌面端**：环境智能探测与客户端安全热重启。
  - **`agy` CLI 凭据同步**：深度联动 macOS Keychain 系统钥匙串，带即时回读校验。
- **无感与显式控制平衡**：后台静默刷新缓存，**账号切换绝不静默发生**，必须由用户在托盘显式触发，绝不打断当前编码会话。

---

## 🎨 UI 界面原型与交互设计

项目提供了独立可交互的本地高保真设计原型，可以在任何现代浏览器中直接预览：

👉 **[查看 macOS 原生 UI 设计稿原型 (docs/product/ui/mockup.html)](docs/product/ui/mockup.html)**

---

## 📚 文档与实战教程

- **[产品模块规划与切片计划 (docs/product/)](docs/product/)**：包含账号存储、OAuth、额度监控、系统集成、配置管理及 UI 等 6 大模块的详细设计与新手切片开发计划。
- **[面向 Go 初学者的实战教程 (docs/tutorial/)](docs/tutorial/)**：基于 VitePress 构建的 8 章节渐进式教学，带你从零掌握纯 Go 桌面开发。

---

## 🛠 常用命令

> 本仓库通过根目录的 `Makefile` 与 `.envrc` 将 `CGO_ENABLED=0` 严格限定在当前工程作用域内，**绝不修改或污染全局 Go 环境**。

```bash
# 查看所有可用指令
make help

# 启动本地开发桌面应用与托盘
make run

# 运行单元测试
make test

# 静态代码检查
make vet

# 编译当前平台二进制 (产物位于 build/)
make build

# 一键交叉编译多平台发布包 (macOS arm64/amd64, Windows, Linux)
make cross-compile

# 启动本地教程站点 (VitePress)
make tutorial-dev
```

---

## 🌐 语言规范约定

本项目所有技术文档、架构规范、代码注释、Git 提交说明及 Agent 交互**均以中文作为主要语言**。
