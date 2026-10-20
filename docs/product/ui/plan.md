# 原生桌面 UI 与托盘模块开发计划 (UI & Tray Module Slices)

本文档面向 Go 初学者，详细拆解基于 **MyGo 原生声明式 UI**（`mygo/ui`）构建托盘与主面板的 4 个开发切片。

---

## 🍰 切片总览

| 切片编号 | 切片名称 | 涉及核心 Go 概念 | 交付成果 |
|---|---|---|---|
| **Slice-UI-01** | MyGo 应用生命周期管理与托盘常驻 | `mygo.App`、`mygo.Tray`、Go 1.16+ 资源嵌入 (`embed.FS`) | `internal/ui/tray.go` 及托盘初始化 |
| **Slice-UI-02** | Flyout 弹窗窗口创建与 Vibrancy 毛玻璃 | 原生窗口选项 (`WindowOptions`)、失焦自动收起机制 | `internal/ui/window.go` 及窗口控制器 |
| **Slice-UI-03** | 声明式账号卡片与配额条组件封装 | `mygo/ui` 声明式 Context、行排版 (`Row`)、列排版 (`Column`) | `internal/ui/account_card.go`, `quota_view.go` |
| **Slice-UI-04** | 主线程状态更新 (`app.OnMain`) 与交互联动 | 异步操作向主线程分发、点击事件绑定、UI 重绘驱动 | `internal/ui/app.go` 及联调闭环 |

---

### 🔹 Slice-UI-01: MyGo 应用生命周期管理与托盘常驻

#### 1. 切片目标
在应用程序启动后，保持常驻在后台与系统顶部菜单栏（macOS Menu Bar），不显示任何常规 Dock 栏大窗口，左键点击托盘图标时触发事件。

#### 2. Go 初学者知识点解析
- **`//go:embed` 静态资源内嵌**：Go 1.16 引入的标准库特性，直接将托盘图标 PNG / ICNS 二进制编译进 Go 执行文件中，无需分发零散的图片文件。
- **MyGo 常驻生命周期**：
  ```go
  app.OnWindowAllClosed(func() {}) // 窗口全关时不退出
  ```

#### 3. 落地文件与接口
- 新建文件：`internal/ui/tray.go`
- 核心函数：
  - `InitTray(app *mygo.Application) (*mygo.Tray, error)`

---

### 🔹 Slice-UI-02: Flyout 弹窗窗口创建与 Vibrancy 毛玻璃

#### 1. 切片目标
实现一个弹出式窗口（宽 390px，高 560px），位置自动吸附在托盘图标正下方，具备原生系统的毛玻璃背景材质（macOS Vibrancy），并在用户点击窗口外侧或按 Esc 时自动隐藏。

#### 2. Go 初学者知识点解析
- **无边框窗口参数**：`TitleBarStyle: mygo.TitleBarHidden`，配合操作系统原生 Popover 样式。

#### 3. 落地文件与接口
- 新建文件：`internal/ui/window.go`
- 核心函数：
  - `ToggleFlyout(tray *mygo.Tray)`

---

### 🔹 Slice-UI-03: 声明式账号卡片与配额条组件封装

#### 1. 切片目标
使用纯 Go 代码（无 HTML/CSS/JS）通过 `mygo/ui` 绘制出如设计稿 [mockup.html](mockup.html) 所展示的账号卡片与进度条。

#### 2. Go 初学者知识点解析
- **声明式 UI 范式**：通过类似 Flutter / SwiftUI 的函数嵌套方式构建界面：
  ```go
  func RenderAccountCard(c *ui.Context, acc *account.Account) {
      ui.Column(c).Padding(12).Background(t.Surface).Children(func() {
          ui.Row(c).Children(func() {
              ui.Text(c, acc.Email).Bold()
          })
      })
  }
  ```

#### 3. 落地文件与接口
- 新建文件：`internal/ui/account_card.go`
- 新建文件：`internal/ui/quota_view.go`

---

### 🔹 Slice-UI-04: 主线程状态更新 (`app.OnMain`) 与交互联动

#### 1. 切片目标
当后台 OAuth 登录完成或配额轮询获得最新数据时，安全地跨协程将状态通知传递给主线程 UI，并触发视图局部刷新。

#### 2. Go 初学者知识点解析
- **`app.OnMain(func() { ... })`**：GUI 编程的黄金铁律——**“永远不要在子协程直接操作界面组件”**。`OnMain` 将回调安全排入主 OS 线程的消息队列，杜绝线程竞争与崩溃。

#### 3. 落地文件与接口
- 新建文件：`internal/ui/state.go`
- 串联测试：启动应用，点击备用账号切换，验证界面即时更新且无闪烁。
