# 铁镌 Iron Etch · Windows

一款本地优先、云端同步的健身记录与 AI 训练分析应用。Windows 版采用桌面优先的布局设计，功能与 Android 版一致，但导航、排版、书库和阅读器均针对鼠标、宽屏和高 DPI 重新设计。

## 当前版本

- Windows：**Win_v5.1.0**
- Flutter：**3.47.9**
- 发布页：<https://github.com/MrKedow/Iron-Etch/releases>
- 默认分支：`Windows`
- 其他分支：`Android`、`HTML`

## 桌面设计

- 左侧固定导航栏，训练、历史、AI 教练、视频合集、书库、动作库、知识库、主题工坊和设置统一入口
- 主页采用桌面宽屏双栏布局：左侧概览与最近训练，右侧训练记录表单
- 主题工坊变为响应式卡片网格，不再把手机卡片等比放大
- 视频合集按窗口宽度自动切换 1 / 2 / 3 列
- 书库使用响应式书架网格，阅读器正文自动限宽
- 无原生标题栏，窗口控制按钮集成在侧边栏顶部
- 支持窗口拖动、最小化、最大化和关闭
- 高 DPI 与宽屏居中适配
- Windows 应用图标与 Android 新版图标一致

## 功能

### 训练记录

- 记录日期、动作、部位、重量、组数、每组次数、训练感受和补剂
- 自动计算做功、总容量和累计训练次数
- 支持多动作、同日合并、历史编辑和删除
- 记录并编辑当日状态电量，在历史、详情和最近训练中展示

### 数据与云同步

- 本地数据持久化，重启后自动恢复
- 坚果云 WebDAV 同步：上传、下载、自动合并
- 下载后立即写回本地并持久化
- 支持 Excel / CSV 导入导出

### AI 教练

- 基于真实训练数据生成训练分析
- 支持自定义 AI 接口、模型、Key 和提示词
- 内置健身知识库，支持在线更新

### 视频合集

- 内置 B 站健身 UP 主合集
- 支持自定义合集、添加喜欢的 UP 主、合集折叠
- 首次进入全量刷新，之后使用本次运行缓存
- 点击合集或 UP 主按需刷新，右上角按钮手动全量刷新
- 使用 WebView2 在应用内播放 B 站视频

### 书库与阅读器

- 内置《北科·健身全书》，在线下载后可离线阅读
- 支持导入 EPUB 2 / EPUB 3
- 目录、全书搜索、划线、书签、小笺和阅读进度
- 阅读底色、字号调节
- Windows 宽屏下正文自动限宽，避免长行和大字号拉伸

### 动作库与知识库

- 175 个动作，覆盖力量、有氧、柔韧、功能与专项
- 动作示意图、目标肌群和动作要领
- 健身知识文章与 AI 语料更新

### 主题

- 多套内置主题、明暗模式和自定义背景
- 主题摘要完整显示
- 主题卡片响应式排布

## 安装

推荐直接下载安装包：

- `Iron-Etch_Win_v5.1.0_Setup.exe`：Windows 安装向导，支持开始菜单和可选桌面快捷方式
- `Iron-Etch_Win_v5.1.0.msi`：标准 Windows Installer 包，适合静默部署

安装后运行：

```text
Iron_Etch.exe
```

不再使用压缩包分发。

## 环境要求

- Windows 10 1809 或更高版本
- Microsoft Edge WebView2 Runtime（Windows 11 通常已内置）
- 构建需要 Flutter 3.47.9、Visual Studio 2022/2026（含 C++ 桌面开发）

## 构建

```powershell
flutter pub get
flutter analyze
flutter build windows --release
```

输出目录：

```text
build\windows\x64\runner\Release\
```

安装包构建：

- EXE 安装程序：使用 Inno Setup 编译 `installer.iss`
- MSI 安装程序：使用 WiX Toolset 3 编译 `installer.wxs` 与 harvest 文件

## 目录结构

```text
lib/
  main.dart                 应用入口、桌面侧栏、主页与训练记录
  providers/                主题、设置、训练数据等状态
  screens/                  历史、设置、主题、书库、视频、AI 教练等页面
  services/                 云同步、EPUB、B 站、AI、知识库、做功计算
  theme/                    主题定义
  widgets/                  通用 UI 组件
assets/
  exercises/                动作示意图
  images/                   启动与背景图片
  icon/app_icon.png         Windows / Android 统一应用图标
  coach_rules.json          AI 教练知识库
  bili_list.json            B 站视频合集
windows/                    Windows Runner 与图标资源
third_party/webview_windows 兼容新版 MSVC 的 WebView2 插件
installer.iss               Inno Setup 安装脚本
installer.wxs               WiX MSI 安装定义
```

## 说明

- 应用不缓存、不代理 B 站视频内容，播放由 B 站官方播放器提供。
- 内置书体积较大，默认从 GitHub Release 下载；下载失败时可先手动下载 `iron_book.epub`，再通过书库右上角导入。
- Windows 使用自定义无边框窗口，侧边栏顶部提供最小化、最大化和关闭按钮。
- 如果 Windows 任务栏仍显示旧图标，这是系统图标缓存导致的；新安装或重启资源管理器后会显示新图标。
- 已发布的历史 Release 源码归档保持不变；从 `Win_v4.1.2` 起的新版本源码统一使用 `iron_etch` / `Iron_Etch` 标识。
