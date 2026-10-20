# 06. 纯 Go SQLite 注入与系统客户端集成

很多初学者认为“在 Go 里操作 SQLite 必须安装 GCC，开启 `CGO_ENABLED=1`”。这是因为最常见的 `github.com/mattn/go-sqlite3` 驱动底层绑定了 C 语言编译。但在 Antigravities 中，我们坚持 **严格零 Cgo（Zero-Cgo）**，选用 `modernc.org/sqlite`，使得代码无论在 macOS、Windows 还是 Linux 上，只要一条 `go build` 就能立刻秒级编译通过。

> 📘 **延伸阅读**：若对 CGO 的优缺点与为什么我们要避免它感兴趣，可随时复习 [01. 序言：深入理解什么是 CGO](./01-introduction.md#2-深入理解什么是-cgo为什么要坚决禁用它cgo_enabled0)。

本章我们将学习如何利用纯 Go 驱动 `modernc.org/sqlite`，安全地将账号凭据注入 Antigravity IDE 的 `state.vscdb`。

---

## 1. 纯 Go SQLite 驱动与写前自动备份

在 VS Code 架构中，全局数据保存在一个名为 `state.vscdb` 的 SQLite 数据库中。

修改外部编辑器的数据库前，有两道至关重要的安全红线：
1. **写前必须生成备份 (`state.vscdb.bak`)**：万一写入失败或数据库锁死，立即将 `.bak` 还原回去；
2. **必须使用事务 (`BEGIN TRANSACTION` -> `COMMIT`)**：要么全部成功，要么完全不改。

```go
package integration

import (
	"database/sql"
	"io"
	"os"

	_ "modernc.org/sqlite" // 纯 Go 驱动注册，零 Cgo！
)

// BackupFile 复制一份备份
func BackupFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, in)
	return err
}

// InjectCredentialsToVscdb 执行事务注入
func InjectCredentialsToVscdb(dbPath, oauthTokenB64, userStatusB64 string) error {
	// 1. 强制写前备份
	bakPath := dbPath + ".bak"
	if err := BackupFile(dbPath, bakPath); err != nil {
		return err
	}

	// 2. 打开 SQLite 连接
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return err
	}
	defer db.Close()

	// 3. 开启事务
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback() // 出错自动回滚

	// 4. 写入新凭据
	stmt := "INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)"
	if _, err = tx.Exec(stmt, "antigravityUnifiedStateSync.oauthToken", oauthTokenB64); err != nil {
		return err
	}
	if _, err = tx.Exec(stmt, "antigravityUnifiedStateSync.userStatus", userStatusB64); err != nil {
		return err
	}
	if _, err = tx.Exec(stmt, "antigravityOnboarding", "true"); err != nil {
		return err
	}

	// 5. 关键：清理历史旧版本的残留 UserID，防止会话读取错乱
	if _, err = tx.Exec("DELETE FROM ItemTable WHERE key = ?", "jetskiStateSync.agentManagerInitState"); err != nil {
		return err
	}

	// 6. 提交事务
	return tx.Commit()
}
```

---

## 2. 纯 Go 极简 Protobuf 编码

`state.vscdb` 中的值并不是纯明文字符串，而是被序列化为 Protobuf 后又转为了 Base64。

很多初学者以为只要用到 Protobuf，就必须安装 `protoc`、编写 `.proto` 文件并生成几千行难以阅读的桩代码。其实在底层，Protobuf 的协议非常直观：

- 每个字段是 `[Tag] [Length] [Payload]`；
- 长度使用变长整数（Varint）表示。

我们可以用几十行简洁的标准库代码完成序列化：

```go
package integration

import (
	"bytes"
	"encoding/base64"
	"encoding/binary"
)

// EncodeStringField 输出一个 Protobuf 字符串字段
func EncodeStringField(fieldNum int, val string) []byte {
	buf := new(bytes.Buffer)
	// Tag = (fieldNum << 3) | 2 (WireType: Length-delimited)
	tag := uint64((fieldNum << 3) | 2)
	
	var varintBuf [10]byte
	n := binary.PutUvarint(varintBuf[:], tag)
	buf.Write(varintBuf[:n])

	// 写入字符串字节长度
	n = binary.PutUvarint(varintBuf[:], uint64(len(val)))
	buf.Write(varintBuf[:n])

	// 写入真实内容
	buf.WriteString(val)
	return buf.Bytes()
}

// EncodeToBase64 组装并转换为 Base64
func EncodeToBase64(payload []byte) string {
	return base64.StdEncoding.EncodeToString(payload)
}
```

---

## 3. macOS Keychain 与 `agy` CLI 凭据同步

除了 IDE 桌面端，很多开发者还经常使用终端里的 `agy` 命令行工具。`agy` 的 Token 存储在 macOS 系统钥匙串中。

在 Go 中，我们可以利用 `os/exec` 调用 macOS 系统的 `security` 原生命令安全写入钥匙串，并立即进行**回读校验**：

```go
//go:build darwin

package integration

import (
	"fmt"
	"os/exec"
	"strings"
)

func SyncAgyToKeychain(email, refreshToken string) error {
	// 写入 macOS Keychain
	cmd := exec.Command("security", "add-generic-password",
		"-a", email,
		"-s", "antigravity",
		"-w", refreshToken,
		"-U", // -U 表示若已存在则更新替换
	)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("写入钥匙串失败: %w", err)
	}

	// 关键防护：立即回读验证，确保 agy CLI 能正确读取
	readCmd := exec.Command("security", "find-generic-password", "-s", "antigravity", "-w")
	out, err := readCmd.Output()
	if err != nil || strings.TrimSpace(string(out)) != refreshToken {
		return fmt.Errorf("钥匙串回读校验失败，Token 不一致")
	}

	return nil
}
```

在下一章中，我们将把这些强大的底层能力全部连接到 **MyGo 声明式原生 UI** 上，构建出极具视觉冲击力的桌面界面！
