# 配额与额度监控模块开发计划 (Quota Module Slices)

本文档面向 Go 初学者，将配额与额度监控拆解为 3 个轻量开发切片。

---

## 🍰 切片总览

| 切片编号 | 切片名称 | 涉及核心 Go 概念 | 交付成果 |
|---|---|---|---|
| **Slice-QUOTA-01** | 模型配额分桶模型与健康度状态算法 | `map[string]ModelQuota`、浮点数计算、枚举类型模拟 | `internal/quota/model.go` 及单元测试 |
| **Slice-QUOTA-02** | 配额 HTTP 客户端与 429 退避处理 | 自定义 `http.Request`、`Bearer` 头、解析嵌套 JSON、退避冷却 | `internal/quota/client.go` 及 Mock 测试 |
| **Slice-QUOTA-03** | 后台低频巡检引擎与随机抖动 (Jitter) | `time.Ticker`、`math/rand/v2` 随机时延、跨协程缓存更新 | `internal/quota/inspector.go` 及全流程测试 |

---

### 🔹 Slice-QUOTA-01: 模型配额分桶模型与健康度状态算法

#### 1. 切片目标
实现 `ModelQuota` 与 `QuotaData` 结构体，根据各模型返回的剩余额度与总额度，计算最小可用比（`LowestRatio`）并评定账号健康状态（Healthy、Warning、Exhausted）。

#### 2. Go 初学者知识点解析
- **`map` 容器的初始化**：使用 `make(map[string]ModelQuota)` 显式初始化，严禁向未初始化的 `nil` map 写入数据（会导致 `panic`）。
- **浮点数边界控制**：计算 `remaining / limit` 时，注意除以 0 的特例保护，并将比例限制在 `[0.0, 1.0]` 范围内。

#### 3. 落地文件与接口
- 新建文件：`internal/quota/model.go`
- 测试文件：`internal/quota/model_test.go`
- 核心函数：
  - `CalculateQuotaStatus(models []ModelQuota) *QuotaData`

#### 4. 审核与测试标准
- 运行测试：`go test -v ./internal/quota -run TestCalculateQuota`
- 审查清单：
  - [ ] 当某模型额度为 0 时，整体 `IsExhausted` 必须为 `true`。
  - [ ] 当模型限额为 0 时（无限制模型），安全处理不发生除以 0 异常。

---

### 🔹 Slice-QUOTA-02: 配额 HTTP 客户端与 429 退避处理

#### 1. 切片目标
封装 HTTP 调用逻辑，携带当前有效的 Access Token 请求端点，解析 Google 配额结构，并在遭遇 429 限流时记录重试退避时间。

#### 2. Go 初学者知识点解析
- **`req.Header.Set("Authorization", "Bearer " + token)`**：标准 OAuth2 鉴权头部设置。
- **自定义 Error 类型**：定义 `ErrRateLimited` 和 `ErrTokenExpired` 哨兵错误，便于调用方通过 `errors.Is(...)` 区分错误类型进行不同动作。

#### 3. 落地文件与接口
- 新建文件：`internal/quota/client.go`
- 测试文件：`internal/quota/client_test.go`
- 核心接口：
  - `FetchQuota(ctx context.Context, token string) (*QuotaData, error)`

#### 4. 审核与测试标准
- 审查清单：
  - [ ] 使用 Mock HTTP 服务分别模拟 200、401、429、500 状态码，验证解析和错误类型返回正确。

---

### 🔹 Slice-QUOTA-03: 后台低频巡检引擎与随机抖动 (Jitter)

#### 1. 切片目标
实现后台轮询引擎，按照设定周期（如每 15 分钟）轮流查询纳管账号的额度；每个账号之间增加 1~3 秒随机抖动，避免瞬时并发流量触发 API 限流。

#### 2. Go 初学者知识点解析
- **抖动 (Jitter) 算法**：`time.Sleep(time.Duration(rand.IntN(2000)) * time.Millisecond)`，平滑请求波峰。
- **Goroutine 泄漏防范**：当主程序退出或 Context 被 Cancel 时，后台巡检循环必须立即感知并退出。

#### 3. 落地文件与接口
- 新建文件：`internal/quota/inspector.go`
- 核心函数：
  - `NewInspector(client Client, store account.Store) *Inspector`
  - `(ins *Inspector) Start(ctx context.Context, interval time.Duration)`

#### 4. 审核与测试标准
- 审查清单：
  - [ ] 验证调用 `cancel()` 后，后台巡检协程能在 100ms 内安全终止。
