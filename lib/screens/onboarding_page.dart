import '../l10n/localized_material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';

class OnboardingPrefs {
  const OnboardingPrefs._();

  static const String completedKey = 'onboarding_completed';
}

class OnboardingPage extends StatefulWidget {
  final Widget? firstRunNextPage;

  const OnboardingPage({super.key, this.firstRunNextPage});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _index = 0;
  bool _completing = false;

  static const List<_OnboardingStepData> _steps = [
    _OnboardingStepData(
      icon: Icons.fitness_center_rounded,
      title: '欢迎来到铁镌',
      subtitle: '记录、复盘、变强',
      accent: Color(0xFFE4B363),
      points: [
        '所有训练数据优先保存在本地，随时可导出备份。',
        '主页记录今天的训练，历史页面回看每一次进步。',
        '本次引导随时可以右上角关闭，之后可在设置 → 关于重新打开。',
      ],
    ),
    _OnboardingStepData(
      icon: Icons.edit_calendar_rounded,
      title: '记录今天的铁',
      subtitle: '日期、动作、部位与打卡照片',
      accent: Color(0xFFF97316),
      points: [
        '选择日期后填写动作、重量、组数与次数。',
        '不同训练类型会自动切换对应的输入项。',
        '开启相机入口后，可以为有氧或训练记录添加打卡照片。',
      ],
    ),
    _OnboardingStepData(
      icon: Icons.battery_charging_full_rounded,
      title: '今日状态电池',
      subtitle: '拖动指针，看看今天的状态',
      accent: Color(0xFF22C55E),
      points: [
        '点击状态卡，左右拖动菱形指针调整电量。',
        '电量会分为需要休息啦、有点累、力量在回来…、Power！！！四档。',
        '每一档都有对应的极光颜色，主页电池下方会同步显示。',
      ],
    ),
    _OnboardingStepData(
      icon: Icons.history_rounded,
      title: '历史与数据',
      subtitle: '每一次训练都算数',
      accent: Color(0xFF3B82F6),
      points: [
        '历史按日期分组，可展开查看动作、照片和状态电量。',
        '编辑训练记录时同样可以拖动状态电池指针。',
        '支持 Excel / CSV 导入导出，数据始终掌握在自己手里。',
      ],
    ),
    _OnboardingStepData(
      icon: Icons.auto_awesome_rounded,
      title: 'AI 教练',
      subtitle: '真实大模型驱动的训练建议',
      accent: Color(0xFF8B5CF6),
      points: [
        'AI 建议默认关闭，可在设置 → AI 教练中开启。',
        '支持免费通道与自定义接口、模型和提示词。',
        'AI 会结合训练记录、状态电量与个人档案给出建议。',
      ],
    ),
    _OnboardingStepData(
      icon: Icons.menu_book_rounded,
      title: '视频合集与书库',
      subtitle: '训练之外，也要持续学习',
      accent: Color(0xFF14B8A6),
      points: [
        '视频合集支持长按编辑、拖动排序和恢复内置合集。',
        '书库支持内置电子书、阅读进度与多种书架材质。',
        '阅读器支持自动隐藏控件、点击两侧翻页和上下滚动。',
      ],
    ),
    _OnboardingStepData(
      icon: Icons.touch_app_rounded,
      title: '触感反馈',
      subtitle: '振动与动效，默认关闭',
      accent: Color(0xFFEC4899),
      points: [
        '设置 → 训练偏好 → 触感反馈中开启总开关。',
        '振动：点击按钮、卡片和模块时提供轻触反馈。',
        '动效：按下内陷、变暗、缩小，松开时回弹放大。',
      ],
    ),
    _OnboardingStepData(
      icon: Icons.notifications_active_rounded,
      title: '提醒与云同步',
      subtitle: '默认关闭，按需开启',
      accent: Color(0xFF0EA5E9),
      points: [
        '训练提醒开启后会请求通知权限，即使退出应用也能收到提醒。',
        '坚果云同步可自定义上传与恢复范围，账号密码始终不同步。',
        '软件内所有功能开关默认关闭，避免未经确认的后台行为。',
      ],
    ),
    _OnboardingStepData(
      icon: Icons.check_circle_rounded,
      title: '准备好了',
      subtitle: '开始镌刻今天的训练',
      accent: Color(0xFF22C55E),
      points: [
        '主页右上角是设置入口，所有自定义开关都在那里。',
        '设置 → 关于 → 使用引导，可以随时重新查看本引导。',
        '现在就开始记录今天的铁吧。',
      ],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    if (_completing) return;
    _completing = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingPrefs.completedKey, true);
    if (!mounted) return;
    if (widget.firstRunNextPage != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => widget.firstRunNextPage!),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _next() {
    if (_index >= _steps.length - 1) {
      _complete();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _previous() {
    if (_index == 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final isLast = _index == _steps.length - 1;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _complete();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 12, 4),
                child: Row(
                  children: [
                    Text(
                      '快速上手',
                      style: TextStyle(
                        color: spec.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_index + 1}/${_steps.length}',
                      style: TextStyle(
                        color: spec.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _complete,
                      child: const Text('退出引导'),
                    ),
                    IconButton(
                      tooltip: context.tr('关闭'),
                      onPressed: _complete,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _steps.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) {
                    return _OnboardingStep(
                      data: _steps[index],
                      spec: spec,
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _steps.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _index ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _index
                                  ? spec.primary
                                  : spec.textSecondary.withValues(alpha: .28),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (_index > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _previous,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                              child: const Text('上一步'),
                            ),
                          ),
                        if (_index > 0) const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: _next,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: Text(isLast ? '开始使用' : '下一步'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingStepData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final List<String> points;

  const _OnboardingStepData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.points,
  });
}

class _OnboardingStep extends StatelessWidget {
  final _OnboardingStepData data;
  final AppThemeSpec spec;

  const _OnboardingStep({required this.data, required this.spec});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    data.accent.withValues(alpha: .85),
                    data.accent.withValues(alpha: .35),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: data.accent.withValues(alpha: .28),
                    blurRadius: 40,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(data.icon, size: 58, color: Colors.white),
            ),
          ),
          const SizedBox(height: 30),
          Text(
            data.title,
            style: TextStyle(
              color: spec.textPrimary,
              fontSize: 25,
              height: 1.15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            data.subtitle,
            style: TextStyle(
              color: data.accent,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          GlassPanel(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final point in data.points) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: data.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          point,
                          style: TextStyle(
                            color: spec.textSecondary,
                            fontSize: 13,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (point != data.points.last) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '提示：所有功能开关默认关闭，可在设置中按需开启。',
            style: TextStyle(
              color: spec.textSecondary.withValues(alpha: .8),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
