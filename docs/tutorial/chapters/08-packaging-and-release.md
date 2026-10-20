# 08. 零 Cgo 跨平台编译与打包发布

得益于我们在整个项目中坚决贯彻的 **`CGO_ENABLED=0` 零 Cgo 架构**，Go 语言强大的跨平台交叉编译能力得到了最大程度的释放。你无需在 macOS 上安装 Windows SDK，也无需配置虚拟机，就能一条命令编译出多平台发布二进制！

---

## 1. 跨平台交叉编译验证

在项目根目录下，运行以下几条命令，验证你的代码是否完全符合跨平台规范：

```bash
# 1. 编译 macOS Apple Silicon (M1/M2/M3/M4) 原生二进制
CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -trimpath -ldflags "-s -w" -o build/antigravities-darwin-arm64 .

# 2. 编译 macOS Intel x86_64 二进制
CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -trimpath -ldflags "-s -w" -o build/antigravities-darwin-amd64 .

# 3. 交叉编译 Windows 64位 执行程序 (.exe)
CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -trimpath -ldflags "-s -w" -o build/antigravities-windows-amd64.exe .

# 4. 交叉编译 Linux 64位 执行程序
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags "-s -w" -o build/antigravities-linux-amd64 .
```

> **参数解析**：
> - `-trimpath`：从可执行文件中移除本地文件绝对路径（如 `/Users/yourname/...`），保护开发者隐私并实现确定性构建（Reproducible Builds）。
> - `-ldflags "-s -w"`：
>   - `-s`：剥离符号表（Symbol Table）；
>   - `-w`：剥离 DWARF 调试信息。
>   这两项能将最终二进制体积缩减 30%~40%，且不影响程序正常运行！

---

## 2. 自动化 GitHub Actions 发布流水线

有了纯 Go 零 Cgo 的优势，编写 GitHub Actions 自动打包发布（CI/CD）变得极为精简。创建 `.github/workflows/release.yml`：

```yaml
name: Release Antigravities

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    name: Build Binary
    runs-on: ubuntu-latest
    strategy:
      matrix:
        include:
          - os: darwin
            arch: arm64
            output: antigravities-darwin-arm64
          - os: darwin
            arch: amd64
            output: antigravities-darwin-amd64
          - os: windows
            arch: amd64
            output: antigravities-windows-amd64.exe
          - os: linux
            arch: amd64
            output: antigravities-linux-amd64

    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Setup Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.24'

      - name: Build Single Binary
        env:
          CGO_ENABLED: 0
          GOOS: ${{ matrix.os }}
          GOARCH: ${{ matrix.arch }}
        run: |
          go build -trimpath -ldflags "-s -w" -o dist/${{{ matrix.output }}} .

      - name: Upload Release Asset
        uses: softprops/action-gh-release@v2
        with:
          files: dist/*
```

只要给 Git 仓库打上一个 tag 并推送（如 `git tag v1.0.0 && git push origin v1.0.0`），GitHub Actions 就会在几分钟内自动编译全平台二进制，并在 Releases 页面供所有用户下载！

---

## 3. 恭喜你！

到这里，你已经完整了解了 Antigravities 的全链路工程实现！从底层的 Google OAuth 2.0 PKCE 协议、并发安全的原子落盘、纯 Go 的 SQLite 数据库事务注入，到 MyGo 原生声明式桌面的主线程渲染，你掌握了一整套现代、轻量、无任何环境包袱的 Go 原生桌面开发技能。

现在，随时进入 `docs/product/` 下的各个模块开发切片，开启你的编码之旅吧！
