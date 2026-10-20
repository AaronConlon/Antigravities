# 账号管理模块开发计划 (Account Module Slices)

本文档面向 Go 语言初学者，将账号管理模块拆解为 4 个轻量级、渐进式的开发切片（Slices）。每个切片控制在 100~200 行代码以内，方便逐个审核与验证。

---

## 🍰 切片总览

| 切片编号 | 切片名称 | 涉及核心 Go 概念 | 交付成果 |
|---|---|---|---|
| **Slice-ACC-01** | 账号数据结构定义与 JSON 序列化 | 结构体 (`struct`)、字段标签 (`json tag`)、时间处理 (`time.Time`) | `internal/account/model.go` 及单元测试 |
| **Slice-ACC-02** | 跨平台 UserDataDir 计算与私有目录创建 | `os` / `path/filepath`、文件权限 (`0700`)、跨平台环境变量 | `internal/account/path.go` 及单元测试 |
| **Slice-ACC-03** | 安全的原子文件写入器 (`AtomicWriteFile`) | `os.CreateTemp`、`defer` 延迟释放、`sync` 刷盘、`os.Rename` 原子替换 | `internal/account/atomic.go` 及单元测试 |
| **Slice-ACC-04** | 账号存储管理服务与并发读写锁 | `sync.RWMutex`、内存 Cache、增删查改、激活切换广播 | `internal/account/store.go` 及全流程测试 |

---

### 🔹 Slice-ACC-01: 账号数据结构定义与 JSON 序列化

#### 1. 切片目标
定义 `Account`、`TokenData`、`QuotaData` 与 `DeviceProfile` 的 Go 结构体，保证其与 `Antigravity-Manager` 的 `accounts.json` 能够相互无缝反序列化（Unmarshal）。

#### 2. Go 初学者知识点解析
- **结构体 (`struct`) 与大写导出规则**：Go 中首字母大写的字段（如 `ID`、`Email`）是公开的（Public），才能被 `encoding/json` 反射读取；小写字段是私有的（Private）。
- **结构体标签 (`json:"..."`)**：告诉 JSON 编解码器键名映射；`omitempty` 表示该字段为空值（`nil`、`""`）时在 JSON 中忽略该字段，避免写入无意义的空字段。

#### 3. 落地文件与接口
- 新建文件：`internal/account/model.go`
- 测试文件：`internal/account/model_test.go`

```go
type TokenData struct {
    AccessToken  string    `json:"access_token"`
    RefreshToken string    `json:"refresh_token"`
    ExpiresAt    time.Time `json:"expires_at"`
    TokenType    string    `json:"token_type"`
}

type Account struct {
    ID          string    `json:"id"`
    Email       string    `json:"email"`
    DisplayName string    `json:"display_name,omitempty"`
    AvatarURL   string    `json:"avatar_url,omitempty"`
    IsActive    bool      `json:"is_active"`
    Token       TokenData `json:"token"`
    UpdatedAt   time.Time `json:"updated_at"`
    CreatedAt   time.Time `json:"created_at"`
}
```

#### 4. 审核与测试标准
- 运行测试：`go test -v ./internal/account -run TestAccountJSON`
- 审查清单：
  - [ ] 验证包含合法与缺失可选字段的 JSON 字符串能否正确反序列化为 `Account`。
  - [ ] 验证序列化时时间格式为 RFC3339。

---

### 🔹 Slice-ACC-02: 跨平台 UserDataDir 计算与私有目录创建

#### 1. 切片目标
解析系统标准的数据目录路径，确保在 macOS、Windows、Linux 下能正确定位到配置目录，并以安全权限（仅当前用户可读写）自动初始化该目录。

#### 2. Go 初学者知识点解析
- **`path/filepath.Join`**：永远不要用字符串拼接 `dir + "/" + file`，`filepath.Join` 会根据操作系统（macOS/Linux 是 `/`，Windows 是 `\`）自动处理分隔符。
- **文件权限模式 (`0700`)**：在 Unix 系统下，`0700` 代表 `rwx------`，即仅当前运行用户拥有读、写、执行权限，其他用户无权访问敏感 Token 文件。

#### 3. 落地文件与接口
- 新建文件：`internal/account/path.go`
- 测试文件：`internal/account/path_test.go`
- 核心函数：
  - `GetAccountsFilePath() (string, error)`
  - `EnsureDirectory(path string) error`

#### 4. 审核与测试标准
- 运行测试：`go test -v ./internal/account -run TestPathResolution`
- 审查清单：
  - [ ] macOS 下输出以 `~/Library/Application Support/Antigravities` 结尾。
  - [ ] 目录创建后，检查其权限模式是否严格为 `0700`。

---

### 🔹 Slice-ACC-03: 安全的原子文件写入器 (`AtomicWriteFile`)

#### 1. 切片目标
实现一个通用的原子写文件函数。若程序在写入大文件时发生崩溃或系统断电，现有文件不会变成半截损坏的空白文件。

#### 2. Go 初学者知识点解析
- **`os.CreateTemp`**：在同目录下创建唯一的临时文件，防止写入冲突。
- **`defer` 语句**：确保即使函数中途出错返回，临时文件也一定能被关闭或清理。
- **`file.Sync()`**：将操作系统内核缓冲区里的数据真正强刷（flush）到物理磁盘扇区。
- **`os.Rename()`**：在绝大多数操作系统（同分区）中，重命名是一个原子（Atomic）操作，切换是瞬时的。

#### 3. 落地文件与接口
- 新建文件：`internal/account/atomic.go`
- 测试文件：`internal/account/atomic_test.go`
- 核心函数：
  - `AtomicWriteFile(filename string, data []byte, perm os.FileMode) error`

```go
func AtomicWriteFile(filename string, data []byte, perm os.FileMode) (err error) {
    dir := filepath.Dir(filename)
    tmp, err := os.CreateTemp(dir, "accounts-*.tmp")
    if err != nil {
        return err
    }
    tmpPath := tmp.Name()
    defer func() {
        tmp.Close()
        if err != nil {
            os.Remove(tmpPath) // 出错时清理临时垃圾
        }
    }()

    if _, err = tmp.Write(data); err != nil {
        return err
    }
    if err = tmp.Sync(); err != nil { // 刷盘
        return err
    }
    if err = tmp.Close(); err != nil {
        return err
    }
    return os.Rename(tmpPath, filename) // 瞬间原子替换
}
```

#### 4. 审核与测试标准
- 运行测试：`go test -v ./internal/account -run TestAtomicWrite`
- 审查清单：
  - [ ] 写入测试后，目标文件存在且内容一致，且没有任何残留的 `.tmp` 临时文件。

---

### 🔹 Slice-ACC-04: 账号存储管理服务与并发读写锁

#### 1. 切片目标
封装 `AccountStore` 内存缓存与持久化层，提供账号增删改查及 `SetActive(id)`，支持多协程高并发安全访问。

#### 2. Go 初学者知识点解析
- **`sync.RWMutex` (读写互斥锁)**：
  - 多个读操作可以同时进行（`mu.RLock()` / `mu.RUnlock()`），读效率极高；
  - 写操作（`mu.Lock()` / `mu.Unlock()`）排他，保证内存切片与磁盘文件修改时的绝对一致性。
- **Go 习惯模式：工厂函数 `NewStore(...)`**：初始化结构体并返回接口指针。

#### 3. 落地文件与接口
- 新建文件：`internal/account/store.go`
- 测试文件：`internal/account/store_test.go`
- 核心接口：
  - `NewStore(filePath string) (Store, error)`
  - `(s *store) List() []*Account`
  - `(s *store) Add(acc *Account) error`
  - `(s *store) SetActive(id string) error`
  - `(s *store) Delete(id string) error`

#### 4. 审核与测试标准
- 运行测试：`go test -v -race ./internal/account`（开启 `-race` 竞态竞争检测）
- 审查清单：
  - [ ] 模拟 100 个并发 goroutine 同时读取和更新账号，`-race` 测试必须 100% PASS，无任何 data race 报警。
  - [ ] 设置 `SetActive` 时，原有 active 账号自动降为 inactive，全库仅保持至多一个 active 账号。
