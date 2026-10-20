# 05. 模型额度解析与后台低频巡检引擎

在管理多个 AI 账号时，最令人头疼的事情就是在写代码写到一半时突然遭遇“Quota Exceeded（配额耗尽）”或“429 Too Many Requests”。本章我们将学习如何设计低频巡检机制，并在请求之间注入“随机抖动（Jitter）”防风控。

---

## 1. 配额模型与百分比计算

一个账号通常同时拥有多个模型的配额桶（如 Gemini 2.5 Pro、Flash、Claude 等）。我们需要找出当前账号最紧缺的核心模型（`LowestRatio`），用来代表账号的健康状态。

创建 `internal/quota/model.go`：

```go
package quota

import "time"

type ModelQuota struct {
	ModelName      string  `json:"model_name"`
	DisplayName    string  `json:"display_name"`
	Limit          int64   `json:"limit"`
	Remaining      int64   `json:"remaining"`
	RemainingRatio float64 `json:"remaining_ratio"` // 0.0 ~ 1.0
}

type QuotaData struct {
	Models      map[string]ModelQuota `json:"models"`
	LowestRatio float64               `json:"lowest_ratio"`
	IsExhausted bool                  `json:"is_exhausted"`
	RefreshedAt time.Time             `json:"refreshed_at"`
}

// CalculateStatus 计算各模型剩余比例与最低水位
func CalculateStatus(models map[string]ModelQuota) *QuotaData {
	res := &QuotaData{
		Models:      models,
		LowestRatio: 1.0,
		RefreshedAt: time.Now(),
	}

	for _, m := range models {
		if m.Limit > 0 {
			ratio := float64(m.Remaining) / float64(m.Limit)
			if ratio < res.LowestRatio {
				res.LowestRatio = ratio
			}
			if m.Remaining <= 0 {
				res.IsExhausted = true
			}
		}
	}
	return res
}
```

---

## 2. 带 Context 超时与 Bearer Token 的 HTTP 客户端

Go 语言标准库中的 `http.DefaultClient` 是没有设置超时的！在桌面开发中，若网络切换或挂起，没有超时的请求会无限期阻塞，耗尽系统资源。

正确的写法是使用带有 `context.WithTimeout` 的显式请求：

```go
func FetchQuotaWithTimeout(ctx context.Context, token string) (*QuotaData, error) {
	// 创建一个最长等待 10 秒的子 Context
	ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, "GET", "https://api.example.com/quota", nil)
	if err != nil {
		return nil, err
	}

	// 注入 OAuth Bearer Token
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("User-Agent", "Antigravities-Desktop/1.0")

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusTooManyRequests {
		return nil, fmt.Errorf("触发限流 (429)，请稍后重试")
	}
	// ... 解析响应 JSON
	return nil, nil
}
```

---

## 3. 后台巡检循环与随机抖动 (Jitter)

如果我们保存了 10 个账号，后台每 15 分钟触发一次刷新，如果在一个 `for` 循环中瞬间把 10 个请求同时打出去，极容易被 Google 的限流网关判定为机器脚本，导致 429 封禁。

解决之道是引入 **Jitter（随机时延抖动）**：

```go
func (ins *Inspector) RunLoop(ctx context.Context, interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return // 主程序退出，优雅退出协程
		case <-ticker.C:
			accounts := ins.store.List()
			for _, acc := range accounts {
				// 关键点：每个账号之间随机睡眠 1 ~ 3 秒
				jitter := time.Duration(1000+rand.Intn(2000)) * time.Millisecond
				time.Sleep(jitter)

				ins.refreshOneAccount(ctx, acc)
			}
		}
	}
}
```

在下一章中，我们将进入 Antigravities 的核心黑科技：**如何不用 Cgo 也能用纯 Go 注入 VS Code 的 SQLite 数据库并切换账号！**
