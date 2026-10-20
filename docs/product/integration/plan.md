# 客户端集成与系统切换模块开发计划 (Integration Module Slices)

本文档面向 Go 初学者，将系统环境探查、数据库注入与钥匙串同步拆解为 5 个由浅入深的开发切片。

---

## 🍰 切片总览

| 切片编号 | 切片名称 | 涉及核心 Go 概念 | 交付成果 |
|---|---|---|---|
| **Slice-INTEG-01** | 目标环境探测与 candidate 路径解析 | `runtime.GOOS`、路径遍历、环境探测算法 | `internal/integration/env.go` 及单元测试 |
| **Slice-INTEG-02** | 纯 Go 轻量 Protobuf 序列化器 | 二进制位运算 (`binary.PutUvarint`)、切片字节拼接、Base64 | `internal/integration/protobuf.go` 及单元测试 |
| **Slice-INTEG-03** | 纯 Go SQLite 凭据注入与写前自动备份 | `database/sql` + `modernc.org/sqlite`（零 Cgo）、事务 (`sql.Tx`)、文件副本拷贝 | `internal/integration/db.go` 及测试 |
| **Slice-INTEG-04** | macOS Keychain 凭据同步与回读验证 | `os/exec.Command` 调用安全工具、纯 Go 系统集成、回读验证 | `internal/integration/keychain_darwin.go` 及测试 |
| **Slice-INTEG-05** | 客户端进程探查、平滑重启与通知 | 跨平台进程列表查询、系统信号 (`syscall.SIGTERM`)、进程拉起 | `internal/integration/process.go` 及切换编排 |

---

### 🔹 Slice-INTEG-01: 目标环境探测与 candidate 路径解析

#### 1. 切片目标
在本地文件系统中定位 Antigravity IDE 和 Antigravity Classic 的存储目录，找到其对应的 `state.vscdb` 数据库文件。

#### 2. Go 初学者知识点解析
- **`os.UserConfigDir()` / `os.UserHomeDir()`**：标准库提供获取当前用户家目录的跨平台方式。
- **文件存在性检查**：在 Go 中判断文件是否存在，惯用写法为 `_, err := os.Stat(path); err == nil || !os.IsNotExist(err)`。

#### 3. 落地文件与接口
- 新建文件：`internal/integration/env.go`
- 核心函数：
  - `FindVscdbPaths(target TargetType) ([]string, error)`

---

### 🔹 Slice-INTEG-02: 纯 Go 轻量 Protobuf 序列化器

#### 1. 切片目标
不借助庞大的 `protoc` 编译器依赖，以极简纯 Go 代码手写构建 Antigravity IDE 所需的 Protobuf 二进制流并转为 Base64 字符串。

#### 2. Go 初学者知识点解析
- **Protobuf Wire Format 编码精要**：
  - 每个字段由 `Tag` (字段编号 << 3 | 线路类型) 和 `Value` 组成。
  - 字符串/字节数组类型（Type 2，Length-delimited）的格式为：`[Tag] [Varint长度] [UTF-8字节]`。
- **`encoding/binary.PutUvarint`**：用于输出变长无符号整数。

#### 3. 落地文件与接口
- 新建文件：`internal/integration/protobuf.go`
- 测试文件：`internal/integration/protobuf_test.go`
- 核心函数：
  - `EncodeOAuthTokenPayload(accessToken, refreshToken string, expiresAt int64) (string, error)`
  - `EncodeUserStatusPayload(email string) string`

#### 4. 审核与测试标准
- 审查清单：
  - [ ] 序列化输出的 Base64 字符串，与 `Antigravity-Manager` 中 Rust `protobuf.rs` 生成的样本逐字节比对必须完全一致。

---

### 🔹 Slice-INTEG-03: 纯 Go SQLite 凭据注入与写前自动备份

#### 1. 切片目标
引入纯 Go SQLite 驱动 `modernc.org/sqlite`（保证 `CGO_ENABLED=0` 完美编译），在修改数据库前备份为 `state.vscdb.bak`，随后在单个数据库事务中完成 `ItemTable` 的注入与脏键清理。

#### 2. Go 初学者知识点解析
- **`database/sql` 驱动注册机制**：匿名导入 `_ "modernc.org/sqlite"`，利用 `init()` 函数向标准库注册纯 Go SQLite 驱动，用法与标准 SQL 完全一致。
- **数据库事务 (`tx.Begin()`)**：在事务中执行多个 SQL，只要任意一条出错就 `tx.Rollback()`，保证数据库要么完全写入、要么完全恢复，绝不处于中间破坏态。

#### 3. 落地文件与接口
- 新建文件：`internal/integration/db.go`
- 测试文件：`internal/integration/db_test.go`
- 核心逻辑：
  ```sql
  INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('antigravityUnifiedStateSync.oauthToken', ?);
  INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('antigravityUnifiedStateSync.userStatus', ?);
  INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('antigravityOnboarding', 'true');
  DELETE FROM ItemTable WHERE key = 'jetskiStateSync.agentManagerInitState';
  ```

#### 4. 审核与测试标准
- 审查清单：
  - [ ] 测试用例自动生成一个 sqlite 数据库样本并执行注入，确认新键写入且旧键已被成功删除。
  - [ ] 验证写入前确已生成 `.bak` 备份文件。

---

### 🔹 Slice-INTEG-04: macOS Keychain 凭据同步与回读验证

#### 1. 切片目标
针对 `agy` CLI 命令行工具，将其认证 Token 同步至 macOS 系统钥匙串（Keychain），并执行即时回读校验，确认 CLI 运行能正常读取。

#### 2. Go 初学者知识点解析
- **条件编译构建标签 (`//go:build darwin`)**：让该文件仅在 macOS 下被编译；对 Windows/Linux 提供占位文件（`keychain_other.go`），实现清晰的跨平台边界。
- **`exec.Command("security", ...)`**：调用 macOS 系统的安全钥匙串命令。

#### 3. 落地文件与接口
- 新建文件：`internal/integration/keychain_darwin.go`
- 新建文件：`internal/integration/keychain_other.go`
- 核心函数：
  - `WriteAgyCredentials(account *account.Account) error`
  - `VerifyAgyCredentials(expectedToken string) error`

---

### 🔹 Slice-INTEG-05: 客户端进程探查、平滑重启与通知

#### 1. 切片目标
检测操作系统中是否有正在运行的 Antigravity 客户端，在凭据写入完成后提供平滑重启支持，并通过 macOS 原生桌面通知向用户确认切换成功。

#### 2. Go 初学者知识点解析
- **`os/exec` 执行跨平台后台进程**：使用 `cmd.Start()` 而不是 `cmd.Run()`，以守护进程方式拉起应用而无需等待应用退出。
- **进程探测与终止**：通过查找进程名称或 PID 发送退出信号。

#### 3. 落地文件与接口
- 新建文件：`internal/integration/process.go`
- 核心函数：
  - `IsAppRunning(target TargetType) bool`
  - `RestartApp(target TargetType) error`
  - `SendSystemNotification(title, message string)`
