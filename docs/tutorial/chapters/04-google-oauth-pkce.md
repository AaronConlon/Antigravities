# 04. Google OAuth 2.0 PKCE 与回环服务器

在桌面客户端中，我们无法像传统的后端网站那样安全地保密 `Client Secret`（因为桌面安装包可能被用户反编译逆向）。RFC 7636 提出的 **PKCE（Proof Key for Code Exchange）** 正是为此而生。

---

## 1. PKCE 的数学原理

PKCE 的核心流程非常简单优雅：
1. **生成随机凭证**：客户端生成一段长度为 43~128 字符的高熵随机字符串，称为 `code_verifier`；
2. **生成挑战码**：客户端对 verifier 做 SHA-256 哈希计算，并用 URL-Safe Base64 编码，得到 `code_challenge`；
3. **发起授权**：打开浏览器请求 Google 授权，请求参数中只带 `code_challenge`；
4. **换取 Token**：拿到返回的 `code` 后，客户端在 POST 请求中带上原始的 `code_verifier`。Google 服务端重新计算哈希比对，验证通过后发放 Token。即使黑客中途拦截了重定向的 `code`，因为他没有初始的 `code_verifier`，也无法冒领 Token！

创建 `internal/oauth/pkce.go`：

```go
package oauth

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"io"
)

// GenerateCodeVerifier 生成 32 字节高熵随机串
func GenerateCodeVerifier() (string, error) {
	buf := make([]byte, 32)
	if _, err := io.ReadFull(rand.Reader, buf); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(buf), nil
}

// GenerateCodeChallenge 计算 SHA256 挑战码
func GenerateCodeChallenge(verifier string) string {
	hash := sha256.Sum256([]byte(verifier))
	return base64.RawURLEncoding.EncodeToString(hash[:])
}
```

---

## 2. 编写临时本地回环 HTTP 服务器

当用户在浏览器里点击“允许”后，Google 会将浏览器重定向到本地地址，例如 `http://127.0.0.1:51121/oauth/callback?code=xxx&state=yyy`。

我们需要在本地临时启动一个 HTTP 服务器接住这个请求，拿到 `code`，给用户浏览器返回一个“授权成功，可关闭窗口”的网页，然后自动优雅关闭服务器。

创建 `internal/oauth/server.go`：

```go
package oauth

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"time"
)

// StartLoopbackServer 启动临时回环监听并返回捕获到的 code
func StartLoopbackServer(ctx context.Context, expectedState string) (int, <-chan string, error) {
	// 监听 127.0.0.1 上的空闲端口
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return 0, nil, err
	}

	port := listener.Addr().(*net.TCPAddr).Port
	codeChan := make(chan string, 1)

	mux := http.NewServeMux()
	server := &http.Server{
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	mux.HandleFunc("/oauth/callback", func(w http.ResponseWriter, r *http.Request) {
		state := r.URL.Query().Get("state")
		code := r.URL.Query().Get("code")

		// 防御 CSRF 攻击
		if state != expectedState || code == "" {
			http.Error(w, "状态校验失败或授权码缺失", http.StatusBadRequest)
			return
		}

		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`
			<!DOCTYPE html><html><body style="font-family: sans-serif; text-align: center; padding-top: 50px;">
				<h2>🎉 授权成功！</h2>
				<p>您已成功登录 Antigravities，现在可以关闭本页面并返回桌面应用。</p>
			</body></html>
		`))

		// 将 code 传给接收者
		codeChan <- code

		// 异步优雅关闭服务器
		go func() {
			time.Sleep(500 * time.Millisecond)
			_ = server.Shutdown(context.Background())
		}()
	})

	go func() {
		_ = server.Serve(listener)
	}()

	return port, codeChan, nil
}
```

> **新手思考点**：为什么这里用 `chan string`？
> 因为 HTTP 请求处理是在独立的 Goroutine 中运行的，而你的业务流程（换取 Token）在主流程中等待。通过 Go 的 channel（通道），我们可以安全优雅地跨协程传递这个关键授权码。

在下一章中，我们将学习**如何定时向后端巡检配额，并在遭遇 429 请求限流时做优雅退避**！
