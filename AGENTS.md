# AGENTS.md

Antigravities 是基于 Go 语言（`CGO_ENABLED=0`）与 [MyGo](https://github.com/egoist/mygo) 桌面框架构建的轻量级 Antigravity 账号管理与切换工具。维护 Google OAuth 2.0 PKCE 认证生命周期，后台巡检与监控模型配额，并在 Antigravity IDE、经典桌面端与 `agy` CLI 间安全切换凭据。

---

## 🌐 核心约定：中文主导

- **语言规范**：项目内所有文档编写、代码注释、Git Commit 提交信息、Issue/PR 讨论以及 AI Agent 的思考与响应，**一律以中文为主要语言**。专有名词（如 OAuth、PKCE、CGO、SQLite）保持通用英文缩写。

---

## 📚 参考项目与详细规格索引

| 资源 | 路径 / 链接 | 职责与参考内容 |
|---|---|---|
| **MyGo 框架** | `/Users/aaron/repos/mygo` | **底层技术底座**：Purego 原生绑定、主线程事件循环、声明式 UI (`mygo/ui`) 与构建规范。 |
| **Antigravity-Manager** | `/Users/aaron/repos/Antigravity-Manager` | **核心业务移植源**：OAuth 回环 (`oauth.rs`)、配额计算 (`quota.rs`)、账号存储 (`account.rs`)、SQLite 注入 (`db.rs`)。 |
| **模块规划与开发切片** | [`docs/product/`](docs/product/) | 包含 6 大模块的详细实现逻辑与面向初学者的渐进式切片开发计划 (`plan.md`)。 |
| **UI 交互设计稿** | [`docs/product/ui/mockup.html`](docs/product/ui/mockup.html) | macOS 原生风格托盘与 Flyout 弹窗高保真交互原型。 |
| **初学者实战教程** | [`docs/tutorial/`](docs/tutorial/) | 基于 VitePress 的渐进式实战教程（8个章节）。 |

---

## ⚡ 硬性开发铁律

1. **绝对零 Cgo (`CGO_ENABLED=0`)**：
   - 全库严禁编写 `import "C"`，所有跨平台系统调用依托 `purego` 或 `syscall`。
   - SQLite 操作强制采用纯 Go 驱动（`modernc.org/sqlite`）。
2. **主线程 UI 渲染纪律**：
   - 所有的视图更新与状态变更必须在主线程执行；后台 Goroutine 必须通过 `app.OnMain(...)` 派发。
3. **免除 Web 构建运行时**：
   - 直接使用 MyGo 原生声明式组件 (`ui.Context`) 绘制界面，禁止引入 Node/Bun/Vite 等前端打包流水线进入最终应用。
4. **禁止静默自动切换账号**：
   - 后台仅更新配额缓存与托盘状态；账号切换**必须由用户在界面显式触发**，防止中断编码进程。

---

## 🛠 常用命令 (Verified)

> 💡 **环境隔离提示**：根目录通过 `Makefile` (`export CGO_ENABLED := 0`) 及 `.envrc` 严格限定环境作用域，**不污染开发者全局 Go 环境**。推荐优先使用 `make` 指令。

| 命令 | 用途 | 预估耗时 |
|---|---|---|
| `make build` / `go build ./...` | 本地完整编译检查 (`CGO_ENABLED=0`) | ~2s |
| `make run` / `go run .` | 启动本地桌面应用与托盘常驻 | ~1s |
| `make test` / `go test -v ./...` | 执行各模块单元测试 | ~3s |
| `make vet` / `go vet ./...` | Go 官方静态代码分析 | ~1s |
| `make cross-darwin-arm64` | 编译 Apple Silicon 原生二进制 | ~3s |
| `make cross-windows` | 验证 Windows 交叉编译 | ~3s |
| `make cross-linux` | 验证 Linux 交叉编译 | ~3s |
| `make cross-compile` | 一键并发交叉编译全平台二进制产物 | ~6s |
| `make tutorial-dev` | 启动本地 VitePress 教程文档服务器 | ~1s |

---

## 📂 目录结构与职责映射

```text
.
├── AGENTS.md               # Agent 开发指南与架构铁律（本文档）
├── README.md               # 面向用户的项目主页与快速入门
├── Makefile                # 局部限定 CGO_ENABLED=0 与常用工程指令
├── .envrc                  # direnv 本地环境变量隔离
├── go.mod / go.sum         # Go 模块与依赖版本锁定
├── main.go                 # 程序入口、MyGo 运行时初始化、托盘挂载
├── internal/
│   ├── account/            # 账号模型、accounts.json 原子写入与并发读写锁
│   ├── config/             # 全局配置、轮询周期、偏好目标 IDE
│   ├── integration/        # state.vscdb 注入 (SQLite)、Protobuf 序列化、Keychain 同步
│   ├── oauth/              # Google OAuth 2.0 PKCE 流程、本地回环服务器、Token 刷新
│   ├── quota/              # 模型额度解析、后台巡检引擎、Jitter 防风控
│   └── ui/                 # MyGo 原生声明式 UI、托盘控制器、Flyout 弹窗
└── docs/
    ├── product/            # 6 大模块的详细规范、数据结构与切片计划 (plan.md)
    └── tutorial/           # 基于 VitePress 的 Go 初学者教学工程
```

---

## 🧭 决策启发式矩阵 (Heuristics)

| 场景 | 处理准则 |
|---|---|
| 修改 SQLite 数据库 (`state.vscdb`) | 先判断客户端是否运行；写入前必须生成 `.bak` 备份，并在单一事务内执行。 |
| 后台配额查询遭遇网络失败或 401/403 | 标记该账号 Token 异常并更新托盘警报，严禁抛出致命 Panic 导致程序崩溃。 |
| 引入新的第三方 Go 依赖库 | 必须验证其在 `CGO_ENABLED=0` 且多平台下可顺利编译通过，拒绝任何带 Cgo 依赖的库。 |
| 后台协程需要更新 UI 数据 | 必须使用 `mygo.App.OnMain(func() { ... })` 包装派发。 |

---

## 🚫 行为边界规范 (Boundaries)

### 必须做 (Always Do)
- 所有代码注释、文档与提交信息严格使用中文。
- 保证多平台在 `CGO_ENABLED=0` 下无错误编译通过。
- 对配置文件 `accounts.json` 采用原子写盘机制（临时文件 + Sync + Rename）。
- 保持数据结构与 `Antigravity-Manager` 保持 1:1 双向兼容。

### 需先确认 (Ask First)
- 引入除 `mygo` / 标准库以外的新核心第三方依赖前。
- 变更 `state.vscdb` 的 Protobuf 注入结构或修改未约定的存储键名。
- 实施具有破坏性的外部进程强杀（`kill -9`）。

### 绝对不做 (Never Do)
- 严禁引入 `import "C"` 或要求本地环境配置 C 编译器。
- 严禁在后台静默自动切换编辑器账号。
- 严禁在主线程事件循环中执行耗时的同步网络请求或重度文件 I/O。
- 严禁将任何明文密钥、Token 凭据提交进 Git 仓库。
