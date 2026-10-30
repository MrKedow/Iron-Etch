# 铁镌 Iron Etch · Windows

一款本地优先、云端同步的健身记录与 AI 训练分析应用。Windows 版使用 Flutter + WebView2 构建，界面与 Android 版保持一致，并针对桌面宽屏、高 DPI 和鼠标操作重新适配。

## 当前版本

- Windows：**Win_v5.0.1**
- Flutter：**3.47.9**
- 发布页：<https://github.com/MrKedow/Iron-Etch/releases>
- 默认分支：`Windows`
- 其他分支：`Android`、`HTML`

## 功能

### 训练记录

- 记录日期、动作、部位、重量、组数、每组次数、训练感受和补剂
- 自动计算做功、总容量和累计训练次数
- 支持多动作、同日合并、历史编辑和删除
- 保存当日状态电量，并在历史、详情和最近训练中展示

### 数据与云同步

- 本地数据持久化，重启后自动恢复
- 坚果云 WebDAV 同步：上传、下载、自动合并
- 下载后立即写回本地并持久化
- 支持 Excel / CSV 导入导出

### AI 教练

- 基于本地训练数据生成训练分析
- 支持自定义 AI 接口、模型和提示词
- 内置训练知识库，可按需更新

### 视频合集

- 内置 B 站健身 UP 主合集
- 支持自定义合集、添加喜欢的 UP 主、合集折叠
- 首次进入全量刷新，之后使用本次运行缓存
- 点击合集或 UP 主时按需刷新，右上角按钮可手动全量刷新
- 使用 WebView2 在应用内播放 B 站视频

### 书库与阅读器

- 内置《北科·健身全书》，在线下载后离线阅读
- 支持导入 EPUB 2 / EPUB 3
- 目录、全书搜索、划线、书签、小笺与阅读进度
- 阅读底色、字号调节
- Windows 宽屏下阅读区域自动限宽，避免长行和大字号拉伸

### 动作库与知识库

- 175 个动作，覆盖力量、有氧、柔韧、功能与专项
- 动作示意图、目标肌群和动作要领
- 健身知识文章与 AI 语料更新

### 主题与桌面适配

- 多套内置主题、明暗模式和自定义背景
- Windows 宽屏居中布局、响应式书库网格
- 高 DPI 适配
- 自定义 Windows 应用图标

## 环境要求

- Windows 10 1809 或更高版本
- Microsoft Edge WebView2 Runtime（Windows 11 通常已内置）
- 构建需要 Flutter 3.47.9、Visual Studio 2022/2026（含 C++ 桌面开发）

## 构建

```powershell
flutter pub get
flutter build windows --release
```

输出目录：

```text
build\windows\x64\runner\Release\
```

运行：

```text
Iron_Etch.exe
```

## 目录结构

```text
lib/
  main.dart                 应用入口、主页与训练记录
  providers/                主题、设置、训练数据等状态
  screens/                  历史、设置、主题、书库、视频、AI 教练等页面
  services/                 云同步、EPUB、B 站、AI、知识库、做功计算
  theme/                    主题定义
  widgets/                  通用 UI 组件
assets/
  exercises/                动作示意图
  images/                   启动与背景图片
  coach_rules.json          AI 教练知识库
  bili_list.json            B 站视频合集
windows/                    Windows Runner 与图标
third_party/webview_windows 兼容新版 MSVC 的 WebView2 插件
```

## 说明

- 应用不缓存、不代理 B 站视频内容，播放由 B 站官方播放器提供。
- 内置书体积较大，默认从 GitHub Release 下载；下载失败时可先手动下载 `iron_book.epub`，再通过书库右上角导入。
- 当前 Flutter 构建仍会提示部分插件使用 Kotlin Gradle Plugin；这是 Flutter 生态迁移期的警告，不影响 Windows 构建。
- 已发布的历史 Release 源码归档保持不变；从 `Win_v4.1.2` 起的新版本源码统一使用 `iron_etch` / `Iron_Etch` 标识。
