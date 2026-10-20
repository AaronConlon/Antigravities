# 应用配置模块开发计划 (Config Module Slices)

本文档面向 Go 初学者，将配置管理拆解为 2 个高内聚的小切片。

---

## 🍰 切片总览

| 切片编号 | 切片名称 | 涉及核心 Go 概念 | 交付成果 |
|---|---|---|---|
| **Slice-CFG-01** | 全局配置结构与缺省字段自动回填 | 结构体、JSON 编解码、默认值合并模式 (`MergeDefaults`) | `internal/config/config.go` 及单元测试 |
| **Slice-CFG-02** | 线程安全配置服务与运行时热更新 | `sync.RWMutex`、原子文件写入、配置变更通知回调 | `internal/config/service.go` 及测试 |

---

### 🔹 Slice-CFG-01: 全局配置结构与缺省字段自动回填

#### 1. 切片目标
定义应用偏好结构体，包括后台巡检间隔、默认切换目标、自启动开关等；当磁盘中读取的配置缺少某些字段时（如版本升级），自动用默认值填充。

#### 2. Go 初学者知识点解析
- **`time.Duration` 的 JSON 处理**：Go 标准库反序列化 `time.Duration` 默认要求是纳秒数字；若要支持 `"15m"`、`"30s"` 字符串，可以通过自定义 `MarshalJSON` / `UnmarshalJSON` 或在配置中存储为字符串并在加载时解析。

#### 3. 落地文件与接口
- 新建文件：`internal/config/config.go`
- 测试文件：`internal/config/config_test.go`

---

### 🔹 Slice-CFG-02: 线程安全配置服务与运行时热更新

#### 1. 切片目标
提供单例配置服务 `Manager`，在内存中维护最新的配置对象，并支持保存到 `config.json`。

#### 2. Go 初学者知识点解析
- **读写锁保护配置读取**：界面多协程并发读取配置时仅需 `RLock()`，开销极小。

#### 3. 落地文件与接口
- 新建文件：`internal/config/service.go`
- 核心方法：
  - `Get() Config`
  - `Update(fn func(cfg *Config)) error`
