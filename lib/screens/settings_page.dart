import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import '../l10n/localized_material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../app_version.dart';
import '../providers/app_providers.dart';
import '../services/ai_coach_service.dart';
import '../services/app_fonts.dart';
import '../services/config_sync.dart';
import '../services/media_permission.dart';
import '../services/reminder_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/press_feedback.dart';
import '../widgets/status_banner.dart';
import '../widgets/user_avatar.dart';
import 'iron_card_page.dart';
import 'onboarding_page.dart';
import 'theme_gallery_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  bool _testingAi = false;
  bool _reminderExpanded = false;
  bool _pendingReminderEnable = false;
  bool _hapticsExpanded = false;
  bool _dashboardExpanded = false;
  bool _aiScopesExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  Future<void> _onAppResumed() async {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>();
    if (_pendingReminderEnable) {
      _pendingReminderEnable = false;
      final granted = await ReminderService.canScheduleExactAlarms();
      if (!mounted) return;
      if (granted) {
        await settings.setRemindersEnabled(true);
        await ReminderService.schedule(settings.reminderTime);
        if (!mounted) return;
        _snack('训练提醒已开启，将准时发送');
      } else {
        _snack('未开启“闹钟和提醒”权限，训练提醒未启用');
      }
      return;
    }
    if (settings.remindersEnabled) {
      await ReminderService.schedule(settings.reminderTime);
    }
  }

  Future<void> _editNickname(SettingsProvider settings) async {
    final controller = TextEditingController(text: settings.nickname);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('修改昵称')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 16,
          decoration: InputDecoration(
            hintText: context.tr('铁友'),
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('取消')),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(context.tr('保存')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    await context.read<SettingsProvider>().setNickname(result);
  }

  Future<void> _chooseAvatar(SettingsProvider settings) async {
    if (!settings.hasAvatar) {
      await _pickAvatar(settings);
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        final spec = sheetContext.watch<ThemeProvider>().currentSpec;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: spec.textSecondary.withValues(alpha: .25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading:
                      Icon(Icons.photo_library_outlined, color: spec.primary),
                  title: Text(context.tr('更换头像')),
                  onTap: () => Navigator.pop(sheetContext, 'pick'),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: Color(0xFFEF4444)),
                  title: const Text(
                    '移除头像',
                    style: TextStyle(color: Color(0xFFEF4444)),
                  ),
                  onTap: () => Navigator.pop(sheetContext, 'remove'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    if (action == 'pick') {
      await _pickAvatar(settings);
    } else if (action == 'remove') {
      final previousPath = settings.avatarPath;
      await settings.clearAvatar();
      if (previousPath != null && previousPath.isNotEmpty) {
        try {
          final previousFile = File(previousPath);
          if (await previousFile.exists()) await previousFile.delete();
        } catch (_) {}
      }
      if (mounted) _showSnack(context.tr('头像已移除'));
    }
  }

  Future<void> _pickAvatar(SettingsProvider settings) async {
    try {
      final granted =
          await MediaPermission.request(context, MediaPermissionType.gallery);
      if (!granted || !mounted) return;
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 88,
      );
      if (picked == null || !mounted) return;
      final directory = await getApplicationDocumentsDirectory();
      final dot = picked.name.lastIndexOf('.');
      final extension =
          dot >= 0 ? picked.name.substring(dot).toLowerCase() : '.jpg';
      final target = File(
        '${directory.path}/profile_avatar_${DateTime.now().millisecondsSinceEpoch}$extension',
      );
      await File(picked.path).copy(target.path);
      final previousPath = settings.avatarPath;
      await settings.setAvatarPath(target.path);
      if (previousPath != null &&
          previousPath.isNotEmpty &&
          previousPath != target.path) {
        try {
          final previousFile = File(previousPath);
          if (await previousFile.exists()) await previousFile.delete();
        } catch (_) {}
      }
      if (mounted) _showSnack(context.tr('头像已更新'));
    } catch (error) {
      if (mounted) _showSnack(context.trArgs('头像设置失败：{e}', {'e': '$error'}));
    }
  }

  Future<String?> _showChoiceDialog({
    required String title,
    required List<String> options,
    required String current,
  }) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final spec = dialogContext.watch<ThemeProvider>().currentSpec;
        return AlertDialog(
          title: Text(title),
          contentPadding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in options)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(dialogContext, option),
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: option == current
                              ? spec.primary.withValues(alpha: .12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                option,
                                style: TextStyle(
                                  color: spec.textPrimary,
                                  fontWeight: option == current
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (option == current)
                              Icon(Icons.check_circle_rounded,
                                  color: spec.primary, size: 20),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('取消')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickLanguage(SettingsProvider settings) async {
    final current = appLanguageByCode(settings.appLanguageCode);
    final result = await _showChoiceDialog(
      title: context.tr('界面语言'),
      current: current.nativeLabel,
      options: appLanguages.map((item) => item.nativeLabel).toList(),
    );
    if (result == null || !mounted) return;
    final selected = appLanguages.firstWhere(
      (item) => item.nativeLabel == result,
      orElse: () => current,
    );
    await settings.setAppLanguage(selected.code);
  }

  Future<void> _pickFont(SettingsProvider settings) async {
    for (final option in appFontOptions.where((item) => item.isDownloadable)) {
      await AppFonts.isDownloaded(option);
    }
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final spec = sheetContext.watch<ThemeProvider>().currentSpec;
        return AnimatedBuilder(
          animation: AppFonts.notifier,
          builder: (context, _) {
            Future<void> select(AppFontOption option) async {
              if (option.isCustom) {
                Navigator.pop(sheetContext);
                await _importFont(settings);
                return;
              }
              if (option.isSystem) {
                await settings.setAppFont('system');
                if (sheetContext.mounted) Navigator.pop(sheetContext);
                return;
              }
              final already = AppFonts.isKnownDownloaded(option.id) ||
                  AppFonts.isLoaded(option.id);
              await settings.setAppFont(option.id);
              if (!already) {
                unawaited(AppFonts.downloadAndLoad(option));
                return;
              }
              if (sheetContext.mounted) Navigator.pop(sheetContext);
            }

            Future<void> remove(AppFontOption option) async {
              await AppFonts.delete(option);
              if (settings.appFontId == option.id) {
                await settings.setAppFont('system');
              }
              if (mounted) {
                _showSnack(
                  this.context.trArgs('已删除字体：{name}', {
                    'name': this.context.tr(option.label),
                  }),
                );
              }
            }

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .86,
                ),
                decoration: BoxDecoration(
                  color: spec.background,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: spec.textSecondary.withValues(alpha: .25),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('字体风格'),
                            style: TextStyle(
                              color: spec.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr('内置字体按需下载，点击即可下载并启用'),
                            style: TextStyle(
                              color: spec.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * .66,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(10, 4, 10, 18),
                        itemCount: appFontOptions.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: spec.textPrimary.withValues(alpha: .06),
                        ),
                        itemBuilder: (context, index) {
                          final option = appFontOptions[index];
                          final isCurrent = settings.appFontId == option.id;
                          final status = AppFonts.statusFor(option.id);
                          final isBusy = status.downloading;
                          final failed = status.error != null && !isBusy;
                          final isDownloaded =
                              AppFonts.isKnownDownloaded(option.id) ||
                                  AppFonts.isLoaded(option.id);
                          final percent = status.progress > 0
                              ? ' ${(status.progress * 100).toStringAsFixed(0)}%'
                              : '';
                          final subtitle = option.isSystem
                              ? context.tr('跟随系统字体')
                              : option.isCustom
                                  ? context.tr('从本地导入字体文件')
                                  : isBusy
                                      ? '${context.tr('正在下载字体…')}$percent'
                                      : failed
                                          ? context.tr('字体下载失败，请检查网络')
                                          : isCurrent
                                              ? context.tr('使用中')
                                              : isDownloaded
                                                  ? context.tr('已下载')
                                                  : context.tr('未下载 · 点击下载并启用');
                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 10),
                            leading: Icon(
                              isCurrent
                                  ? Icons.check_circle_rounded
                                  : option.isDownloadable && !isDownloaded
                                      ? Icons.cloud_download_outlined
                                      : Icons.font_download_outlined,
                              color:
                                  isCurrent ? spec.primary : spec.textSecondary,
                            ),
                            title: Text(context.tr(option.label)),
                            subtitle: Text(
                              subtitle,
                              style: TextStyle(
                                color: spec.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            trailing: isBusy
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: spec.primary,
                                    ),
                                  )
                                : option.isDownloadable && isDownloaded
                                    ? IconButton(
                                        tooltip: context.tr('删除字体'),
                                        onPressed: () => remove(option),
                                        icon: Icon(
                                          Icons.delete_outline_rounded,
                                          color: spec.textSecondary,
                                        ),
                                      )
                                    : option.isDownloadable
                                        ? Icon(
                                            Icons.download_rounded,
                                            color: spec.primary,
                                          )
                                        : option.isCustom
                                            ? Icon(
                                                Icons.file_open_outlined,
                                                color: spec.textSecondary,
                                              )
                                            : null,
                            onTap: () => select(option),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _importFont(SettingsProvider settings) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['ttf', 'otf', 'ttc'],
    );
    if (picked.isEmpty) return;
    final sourcePath = picked.single.path;
    if (sourcePath == null || sourcePath.isEmpty) return;
    try {
      final dir = await getApplicationSupportDirectory();
      final extension = sourcePath.split('.').last.toLowerCase();
      final target = File(
        '${dir.path}${Platform.pathSeparator}'
        'iron_etch_font_${DateTime.now().millisecondsSinceEpoch}.$extension',
      );
      await File(sourcePath).copy(target.path);
      final ok = await settings.setCustomFont(target.path);
      if (!mounted) return;
      _showSnack(
        ok ? context.tr('自定义字体已导入') : context.tr('字体导入失败，请确认文件有效'),
      );
    } catch (error) {
      if (!mounted) return;
      _showSnack(context.trArgs('字体导入失败：{e}', {'e': '$error'}));
    }
  }

  Future<double?> _showSliderDialog({
    required String title,
    required String description,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required String Function(double) labelBuilder,
  }) {
    var current = value;
    return showDialog<double>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final spec = context.watch<ThemeProvider>().currentSpec;
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(
                    color: spec.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    labelBuilder(current),
                    style: TextStyle(
                      color: spec.primary,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Slider(
                  value: current,
                  min: min,
                  max: max,
                  divisions: divisions,
                  label: labelBuilder(current),
                  onChanged: (newValue) =>
                      setDialogState(() => current = newValue),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(context.tr('取消')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, current),
                child: Text(context.tr('确定')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editGoal(SettingsProvider settings) async {
    final result = await _showChoiceDialog(
      title: context.tr('训练目标'),
      current: settings.trainingGoal,
      options: const ['增肌', '减脂', '力量', '塑形', '健康'],
    );
    if (result == null || !mounted) return;
    await context.read<SettingsProvider>().setTrainingGoal(result);
  }

  Future<void> _editExperience(SettingsProvider settings) async {
    final result = await _showChoiceDialog(
      title: context.tr('训练经验'),
      current: settings.experience,
      options: const ['新手', '进阶', '高阶'],
    );
    if (result == null || !mounted) return;
    await context.read<SettingsProvider>().setExperience(result);
  }

  Future<void> _editWeeklyGoal(SettingsProvider settings) async {
    final value = await _showSliderDialog(
      title: context.tr('每周训练目标'),
      description: 'AI 教练与首页会按这个目标评估你的训练频率。',
      value: settings.weeklyGoal.toDouble(),
      min: 1,
      max: 7,
      divisions: 6,
      labelBuilder: (v) => context.trArgs('{n} 天 / 周', {'n': '${v.round()}'}),
    );
    if (value == null || !mounted) return;
    await context.read<SettingsProvider>().setWeeklyGoal(value.round());
  }

  Future<void> _editBodyWeight(SettingsProvider settings) async {
    final value = await _showSliderDialog(
      title: context.tr('体重'),
      description: '用于估算训练做功与热量消耗。',
      value: settings.bodyWeight,
      min: 30,
      max: 200,
      divisions: 340,
      labelBuilder: (v) => '${v.toStringAsFixed(1)} kg',
    );
    if (value == null || !mounted) return;
    await context.read<SettingsProvider>().setBodyWeight(value);
  }

  Future<void> _editRestSeconds(SettingsProvider settings) async {
    final value = await _showSliderDialog(
      title: context.tr('默认组间休息'),
      description: '记录训练时参考用的默认休息时间。',
      value: settings.restSeconds.toDouble(),
      min: 15,
      max: 300,
      divisions: 19,
      labelBuilder: (v) => context.trArgs('{n} 秒', {'n': '${v.round()}'}),
    );
    if (value == null || !mounted) return;
    await context.read<SettingsProvider>().setRestSeconds(value.round());
  }

  Future<void> _editWeightUnit(SettingsProvider settings) async {
    final result = await _showChoiceDialog(
      title: context.tr('重量单位'),
      current: settings.weightUnit,
      options: const ['kg', 'lb'],
    );
    if (result == null || !mounted) return;
    await context.read<SettingsProvider>().setWeightUnit(result);
  }

  Future<void> _pickReminderTime(SettingsProvider settings) async {
    final parts = settings.reminderTime.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 20,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: context.tr('选择提醒时间'),
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null || !mounted) return;
    final text =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    await context.read<SettingsProvider>().setReminderTime(text);
    if (settings.remindersEnabled) {
      await ReminderService.schedule(text);
    }
  }

  Future<void> _toggleReminders(
    SettingsProvider settings,
    bool value,
  ) async {
    if (!value) {
      _pendingReminderEnable = false;
      await settings.setRemindersEnabled(false);
      await ReminderService.cancel();
      return;
    }
    final granted = await ReminderService.requestPermission();
    if (!mounted) return;
    if (!granted) {
      _snack('需要通知权限才能发送训练提醒，请在系统设置中允许通知');
      return;
    }
    final exact = await ReminderService.canScheduleExactAlarms();
    if (!mounted) return;
    if (!exact) {
      _pendingReminderEnable = true;
      final opened = await ReminderService.requestExactAlarmPermission();
      if (!mounted) return;
      if (!opened) {
        _pendingReminderEnable = false;
        _snack('无法打开“闹钟和提醒”设置，请手动在系统设置中允许');
      } else {
        _snack('请开启“闹钟和提醒”权限，返回后会自动开启训练提醒');
      }
      return;
    }
    await settings.setRemindersEnabled(true);
    await ReminderService.schedule(settings.reminderTime);
  }

  Future<void> _editAiPrompt(SettingsProvider settings) async {
    final controller = TextEditingController(text: settings.aiPrompt);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final spec = dialogContext.watch<ThemeProvider>().currentSpec;
        return AlertDialog(
          title: Text(context.tr('AI 提示词')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '设置后会作为首条提问真实发送给 AI，并替换训练舱顶部的默认问题。留空则使用内置默认提问。',
                  style: TextStyle(
                    color: spec.textSecondary,
                    fontSize: 11.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  minLines: 4,
                  maxLines: 10,
                  decoration: InputDecoration(
                    hintText: context.tr(
                      '例如：你是一位严谨的力量举教练，只输出中文结论，不要输出思考过程…',
                    ),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.text = '';
              },
              child: Text(context.tr('清空')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('取消')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.tr('保存')),
            ),
          ],
        );
      },
    );
    if (saved == true && mounted) {
      await context.read<SettingsProvider>().setAiPrompt(controller.text);
    }
    controller.dispose();
  }

  Future<void> _testAi(SettingsProvider settings) async {
    if (!settings.aiEnabled) {
      _showSnack(context.tr('AI 建议当前已关闭，请先开启。'));
      return;
    }
    setState(() => _testingAi = true);
    final reply = await AiCoachService.testConnection(
      endpoint: settings.aiEndpoint,
      model: settings.aiModel,
      apiKey: settings.aiApiKey,
      reasoningEffort: settings.aiReasoningEffort,
    );
    if (!mounted) return;
    setState(() => _testingAi = false);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(
              reply.success
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              color: reply.success ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text(reply.success ? '连接成功' : '连接未成功'),
          ],
        ),
        content: Text(
          reply.success
              ? '${reply.content}\n\n模型：${settings.aiModel}'
              : '${reply.error ?? '未知错误'}\n\n提示：免费通道可能限流，可在配置中填写 API Key 或稍后重试。',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('知道了')),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    final provider = context.read<WorkoutProvider>();
    if (provider.records.isEmpty) {
      _showSnack(context.tr('还没有可导出的训练记录'));
      return;
    }
    try {
      final path = await ExcelExportService().exportToExcel(provider.records);
      if (path == null) {
        _showSnack(trGlobal('导出失败，请稍后重试'));
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: trGlobal('铁镌训练数据'),
        ),
      );
    } catch (e) {
      if (mounted) {
        _showSnack(trGlobalArgs('导出失败：{e}', {'e': '$e'}));
      }
    }
  }

  Future<void> _mergeData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('整合同日记录')),
        content: Text(context.tr('把同一天的多条记录合并为一条，动作会保留。是否继续？')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('取消')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('整合')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    context.read<WorkoutProvider>().mergeSameDayRecords();
    _showSnack(context.tr('已整合同一天的记录'));
  }

  Future<void> _clearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('清空全部训练记录？')),
        content: Text(context.tr('所有训练历史都会被删除，且无法恢复。建议先导出备份。')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('取消')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.tr('清空')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    context.read<WorkoutProvider>().clearRecords();
    _showSnack(context.tr('训练记录已清空'));
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showAbout() {
    final spec = context.watch<ThemeProvider>().currentSpec;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 34,
                height: 34,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Text(context.tr('关于铁镌')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '铁镌 · 镌刻每一次撸铁',
              style: TextStyle(
                color: spec.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.trArgs('版本 {v}（Android）', {'v': appVersion}),
              style: TextStyle(color: spec.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Text(
              '一个专注训练记录、数据洞察与 AI 教练的开源健身工具。',
              style: TextStyle(
                color: spec.textSecondary,
                fontSize: 12.5,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () => launchUrl(
                Uri.parse('https://github.com/MrKedow/Iron-Etch'),
              ),
              child: const Text(
                'GitHub · MrKedow/Iron-Etch',
                style: TextStyle(color: Colors.blue, fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => launchUrl(
                Uri.parse('mailto:Ethocas@outlook.com'),
              ),
              child: const Text(
                '邮箱 · Ethocas@outlook.com',
                style: TextStyle(color: Colors.blue, fontSize: 12.5),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('关闭')),
          ),
        ],
      ),
    );
  }

  void _showAcknowledgments() {
    final spec = context.watch<ThemeProvider>().currentSpec;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('鸣谢')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ackItem(
              spec,
              'exercises-dataset / exercises-dataset-zh',
              '动作数据、中文名称与演示图（MIT；媒体 © Gym visual，180×180）',
              'https://github.com/hasaneyldrm/exercises-dataset',
            ),
            const SizedBox(height: 12),
            _ackItem(
              spec,
              'Gym visual',
              'exercises-dataset 动作演示图版权方',
              'https://gymvisual.com/',
            ),
            const SizedBox(height: 12),
            _ackItem(
              spec,
              'free-exercise-db / exercises.json',
              '动作教学示意图与动作数据（Public Domain）',
              'https://github.com/yuhonas/free-exercise-db',
            ),
            const SizedBox(height: 12),
            _ackItem(
              spec,
              'open-exercisedb',
              '动作数据交叉校验（MIT）',
              'https://github.com/Glowupp-app/open-exercisedb',
            ),
            const SizedBox(height: 12),
            _ackItem(
              spec,
              'ExRx.net',
              '动作分类与肌群命名参考',
              'https://exrx.net',
            ),
            const SizedBox(height: 12),
            _ackItem(
              spec,
              'ACE / NASM / ACSM',
              '动作库、矫正训练体系与运动测试处方参考',
              'https://www.acefitness.org',
            ),
            const SizedBox(height: 12),
            _ackItem(
              spec,
              'Google Fonts',
              '内置字体来源（SIL Open Font License 1.1，经 jsDelivr / GitHub 多源按需下载）',
              'https://github.com/google/fonts',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('关闭')),
          ),
        ],
      ),
    );
  }

  Widget _ackItem(
    AppThemeSpec spec,
    String name,
    String description,
    String url,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => launchUrl(Uri.parse(url)),
          child: Text(
            name,
            style: TextStyle(
              color: spec.primary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          description,
          style: TextStyle(
            color: spec.textSecondary,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _profileAvatar(SettingsProvider settings, AppThemeSpec spec) {
    final nickname = settings.nickname.trim();
    final initial = nickname.isEmpty ? '铁' : nickname.characters.first;
    return GestureDetector(
      onTap: () => _chooseAvatar(settings),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 58,
            height: 58,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: spec.heroGradient,
              borderRadius: BorderRadius.circular(18),
            ),
            child: UserAvatar(
              path: settings.avatarPath,
              size: 58,
              circle: false,
              fallback: Text(
                initial,
                style: TextStyle(
                  color: spec.onHero,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Positioned(
            right: -5,
            bottom: -5,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: spec.primary,
                shape: BoxShape.circle,
                border: Border.all(color: spec.background, width: 2),
              ),
              child: Icon(
                Icons.photo_camera_rounded,
                size: 12,
                color: spec.isDark ? spec.background : spec.onHero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCloudSync(NutstoreService nutstore) async {
    if (!nutstore.isConnected) {
      await _showCloudLogin(nutstore);
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final spec = sheetContext.watch<ThemeProvider>().currentSpec;
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
            decoration: BoxDecoration(
              color: spec.background,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: spec.textSecondary.withValues(alpha: .3),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '坚果云同步',
                  style: TextStyle(
                    color: spec.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.trArgs('已连接：{name}', {
                    'name': nutstore.username ?? '',
                  }),
                  style: TextStyle(
                    color: spec.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: Icon(Icons.upload_rounded, color: spec.primary),
                  title: Text(context.tr('同步配置到云端')),
                  onTap: () => Navigator.pop(sheetContext, 'upload'),
                ),
                ListTile(
                  leading: Icon(Icons.download_rounded, color: spec.secondary),
                  title: Text(context.tr('从云端恢复配置')),
                  onTap: () => Navigator.pop(sheetContext, 'download'),
                ),
                ListTile(
                  leading: Icon(Icons.tune_rounded, color: spec.textSecondary),
                  title: Text(context.tr('同步内容')),
                  subtitle: Text(context.tr('自定义允许上传与恢复的配置范围')),
                  onTap: () => Navigator.pop(sheetContext, 'scopes'),
                ),
                ListTile(
                  leading: Icon(Icons.link_off_rounded,
                      color: const Color(0xFFF97316)),
                  title: Text(context.tr('断开连接')),
                  onTap: () => Navigator.pop(sheetContext, 'disconnect'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    if (action == 'upload') {
      await _uploadConfig(nutstore);
    } else if (action == 'download') {
      await _downloadConfig(nutstore);
    } else if (action == 'scopes') {
      await _showSyncScopes();
    } else if (action == 'disconnect') {
      await nutstore.clearCredentials();
      _snack('已断开坚果云连接');
    }
  }

  Future<void> _showCloudLogin(NutstoreService nutstore) async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('连接坚果云')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '在坚果云网页端「安全选项」生成应用密码后填写。',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: context.tr('坚果云账号'),
                  hintText: context.tr('邮箱地址'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: context.tr('应用密码'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('取消')),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await nutstore.connect(
                username: usernameController.text.trim(),
                password: passwordController.text.trim(),
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext, ok);
            },
            child: Text(context.tr('连接')),
          ),
        ],
      ),
    );
    usernameController.dispose();
    passwordController.dispose();
    if (!mounted) return;
    _snack(result == true ? '坚果云连接成功' : '坚果云连接失败');
  }

  Future<void> _showSyncScopes() async {
    var scopes = await ConfigSyncService.loadScopes();
    if (!mounted) return;
    final result = await showModalBottomSheet<Set<ConfigSyncScope>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final spec = sheetContext.watch<ThemeProvider>().currentSpec;
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Container(
              margin: const EdgeInsets.only(top: 60),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * .82,
              ),
              decoration: BoxDecoration(
                color: spec.background,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: spec.textSecondary.withValues(alpha: .3),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '同步内容',
                          style: TextStyle(
                            color: spec.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setSheetState(
                            () => scopes = ConfigSyncService.allScopes.toSet()),
                        child: Text(context.tr('全选')),
                      ),
                      TextButton(
                        onPressed: () =>
                            setSheetState(() => scopes = <ConfigSyncScope>{}),
                        child: Text(context.tr('清空')),
                      ),
                    ],
                  ),
                  Text(
                    '控制上传到云端以及从云端恢复时包含的内容。坚果云账号与应用密码始终不会同步。',
                    style: TextStyle(
                      color: spec.textSecondary,
                      fontSize: 11.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final scope in ConfigSyncService.allScopes)
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              scope.label,
                              style: TextStyle(
                                color: spec.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              scope.description,
                              style: TextStyle(
                                color: spec.textSecondary,
                                fontSize: 11,
                                height: 1.35,
                              ),
                            ),
                            value: scopes.contains(scope),
                            onChanged: (value) => setSheetState(() {
                              if (value) {
                                scopes.add(scope);
                              } else {
                                scopes.remove(scope);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.pop(sheetContext, Set.of(scopes)),
                      child: Text(context.tr('保存选择')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (result == null) return;
    await ConfigSyncService.saveScopes(result);
    if (mounted) {
      _snack(context.trArgs('同步内容已更新（已选 {n} 项）', {
        'n': '${result.length}',
      }));
    }
  }

  String _fileExtension(String path) {
    final dot = path.lastIndexOf('.');
    return dot >= 0 ? path.substring(dot).toLowerCase() : '.jpg';
  }

  Future<Map<String, dynamic>> _uploadConfigFiles(
    NutstoreService nutstore,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final files = <String, dynamic>{};
    for (final key in ConfigSyncService.fileKeys) {
      final path = prefs.getString(key);
      if (path == null || path.trim().isEmpty) continue;
      final file = File(path);
      if (!await file.exists()) continue;
      final remote =
          '${ConfigSyncService.fileRemotePrefixes[key]}${_fileExtension(path)}';
      if (await nutstore.uploadAdditionalFile(path, remote)) {
        files[key] = {'remote': remote};
      }
    }
    return files;
  }

  Future<void> _restoreConfigFiles(
    NutstoreService nutstore,
    Map<String, dynamic> files,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    final restoreDir = Directory('${directory.path}/cloud_restored');
    if (!await restoreDir.exists()) {
      await restoreDir.create(recursive: true);
    }
    final prefs = await SharedPreferences.getInstance();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    for (final entry in files.entries) {
      final key = entry.key;
      if (!ConfigSyncService.fileKeys.contains(key)) continue;
      final meta = entry.value;
      if (meta is! Map) continue;
      final remote = meta['remote']?.toString();
      if (remote == null || remote.isEmpty) continue;
      final savePath =
          '${restoreDir.path}/${key}_$stamp${_fileExtension(remote)}';
      final ok = await nutstore.downloadNamedFile(remote, savePath);
      if (ok) {
        await prefs.setString(key, savePath);
      } else {
        await prefs.remove(key);
      }
    }
  }

  Future<void> _uploadConfig(NutstoreService nutstore) async {
    final scopes = await ConfigSyncService.loadScopes();
    if (scopes.isEmpty) {
      _snack('请先在「同步内容」中选择要上传的项目');
      return;
    }
    final payload = await ConfigSyncService.buildPayload(scopes);
    if (scopes.contains(ConfigSyncScope.images)) {
      payload['files'] = await _uploadConfigFiles(nutstore);
    }
    final ok = await nutstore.uploadConfig(jsonEncode(payload));
    if (!mounted) return;
    _snack(
      ok
          ? context.trArgs('配置已同步到云端（{n} 项范围）', {
              'n': '${scopes.length}',
            })
          : context.tr('上传失败，请检查网络'),
    );
  }

  Future<void> _downloadConfig(NutstoreService nutstore) async {
    final raw = await nutstore.downloadConfig();
    if (raw == null) {
      _snack('云端暂无配置或下载失败');
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _snack('配置格式错误');
        return;
      }
      final data = Map<String, dynamic>.from(decoded);
      final scopes = await ConfigSyncService.loadScopes();
      if (scopes.isEmpty) {
        _snack('请先在「同步内容」中选择要恢复的项目');
        return;
      }
      final applied = await ConfigSyncService.applyPayload(data, scopes);
      if (scopes.contains(ConfigSyncScope.images) && data['files'] is Map) {
        await _restoreConfigFiles(
          nutstore,
          Map<String, dynamic>.from(data['files'] as Map),
        );
      }
      if (!mounted) return;
      await context.read<SettingsProvider>().reload();
      if (!mounted) return;
      await context.read<ThemeProvider>().reload();
      if (!mounted) return;
      _snack(context.trArgs('已恢复 {n} 项配置，部分页面重新进入后生效', {
        'n': '$applied',
      }));
    } catch (_) {
      _snack('配置解析失败');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final spec = context.watch<ThemeProvider>().currentSpec;
    final themeProvider = context.watch<ThemeProvider>();
    final nutstore = context.watch<NutstoreService>();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: spec.background.withValues(alpha: .82),
            title: Text(context.tr('设置')),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              18,
              4,
              18,
              34 + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                GlassPanel(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _profileAvatar(settings, spec),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    settings.nickname,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: spec.textPrimary,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  onPressed: () => _editNickname(settings),
                                  tooltip: context.tr('修改昵称'),
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(Icons.edit_rounded,
                                      size: 17, color: spec.textSecondary),
                                ),
                              ],
                            ),
                            Text(
                              '${context.tr(settings.trainingGoal)} · ${context.tr(settings.experience)} · ${settings.bodyWeight.toStringAsFixed(1)} kg',
                              style: TextStyle(
                                color: spec.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Pill(
                                  label: context.trArgs('每周 {n} 练', {
                                    'n': '${settings.weeklyGoal}',
                                  }),
                                  icon: Icons.flag_rounded,
                                ),
                                Pill(
                                  label: settings.hasAiKey
                                      ? 'AI 已配置 Key'
                                      : 'AI 免费通道',
                                  icon: Icons.auto_awesome_rounded,
                                  color: settings.hasAiKey
                                      ? const Color(0xFF22C55E)
                                      : spec.secondary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SectionHeader(
                  title: context.tr('个人档案'),
                  subtitle: context.tr('让 AI 更懂你的训练背景'),
                ),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.account_circle_outlined,
                      title: context.tr('头像'),
                      subtitle: settings.hasAvatar
                          ? context.tr('已设置 · 点击更换或移除')
                          : context.tr('未设置 · 点击从相册选择'),
                      onTap: () => _chooseAvatar(settings),
                    ),
                    _SettingsTile(
                      icon: Icons.flag_rounded,
                      title: context.tr('训练目标'),
                      subtitle: settings.trainingGoal,
                      onTap: () => _editGoal(settings),
                    ),
                    _SettingsTile(
                      icon: Icons.trending_up_rounded,
                      title: context.tr('训练经验'),
                      subtitle: settings.experience,
                      onTap: () => _editExperience(settings),
                    ),
                    _SettingsTile(
                      icon: Icons.monitor_weight_outlined,
                      title: context.tr('体重'),
                      subtitle: '${settings.bodyWeight.toStringAsFixed(1)} kg',
                      onTap: () => _editBodyWeight(settings),
                    ),
                    _SettingsTile(
                      icon: Icons.badge_outlined,
                      title: context.tr('铁卡'),
                      subtitle: settings.heightCm == null
                          ? context.tr('可选填写身高、年龄、体脂与静息心率')
                          : context.trArgs('完整度 {p}% · 点击完善', {
                              'p':
                                  '${(settings.ironProfile.completeness * 100).round()}',
                            }),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const IronCardPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                SectionHeader(
                  title: context.tr('训练偏好'),
                  subtitle: context.tr('这些设置会影响记录与 AI 分析'),
                ),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.calendar_view_week_rounded,
                      title: context.tr('每周训练目标'),
                      subtitle: '${settings.weeklyGoal} ${context.tr('天 / 周')}',
                      onTap: () => _editWeeklyGoal(settings),
                    ),
                    _SettingsTile(
                      icon: Icons.straighten_rounded,
                      title: context.tr('重量单位'),
                      subtitle: settings.weightUnit,
                      onTap: () => _editWeightUnit(settings),
                    ),
                    _SettingsTile(
                      icon: Icons.timer_outlined,
                      title: context.tr('默认组间休息'),
                      subtitle: '${settings.restSeconds} ${context.tr('秒')}',
                      onTap: () => _editRestSeconds(settings),
                    ),
                    _SettingsTreeTile(
                      icon: Icons.vibration_rounded,
                      title: context.tr('触感反馈'),
                      subtitle: settings.haptics
                          ? context.tr('已开启 · 展开选择振动与动效')
                          : context.tr('默认关闭 · 展开后可分别开启'),
                      expanded: _hapticsExpanded,
                      onToggle: () => setState(
                        () => _hapticsExpanded = !_hapticsExpanded,
                      ),
                      switchValue: settings.haptics,
                      onSwitchChanged: (value) =>
                          context.read<SettingsProvider>().setHaptics(value),
                      children: [
                        _SettingsTreeChild(
                          icon: Icons.vibration_outlined,
                          title: context.tr('振动'),
                          subtitle: context.tr('点击时提供轻触振动反馈'),
                          switchValue: settings.hapticsVibration,
                          onChanged: settings.haptics
                              ? (value) => context
                                  .read<SettingsProvider>()
                                  .setHapticsVibration(value)
                              : null,
                        ),
                        _SettingsTreeChild(
                          icon: Icons.animation_rounded,
                          title: context.tr('动效'),
                          subtitle: context.tr('按下内陷、变暗、缩小，松开回弹'),
                          switchValue: settings.hapticsMotion,
                          onChanged: settings.haptics
                              ? (value) => context
                                  .read<SettingsProvider>()
                                  .setHapticsMotion(value)
                              : null,
                        ),
                      ],
                    ),
                    _SettingsTreeTile(
                      icon: Icons.photo_camera_rounded,
                      title: context.tr('仪表盘拍照入口'),
                      subtitle: settings.dashboardCameraEnabled
                          ? context.tr('已显示 · 展开控制照片识别')
                          : context.tr('已隐藏 · 展开后可重新开启'),
                      expanded: _dashboardExpanded,
                      onToggle: () => setState(
                        () => _dashboardExpanded = !_dashboardExpanded,
                      ),
                      switchValue: settings.dashboardCameraEnabled,
                      onSwitchChanged: (value) => context
                          .read<SettingsProvider>()
                          .setDashboardCameraEnabled(value),
                      children: [
                        _SettingsTreeChild(
                          icon: Icons.document_scanner_outlined,
                          title: context.tr('识别打卡照片数据'),
                          subtitle: settings.dashboardAiScanEnabled
                              ? context.tr('识别照片中的距离/速度')
                              : context.tr('关闭识别 · 照片仅作为打卡记录'),
                          switchValue: settings.dashboardAiScanEnabled,
                          onChanged: settings.dashboardCameraEnabled
                              ? (value) => context
                                  .read<SettingsProvider>()
                                  .setDashboardAiScanEnabled(value)
                              : null,
                        ),
                      ],
                    ),
                    _SettingsTreeTile(
                      icon: Icons.notifications_active_outlined,
                      title: context.tr('训练提醒'),
                      subtitle: settings.remindersEnabled
                          ? context.trArgs('每天 {time} 提醒 · 展开自定义', {
                              'time': settings.reminderTime,
                            })
                          : context.tr('关闭 · 展开后可设置提醒'),
                      expanded: _reminderExpanded,
                      onToggle: () => setState(
                        () => _reminderExpanded = !_reminderExpanded,
                      ),
                      switchValue: settings.remindersEnabled,
                      onSwitchChanged: (value) =>
                          _toggleReminders(settings, value),
                      children: [
                        _ReminderMessageField(
                          initialValue: settings.reminderMessage,
                          onChanged: (value) => context
                              .read<SettingsProvider>()
                              .setReminderMessage(value),
                        ),
                        _SettingsTreeChild(
                          icon: Icons.schedule_rounded,
                          title: context.tr('提醒时间'),
                          subtitle: settings.reminderTime,
                          onTap: () => _pickReminderTime(settings),
                        ),
                      ],
                    ),
                  ],
                ),
                SectionHeader(
                  title: context.tr('AI 教练'),
                  subtitle: context.tr('免费多通道 · 自动回退 · 真实大模型驱动'),
                ),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.auto_awesome_rounded,
                      title: context.tr('启用 AI 建议'),
                      subtitle: settings.aiEnabled
                          ? context.tr('已开启')
                          : context.tr('已关闭'),
                      trailing: Switch.adaptive(
                        value: settings.aiEnabled,
                        onChanged: (value) => context
                            .read<SettingsProvider>()
                            .setAiEnabled(value),
                      ),
                      onTap: () => context
                          .read<SettingsProvider>()
                          .setAiEnabled(!settings.aiEnabled),
                    ),
                    _SettingsTreeTile(
                      icon: Icons.shield_outlined,
                      title: '调整数据权限',
                      subtitle: context.trArgs(
                        '已授权 {n}/{total} 类 · 展开精细控制',
                        {
                          'n': '${settings.aiDataScopeCount}',
                          'total': '${aiDataScopeIds.length}',
                        },
                      ),
                      expanded: _aiScopesExpanded,
                      onToggle: () => setState(
                        () => _aiScopesExpanded = !_aiScopesExpanded,
                      ),
                      switchValue: settings.aiDataScopeCount > 0,
                      onSwitchChanged: (value) => context
                          .read<SettingsProvider>()
                          .setAllAiDataScopes(value),
                      children: [
                        for (final group in aiDataScopeGroups)
                          _AiScopeGroupTile(
                            group: group,
                            options: aiDataScopeOptions
                                .where((option) => option.group == group.id)
                                .toList(growable: false),
                            settings: settings,
                          ),
                      ],
                    ),
                    _SettingsTile(
                      icon: _testingAi
                          ? Icons.hourglass_top_rounded
                          : Icons.network_check_rounded,
                      title: context.tr('测试连接'),
                      subtitle: _testingAi
                          ? context.tr('正在测试 AI 通道…')
                          : context.tr('检查免费通道或 Key 是否可用'),
                      trailing: _testingAi
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.chevron_right_rounded,
                              color: spec.textSecondary),
                      onTap: _testingAi ? null : () => _testAi(settings),
                    ),
                    _SettingsTile(
                      icon: Icons.edit_note_rounded,
                      title: context.tr('AI 提示词'),
                      subtitle: settings.aiPrompt.trim().isEmpty
                          ? context.tr('使用内置默认提问 · 点击自定义')
                          : settings.aiPrompt,
                      onTap: () => _editAiPrompt(settings),
                    ),
                  ],
                ),
                SectionHeader(
                  title: context.tr('外观与个性'),
                  subtitle: context.tr('主题会改变整页配色、卡片与背景'),
                ),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.palette_outlined,
                      title: context.tr('主题工坊'),
                      subtitle:
                          '${spec.emoji} ${context.tr(spec.name)} · ${context.tr(spec.subtitle)}',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ThemeGalleryPage(),
                          ),
                        );
                      },
                    ),
                    _SettingsTile(
                      icon: Icons.translate_rounded,
                      title: context.tr('界面语言'),
                      subtitle: appLanguageByCode(settings.appLanguageCode)
                          .nativeLabel,
                      onTap: () => _pickLanguage(settings),
                    ),
                    _SettingsTile(
                      icon: Icons.font_download_outlined,
                      title: context.tr('字体风格'),
                      subtitle:
                          context.tr(appFontById(settings.appFontId).label),
                      onTap: () => _pickFont(settings),
                    ),
                    _SettingsTile(
                      icon: Icons.bolt_rounded,
                      title: context.tr('我的状态'),
                      subtitle:
                          '${settings.statusEmoji} ${context.tr(settings.statusText)}',
                      onTap: () => showStatusEditor(context),
                    ),
                    _SettingsTile(
                      icon: Icons.wb_sunny_outlined,
                      title: context.tr('今日格言'),
                      subtitle: context.tr(settings.todayQuote),
                    ),
                    if (themeProvider.hasCustomBackground)
                      _SettingsTile(
                        icon: Icons.image_outlined,
                        title: context.tr('自定义背景'),
                        subtitle: context.tr('已应用 · 可在主题工坊中移除'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ThemeGalleryPage(),
                            ),
                          );
                        },
                      ),
                  ],
                ),
                SectionHeader(
                  title: context.tr('数据管理'),
                  subtitle: context.tr('本地记录与导出备份'),
                ),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.ios_share_rounded,
                      title: context.tr('导出 Excel'),
                      subtitle: context.trArgs('{n} 条记录', {
                        'n':
                            '${context.watch<WorkoutProvider>().records.length}',
                      }),
                      onTap: _exportData,
                    ),
                    _SettingsTile(
                      icon: Icons.merge_type_rounded,
                      title: context.tr('整合同日记录'),
                      subtitle: context.tr('合并同一天的多次训练'),
                      onTap: _mergeData,
                    ),
                    _SettingsTile(
                      icon: Icons.delete_sweep_outlined,
                      title: context.tr('清空训练记录'),
                      subtitle: context.tr('建议先导出备份'),
                      danger: true,
                      onTap: _clearData,
                    ),
                  ],
                ),
                SectionHeader(
                  title: context.tr('云同步'),
                  subtitle: context.tr('配置与训练数据同步到坚果云'),
                ),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.cloud_sync_rounded,
                      title: context.tr('坚果云同步'),
                      subtitle: nutstore.isConnected
                          ? '${context.tr('已连接')} · ${nutstore.username}'
                          : context.tr('未配置 · 点击配置'),
                      onTap: () => _showCloudSync(nutstore),
                    ),
                  ],
                ),
                SectionHeader(title: context.tr('关于')),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.fitness_center_rounded,
                      title: context.tr('铁镌'),
                      subtitle: '${context.tr('版本')} $appVersion · '
                          '${context.tr('镌刻每一次撸铁')}',
                      onTap: _showAbout,
                    ),
                    _SettingsTile(
                      icon: Icons.explore_rounded,
                      title: context.tr('使用引导'),
                      subtitle: context.tr('重新查看功能说明与自定义开关'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OnboardingPage(),
                        ),
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.code_rounded,
                      title: context.tr('开源地址'),
                      subtitle: 'github.com/MrKedow/Iron-Etch',
                      onTap: () => launchUrl(
                        Uri.parse(
                          'https://github.com/MrKedow/Iron-Etch',
                        ),
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.volunteer_activism_rounded,
                      title: context.tr('鸣谢'),
                      subtitle: context.tr('动作示意图与动作分类参考来源'),
                      onTap: _showAcknowledgments,
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    return GlassPanel(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 58,
                endIndent: 14,
                color: spec.textPrimary.withValues(alpha: .055),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final tone = danger ? const Color(0xFFEF4444) : spec.primary;
    return AppPressFeedback(
      borderRadius: 14,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 18, color: tone),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: danger
                              ? const Color(0xFFEF4444)
                              : spec.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: spec.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (onTap != null)
                  Icon(Icons.chevron_right_rounded,
                      color: spec.textSecondary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsTreeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool expanded;
  final VoidCallback onToggle;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;
  final List<Widget> children;

  const _SettingsTreeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.expanded,
    required this.onToggle,
    required this.children,
    this.switchValue,
    this.onSwitchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    return Column(
      children: [
        _SettingsTile(
          icon: icon,
          title: title,
          subtitle: subtitle,
          onTap: onToggle,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (switchValue != null)
                Switch.adaptive(
                  value: switchValue!,
                  onChanged: onSwitchChanged,
                ),
              const SizedBox(width: 2),
              AnimatedRotation(
                turns: expanded ? .5 : 0,
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  Icons.expand_more_rounded,
                  size: 20,
                  color: spec.textSecondary,
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? Container(
                  margin: const EdgeInsets.fromLTRB(28, 0, 14, 10),
                  padding: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: spec.primary.withValues(alpha: .22),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: children,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _SettingsTreeChild extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool? switchValue;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onTap;

  const _SettingsTreeChild({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.switchValue,
    this.onChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final enabled = onTap != null || (switchValue != null && onChanged != null);
    final tone =
        enabled ? spec.primary : spec.textSecondary.withValues(alpha: .45);
    return AppPressFeedback(
      borderRadius: 12,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ??
              (switchValue != null && onChanged != null
                  ? () => onChanged!(!switchValue!)
                  : null),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
            child: Row(
              children: [
                Icon(icon, size: 15, color: tone),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: enabled ? spec.textPrimary : tone,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: spec.textSecondary.withValues(
                            alpha: enabled ? 1 : .5,
                          ),
                          fontSize: 10.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (switchValue != null)
                  Transform.scale(
                    scale: .78,
                    child: Switch.adaptive(
                      value: switchValue!,
                      onChanged: onChanged,
                    ),
                  )
                else if (onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: spec.textSecondary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiScopeGroupTile extends StatefulWidget {
  final AiDataScopeGroup group;
  final List<AiDataScopeOption> options;
  final SettingsProvider settings;

  const _AiScopeGroupTile({
    required this.group,
    required this.options,
    required this.settings,
  });

  @override
  State<_AiScopeGroupTile> createState() => _AiScopeGroupTileState();
}

class _AiScopeGroupTileState extends State<_AiScopeGroupTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final enabled = widget.options
        .where((option) => widget.settings.aiDataScopeEnabled(option.id))
        .length;
    return Column(
      children: [
        AppPressFeedback(
          borderRadius: 10,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 7,
                  horizontal: 4,
                ),
                child: Row(
                  children: [
                    Icon(
                      _aiGroupIcon(widget.group.id),
                      size: 15,
                      color: enabled > 0
                          ? spec.primary
                          : spec.textSecondary.withValues(alpha: .5),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.group.label,
                            style: TextStyle(
                              color: spec.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${widget.group.description} · $enabled/'
                            '${widget.options.length}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: spec.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Transform.scale(
                      scale: .72,
                      child: Switch.adaptive(
                        value: enabled > 0,
                        onChanged: (value) =>
                            widget.settings.setAiDataScopeGroup(
                          widget.options.map((option) => option.id),
                          value,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 17,
                      color: spec.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Container(
                  margin: const EdgeInsets.only(left: 18, bottom: 4),
                  padding: const EdgeInsets.only(left: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: spec.textPrimary.withValues(alpha: .1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      for (final option in widget.options)
                        _SettingsTreeChild(
                          icon: _aiScopeIcon(option.id),
                          title: option.label,
                          subtitle: option.description,
                          switchValue:
                              widget.settings.aiDataScopeEnabled(option.id),
                          onChanged: (value) =>
                              widget.settings.setAiDataScope(option.id, value),
                        ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

IconData _aiGroupIcon(String id) {
  switch (id) {
    case 'profile':
      return Icons.badge_outlined;
    case 'summary':
      return Icons.summarize_outlined;
    case 'weekly':
      return Icons.date_range_outlined;
    case 'parts':
      return Icons.accessibility_new_rounded;
    case 'recent':
      return Icons.history_rounded;
    case 'exercise':
      return Icons.fitness_center_rounded;
    case 'feeling':
      return Icons.mood_outlined;
    default:
      return Icons.tune_rounded;
  }
}

IconData _aiScopeIcon(String id) {
  switch (id) {
    case 'profile':
      return Icons.badge_outlined;
    case 'summary':
      return Icons.summarize_outlined;
    case 'weekly':
      return Icons.date_range_outlined;
    case 'parts':
      return Icons.accessibility_new_rounded;
    case 'recent':
      return Icons.history_rounded;
    case 'exercises':
      return Icons.fitness_center_rounded;
    case 'feelings':
      return Icons.mood_outlined;
    default:
      return Icons.tune_rounded;
  }
}

class _ReminderMessageField extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;

  const _ReminderMessageField({
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_ReminderMessageField> createState() => _ReminderMessageFieldState();
}

class _ReminderMessageFieldState extends State<_ReminderMessageField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);
  final FocusNode _focusNode = FocusNode();

  @override
  void didUpdateWidget(covariant _ReminderMessageField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != _controller.text && !_focusNode.hasFocus) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        decoration: BoxDecoration(
          color: spec.textPrimary.withValues(alpha: .035),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: spec.primary.withValues(alpha: .18),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 18,
                color: spec.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.done,
                style: TextStyle(
                  color: spec.textPrimary,
                  fontSize: 13.5,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: context.tr('输入提醒文案'),
                  hintStyle: TextStyle(
                    color: spec.textSecondary.withValues(alpha: .65),
                    fontSize: 13.5,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: widget.onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
