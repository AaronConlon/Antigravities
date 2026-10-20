# 02. 环境搭建与首个托盘窗口

本章我们将初始化 Go 模块，引入 MyGo 框架依赖，并编写一个能够常驻在 macOS 顶部菜单栏的最简桌面窗口。

---

## 1. 准备工作

确保你的电脑上已经安装了 **Go 1.23+**。在终端中执行以下命令检查版本：

```bash
go version
# 输出示例: go version go1.24.0 darwin/arm64
```

### 环境变量隔离：如何不影响其他 Go 项目？

很多初学者容易犯的一个错误是：直接在系统的 `~/.zshrc` 或 `~/.bashrc` 中写入 `export CGO_ENABLED=0`，或者运行全局的 `go env -w CGO_ENABLED=0`。

> ⚠️ **隐患**：如果你的电脑上同时还在开发其他依赖 CGO 的项目（例如使用了带 C 依赖的音视频编解码库或传统的 `go-sqlite3`），全局禁用 CGO 会导致那些项目无法正常构建！

**最佳实践：局部限定（Project-scoped Environment）**

在 Antigravities 中，我们通过根目录的 **`Makefile`** 和 **`.envrc`** 来实现无侵入的局部限定：

1. **Makefile 自动注入**：
   在 `Makefile` 顶部声明：
   ```makefile
   export CGO_ENABLED := 0
   ```
   只要通过 `make run`、`make build`、`make test` 执行任务，`CGO_ENABLED=0` 仅对当前进程树生效，一旦退出 make 命令，你的终端全局环境没有任何变化！
2. **配合 direnv (`.envrc`)**：
   若你安装了 [direnv](https://direnv.net/)，进入该目录时会自动激活 `.envrc`，离开目录时自动还原。

> 💡 **初学者提示**：关于什么是 CGO、它的运行开销以及为什么我们坚决选择禁用它，请参考第一章的专门讲解：[01. 深入理解：什么是 CGO？为什么要坚决禁用它（CGO_ENABLED=0）？](./01-introduction.md#2-深入理解什么是-cgo为什么要坚决禁用它cgo_enabled0)。

---

## 2. 初始化 Go Module

在项目根目录下初始化 Go 模块并添加 MyGo 依赖：

```bash
go mod init github.com/aaron/antigravities
go get github.com/egoist/mygo@latest
```

---

## 3. 编写第一个常驻托盘应用 (`main.go`)

在根目录下创建 `main.go`，体验 MyGo 的极简 API：

```go
package main

import (
	"log"

	"github.com/egoist/mygo"
	"github.com/egoist/mygo/ui"
)

func main() {
	app := mygo.App
	app.SetName("Antigravities")

	// 关键生命周期 1: 窗口全部关闭时不退出程序（保持托盘常驻）
	app.OnWindowAllClosed(func() {})

	app.WhenReady(func() {
		log.Println("Antigravities 已就绪，正在初始化托盘...")

		// 初始化托盘
		tray := app.NewTray()
		tray.SetTitle(" 78%") // 在 macOS 菜单栏展示简短配额

		// 为托盘绑定菜单项
		menu := mygo.NewMenu([]*mygo.MenuItem{
			{
				Label: "打开控制面板",
				Click: func(*mygo.MenuItem, *mygo.Window) {
					openFlyoutWindow()
				},
			},
			mygo.Separator(),
			{
				Label: "退出 Antigravities",
				Click: func(*mygo.MenuItem, *mygo.Window) {
					app.Quit()
				},
			},
		})
		tray.SetMenu(menu)
	})

	// 启动事件循环
	if err := app.Run(); err != nil {
		log.Fatal(err)
	}
}

func openFlyoutWindow() {
	// 创建一个无边框的原生毛玻璃窗口
	mygo.NewWindow(mygo.WindowOptions{
		Title:         "Antigravities",
		Width:         390,
		Height:        560,
		TitleBarStyle: mygo.TitleBarHidden,
		Content: func(c *ui.Context) {
			t := c.Theme()
			c.Root().Background(ui.Transparent)

			ui.Column(c).Fill().Padding(16).Background(t.Surface).Radius(12).Children(func() {
				ui.Text(c, "Antigravities 控制中心").FontSize(16).Bold()
				ui.Text(c, "纯 Go 声明式 UI 已成功就绪！").Color(t.Muted)
			})
		},
	})
}
```

---

## 4. 运行与验证

在终端中执行：

```bash
go run .
```

你会看到：
1. macOS 顶部菜单栏出现带有 `78%` 文字的托盘图标；
2. 点击托盘图标中的“打开控制面板”，屏幕上会弹出一个原生渲染的毛玻璃卡片窗口；
3. 检查系统活动监视器（Activity Monitor），你会发现它的内存占用极低（通常不到 30MB）！

在下一章中，我们将进入业务开发的第一步：**如何为账号设计结构体，并实现工业级安全的原子文件写入**。
