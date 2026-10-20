import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'Antigravities 实战教程',
  description: '面向 Go 初学者的纯 Go 原生桌面应用实战指南 (Zero-Cgo & MyGo)',
  lang: 'zh-CN',
  base: '/',
  themeConfig: {
    logo: '⚡',
    nav: [
      { text: '教程首页', link: '/' },
      { text: '开始学习', link: '/chapters/01-introduction' },
      { text: '产品模块规范', link: 'https://github.com/AaronConlon/Antigravities/tree/main/docs/product' },
      { text: 'GitHub 仓库', link: 'https://github.com/AaronConlon/Antigravities' }
    ],
    sidebar: [
      {
        text: '📖 准备篇',
        items: [
          { text: '01. 序言与纯 Go 桌面开发哲学', link: '/chapters/01-introduction' },
          { text: '02. 环境搭建与首个托盘窗口', link: '/chapters/02-environment-and-mygo' }
        ]
      },
      {
        text: '🛠 核心模块实战',
        items: [
          { text: '03. 账号模型与安全的原子文件持久化', link: '/chapters/03-account-persistence' },
          { text: '04. Google OAuth 2.0 PKCE 与回环服务器', link: '/chapters/04-google-oauth-pkce' },
          { text: '05. 模型额度解析与后台低频巡检引擎', link: '/chapters/05-quota-monitoring' },
          { text: '06. 纯 Go SQLite 注入与系统客户端集成', link: '/chapters/06-system-integration-sqlite' },
          { text: '07. MyGo 声明式原生 UI 与状态绑定', link: '/chapters/07-native-declarative-ui' }
        ]
      },
      {
        text: '🚀 发布与进阶',
        items: [
          { text: '08. 零 Cgo 跨平台编译与打包发布', link: '/chapters/08-packaging-and-release' }
        ]
      }
    ],
    socialLinks: [
      { icon: 'github', link: 'https://github.com/AaronConlon/Antigravities' }
    ],
    footer: {
      message: '基于 MIT 协议开放 · 纯 Go 零 Cgo 桌面应用教程',
      copyright: 'Copyright © 2026 AaronConlon'
    }
  }
})
