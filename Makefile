# ==============================================================================
# Antigravities 构建与工程管理 Makefile
# 核心约束：在本仓库作用域内强制锁定 CGO_ENABLED=0，绝不污染全局开发环境
# ==============================================================================

export CGO_ENABLED := 0

APP_NAME     := antigravities
BUILD_DIR    := build
LDFLAGS      := -s -w
GO_FLAGS     := -trimpath -ldflags "$(LDFLAGS)"

.PHONY: all help build run test vet clean cross-compile cross-darwin-arm64 cross-darwin-amd64 cross-windows cross-linux tutorial-dev tutorial-build

all: build

help:
	@echo "Antigravities 构建指令列表 (CGO_ENABLED=0 局部限定):"
	@echo "  make run                   - 本地运行桌面应用与托盘"
	@echo "  make build                 - 编译当前平台发布二进制"
	@echo "  make test                  - 运行所有模块单元测试"
	@echo "  make vet                   - 运行 Go 官方静态代码检查"
	@echo "  make clean                 - 清理构建产物与临时文件"
	@echo "  make cross-compile         - 交叉编译全部目标平台二进制"
	@echo "  make cross-darwin-arm64    - 交叉编译 Apple Silicon (M1-M4) 原生版本"
	@echo "  make cross-darwin-amd64    - 交叉编译 macOS Intel 版本"
	@echo "  make cross-windows         - 交叉编译 Windows 64位版本 (.exe)"
	@echo "  make cross-linux           - 交叉编译 Linux 64位版本"
	@echo "  make tutorial-dev          - 启动本地 VitePress 教程开发服务器"
	@echo "  make tutorial-build        - 编译 VitePress 教程静态站点"

build:
	@mkdir -p $(BUILD_DIR)
	go build $(GO_FLAGS) -o $(BUILD_DIR)/$(APP_NAME) .

run:
	go run .

test:
	go test -v ./...

vet:
	go vet ./...

clean:
	@rm -rf $(BUILD_DIR)
	@echo "构建目录 $(BUILD_DIR) 已清理"

cross-darwin-arm64:
	@mkdir -p $(BUILD_DIR)
	GOOS=darwin GOARCH=arm64 go build $(GO_FLAGS) -o $(BUILD_DIR)/$(APP_NAME)-darwin-arm64 .

cross-darwin-amd64:
	@mkdir -p $(BUILD_DIR)
	GOOS=darwin GOARCH=amd64 go build $(GO_FLAGS) -o $(BUILD_DIR)/$(APP_NAME)-darwin-amd64 .

cross-windows:
	@mkdir -p $(BUILD_DIR)
	GOOS=windows GOARCH=amd64 go build $(GO_FLAGS) -o $(BUILD_DIR)/$(APP_NAME)-windows-amd64.exe .

cross-linux:
	@mkdir -p $(BUILD_DIR)
	GOOS=linux GOARCH=amd64 go build $(GO_FLAGS) -o $(BUILD_DIR)/$(APP_NAME)-linux-amd64 .

cross-compile: cross-darwin-arm64 cross-darwin-amd64 cross-windows cross-linux
	@echo "所有目标平台交叉编译已完成，产物位于 $(BUILD_DIR)/"

tutorial-dev:
	cd docs/tutorial && bun run dev

tutorial-build:
	cd docs/tutorial && bun run build
