---
layout: home

hero:
  name: "Antigravities 实战教程"
  text: "从零构建纯 Go 原生跨平台桌面应用"
  tagline: "零 Cgo、极简单二进制、MyGo 声明式 UI，面向 Go 初学者的渐进式开发指南"
  actions:
    - theme: brand
      text: 立即开始学习 🚀
      link: /chapters/01-introduction
    - theme: alt
      text: 查看 UI 交互设计稿
      link: https://github.com/AaronConlon/Antigravities/blob/main/docs/product/ui/mockup.html

features:
  - icon: ⚡
    title: 严守 Zero-Cgo 哲学
    details: 不引入任何 CGO 依赖，依托 purego 和 syscall 跨平台调用原生 API，秒级编译与极简交叉编译。
  - icon: 🖥
    title: MyGo 纯原生声明式 UI
    details: 无需任何 Node/Webview 臃肿打包，通过 Go 语言原生声明式排版与 macOS Vibrancy 毛玻璃渲染。
  - icon: 🔐
    title: 真实工程级认证与存储
    details: 完整实现 Google OAuth 2.0 PKCE 回环登录、atomic write 原子写盘、SQLite 凭据注入与钥匙串同步。
  - icon: 🍰
    title: 面向初学者的切片设计
    details: 每个章节拆解为 100 行级的小切片，配套详尽的概念解析、错误处理模式和单元测试验证。
---

## 🎯 教程目标

本教程专为想学习 **“如何使用 Go 语言开发真正工业级桌面软件”** 的初学者量身打造。我们将以开源的 **Antigravities**（Antigravity 多账号管理与配额切换工具）为全流程案例，带你一步一步走完：

1. **项目骨架与构建机制**：体验纯 Go 桌面技术选型与架构原则；
2. **凭据安全与原子写盘**：掌握 Go 结构体标签、并发读写锁及 `atomic.Rename` 防破坏技巧；
3. **网络与协议安全**：手把手编写 PKCE 算法、本地临时 HTTP 监听以及 OAuth 2.0 状态机；
4. **数据库与系统集成**：不用 `gcc` 也能通过 `modernc.org/sqlite` 完成数据库事务注入与系统级进程联动；
5. **UI 声明式交互**：从系统托盘图标到交互式 Popover，体会不带 Electron 也能快速写出精致 Mac 质感应用的乐趣！
