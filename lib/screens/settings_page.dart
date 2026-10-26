import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../providers/app_providers.dart';
import '../services/ai_coach_service.dart';
import '../widgets/app_ui.dart';
import '../widgets/status_banner.dart';
import 'theme_gallery_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _testingAi = false;

  Future<void> _editNickname(SettingsProvider settings) async {
    final controller = TextEditingController(text: settings.nickname);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 16,
          decoration: const InputDecoration(
            hintText: '铁友',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    await context.read<SettingsProvider>().setNickname(result);
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
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
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
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, current),
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editGoal(SettingsProvider settings) async {
    final result = await _showChoiceDialog(
      title: '训练目标',
      current: settings.trainingGoal,
      options: const ['增肌', '减脂', '力量', '塑形', '健康'],
    );
    if (result == null || !mounted) return;
    await context.read<SettingsProvider>().setTrainingGoal(result);
  }

  Future<void> _editExperience(SettingsProvider settings) async {
    final result = await _showChoiceDialog(
      title: '训练经验',
      current: settings.experience,
      options: const ['新手', '进阶', '高阶'],
    );
    if (result == null || !mounted) return;
    await context.read<SettingsProvider>().setExperience(result);
  }

  Future<void> _editWeeklyGoal(SettingsProvider settings) async {
    final value = await _showSliderDialog(
      title: '每周训练目标',
      description: 'AI 教练与首页会按这个目标评估你的训练频率。',
      value: settings.weeklyGoal.toDouble(),
      min: 1,
      max: 7,
      divisions: 6,
      labelBuilder: (v) => '${v.round()} 天 / 周',
    );
    if (value == null || !mounted) return;
    await context.read<SettingsProvider>().setWeeklyGoal(value.round());
  }

  Future<void> _editBodyWeight(SettingsProvider settings) async {
    final value = await _showSliderDialog(
      title: '体重',
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
      title: '默认组间休息',
      description: '记录训练时参考用的默认休息时间。',
      value: settings.restSeconds.toDouble(),
      min: 15,
      max: 300,
      divisions: 19,
      labelBuilder: (v) => '${v.round()} 秒',
    );
    if (value == null || !mounted) return;
    await context.read<SettingsProvider>().setRestSeconds(value.round());
  }

  Future<void> _editWeightUnit(SettingsProvider settings) async {
    final result = await _showChoiceDialog(
      title: '重量单位',
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
      helpText: '选择提醒时间',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null || !mounted) return;
    final text =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    await context.read<SettingsProvider>().setReminderTime(text);
  }

  Future<void> _editAiConfig(SettingsProvider settings) async {
    final endpointController = TextEditingController(text: settings.aiEndpoint);
    final modelController = TextEditingController(text: settings.aiModel);
    final keyController = TextEditingController(text: settings.aiApiKey);
    var obscureKey = true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final spec = context.watch<ThemeProvider>().currentSpec;
          return AlertDialog(
            title: const Text('OpenCode AI 配置'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: spec.primary.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '铁镌通过 OpenCode Zen 的 OpenAI 兼容接口调用真实大模型。'
                      '不填 API Key 时会尝试免费通道，可能受到限流。',
                      style: TextStyle(
                        color: spec.textSecondary,
                        fontSize: 11.5,
                        height: 1.55,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: endpointController,
                    decoration: const InputDecoration(
                      labelText: '接口地址',
                      hintText: SettingsProvider.defaultAiEndpoint,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: modelController,
                    decoration: const InputDecoration(
                      labelText: '模型名称',
                      hintText: SettingsProvider.defaultAiModel,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: keyController,
                    obscureText: obscureKey,
                    decoration: InputDecoration(
                      labelText: 'API Key（可选）',
                      hintText: 'sk-...',
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setDialogState(() => obscureKey = !obscureKey),
                        icon: Icon(
                          obscureKey
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true && mounted) {
      await context.read<SettingsProvider>().setAiConfig(
            endpoint: endpointController.text,
            model: modelController.text,
            apiKey: keyController.text,
          );
    }
    endpointController.dispose();
    modelController.dispose();
    keyController.dispose();
  }

  Future<void> _testAi(SettingsProvider settings) async {
    if (!settings.aiEnabled) {
      _showSnack('AI 建议当前已关闭，请先开启。');
      return;
    }
    setState(() => _testingAi = true);
    final reply = await AiCoachService.testConnection(
      endpoint: settings.aiEndpoint,
      model: settings.aiModel,
      apiKey: settings.aiApiKey,
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
              : '${reply.error ?? '未知错误'}\n\n提示：可在设置中填写 OpenCode API Key，或稍后重试免费通道。',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    final provider = context.read<WorkoutProvider>();
    if (provider.records.isEmpty) {
      _showSnack('还没有可导出的训练记录');
      return;
    }
    try {
      final path = await ExcelExportService().exportToExcel(provider.records);
      if (path == null) {
        _showSnack('导出失败，请稍后重试');
        return;
      }
      await Share.shareXFiles([XFile(path)], text: '铁镌训练数据');
    } catch (e) {
      if (mounted) _showSnack('导出失败：$e');
    }
  }

  Future<void> _mergeData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('整合同日记录'),
        content: const Text('把同一天的多条记录合并为一条，动作会保留。是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('整合'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    context.read<WorkoutProvider>().mergeSameDayRecords();
    _showSnack('已整合同一天的记录');
  }

  Future<void> _clearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空全部训练记录？'),
        content: const Text('所有训练历史都会被删除，且无法恢复。建议先导出备份。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    context.read<WorkoutProvider>().clearRecords();
    _showSnack('训练记录已清空');
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
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: spec.heroGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.fitness_center_rounded,
                  size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('关于铁镌'),
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
              '版本 1.2.0（Android）',
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
                Uri.parse('https://github.com/MrKedow/Fitness-Tracker'),
              ),
              child: const Text(
                'GitHub · MrKedow/Fitness-Tracker',
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
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final spec = context.watch<ThemeProvider>().currentSpec;
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: spec.background.withValues(alpha: .82),
            title: const Text('设置'),
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
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: spec.heroGradient,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Center(
                          child: Text(
                            settings.nickname.characters.first,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
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
                                  tooltip: '修改昵称',
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(Icons.edit_rounded,
                                      size: 17, color: spec.textSecondary),
                                ),
                              ],
                            ),
                            Text(
                              '${settings.trainingGoal} · ${settings.experience} · ${settings.bodyWeight.toStringAsFixed(1)} kg',
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
                                  label: '每周 ${settings.weeklyGoal} 练',
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
                const SectionHeader(
                  title: '个人档案',
                  subtitle: '让 AI 更懂你的训练背景',
                ),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.flag_rounded,
                      title: '训练目标',
                      subtitle: settings.trainingGoal,
                      onTap: () => _editGoal(settings),
                    ),
                    _SettingsTile(
                      icon: Icons.trending_up_rounded,
                      title: '训练经验',
                      subtitle: settings.experience,
                      onTap: () => _editExperience(settings),
                    ),
                    _SettingsTile(
                      icon: Icons.monitor_weight_outlined,
                      title: '体重',
                      subtitle: '${settings.bodyWeight.toStringAsFixed(1)} kg',
                      onTap: () => _editBodyWeight(settings),
                    ),
                  ],
                ),
                const SectionHeader(
                  title: '训练偏好',
                  subtitle: '这些设置会影响记录与 AI 分析',
                ),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.calendar_view_week_rounded,
                      title: '每周训练目标',
                      subtitle: '${settings.weeklyGoal} 天 / 周',
                      onTap: () => _editWeeklyGoal(settings),
                    ),
                    _SettingsTile(
                      icon: Icons.straighten_rounded,
                      title: '重量单位',
                      subtitle: settings.weightUnit,
                      onTap: () => _editWeightUnit(settings),
                    ),
                    _SettingsTile(
                      icon: Icons.timer_outlined,
                      title: '默认组间休息',
                      subtitle: '${settings.restSeconds} 秒',
                      onTap: () => _editRestSeconds(settings),
                    ),
                    _SettingsTile(
                      icon: Icons.vibration_rounded,
                      title: '触感反馈',
                      subtitle: '保存与切换时提供轻触反馈',
                      trailing: Switch.adaptive(
                        value: settings.haptics,
                        onChanged: (value) =>
                            context.read<SettingsProvider>().setHaptics(value),
                      ),
                      onTap: () => context
                          .read<SettingsProvider>()
                          .setHaptics(!settings.haptics),
                    ),
                    _SettingsTile(
                      icon: Icons.notifications_active_outlined,
                      title: '训练提醒',
                      subtitle: settings.remindersEnabled
                          ? '每天 ${settings.reminderTime} 提醒'
                          : '关闭',
                      trailing: Switch.adaptive(
                        value: settings.remindersEnabled,
                        onChanged: (value) => context
                            .read<SettingsProvider>()
                            .setRemindersEnabled(value),
                      ),
                      onTap: () => context
                          .read<SettingsProvider>()
                          .setRemindersEnabled(!settings.remindersEnabled),
                    ),
                    if (settings.remindersEnabled)
                      _SettingsTile(
                        icon: Icons.schedule_rounded,
                        title: '提醒时间',
                        subtitle: settings.reminderTime,
                        onTap: () => _pickReminderTime(settings),
                      ),
                  ],
                ),
                const SectionHeader(
                  title: 'AI 教练',
                  subtitle: 'OpenCode Zen · 真实大模型驱动',
                ),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.auto_awesome_rounded,
                      title: '启用 AI 建议',
                      subtitle: settings.aiEnabled ? '已开启' : '已关闭',
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
                    _SettingsTile(
                      icon: Icons.link_rounded,
                      title: '接口地址',
                      subtitle: settings.aiEndpoint,
                      onTap: () => _editAiConfig(settings),
                    ),
                    _SettingsTile(
                      icon: Icons.memory_rounded,
                      title: '模型',
                      subtitle: settings.aiModel,
                      onTap: () => _editAiConfig(settings),
                    ),
                    _SettingsTile(
                      icon: Icons.key_rounded,
                      title: 'API Key',
                      subtitle:
                          settings.hasAiKey ? '已保存 · 点击修改' : '未填写 · 使用免费通道',
                      onTap: () => _editAiConfig(settings),
                    ),
                    _SettingsTile(
                      icon: _testingAi
                          ? Icons.hourglass_top_rounded
                          : Icons.network_check_rounded,
                      title: '测试连接',
                      subtitle:
                          _testingAi ? '正在连接 OpenCode…' : '检查 Key 与网络是否可用',
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
                  ],
                ),
                const SectionHeader(
                  title: '外观与个性',
                  subtitle: '主题会改变整页配色、卡片与背景',
                ),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.palette_outlined,
                      title: '主题工坊',
                      subtitle: '${spec.emoji} ${spec.name} · ${spec.subtitle}',
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
                      icon: Icons.bolt_rounded,
                      title: '我的状态',
                      subtitle:
                          '${settings.statusEmoji} ${settings.statusText}',
                      onTap: () => showStatusEditor(context),
                    ),
                    _SettingsTile(
                      icon: Icons.wb_sunny_outlined,
                      title: '今日格言',
                      subtitle: settings.todayQuote,
                    ),
                    if (themeProvider.hasCustomBackground)
                      _SettingsTile(
                        icon: Icons.image_outlined,
                        title: '自定义背景',
                        subtitle: '已应用 · 可在主题工坊中移除',
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
                const SectionHeader(
                  title: '数据管理',
                  subtitle: '本地记录与导出备份',
                ),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.ios_share_rounded,
                      title: '导出 Excel',
                      subtitle:
                          '${context.watch<WorkoutProvider>().records.length} 条记录',
                      onTap: _exportData,
                    ),
                    _SettingsTile(
                      icon: Icons.merge_type_rounded,
                      title: '整合同日记录',
                      subtitle: '合并同一天的多次训练',
                      onTap: _mergeData,
                    ),
                    _SettingsTile(
                      icon: Icons.delete_sweep_outlined,
                      title: '清空训练记录',
                      subtitle: '建议先导出备份',
                      danger: true,
                      onTap: _clearData,
                    ),
                  ],
                ),
                const SectionHeader(title: '关于'),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.fitness_center_rounded,
                      title: '铁镌',
                      subtitle: '版本 1.2.0 · 镌刻每一次撸铁',
                      onTap: _showAbout,
                    ),
                    _SettingsTile(
                      icon: Icons.code_rounded,
                      title: '开源地址',
                      subtitle: 'github.com/MrKedow/Fitness-Tracker',
                      onTap: () => launchUrl(
                        Uri.parse(
                          'https://github.com/MrKedow/Fitness-Tracker',
                        ),
                      ),
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
    return Material(
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
                        color:
                            danger ? const Color(0xFFEF4444) : spec.textPrimary,
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
    );
  }
}
