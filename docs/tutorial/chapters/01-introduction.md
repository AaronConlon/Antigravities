# 01. 序言与纯 Go 桌面开发哲学

欢迎来到 Antigravities 开发实战！在开始编写第一行代码之前，我们先来探讨一个对于 Go 初学者非常关键的问题：**为什么我们要用纯 Go 开发桌面应用？我们该如何跨越技术选型的陷阱？**

---

## 1. 为什么不用 Electron 或 Tauri？

过去开发桌面客户端，大多数人首先想到的是：
- **Electron**：Chromium + Node.js。优点是 Web 生态丰富，但缺点是打包体积大（动辄 100MB+），启动慢，且空闲内存占用常年维持在数百兆。
- **Tauri**：Rust 后台 + 系统 WebView。相比 Electron 已经轻量很多，但开发需要同时掌握 Rust 语法、Node 打包流水线（Vite、Rollup 等），构建时还要依赖大量 C 库。

而在 Go 语言生态中，我们有了 **MyGo** (`github.com/egoist/mygo`)：
- **零 Cgo（Zero-Cgo）**：纯 Go 代码，不需要在机器上配置 GCC / Clang / MinGW。
- **直接绘制的原生声明式 UI (`mygo/ui`)**：使用纯 Go 构建界面，完全摆脱了 Node.js、Bun、Webpack、Vite 等繁重的 Web 前端工具链。
- **极致的启动速度与内存**：启动只需几十毫秒，空闲常驻内存低至 20MB。
- **单二进制交付**：最终编译产物就是一个干净、独立的 Go 可执行文件，双击即运行。

---

## 2. 核心架构设计思想

Antigravities 作为一个专为 Antigravity 开发者设计的账号切换与配额监控工具，其核心设计遵循以下原则：

1. **宁缺毋滥的依赖管理**：
   - 拒绝引入带 Cgo 的包。
   - 数据库操作使用纯 Go 编写的 `modernc.org/sqlite`。
   - 底层系统调用通过纯 Go 的 `purego`（macOS/Linux）或标准库 `syscall`（Windows）。
2. **安全第一的显式控制**：
   - 后台默默刷新配额，但**账号切换绝不静默发生**，必须由用户在托盘显式点击。
   - 对任何外部 SQLite 数据库（如 VS Code 的 `state.vscdb`）的修改，前置必须自动生成 `.bak` 备份文件。
3. **主线程与并发纪律**：
   - 网络 I/O（OAuth 授权、配额请求）全部放在独立 Goroutine 中异步运行。
   - 所有 UI 组件的修改和状态变更，强制排队回主线程 (`app.OnMain(...)`) 执行，杜绝界面渲染崩溃。

在下一章中，我们将开始配置本地开发环境，并写出我们的第一个 MyGo 托盘程序！
