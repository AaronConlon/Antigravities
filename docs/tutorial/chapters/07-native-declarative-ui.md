# 07. MyGo 声明式原生 UI 与状态绑定

在本章中，我们将把前面几章写好的账号管理器、OAuth 登录和 SQLite 注入器，与桌面界面紧密结合在一起。我们将学习 **MyGo 声明式 UI 范式**，并掌握 GUI 编程中最重要的**主线程调度规则 (`app.OnMain`)**。

---

## 1. 声明式 UI（Declarative UI）编程模型

传统的命令式 GUI 编程（如 MFC、Swing 等）需要手动创建按钮、计算坐标并逐个调用 `button.setText(...)`。

而在 MyGo 中，采用了现代声明式语法：**“界面是当前状态的直接映射（UI = f(State)）”**。

```go
package ui

import (
	"github.com/egoist/mygo/ui"
	"antigravities/internal/account"
)

// RenderAccountCard 声明单个账号卡片
func RenderAccountCard(c *ui.Context, acc *account.Account, onSwitch func()) {
	t := c.Theme()

	// 纵向卡片容器
	card := ui.Column(c).
		Padding(12).
		Radius(8).
		Gap(8)

	if acc.IsActive {
		card.Background(t.Accent.WithAlpha(0.1)).Border(1, t.Accent)
	} else {
		card.Background(t.Surface).Border(1, t.Border)
	}

	card.Children(func() {
		// 横向排列：头像 + 邮箱 + 切换按钮
		ui.Row(c).AlignItems(ui.Center).Gap(10).Children(func() {
			ui.Text(c, acc.Email).Bold().Grow(1)

			if acc.IsActive {
				ui.Text(c, "生效中").Color(t.Success).FontSize(11)
			} else {
				ui.Button(c, "切换").OnClick(onSwitch)
			}
		})
	})
}
```

---

## 2. 铁律：永远通过 `app.OnMain` 跨协程更新 UI

GUI 框架（无论 macOS AppKit、Windows Win32 还是 Linux GTK）的窗口事件循环都在**主操作系统线程（Main OS Thread）**上运行。

> ⚠️ **新手最容易踩的坑**：
> 如果你在后台网络请求协程里直接调用 `window.SetTitle(...)` 或修改绑定在视图上的数据，程序可能会偶发崩溃（`fatal error: concurrent map writes` 或系统底层段错误 Segmentation Fault）。

**正确姿势：**
当后台协程完成工作后，通过 `mygo.App.OnMain` 把更新任务派发回主线程队列：

```go
// 后台协程中执行 OAuth 登录
go func() {
	result, err := oauthSvc.StartLoginFlow(ctx)
	if err != nil {
		log.Printf("登录失败: %v", err)
		return
	}

	// 关键：将状态回传给主线程执行
	mygo.App.OnMain(func() {
		// 这里是在主线程执行，更新数据和重绘完全安全！
		accountStore.Add(result.Account)
		refreshUI()
	})
}()
```

---

## 3. 对齐设计稿：完整的 Flyout 弹窗设计

在我们的产品设计稿 [mockup.html](https://github.com/AaronConlon/Antigravities/blob/main/docs/product/ui/mockup.html) 中，主弹窗拥有精美的毛玻璃材质、环境切换栏、当前生效账号卡片与备用账号列表。

在 MyGo 中，我们只需将其拆分为清晰的组件函数：
- `RenderHeader(c)`：展示应用标题与添加账号按钮；
- `RenderTargetSelector(c)`：选择目标客户端（IDE / Classic / agy）；
- `RenderActiveCard(c, activeAcc)`：展示活跃账号与模型额度条；
- `RenderAccountList(c, standbyAccounts)`：循环渲染备用账号行。

在下一章中，我们将进入终章：**如何将我们的纯 Go 桌面程序编译并打包发布到多个平台！**
