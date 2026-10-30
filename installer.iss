; 脚本由 Inno Setup 脚本向导生成！
; 有关创建 Inno Setup 脚本文件的详细资料，请查阅帮助文档！

#define MyAppName "铁镌"
#define MyAppVersion "4.1.2"
#define MyAppPublisher "MrKedow"
#define MyAppURL "https://github.com/MrKedow/Fitness-Tracker"
#define MyAppExeName "Iron_Etch.exe"

[Setup]
; 注: AppId 的值为单独标识该应用程序。
; 不要为其他安装程序使用相同的 AppId 值。
; (生成新的 GUID，点击 工具|在 IDE 中生成 GUID。)
AppId={{E3A7F8D1-2B4C-4A9D-9C7A-6F5B3D8E1F2A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
;AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
; 移除以下行中的注释以在安装时运行一些管理任务（需要重新启动）
;PrivilegesRequired=admin
; 为安装程序设置图标
SetupIconFile=app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "chinese"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\windows\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; 注意: 不要在任何共享系统文件上使用“Flags: ignoreversion”

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
