## 概述
#### 一款健身记录兼电子陪练APP、支持三端同步和数据导出。告别纸笔和复杂表格，用精美而优雅的界面铭记每一次训练，自动计算做功，并即时获取AI训练分析。
---
#### Newest CSDN：[Android_v1.1](https://blog.csdn.net/Ethocas/article/details/160692111)
---
#### 2026.04.30 [Android_v1.1 Release](https://github.com/MrKedow/Fitness-Tracker/releases/tag/Android_v1.1)
#### 2026.04.24 [Android_v1.0 Release](https://github.com/MrKedow/Fitness-Tracker/releases/tag/Android_v1.0)
#### 2026.04.20 [Win_v4.0 Release](https://github.com/MrKedow/Fitness-Tracker/releases/tag/Win_v4.0)
#### 2026.04.19 [Win_v3.1.1 Release](https://github.com/MrKedow/Fitness-Tracker/releases/tag/Win_v3.1.1)
#### 2026.04.16 [Win_v3.0 Release](https://github.com/MrKedow/Fitness-Tracker/releases/tag/Win_Newest_Stable)
#### 2026.04.15 [Win_v2.0 Release](https://github.com/MrKedow/Fitness-Tracker/releases/tag/Win_Newest_Stable)
---

## 核心功能
---
### 智能表单填写
- **日期选择**：记录训练日期，自动计算“距第一次健身已过时间”（首次训练时间：**2025-06-09 18:29**）
- **动态项目列表**：点击“+添加项目”添加多个训练项目，点击“-删除项目”删除项目
- **详细字段**：
  - 项目名称（如：卧推、深蹲）
  - 锻炼部位（胸、背、腿、肩、腹）
  - 重量 (kg)
  - 组数 × 每组次数
  - 感受（文字描述）
  - 补剂（选填）
- **智能做功计算**：
  - 内置行程（肩/背/胸 60cm，腿 70cm）
  - 腹部采用科学估算（65kg成年人30°斜面仰卧起坐）
  - 实时显示本次训练的总做功（焦耳/千焦）

---
### 历史记录管理
- **来时的路**：展示所有已保存的训练记录
- **编辑**：“来时的路”页，可修改、删除任意条目，也可进行同日期合并
- **导出**：“来时的路”页，点击“⬇️”可导出“健身记录实时表.xlsx”分享至微信

### 坚果云同步（WebDAV）
- **首次连接**：点击首页右上角的“☁️”，输入坚果云账户名、应用密码（支持“记住密码”）
- **状态保持**：连接坚果云后，云状态即被保持，右上角“☁️”变绿；可再次点击“☁️”退出或切换云账号
- **双端同步**：当前所有记录自动保存为workout_data.json并上传至坚果云，“来时的路”页，点击“云同步”，云端和本地数据即统一，只有云端和本地都删除某条记录，它才会被云同步排除


---

## 主题与UI交互
- 内置 **5 套精美主题**（远山青、萤石黑、珠玉白、活力橙、全透明）
- 响应式布局，适配 Android 手机
- 平滑动画与现代化圆角设计
- 光标监听，输入框不会被键盘遮挡

---

## 技术栈

| 技术 | 用途 |
|------|------|
| **Flutter 3.22** | 跨平台 UI 框架 |
| **Dart** | 业务逻辑 |
| **SharedPreferences** | 本地配置与数据存储 |
| **path_provider** | 文件路径管理 |
| **http** | WebDAV 网络请求 |
| **intl** | 日期格式化 |
| **provider** | 状态管理 |

---

## 安装

### Android
1. 下载最新版 `Releases apk`
2. 安装。

### 从源码构建
```bash
从本仓库下载.dart和.yaml文件，在当前目录进入命令行（以下为示例）：
cd fitness_tracker
flutter pub get
flutter run -d android
无问题后运行：
flutter build apk

```

---

## 坚果云

1. 登录 [坚果云网页版](https://www.jianguoyun.com)
2. 点击右上角账户 → **账户信息** → **安全选项**
3. 在 **第三方应用管理** 中点击 **添加应用**，名称任意（如：FitnessTracker）
4. 复制生成的 **应用密码**（不是登录密码）
5. 首次运行程序时，点击主页右上角“☁️”，填写：
   - 账户邮箱：坚果云注册邮箱
   - 应用密码：应用密码
6. 勾选“记住密码”后，下次启动自动连接

> ⚠️ 注意：请勿将真实密码提交到代码仓库！本仓库示例已脱敏。

---

## 其他

### 目录结构
```
lib/
├── main.dart                 # 应用入口
├── models/                   # 数据模型（WorkoutRecord, WorkoutProject）
├── providers/                # 状态管理（WorkoutProvider, ThemeProvider）
├── services/                 # 核心服务（ExcelCSVService, NutstoreService）
└── screens/                  # 页面（MainScreen, HistoryScreen）
```

### 调试
- Windows：`flutter run -d windows`
- Android：连接手机后 `flutter run`

### 发布
```bash
# Windows EXE
flutter build windows --release

# Android APK
flutter build apk --release
```

### PR指南
欢迎提交 Issue 和 Pull Request。请确保代码符合 `flutter format` 规范。

---

## 开源协议
本项目采用 **MIT 协议**，详情见 [LICENSE](https://opensource.org/license/mit) 文件。

---

## 联系我
如有问题，请提交 [GitHub Issues](https://github.com/MrKedow/Fitness-Tracker/issues)。

**开始记录你的健身旅程吧！** 
