import 'dart:async';
import 'dart:math';

import '../l10n/localized_material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/exercise_library.dart';
import '../main.dart';
import '../providers/app_providers.dart';
import '../services/ai_coach_service.dart';
import '../services/coach_insights.dart';
import '../services/knowledge_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_config_dialog.dart';
import '../widgets/ai_message_text.dart';
import '../widgets/ai_reasoning_panel.dart';
import '../widgets/app_ui.dart';
import '../widgets/user_avatar.dart';
import 'insight_detail_pages.dart';
import 'knowledge_page.dart';

class CoachAnalysisPage extends StatefulWidget {
  const CoachAnalysisPage({super.key});

  @override
  State<CoachAnalysisPage> createState() => _CoachAnalysisPageState();
}

class _CoachAnalysisPageState extends State<CoachAnalysisPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orbController;
  CoachKnowledge _knowledge = CoachKnowledge.empty();
  bool _knowledgeLoading = true;
  List<KnowledgeArticle> _liveArticles = const [];
  bool _liveLoading = true;
  String? _liveError;

  final List<_ChatTurn> _chat = [];
  bool _aiLoading = false;
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _aiKey = GlobalKey();
  final GlobalKey _lastTurnKey = GlobalKey();
  final Random _random = Random();
  Timer? _typingTimer;
  int _turnSeq = 0;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        _loadKnowledge();
        _loadLiveKnowledge();
      });
    });
  }

  Future<void> _loadKnowledge() async {
    final knowledge = await CoachKnowledge.load();
    if (!mounted) return;
    setState(() {
      _knowledge = knowledge;
      _knowledgeLoading = false;
    });
  }

  Future<void> _loadLiveKnowledge() async {
    setState(() => _liveLoading = true);
    final bundle = await KnowledgeService.fetchAll(limitPerTopic: 2);
    if (!mounted) return;
    setState(() {
      _liveArticles = bundle.articles.take(4).toList();
      _liveError = bundle.failures.isEmpty ? null : bundle.failures.first;
      _liveLoading = false;
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _orbController.dispose();
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _beginTypewriter(_ChatTurn turn) {
    if (!mounted || turn.visibleChars == null || turn.typing) return;
    turn.typing = true;
    _typingTimer?.cancel();
    _typingTimer = Timer.periodic(const Duration(milliseconds: 18), (timer) {
      if (!mounted || !_chat.contains(turn)) {
        timer.cancel();
        return;
      }
      final full = turn.content;
      final shown = turn.visibleChars ?? full.length;
      if (shown < full.length) {
        setState(() {
          turn.visibleChars = min(full.length, shown + 2);
        });
      } else if (turn.answerDone) {
        timer.cancel();
        turn.typing = false;
        _typingTimer = null;
      }
    });
  }

  void _handleReasoningMarqueeDone(_ChatTurn turn) {
    if (!mounted || turn.reasoningStreaming) return;
    _beginTypewriter(turn);
  }

  CoachInsights get _insights =>
      CoachInsights(context.read<WorkoutProvider>().records);

  void _scrollToAi({bool latestTurn = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = latestTurn && _lastTurnKey.currentContext != null
          ? _lastTurnKey.currentContext
          : _aiKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        alignment: latestTurn ? .12 : .04,
      );
    });
  }

  Future<void> _askAi({String? presetQuestion}) async {
    final settings = context.read<SettingsProvider>();
    final insights = _insights;
    final customPrompt = settings.aiPrompt.trim();
    final defaultQuestion = customPrompt.isNotEmpty
        ? customPrompt
        : '请根据我的训练数据，给出最近训练的详细分析、问题和下一步建议。';
    final question = presetQuestion ??
        (presetQuestion == null && _chat.isEmpty
            ? defaultQuestion
            : _questionController.text.trim());

    if (!settings.aiEnabled) {
      _showSnack(context.tr('AI 建议已在设置中关闭，可随时重新开启。'));
      return;
    }
    if (question.isEmpty && _chat.isNotEmpty) {
      _showSnack(context.tr('先写下一个问题，再让 AI 教练分析。'));
      return;
    }

    final effectiveQuestion = question.isEmpty ? defaultQuestion : question;

    _typingTimer?.cancel();
    for (final turn in _chat) {
      if (turn.visibleChars != null) {
        turn.visibleChars = turn.content.length;
        turn.typing = false;
      }
    }
    final assistant = _ChatTurn(
      id: ++_turnSeq,
      role: _ChatRole.assistant,
      content: '',
      reasoning: '',
      loading: true,
      visibleChars: 0,
      answerDone: false,
      reasoningStreaming: true,
    );
    setState(() {
      _aiLoading = true;
      _chat.add(_ChatTurn(role: _ChatRole.user, content: effectiveQuestion));
      _chat.add(assistant);
      _questionController.clear();
    });
    _scrollToAi(latestTurn: true);

    final languageName = switch (AppLocalizations.currentLanguageCode) {
      'en' => 'English',
      'ja' => 'Japanese',
      'ko' => 'Korean',
      'ru' => 'Russian',
      _ => 'Chinese',
    };
    final systemPrompt = '''
You are the AI strength coach of the Iron Etch app, powered by free AI channels.
Your style: professional, direct, and warm, like an experienced coach who understands training data. Avoid empty encouragement and always cite the user's real data.
Training advice must follow scientific evidence; state uncertainty when unsure; never provide a medical diagnosis, and suggest seeing a doctor if pain or injury is involved.
Focus on: quality of the latest session, volume and frequency, muscle balance, progressive overload, recovery, and next week's plan.

Output format:
1. Respond only in $languageName. Do not output a Chinese draft or self-explanation.
2. You may use Markdown, such as level-2 headings, bold text, bullet points, and tables; do not litter the body with asterisks.
3. Start with a one-sentence conclusion of no more than 24 words summarizing the status.
4. Follow with 2-3 short sections using brief headings similar to "Conclusion", "Issues", and "Plan", each with 1-3 sentences.
5. End with one separate line beginning with the $languageName equivalent of "Do this today:" and give one concrete action the user can do today.
6. Keep a natural tone, as if the coach is speaking face to face; prioritize complete content and never cut key advice just to save words.

The user's real workout data follows:
${insights.buildAiContext(settings)}
''';

    final history = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];
    for (final turn in _chat) {
      if (turn.loading) continue;
      if (turn.role == _ChatRole.assistant && turn.isError) continue;
      history.add({
        'role': turn.role == _ChatRole.user ? 'user' : 'assistant',
        'content': turn.content,
      });
    }

    final reply = await AiCoachService.chatStream(
      messages: history,
      endpoint: settings.aiEndpoint,
      model: settings.aiModel,
      apiKey: settings.aiApiKey,
      reasoningEffort: settings.aiReasoningEffort,
      onReasoningChunk: (delta) {
        if (!mounted) return;
        setState(() => assistant.reasoning += delta);
      },
      onContentChunk: (delta) {
        if (!mounted) return;
        setState(() => assistant.content += delta);
        if (!assistant.typing &&
            (!assistant.reasoningStreaming ||
                assistant.reasoning.trim().isEmpty)) {
          _beginTypewriter(assistant);
        }
      },
      onReasoningDone: () {
        if (!mounted) return;
        setState(() => assistant.reasoningStreaming = false);
        if (assistant.reasoning.trim().isEmpty ||
            assistant.content.trim().isNotEmpty) {
          _beginTypewriter(assistant);
        }
      },
    );

    if (!mounted) return;
    setState(() {
      _aiLoading = false;
      assistant.loading = false;
      assistant.answerDone = true;
      assistant.reasoningStreaming = false;
      if (reply.success) {
        if (assistant.reasoning.trim().isEmpty &&
            reply.reasoning.trim().isNotEmpty) {
          assistant.reasoning = reply.reasoning;
        }
        if (assistant.content.trim().isEmpty) {
          assistant.content = reply.content;
        }
        if (assistant.content.trim().isEmpty) {
          assistant.content = trGlobal(
            '模型只返回了思考内容，没有生成最终回答。可以重新提问或降低推理强度。',
          );
          assistant.visibleChars = null;
        }
      } else {
        assistant
          ..content = _fallbackAdvice(
            reply.error ?? trGlobal('AI 暂时不可用'),
            insights,
          )
          ..reasoning = ''
          ..isError = true
          ..visibleChars = null;
      }
    });
    if (reply.success &&
        assistant.visibleChars != null &&
        !assistant.typing &&
        assistant.content.trim().isNotEmpty) {
      _beginTypewriter(assistant);
    }
    _scrollToAi(latestTurn: true);
  }

  String _fallbackAdvice(String error, CoachInsights insights) {
    final buffer = StringBuffer();
    buffer.writeln(trGlobalArgs('AI 在线服务暂时不可用：{e}', {'e': error}));
    buffer.writeln();
    buffer.writeln(trGlobal('先给你一份离线教练建议：'));
    if (insights.lastRecord == null) {
      buffer.writeln(
        trGlobal('• 还没有训练记录，先完成第一次训练，AI 才能基于真实数据给建议。'),
      );
      return buffer.toString();
    }
    buffer.writeln(
      trGlobalArgs('• 最近一次训练做功 {w} 千焦，共 {p} 个项目。', {
        'w': (insights.lastWork / 1000).toStringAsFixed(1),
        'p': '${insights.lastRecord!.projects.length}',
      }),
    );
    if (insights.previousWork > 0) {
      final diff = insights.lastWork - insights.previousWork;
      buffer.writeln(
        trGlobalArgs('• 与上一次相比容量{trend} {w} 千焦。', {
          'trend': trGlobal(diff >= 0 ? '提升' : '下降'),
          'w': (diff.abs() / 1000).toStringAsFixed(1),
        }),
      );
    }
    if (insights.missingPartsWeek.isNotEmpty) {
      buffer.writeln(
        trGlobalArgs('• 本周还缺少 {parts} 的训练，下周优先补齐。', {
          'parts': insights.missingPartsWeek.map(trGlobal).join(', '),
        }),
      );
    } else {
      buffer.writeln(trGlobal('• 本周部位覆盖较全面，继续保持。'));
    }
    buffer.writeln(
      trGlobal('• 下一次训练优先保持动作质量，再尝试在主要动作上增加 1-2.5kg 或 1-2 次。'),
    );
    return buffer.toString();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = context.watch<WorkoutProvider>().records;
    final settings = context.watch<SettingsProvider>();
    final spec = context.watch<ThemeProvider>().currentSpec;
    final insights = CoachInsights(records);
    final recent = insights.sortedDesc;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 0,
            backgroundColor: spec.background.withValues(alpha: .8),
            title: Text(context.tr('AI 训练舱')),
            actions: [
              IconButton(
                tooltip: context.tr('刷新 AI 建议'),
                onPressed: _aiLoading ? null : () => _askAi(),
                icon: const Icon(Icons.auto_awesome_rounded),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeSlideIn(
                    child: _HeroPanel(
                      insights: insights,
                      settings: settings,
                      orb: _orbController,
                      onAskAi: () {
                        if (_chat.isEmpty) {
                          _askAi();
                        } else {
                          _scrollToAi(latestTurn: true);
                        }
                      },
                    ),
                  ),
                  const SectionHeader(
                    title: '训练概览',
                    subtitle: '来自你真实训练记录的关键数据',
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          label: '累计训练',
                          value: '${insights.totalSessions}',
                          unit: '次',
                          icon: Icons.fitness_center_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatTile(
                          label: '本周训练',
                          value: '${insights.thisWeekSessions}',
                          unit: '/${settings.weeklyGoal}',
                          icon: Icons.calendar_month_rounded,
                          accent: spec.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          label: '总训练容量',
                          value: (insights.totalWork / 1000).toStringAsFixed(1),
                          unit: '千焦',
                          icon: Icons.bolt_rounded,
                          accent: const Color(0xFFFFA24C),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatTile(
                          label: '累计组数',
                          value: '${insights.totalSets}',
                          unit: '组',
                          icon: Icons.stacked_bar_chart_rounded,
                          accent: const Color(0xFF4FD1C5),
                        ),
                      ),
                    ],
                  ),
                  const SectionHeader(
                    title: '最近训练分析',
                    subtitle: '逐项拆解最近一次训练',
                  ),
                  FadeSlideIn(
                    index: 1,
                    child: _RecentAnalysisCard(
                      insights: insights,
                      records: recent,
                    ),
                  ),
                  const SectionHeader(
                    title: '训练洞察',
                    subtitle: '频率、容量、均衡与个人纪录',
                  ),
                  _InsightGrid(insights: insights, settings: settings),
                  const SectionHeader(
                    title: 'AI 教练建议',
                    subtitle: '真实大模型 · 基于你的训练数据生成',
                  ),
                  Container(
                    key: _aiKey,
                    child: _AiCoachCard(
                      spec: spec,
                      settings: settings,
                      chat: _chat,
                      loading: _aiLoading,
                      controller: _questionController,
                      lastTurnKey: _lastTurnKey,
                      onSend: () => _askAi(),
                      onPreset: (question) => _askAi(presetQuestion: question),
                      onReasoningMarqueeDone: _handleReasoningMarqueeDone,
                      onOpenSettings: () {
                        _showAiConfig(context, settings);
                      },
                    ),
                  ),
                  SectionHeader(
                    title: '知识补给',
                    subtitle: '实时同步 PubMed 与 WHO，下拉查看全部',
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const KnowledgePage(),
                          ),
                        );
                      },
                      child: const Text('全部'),
                    ),
                  ),
                  if (_liveLoading && _liveArticles.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 26),
                      child: Center(
                        child: Column(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 10),
                            Text(
                              '正在获取最新研究…',
                              style: TextStyle(
                                color: spec.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_liveArticles.isNotEmpty)
                    for (final article in _liveArticles)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: KnowledgeArticleCard(article: article),
                      )
                  else if (_knowledgeLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    _KnowledgeGrid(
                      knowledge: _knowledge,
                      random: _random,
                    ),
                    if (_liveError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '实时资讯暂不可用，已展示本地精选：$_liveError',
                          style: TextStyle(
                            color: spec.textSecondary,
                            fontSize: 10.5,
                            height: 1.5,
                          ),
                        ),
                      ),
                  ],
                  const SectionHeader(
                    title: '健身以来',
                    subtitle: '每一次训练都在塑造更好的你',
                  ),
                  FadeSlideIn(
                    index: 2,
                    child: _OverallCard(insights: insights),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAiConfig(BuildContext context, SettingsProvider settings) {
    showAiConfigDialog(context, settings);
  }
}

enum _ChatRole { user, assistant }

class _ChatTurn {
  final int id;
  final _ChatRole role;
  String content;
  String reasoning;
  bool loading;
  bool isError = false;
  int? visibleChars;
  bool answerDone;
  bool reasoningStreaming;
  bool typing = false;

  _ChatTurn({
    this.id = 0,
    required this.role,
    required this.content,
    this.reasoning = '',
    this.loading = false,
    this.visibleChars,
    this.answerDone = true,
    this.reasoningStreaming = false,
  });

  String get displayContent {
    final shown = visibleChars;
    if (shown == null) return content;
    return content.substring(
        0, shown < content.length ? shown : content.length);
  }
}

class _HeroPanel extends StatelessWidget {
  final CoachInsights insights;
  final SettingsProvider settings;
  final AnimationController orb;
  final VoidCallback onAskAi;

  const _HeroPanel({
    required this.insights,
    required this.settings,
    required this.orb,
    required this.onAskAi,
  });

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    return GlassPanel(
      padding: EdgeInsets.zero,
      gradient: LinearGradient(
        colors: [
          Color.lerp(spec.primary, spec.card, .55)!,
          Color.lerp(spec.secondary, spec.background, .4)!,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -46,
            top: -60,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: orb,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: orb.value * pi * 2,
                    child: Container(
                      width: 210,
                      height: 210,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            spec.primary.withValues(alpha: .55),
                            spec.secondary.withValues(alpha: .28),
                            Colors.transparent,
                            spec.primary.withValues(alpha: .55),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: spec.onHero.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: spec.onHero.withValues(alpha: .18),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4ADE80),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _aiChannelLabel(settings),
                            style: TextStyle(
                              color: spec.onHero,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.auto_awesome,
                        color: spec.onHero.withValues(alpha: .6), size: 18),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  context.trArgs('{greeting}，{name}', {
                    'greeting': dayGreeting(),
                    'name': context.tr(settings.nickname),
                  }),
                  style: TextStyle(
                    color: spec.onHero,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  insights.lastRecord == null
                      ? '记录第一次训练，让 AI 教练认识你。'
                      : '最近一次训练 · ${formatMonthDay(insights.lastRecord!.date)} · ${insights.lastRecord!.projects.length} 个项目',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: spec.onHeroMuted,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _heroMetric(
                        spec,
                        '${insights.thisWeekSessions}',
                        '本周次数',
                        '目标 ${settings.weeklyGoal}',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 38,
                      color: spec.onHero.withValues(alpha: .16),
                    ),
                    Expanded(
                      flex: 3,
                      child: _heroMetric(
                        spec,
                        (insights.totalWork / 1000).toStringAsFixed(1),
                        '总容量',
                        '千焦',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 38,
                      color: spec.onHero.withValues(alpha: .16),
                    ),
                    Expanded(
                      flex: 2,
                      child: _heroMetric(
                        spec,
                        '${insights.trainingDays}',
                        '训练天数',
                        '天',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onAskAi,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor:
                          spec.isDark ? spec.background : spec.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.bolt_rounded, size: 20),
                    label: const Text('让 AI 教练分析我的训练'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroMetric(
      AppThemeSpec spec, String value, String label, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: spec.onHero,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: spec.onHeroMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Text(
              sub,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: spec.onHero.withValues(alpha: .55),
                fontSize: 9,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentAnalysisCard extends StatelessWidget {
  final CoachInsights insights;
  final List<WorkoutRecord> records;

  const _RecentAnalysisCard({
    required this.insights,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final last = insights.lastRecord;
    if (last == null) {
      return GlassPanel(
        child: EmptyState(
          icon: Icons.analytics_outlined,
          title: '还没有可分析的训练',
          message: '回到主页记录一次训练，这里会立刻生成项目拆解与进步曲线。',
        ),
      );
    }

    final diff = insights.previousWork <= 0
        ? null
        : insights.lastWork - insights.previousWork;
    final progressList = insights.lastExerciseProgress;

    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GradientIconBadge(
                icon: Icons.insights_rounded,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${formatMonthDay(last.date)} · '
                  '${context.trArgs('第 {n} 次训练', {
                        'n': '${last.sessionNumber ?? '—'}'
                      })}',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: spec.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Pill(
                label: diff == null
                    ? '首次对比'
                    : diff >= 0
                        ? '容量 +${(diff / 1000).toStringAsFixed(1)} kJ'
                        : '容量 -${(diff.abs() / 1000).toStringAsFixed(1)} kJ',
                color: diff == null
                    ? spec.primary
                    : diff >= 0
                        ? const Color(0xFF34C759)
                        : const Color(0xFFFF9500),
                icon: diff == null
                    ? Icons.flag_rounded
                    : diff >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: spec.primary.withValues(alpha: .075),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: spec.primary.withValues(alpha: .14),
              ),
            ),
            child: Row(
              children: [
                _miniMetric(
                  (insights.lastWork / 1000).toStringAsFixed(1),
                  '本次做功 kJ',
                  spec,
                ),
                _miniDivider(spec),
                _miniMetric(
                  (insights.averageWork / 1000).toStringAsFixed(1),
                  '平均容量 kJ',
                  spec,
                ),
                _miniDivider(spec),
                _miniMetric(
                  '${insights.lastParts.length}/${ExerciseLibrary.trainingParts.length}',
                  '部位覆盖',
                  spec,
                ),
              ],
            ),
          ),
          if (progressList.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              '动作进步',
              style: TextStyle(
                color: spec.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            ...progressList.map((progress) {
              final detail = progress.isTimeBased
                  ? '${progress.durationMinutes.toStringAsFixed(0)} 分钟'
                      '${progress.distanceKm > 0 ? ' · ${progress.distanceKm.toStringAsFixed(1)} km' : ''}'
                  : '${progress.sets}×${progress.reps} @ ${progress.currentWeight}kg';
              final change = progress.isTimeBased
                  ? progress.category
                  : (progress.isFirst
                      ? '首次'
                      : '${progress.diff! >= 0 ? '+' : ''}${progress.diff!.toStringAsFixed(1)}kg');
              final tone = progress.isTimeBased || progress.isFirst
                  ? spec.textSecondary
                  : (progress.diff! >= 0
                      ? const Color(0xFF34C759)
                      : const Color(0xFFFF9500));
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: tone,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        '${progress.name} · ${progress.part}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: spec.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      detail,
                      style: TextStyle(
                        color: spec.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 62,
                      child: Text(
                        change,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: tone,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (insights.missingPartsLast.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9500).withValues(alpha: .08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      size: 16, color: Color(0xFFFF9500)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '这次没有练到 ${insights.missingPartsLast.join('、')}，下次可以优先安排。',
                      style: TextStyle(
                        color: spec.textSecondary,
                        fontSize: 11.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniMetric(String value, String label, AppThemeSpec spec) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: spec.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: spec.textSecondary,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniDivider(AppThemeSpec spec) {
    return Container(
      width: 1,
      height: 26,
      color: spec.textPrimary.withValues(alpha: .08),
    );
  }
}

class _InsightGrid extends StatelessWidget {
  final CoachInsights insights;
  final SettingsProvider settings;

  const _InsightGrid({required this.insights, required this.settings});

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final goalProgress =
        (insights.thisWeekSessions / settings.weeklyGoal).clamp(0.0, 1.0);
    final partStats = insights.partStats;
    final maxWork = partStats.isEmpty
        ? 1.0
        : partStats.first.work.clamp(1.0, double.infinity);
    final trend = insights.volumeTrend;
    final maxTrend = trend.isEmpty
        ? 1.0
        : trend.map((e) => e.work).reduce(max).clamp(1.0, double.infinity);
    final bests = insights.exerciseBests.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        SizedBox(
          height: 184,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: FadeSlideIn(
                  index: 1,
                  child: GlassPanel(
                    padding: const EdgeInsets.all(16),
                    onTap: () => _open(context, const WeeklyTrainingDaysPage()),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cardHeader(Icons.flag_rounded, '本周目标', spec),
                        const SizedBox(height: 14),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${insights.thisWeekSessions}',
                                style: TextStyle(
                                  color: spec.textPrimary,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              TextSpan(
                                text: ' / ${settings.weeklyGoal} 次',
                                style: TextStyle(
                                  color: spec.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: goalProgress,
                            minHeight: 7,
                            backgroundColor:
                                spec.textPrimary.withValues(alpha: .07),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          insights.thisWeekSessions >= settings.weeklyGoal
                              ? '本周目标已完成，保持恢复。'
                              : '还差 ${settings.weeklyGoal - insights.thisWeekSessions} 次达成目标。',
                          style: TextStyle(
                            color: spec.textSecondary,
                            fontSize: 10.5,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FadeSlideIn(
                  index: 2,
                  child: GlassPanel(
                    padding: const EdgeInsets.all(16),
                    onTap: () => _open(context, const PartBalanceDetailPage()),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cardHeader(Icons.balance_rounded, '部位均衡', spec),
                        const SizedBox(height: 12),
                        ...partStats.take(4).map((stat) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  child: Text(
                                    stat.part,
                                    style: TextStyle(
                                      color: spec.textSecondary,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value:
                                          (stat.work / maxWork).clamp(0.0, 1.0),
                                      minHeight: 5,
                                      backgroundColor: spec.textPrimary
                                          .withValues(alpha: .06),
                                      color: stat.part == '腿'
                                          ? const Color(0xFFFF9500)
                                          : spec.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (partStats.isEmpty)
                          Text(
                            '暂无数据',
                            style: TextStyle(
                              color: spec.textSecondary,
                              fontSize: 10.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 184,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: FadeSlideIn(
                  index: 3,
                  child: GlassPanel(
                    padding: const EdgeInsets.all(16),
                    onTap: () => _open(context, const VolumeTrendPage()),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cardHeader(Icons.show_chart_rounded, '容量趋势', spec),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 66,
                          child: trend.isEmpty
                              ? Center(
                                  child: Text(
                                    '暂无容量数据',
                                    style: TextStyle(
                                      color: spec.textSecondary,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: trend.map((point) {
                                    final ratio =
                                        (point.work / maxTrend).clamp(.12, 1.0);
                                    return Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 2),
                                        child: Container(
                                          height: 66 * ratio,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                spec.primary,
                                                spec.primary
                                                    .withValues(alpha: .28),
                                              ],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          trend.length < 2
                              ? '再记录几次即可看到趋势'
                              : '最近 ${trend.length} 次训练容量',
                          style: TextStyle(
                            color: spec.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FadeSlideIn(
                  index: 4,
                  child: GlassPanel(
                    padding: const EdgeInsets.all(16),
                    onTap: () => _open(context, const PersonalRecordsPage()),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cardHeader(Icons.emoji_events_rounded, '个人记录', spec),
                        const SizedBox(height: 13),
                        if (bests.isEmpty)
                          Text(
                            '暂无重量记录',
                            style: TextStyle(
                              color: spec.textSecondary,
                              fontSize: 10.5,
                            ),
                          )
                        else
                          ...bests.take(3).map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.key,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: spec.textPrimary,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${entry.value.toStringAsFixed(entry.value % 1 == 0 ? 0 : 1)}kg',
                                    style: TextStyle(
                                      color: spec.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Widget _cardHeader(IconData icon, String title, AppThemeSpec spec) {
    return Row(
      children: [
        Icon(icon, size: 15, color: spec.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: spec.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Icon(
          Icons.chevron_right_rounded,
          size: 16,
          color: spec.textSecondary.withValues(alpha: .7),
        ),
      ],
    );
  }
}

class _AiCoachCard extends StatelessWidget {
  final AppThemeSpec spec;
  final SettingsProvider settings;
  final List<_ChatTurn> chat;
  final bool loading;
  final TextEditingController controller;
  final GlobalKey lastTurnKey;
  final VoidCallback onSend;
  final void Function(String) onPreset;
  final void Function(_ChatTurn) onReasoningMarqueeDone;
  final VoidCallback onOpenSettings;

  const _AiCoachCard({
    required this.spec,
    required this.settings,
    required this.chat,
    required this.loading,
    required this.controller,
    required this.lastTurnKey,
    required this.onSend,
    required this.onPreset,
    required this.onReasoningMarqueeDone,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      gradient: LinearGradient(
        colors: [
          spec.card.withValues(alpha: .96),
          spec.primary.withValues(alpha: .09),
          spec.card.withValues(alpha: .96),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GradientIconBadge(
                icon: Icons.smart_toy_rounded,
                colors: [spec.primary, spec.secondary],
                size: 42,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '铁镌 AI 教练',
                          style: TextStyle(
                            color: spec.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Pill(
                          label: 'REAL AI',
                          icon: Icons.auto_awesome_rounded,
                          color: spec.secondary,
                          filled: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_aiChannelLabel(settings)} · ${settings.aiModel}',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: spec.textSecondary,
                        fontSize: 10,
                        letterSpacing: .3,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onOpenSettings,
                icon: Icon(Icons.tune_rounded,
                    size: 19, color: spec.textSecondary),
                tooltip: context.tr('AI 设置'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (chat.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: spec.primary.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: spec.primary.withValues(alpha: .12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '基于真实训练数据的 AI 建议',
                    style: TextStyle(
                      color: spec.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'AI 会读取你的训练容量、频率、肌群分布和重量变化，给出可执行的下一步。若免费通道限流，可配置 API Key 后继续使用。',
                    style: TextStyle(
                      color: spec.textSecondary,
                      fontSize: 11.5,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < chat.length; i++)
              i == chat.length - 1
                  ? KeyedSubtree(
                      key: lastTurnKey,
                      child: _ChatBubble(
                        turn: chat[i],
                        spec: spec,
                        settings: settings,
                        onReasoningMarqueeDone: onReasoningMarqueeDone,
                      ),
                    )
                  : _ChatBubble(
                      turn: chat[i],
                      spec: spec,
                      settings: settings,
                      onReasoningMarqueeDone: onReasoningMarqueeDone,
                    ),
          if (loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: spec.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'AI 教练正在分析你的训练数据…',
                    style: TextStyle(
                      color: spec.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _quickChip('我的瓶颈在哪？'),
              _quickChip('下周怎么安排？'),
              _quickChip('动作安排合理吗？'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: context.tr('追问 AI 教练…'),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: loading ? null : onSend,
                icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                tooltip: context.tr('发送'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'AI 建议仅供训练参考，不替代专业医疗或康复意见。',
            style: TextStyle(
              color: spec.textSecondary.withValues(alpha: .7),
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickChip(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: loading ? null : () => onPreset(text),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _ChatTurn turn;
  final AppThemeSpec spec;
  final SettingsProvider settings;
  final void Function(_ChatTurn) onReasoningMarqueeDone;

  const _ChatBubble({
    required this.turn,
    required this.spec,
    required this.settings,
    required this.onReasoningMarqueeDone,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = turn.role == _ChatRole.user;
    final avatarPath = settings.avatarPath;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isUser
              ? spec.primary.withValues(alpha: .16)
              : (turn.isError
                  ? const Color(0xFFFF9500).withValues(alpha: .1)
                  : spec.textPrimary.withValues(alpha: .045)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 5),
            bottomRight: Radius.circular(isUser ? 5 : 16),
          ),
          border: Border.all(
            color: isUser
                ? spec.primary.withValues(alpha: .2)
                : spec.textPrimary.withValues(alpha: .05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isUser)
                  UserAvatar(
                    path: avatarPath,
                    size: 18,
                    fallback: Icon(
                      Icons.person_rounded,
                      size: 12,
                      color: spec.primary,
                    ),
                  )
                else
                  Icon(
                    Icons.smart_toy_rounded,
                    size: 12,
                    color: spec.secondary,
                  ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    isUser
                        ? settings.nickname
                        : (turn.isError ? '离线教练' : 'AI 教练'),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isUser ? spec.primary : spec.textSecondary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (!isUser && turn.reasoning.trim().isNotEmpty)
              AiReasoningPanel(
                key: ValueKey('reasoning-${turn.id}'),
                reasoning: turn.reasoning,
                spec: spec,
                streaming: turn.reasoningStreaming,
                stopMarquee: turn.typing || (turn.visibleChars ?? 0) > 0,
                onMarqueeCompleted: () => onReasoningMarqueeDone(turn),
              ),
            AiMessageText(
              text: turn.displayContent,
              spec: spec,
            ),
          ],
        ),
      ),
    );
  }
}

String _aiChannelLabel(SettingsProvider settings) {
  final provider = settings.aiProvider;
  final base = provider.isCustom ? 'CUSTOM · AI' : provider.label.toUpperCase();
  return settings.hasAiKey ? '$base · KEY' : base;
}

class _KnowledgeGrid extends StatelessWidget {
  final CoachKnowledge knowledge;
  final Random random;

  const _KnowledgeGrid({required this.knowledge, required this.random});

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final items = knowledge.dailySet(random);
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FadeSlideIn(
              index: i,
              child: GlassPanel(
                padding: const EdgeInsets.all(16),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => _KnowledgeSheet(
                      item: items[i],
                    ),
                  );
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: spec.primary.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Text(
                        items[i].icon,
                        style: const TextStyle(fontSize: 19),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                items[i].category,
                                style: TextStyle(
                                  color: spec.primary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .4,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.open_in_full_rounded,
                                size: 12,
                                color: spec.textSecondary.withValues(alpha: .7),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            items[i].text,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: spec.textPrimary,
                              fontSize: 12,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _KnowledgeSheet extends StatelessWidget {
  final KnowledgeItem item;

  const _KnowledgeSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(item.icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Text(
                  item.category,
                  style: TextStyle(
                    color: spec.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              item.text,
              style: TextStyle(
                color: spec.textPrimary,
                fontSize: 14,
                height: 1.75,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '内容来自本地健身知识库，会自动过滤低质量语料。',
              style: TextStyle(
                color: spec.textSecondary,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverallCard extends StatelessWidget {
  final CoachInsights insights;

  const _OverallCard({required this.insights});

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final favorite = insights.favoritePart;
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      gradient: LinearGradient(
        colors: [
          spec.card.withValues(alpha: .96),
          spec.secondary.withValues(alpha: .07),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GradientIconBadge(
                icon: Icons.military_tech_rounded,
                colors: [const Color(0xFFFFD166), spec.primary],
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '你已完成 ${insights.totalSessions} 次训练',
                      style: TextStyle(
                        color: spec.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '训练 ${insights.trainingDays} 天 · ${insights.totalSets} 组 · 约 ${insights.totalCalories} 千卡',
                      style: TextStyle(
                        color: spec.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: spec.textPrimary.withValues(alpha: .035),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: spec.textPrimary.withValues(alpha: .055),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  favorite == null
                      ? '开始记录后，这里会生成你的训练画像。'
                      : '你最常训练「${favorite.part}」，共 ${favorite.sessions} 次、${favorite.sets} 组。${favorite.part == '腿' ? '腿部训练是全身力量的发动机，保持这份勇气。' : '建议同时关注薄弱部位，让身体发展更均衡。'}',
                  style: TextStyle(
                    color: spec.textPrimary,
                    fontSize: 12,
                    height: 1.65,
                  ),
                ),
                if (insights.bestRecord != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    '单次最高容量：${(insights.bestRecord!.totalWork / 1000).toStringAsFixed(1)} 千焦（${DateFormat('yyyy-MM-dd').format(insights.bestRecord!.date)}）',
                    style: TextStyle(
                      color: spec.textSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (insights.totalSessions > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 14, color: spec.primary),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '每一次记录都在为下一次突破提供依据。',
                    style: TextStyle(
                      color: spec.textSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
