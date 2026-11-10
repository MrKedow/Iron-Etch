# 铁镌 Iron Etch · Android

一款本地优先、云端同步的健身记录与 AI 训练分析应用。Android 版使用 Flutter 构建，支持训练记录、历史分析、AI 教练、动作库、视频合集、电子书阅读和主题系统。

## 当前版本

- Android：**Android_v3.3.3**（`versionCode 9`）
- Flutter：**3.47.9** / Dart **3.13.7**
- 发布页：<https://github.com/MrKedow/Iron-Etch/releases/tag/Android_v3.3.3>
- 默认分支：`Windows`
- 其他分支：`Android`、`HTML`

> 正式商店发行、签名配置、渠道打包与发布流程由维护者通过私有发布流程管理，不在公开仓库提供。

## 功能

### 训练记录

- 记录日期、动作、部位、重量、组数、每组次数、训练感受和补剂
- 自动计算做功、总容量和累计训练次数
- 支持多动作、同日合并、历史编辑与删除
- 记录并编辑当日状态电量，在历史、详情和最近训练中展示

### 历史与数据

- 历史训练按日期分组，支持折叠、详情和最近训练卡片
- 数据本地持久化，重启后自动恢复
- 坚果云 WebDAV 云同步：上传、下载、合并
- 云同步包含状态电量等完整字段
- 支持 Excel / CSV 导入导出

### AI 教练

- 基于真实训练数据生成训练建议
- 支持自定义 AI 接口、模型、Key 和提示词
- 内置健身知识库，支持在线更新
- 训练洞察、近期分析和动作建议

### 视频合集

- 内置 B 站健身 UP 主合集
- 支持添加喜欢的 UP 主、自定义合集和合集排序
- 合集名称行支持折叠 / 展开
- 首次进入全量刷新，后续复用本次运行缓存
- 点击合集或 UP 主按需刷新，右上角按钮手动全量刷新
- 使用 B 站官方播放器在应用内播放

### 书库与阅读器

- 内置《北科·健身全书》，在线下载后离线阅读
- 支持导入 EPUB 2 / EPUB 3
- 目录、全书搜索、划线、书签、小笺和阅读进度
- 字号、阅读底色和阅读设置
- 多源测速下载、下载进度与速度显示

### 动作库与知识库

- 2200+ 个动作，覆盖力量、有氧、柔韧、功能与专项
- 动作示意图、目标肌群和动作要领，支持点击查看大图
- 数据来自 exercises-dataset-zh、free-exercise-db / exercises.json，并以 open-exercisedb 交叉校验
- 健身知识文章与 AI 语料更新

### 主题与多尺寸适配

- 多套内置主题、明暗模式和自定义背景
- 主题摘要完整显示，支持昼夜跟随系统
- 主页日期、历史训练次数、编辑页日期适配宽窄屏
- 应用内电池状态编辑与最近训练卡片适配

## 环境要求

- Android 5.0 及以上
- 构建需要 Flutter 3.47.9
- Gradle 9.2.0、Android Gradle Plugin 9.0.1、Kotlin 2.3.20
- compileSdk 36

## 开发构建

公开仓库仅提供开发调试构建说明，不包含商店签名、AAB 打包、渠道发布和正式分发流程。

```powershell
flutter pub get
flutter analyze
flutter build apk --debug
```

安装调试包：

```powershell
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

正式发行版本由维护者使用私有发布文档构建和签名，公开源码不代表官方发行授权。

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
```

## 致谢与数据来源

动作库的数据与演示图来自以下公开数据集，特此致谢：

- **exercises-dataset / exercises-dataset-zh** — 动作数据、中文名称与演示图，MIT License，Copyright (c) 2026 Hasan Emir Yıldırım。
  - 演示图版权：**© Gym visual — https://gymvisual.com/**，按 180×180 分辨率与署名要求使用。
- **free-exercise-db / exercises.json** — 动作教学图与动作数据，Public Domain（Unlicense）。
- **open-exercisedb** — 动作数据交叉校验，MIT License，Copyright (c) 2026 Glowupp-app。
- **ExRx.net / ACE / NASM / ACSM** — 动作分类、肌群命名与训练处方参考。

生成与校验脚本见 `tool/generate_exercise_library.py`、`tool/validate_exercise_library.py`。

## 许可证

本仓库采用 **Source-Available** 授权，不是 OSI 开源许可。源码仅允许查看、通过 GitHub 克隆/派生用于个人学习和评估，以及向官方仓库提交贡献。

禁止商用、再分发、发布安装包、上架应用商店、制作衍生发行版，或使用“铁镌 / Iron Etch”名称与图标暗示官方授权。

详见：

- `LICENSE`
- `NOTICE`
- `TRADEMARK.md`

官方安装包只通过授权应用商店和官方 GitHub Release 发布：

<https://github.com/MrKedow/Iron-Etch/releases>

## 说明

- 应用不缓存、不代理 B 站视频内容，播放由 B 站官方播放器提供。
- 内置书默认从 GitHub Release 下载；如网络不稳定，可手动下载 `iron_book.epub` 后通过书库导入。
- 当前 `flutter analyze` 无 error / warning / info。
- 构建时可能出现插件 Kotlin Gradle Plugin 迁移提示，这是 Flutter 生态升级期警告，不影响当前构建。
