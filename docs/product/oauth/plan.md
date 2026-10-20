# OAuth 认证模块开发计划 (OAuth Module Slices)

本文档面向 Go 初学者，将 Google OAuth 2.0 PKCE 认证流程拆解为 4 个紧凑清晰的开发切片。

---

## 🍰 切片总览

| 切片编号 | 切片名称 | 涉及核心 Go 概念 | 交付成果 |
|---|---|---|---|
| **Slice-OAUTH-01** | PKCE 验证码与挑战码生成算法 | `crypto/rand`、`crypto/sha256`、`base64.RawURLEncoding` | `internal/oauth/pkce.go` 及单元测试 |
| **Slice-OAUTH-02** | 本地动态回环 HTTP 服务器与优雅关闭 | `net.Listen`、`http.Server`、`context.WithTimeout`、`http.HandlerFunc` | `internal/oauth/server.go` 及测试 |
| **Slice-OAUTH-03** | Token 交换客户端与 UserInfo 请求 | `net/http` POST/GET、表单编码 (`url.Values`)、错误分级 | `internal/oauth/client.go` 及 Mock 测试 |
| **Slice-OAUTH-04** | 后台 Token 静默刷新调度器 | `time.Ticker`、`select` 语句、通道 (`chan struct{}`) 控制退出 | `internal/oauth/scheduler.go` 及测试 |

---

### 🔹 Slice-OAUTH-01: PKCE 验证码与挑战码生成算法

#### 1. 切片目标
生成符合 RFC 7636 规范的高熵随机 `code_verifier` 和基于 SHA-256 的 `code_challenge`，为 Google 登录提供防拦截保护。

#### 2. Go 初学者知识点解析
- **`crypto/rand` vs `math/rand`**：涉及安全/认证的随机数**必须使用 `crypto/rand`**，它是操作系统内核提供的真随机源；`math/rand` 是伪随机数生成器，容易被预测攻击。
- **`base64.RawURLEncoding`**：标准 Base64 包含 `+`、`/` 和末尾补位 `=`，这些在 URL 中是非法的；URL-Safe Base64 会将它们转为 `-` 和 `_`，并去掉末尾的 `=`。

#### 3. 落地文件与接口
- 新建文件：`internal/oauth/pkce.go`
- 测试文件：`internal/oauth/pkce_test.go`
- 核心函数：
  - `GenerateCodeVerifier() (string, error)`
  - `GenerateCodeChallenge(verifier string) string`

```go
func GenerateCodeChallenge(verifier string) string {
    hash := sha256.Sum256([]byte(verifier))
    return base64.RawURLEncoding.EncodeToString(hash[:])
}
```

#### 4. 审核与测试标准
- 运行测试：`go test -v ./internal/oauth -run TestPKCE`
- 审查清单：
  - [ ] 连续生成的 1000 个 verifier 均互不相同。
  - [ ] 对标准测试向量，计算出的 challenge 严格符合 RFC 7636 样例期望。

---

### 🔹 Slice-OAUTH-02: 本地动态回环 HTTP 服务器与优雅关闭

#### 1. 切片目标
启动本地临时 HTTP 服务器（绑定 `127.0.0.1` 上的端口），捕获浏览器授权后的 Auth Code；并在收到回调或 120 秒超时后优雅关闭服务器。

#### 2. Go 初学者知识点解析
- **`127.0.0.1:0` 动态分配端口**：如果固定端口被占用，监听 `:0` 会让操作系统内核自动分配一个可用的空闲端口。
- **`chan string` (通道)**：用于在 HTTP 请求处理协程与主调用流程之间传递 Code 字符串，是 Go “不要通过共享内存来通信，而要通过通信来共享内存”的经典体现。
- **`server.Shutdown(ctx)`**：优雅停止，允许当前正在响应的请求写完，不会强行斩断连接。

#### 3. 落地文件与接口
- 新建文件：`internal/oauth/server.go`
- 测试文件：`internal/oauth/server_test.go`
- 核心函数：
  - `StartLoopbackServer(ctx context.Context, expectedState string) (port int, codeChan <-chan string, err error)`

#### 4. 审核与测试标准
- 运行测试：`go test -v ./internal/oauth -run TestLoopbackServer`
- 审查清单：
  - [ ] 发送带错误 `state` 的请求应返回 400，且 `codeChan` 不会收到值。
  - [ ] 发送正确 `state` 与 `code` 后，浏览器端收到友好的成功 HTML 页面，服务器随后安全关闭端口。

---

### 🔹 Slice-OAUTH-03: Token 交换客户端与 UserInfo 请求

#### 1. 切片目标
使用获取到的 `code` 向 Google Token 端点请求交换 `access_token`、`refresh_token`，并紧随其后请求 UserInfo 获取用户邮箱与头像。

#### 2. Go 初学者知识点解析
- **`http.Client.Timeout`**：绝不使用默认的 `http.DefaultClient`，它没有超时限制，网络卡顿时会导致协程永久泄露。
- **`defer resp.Body.Close()`**：HTTP 响应体必须显式关闭并清空，否则底层的 TCP 连接无法复用进连接池（Keep-Alive 泄露）。

#### 3. 落地文件与接口
- 新建文件：`internal/oauth/client.go`
- 测试文件：`internal/oauth/client_test.go`
- 核心函数：
  - `ExchangeCodeForToken(ctx context.Context, code, verifier, redirectURI string) (*TokenResponse, error)`
  - `GetUserInfo(ctx context.Context, accessToken string) (*UserInfoResponse, error)`

#### 4. 审核与测试标准
- 审查清单：
  - [ ] 使用 `httptest.NewServer` 模拟 Google 端点，测试正常 200 响应与 400 invalid_grant 错误处理。

---

### 🔹 Slice-OAUTH-04: 后台 Token 静默刷新调度器

#### 1. 切片目标
运行后台循环，持续监控内存中的所有账号，在 Token 到期前 15 分钟静默换取新 Token，保证用户始终处于可用状态。

#### 2. Go 初学者知识点解析
- **`time.NewTicker`**：周期性触发事件，必须在退出时调用 `ticker.Stop()` 防止内存泄漏。
- **`select` 多路复用**：同时监听 `ctx.Done()`（外界取消信号）和 `ticker.C`（定时时钟），实现优雅启停。

#### 3. 落地文件与接口
- 新建文件：`internal/oauth/scheduler.go`
- 核心函数：
  - `StartRefreshScheduler(ctx context.Context, store account.Store, interval time.Duration)`

#### 4. 审核与测试标准
- 审查清单：
  - [ ] 构造一个剩余 5 分钟过期的 Mock 账号，验证调度器能否在下一次 tick 时正确触发刷新逻辑。
