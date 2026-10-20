# 应用配置模块 (Config Module)

## 1. 模块功能

配置模块负责管理 Antigravities 的全局运行时选项与用户偏好，主要包括：

- **配额巡检周期配置**：允许配置后台额度刷新的频率（例如 5 分钟、15 分钟、30 分钟或 1 小时，默认 15 分钟）。
- **首选切换目标 (Target Preference)**：设置默认切换环境（`auto` 智能探测、`ide` Antigravity IDE、`classic` 原生桌面端、`agy` CLI 凭据）。
- **开机自启动管理**：利用 macOS LaunchAgents plist 或系统服务，支持登录时常驻托盘自启。
- **通知策略配置**：控制账号切换成功、额度耗尽警报等系统桌面通知的启用/静音状态。
- **配置持久化与热更新**：以 JSON 格式存储于用户数据目录，并在用户修改时实时生效。

---

## 2. 实现逻辑与算法

### 2.1 存储与初始化
- 存储路径：`filepath.Join(mygo.App.UserDataDir(), "config.json")`。
- 加载策略：
  1. 尝试读取文件；若文件不存在，则生成带默认参数的配置并写入。
  2. 若读取到旧版配置文件缺少新增字段，自动执行字段合并（Zero-value filling with defaults）。

---

## 3. 详细设计 (Design)

### 3.1 配置结构定义

```go
package config

import "time"

type Config struct {
	// 后台巡检周期，默认 15m
	QuotaPollingInterval time.Duration `json:"quota_polling_interval"`

	// 首选切换目标: "auto", "ide", "classic", "agy"
	DefaultTarget string `json:"default_target"`

	// 是否开启登录自启动
	LaunchAtLogin bool `json:"launch_at_login"`

	// 是否允许系统通知
	EnableNotifications bool `json:"enable_notifications"`

	// 界面主题模式: "system", "dark", "light"
	Theme string `json:"theme"`
}

func DefaultConfig() *Config {
	return &Config{
		QuotaPollingInterval: 15 * time.Minute,
		DefaultTarget:        "auto",
		LaunchAtLogin:        false,
		EnableNotifications:  true,
		Theme:                "system",
	}
}
```
