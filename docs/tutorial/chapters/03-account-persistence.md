# 03. 账号模型与安全的原子文件持久化

在桌面客户端中，如果用户正在写入账号 Token，突然断电或系统崩溃，很容易导致配置文件被截断，甚至变成一个 0 字节的空白坏文件。本章我们将学习如何设计严谨的 Go 结构体，并通过“原子写（Atomic Write）”技术解决这一隐患。

---

## 1. 结构体与 JSON 标签

在 Go 中，我们使用带有 `json:"..."` 标签的结构体表示账号实体。创建 `internal/account/model.go`：

```go
package account

import "time"

// TokenData 存储 OAuth 认证凭据
type TokenData struct {
	AccessToken  string    `json:"access_token"`
	RefreshToken string    `json:"refresh_token"`
	ExpiresAt    time.Time `json:"expires_at"` // 绝对过期时间
	TokenType    string    `json:"token_type"`
}

// Account 代表单个受管理的 Antigravity 账号
type Account struct {
	ID          string    `json:"id"`                     // 唯一 UUID
	Email       string    `json:"email"`                  // 登录邮箱
	DisplayName string    `json:"display_name,omitempty"` // 选填昵称，空值时不序列化
	AvatarURL   string    `json:"avatar_url,omitempty"`   // 头像
	IsActive    bool      `json:"is_active"`              // 是否为当前生效账号
	Token       TokenData `json:"token"`
	UpdatedAt   time.Time `json:"updated_at"`
	CreatedAt   time.Time `json:"created_at"`
}
```

> **新手思考点**：为什么结构体字段必须大写？
> 因为在 Go 中，首字母大写表示公开（Exported）。`encoding/json` 标准库是作为外部包通过反射来读取这些字段的。如果字段写成小写（如 `id`），JSON 编码器将无法读取它们，最终序列化出的内容会变成空的 `{}`！

---

## 2. 什么是原子文件写入 (Atomic Write)？

很多初学者保存文件习惯直接写：
```go
// 危险做法：如果写入中途崩溃，已有文件直接被清空截断！
os.WriteFile("accounts.json", data, 0600)
```

**工业级防崩溃标准模式**：
1. **写临时文件**：在同目录下创建一个随机命名的临时文件（如 `accounts.json.tmp.12345`）；
2. **物理刷盘**：调用 `file.Sync()`，强迫操作系统内核将缓存真正写入物理磁盘；
3. **安全关闭**：调用 `file.Close()`；
4. **原子重命名**：调用 `os.Rename(tmpFile, "accounts.json")`。

在现代操作系统中，同文件系统下的重命名操作是由文件系统原子完成的，只要重命名成功，文件内容就是 100% 完整的。

创建 `internal/account/atomic.go`：

```go
package account

import (
	"os"
	"path/filepath"
)

// AtomicWriteFile 保证落盘过程具有原子性
func AtomicWriteFile(filename string, data []byte, perm os.FileMode) (err error) {
	dir := filepath.Dir(filename)

	// 1. 创建同目录下的临时文件
	tmpFile, err := os.CreateTemp(dir, "accounts-*.tmp")
	if err != nil {
		return err
	}
	tmpName := tmpFile.Name()

	// 2. 使用 defer 确保如果中途出错，临时文件一定被清理
	defer func() {
		tmpFile.Close()
		if err != nil {
			_ = os.Remove(tmpName)
		}
	}()

	// 3. 写入完整数据
	if _, err = tmpFile.Write(data); err != nil {
		return err
	}

	// 4. 关键：强制刷入物理扇区
	if err = tmpFile.Sync(); err != nil {
		return err
	}

	if err = tmpFile.Close(); err != nil {
		return err
	}

	// 5. 瞬间原子替换
	return os.Rename(tmpName, filename)
}
```

---

## 3. 并发安全读写锁 (`sync.RWMutex`)

后台有定时巡检协程在刷新 Token，前台有用户在点击切换账号，为了防止多个协程同时读写内存里的账号切片造成崩溃（Data Race），我们使用读写锁：

```go
type store struct {
	mu       sync.RWMutex
	filePath string
	accounts []*Account
}

// 读操作使用 RLock (允许多个协程同时读取)
func (s *store) List() []*Account {
	s.mu.RLock()
	defer s.mu.RUnlock()
	
	// 返回副本，防止外部修改
	copied := make([]*Account, len(s.accounts))
	copy(copied, s.accounts)
	return copied
}

// 写操作使用 Lock (独占排他)
func (s *store) Add(acc *Account) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.accounts = append(s.accounts, acc)
	return s.saveLocked() // 将最新内存数据落盘
}
```

在下一章中，我们将进入实战重头戏：**如何用纯 Go 实现 Google OAuth 2.0 PKCE 认证流程并捕获浏览器回调**！
