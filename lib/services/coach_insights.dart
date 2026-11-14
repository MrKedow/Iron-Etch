import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/exercise_library.dart';
import '../main.dart';
import '../providers/app_providers.dart';

class PartStat {
  final String part;
  final int sessions;
  final int sets;
  final double work;
  final double minutes;

  const PartStat({
    required this.part,
    required this.sessions,
    required this.sets,
    required this.work,
    this.minutes = 0,
  });
}

class ExerciseProgress {
  final String name;
  final String part;
  final double currentWeight;
  final double? previousWeight;
  final int sets;
  final int reps;
  final String category;
  final double durationMinutes;
  final double distanceKm;

  const ExerciseProgress({
    required this.name,
    required this.part,
    required this.currentWeight,
    required this.previousWeight,
    required this.sets,
    required this.reps,
    this.category = '力量',
    this.durationMinutes = 0,
    this.distanceKm = 0,
  });

  bool get isTimeBased =>
      category == '有氧' || category == '柔韧' || category == '专项';

  double? get diff =>
      previousWeight == null ? null : currentWeight - previousWeight!;

  bool get isFirst => previousWeight == null;
}

class VolumePoint {
  final DateTime date;
  final double work;

  const VolumePoint(this.date, this.work);
}

class CoachInsights {
  final List<WorkoutRecord> records;

  CoachInsights(this.records);

  List<WorkoutRecord> get sortedAsc {
    final list = List<WorkoutRecord>.from(records)
      ..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  List<WorkoutRecord> get sortedDesc => sortedAsc.reversed.toList();

  WorkoutRecord? get lastRecord => sortedDesc.isEmpty ? null : sortedDesc.first;

  WorkoutRecord? get previousRecord =>
      sortedDesc.length < 2 ? null : sortedDesc[1];

  int get totalSessions => records
      .map((r) => DateFormat('yyyy-MM-dd').format(r.date))
      .toSet()
      .length;

  int get totalSets => records.fold(
      0, (sum, r) => sum + r.projects.fold(0, (s, p) => s + p.sets));

  double get totalWork => records.fold(0.0, (sum, r) => sum + r.totalWork);

  double get totalDurationMinutes =>
      records.fold(0.0, (sum, r) => sum + r.totalDurationMinutes);

  double get totalDistanceKm =>
      records.fold(0.0, (sum, r) => sum + r.totalDistanceKm);

  int get totalCalories =>
      records.fold(0.0, (sum, r) => sum + r.totalCalories).round();

  double get lastWork => lastRecord?.totalWork ?? 0;
  double get previousWork => previousRecord?.totalWork ?? 0;
  double get lastWeekWork => _workForLastDays(7);
  double get prevWeekWork => _workForPreviousDays(7);

  WorkoutRecord? get bestRecord {
    if (records.isEmpty) return null;
    return records.reduce((a, b) => a.totalWork >= b.totalWork ? a : b);
  }

  int get thisWeekSessions {
    final monday = _startOfWeek(DateTime.now());
    final nextMonday = monday.add(const Duration(days: 7));
    return records.where((r) {
      final date = DateTime(r.date.year, r.date.month, r.date.day);
      return !date.isBefore(monday) && date.isBefore(nextMonday);
    }).length;
  }

  int get lastWeekSessions {
    final thisMonday = _startOfWeek(DateTime.now());
    final lastMonday = thisMonday.subtract(const Duration(days: 7));
    return records.where((r) {
      final date = DateTime(r.date.year, r.date.month, r.date.day);
      return !date.isBefore(lastMonday) && date.isBefore(thisMonday);
    }).length;
  }

  int get thisMonthSessions {
    final now = DateTime.now();
    return records.where((r) {
      return r.date.year == now.year && r.date.month == now.month;
    }).length;
  }

  int get trainingDays => records
      .map((r) => DateFormat('yyyy-MM-dd').format(r.date))
      .toSet()
      .length;

  int get daysSinceFirst {
    if (records.isEmpty) return 0;
    return DateTime.now().difference(sortedAsc.first.date).inDays;
  }

  int get currentStreakDays {
    if (records.isEmpty) return 0;
    final days = records
        .map((r) => DateTime(r.date.year, r.date.month, r.date.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final first = days.first;
    final diffFromToday = todayDate.difference(first).inDays;
    if (diffFromToday > 1) return 0;
    var streak = 1;
    var cursor = first;
    for (var i = 1; i < days.length; i++) {
      final expected = cursor.subtract(const Duration(days: 1));
      if (days[i] == expected) {
        streak++;
        cursor = days[i];
      } else if (days[i].isBefore(expected)) {
        break;
      }
    }
    return streak;
  }

  double get averageWork {
    final count = records.where((r) => r.totalWork > 0).length;
    if (count == 0) return 0;
    return totalWork / count;
  }

  List<PartStat> get partStats {
    final sessions = <String, Set<String>>{};
    final sets = <String, int>{};
    final work = <String, double>{};
    final minutes = <String, double>{};
    for (final record in records) {
      final recordKey = DateFormat('yyyy-MM-dd').format(record.date);
      for (final project in record.projects) {
        if (project.name.trim().isEmpty) continue;
        sessions.putIfAbsent(project.part, () => {}).add(recordKey);
        sets[project.part] = (sets[project.part] ?? 0) + project.sets;
        work[project.part] =
            (work[project.part] ?? 0) + project.calculateWork();
        minutes[project.part] =
            (minutes[project.part] ?? 0) + project.durationMinutes;
      }
    }
    final parts =
        <String>{...sessions.keys, ...sets.keys, ...work.keys}.toList()
          ..sort((a, b) {
            final byWork = (work[b] ?? 0).compareTo(work[a] ?? 0);
            if (byWork != 0) return byWork;
            return (minutes[b] ?? 0).compareTo(minutes[a] ?? 0);
          });
    return parts
        .map((part) => PartStat(
              part: part,
              sessions: sessions[part]?.length ?? 0,
              sets: sets[part] ?? 0,
              work: work[part] ?? 0,
              minutes: minutes[part] ?? 0,
            ))
        .toList();
  }

  PartStat? get favoritePart {
    final stats = partStats;
    if (stats.isEmpty) return null;
    return stats.first;
  }

  List<String> get lastParts =>
      lastRecord?.projects.map((p) => p.part).toSet().toList() ?? [];

  List<String> get missingPartsLast {
    final had = lastParts.toSet();
    return ExerciseLibrary.trainingParts
        .where((part) => !had.contains(part))
        .toList();
  }

  List<String> get weekParts {
    final monday = _startOfWeek(DateTime.now());
    final parts = <String>{};
    for (final record in records) {
      final date =
          DateTime(record.date.year, record.date.month, record.date.day);
      if (!date.isBefore(monday)) {
        parts.addAll(record.projects.map((p) => p.part));
      }
    }
    return parts.toList();
  }

  List<String> get missingPartsWeek => ExerciseLibrary.trainingParts
      .where((part) => !weekParts.contains(part))
      .toList();

  List<ExerciseProgress> get lastExerciseProgress {
    final last = lastRecord;
    if (last == null) return [];
    final result = <ExerciseProgress>[];
    for (final project in last.projects) {
      if (project.name.trim().isEmpty) continue;
      final previous = _findPreviousProject(
        project.name,
        project.part,
        last.date,
      );
      result.add(ExerciseProgress(
        name: project.name,
        part: project.part,
        currentWeight: project.weight,
        previousWeight: previous?.weight,
        sets: project.sets,
        reps: project.repsPerSet,
        category: project.category,
        durationMinutes: project.durationMinutes,
        distanceKm: project.distanceKm,
      ));
    }
    return result;
  }

  WorkoutProject? _findPreviousProject(
      String name, String part, DateTime before) {
    final sorted = sortedDesc;
    for (final record in sorted) {
      if (!record.date.isBefore(before)) continue;
      for (final project in record.projects) {
        if (project.name == name && project.part == part) {
          return project;
        }
      }
    }
    return null;
  }

  List<VolumePoint> get volumeTrend {
    final list = sortedAsc
        .where((r) => r.totalWork > 0)
        .map((r) => VolumePoint(r.date, r.totalWork))
        .toList();
    if (list.length <= 12) return list;
    return list.sublist(list.length - 12);
  }

  Map<String, double> get exerciseBests {
    final map = <String, double>{};
    for (final record in records) {
      for (final project in record.projects) {
        if (project.name.trim().isEmpty || project.weight <= 0) continue;
        final key = project.name;
        if ((map[key] ?? 0) < project.weight) {
          map[key] = project.weight;
        }
      }
    }
    return map;
  }

  double _workForLastDays(int days) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    return records
        .where((r) => !r.date.isBefore(start))
        .fold(0.0, (sum, r) => sum + r.totalWork);
  }

  double _workForPreviousDays(int days) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final start = end.subtract(Duration(days: days));
    final prevStart = start.subtract(Duration(days: days));
    return records
        .where((r) => !r.date.isBefore(prevStart) && r.date.isBefore(start))
        .fold(0.0, (sum, r) => sum + r.totalWork);
  }

  static DateTime _startOfWeek(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  String buildAiContext(SettingsProvider settings) {
    final buffer = StringBuffer();
    final hasAnyScope = settings.aiDataScopeCount > 0;
    if (!hasAnyScope) {
      return '【数据权限】用户未授权发送任何训练数据。请仅给出通用的训练建议，并提醒用户可在设置中调整数据权限。\n';
    }

    if (settings.aiDataScopeEnabled('profile_basic')) {
      buffer.writeln('【基础画像】');
      buffer.writeln(
          '昵称：${settings.nickname}；目标：${settings.trainingGoal}；经验：${settings.experience}；周训练目标：${settings.weeklyGoal}次。');
      buffer.writeln();
    }

    if (settings.aiDataScopeEnabled('profile_body')) {
      buffer.writeln('【身体数据】');
      buffer.writeln(
          '体重：${settings.bodyWeight}kg；身高：${settings.heightCm == null ? '未填写' : '${settings.heightCm}cm'}；年龄：${settings.age ?? '未填写'}；体脂率：${settings.bodyFatPercent == null ? '未填写' : '${settings.bodyFatPercent}%'}；静息心率：${settings.restingHeartRate ?? '未填写'}。');
      buffer.writeln();
    }

    if (settings.aiDataScopeEnabled('summary_strength')) {
      buffer.writeln('【力量训练汇总】');
      buffer.writeln(
          '累计训练：$totalSessions次；总组数：$totalSets组；总做功：${(totalWork / 1000).toStringAsFixed(1)}千焦；估算消耗：$totalCalories千卡；训练天数：$trainingDays天。');
      buffer.writeln();
    }

    if (settings.aiDataScopeEnabled('summary_cardio')) {
      buffer.writeln('【有氧训练汇总】');
      buffer.writeln(
          '有氧时长：${totalDurationMinutes.toStringAsFixed(0)}分钟；有氧距离：${totalDistanceKm.toStringAsFixed(1)}公里。');
      buffer.writeln();
    }

    if (settings.aiDataScopeEnabled('weekly_frequency')) {
      buffer.writeln('【训练频率对比】');
      buffer.writeln('本周训练：$thisWeekSessions次；上周：$lastWeekSessions次。');
      buffer.writeln();
    }

    if (settings.aiDataScopeEnabled('weekly_work')) {
      buffer.writeln('【训练做功对比】');
      buffer.writeln(
          '最近7天做功：${(lastWeekWork / 1000).toStringAsFixed(1)}千焦；前7天：${(prevWeekWork / 1000).toStringAsFixed(1)}千焦。');
      buffer.writeln();
    }

    if (settings.aiDataScopeEnabled('parts_distribution')) {
      final fav = favoritePart;
      buffer.writeln('【部位容量分布】');
      if (fav != null) {
        buffer.writeln('最常训练部位：${fav.part}（${fav.sessions}次，${fav.sets}组）。');
      }
      for (final stat in partStats) {
        buffer.writeln(
            '${stat.part}：${stat.sessions}次，${stat.sets}组，${(stat.work / 1000).toStringAsFixed(1)}千焦${stat.minutes > 0 ? '，${stat.minutes.toStringAsFixed(0)}分钟' : ''}');
      }
      buffer.writeln();
    }

    if (settings.aiDataScopeEnabled('parts_missing')) {
      buffer.writeln('【本周缺失部位】');
      buffer.writeln(missingPartsWeek.isEmpty
          ? '无，覆盖全面。'
          : '${missingPartsWeek.join('、')}。');
      buffer.writeln();
    }

    final recent = sortedDesc.take(8).toList();
    if (settings.aiDataScopeEnabled('recent_strength')) {
      buffer.writeln('【最近力量明细】');
      for (final record in recent) {
        final projects = record.projects
            .where((p) => !p.isTimeBased && p.name.trim().isNotEmpty)
            .map((p) => '${p.name}(${p.part}) '
                '${p.weight}kg×${p.sets}组×${p.repsPerSet}次')
            .join('；');
        if (projects.isEmpty) continue;
        buffer.writeln(
            '${DateFormat('yyyy-MM-dd').format(record.date)} 第${record.sessionNumber ?? '-'}次：$projects。总做功${(record.totalWork / 1000).toStringAsFixed(1)}千焦。');
      }
      buffer.writeln();
    }

    if (settings.aiDataScopeEnabled('recent_cardio')) {
      buffer.writeln('【最近有氧明细】');
      for (final record in recent) {
        final projects = record.projects
            .where((p) => p.isTimeBased && p.name.trim().isNotEmpty)
            .map((p) => '${p.name}(${p.part}) '
                '${p.durationMinutes.toStringAsFixed(0)}分钟'
                '${p.distanceKm > 0 ? ' ${p.distanceKm.toStringAsFixed(1)}公里' : ''} '
                '约${p.estimatedCalories().round()}千卡')
            .join('；');
        if (projects.isEmpty) continue;
        buffer.writeln(
            '${DateFormat('yyyy-MM-dd').format(record.date)} 第${record.sessionNumber ?? '-'}次：$projects。');
      }
      buffer.writeln();
    }

    if (settings.aiDataScopeEnabled('exercise_weights')) {
      buffer.writeln('【最近一次与上次的重量对比】');
      for (final progress in lastExerciseProgress) {
        final diff = progress.diff;
        buffer.writeln(
            '${progress.name}：${progress.currentWeight}kg，上次${progress.previousWeight ?? '无'}kg${diff == null ? '' : '，变化${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}kg'}。');
      }
      buffer.writeln();
    }

    if (settings.aiDataScopeEnabled('feelings')) {
      buffer.writeln('【训练感受与备注】');
      var hasFeeling = false;
      for (final record in recent) {
        final feelings = record.projects
            .where((p) => p.feeling.trim().isNotEmpty)
            .map((p) =>
                '${p.name}：${p.feeling.trim()}${p.supplement.trim().isEmpty ? '' : '（备注：${p.supplement.trim()}）'}')
            .join('；');
        if (feelings.isEmpty) continue;
        hasFeeling = true;
        buffer.writeln(
            '${DateFormat('yyyy-MM-dd').format(record.date)}：$feelings。');
      }
      if (!hasFeeling) buffer.writeln('最近训练没有记录主观感受或备注。');
      buffer.writeln();
    }

    return buffer.toString();
  }
}

class KnowledgeItem {
  final String category;
  final String text;
  final String icon;

  const KnowledgeItem({
    required this.category,
    required this.text,
    required this.icon,
  });
}

class CoachKnowledge {
  final List<String> facts;
  final List<String> research;
  final List<String> myths;
  final List<String> protocols;
  final List<String> tips;
  final List<String> encouragements;

  const CoachKnowledge({
    required this.facts,
    required this.research,
    required this.myths,
    required this.protocols,
    required this.tips,
    required this.encouragements,
  });

  static CoachKnowledge empty() => const CoachKnowledge(
        facts: [],
        research: [],
        myths: [],
        protocols: [],
        tips: [],
        encouragements: [],
      );

  static Future<CoachKnowledge> load() async {
    try {
      final raw = await rootBundle.loadString('assets/coach_rules.json');
      try {
        return await Isolate.run(() => _parse(raw));
      } catch (_) {
        return _parse(raw);
      }
    } catch (_) {
      return empty();
    }
  }

  static CoachKnowledge _parse(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return CoachKnowledge(
      facts: _clean(json['scientific_facts']),
      research: _clean(json['research_summaries']),
      myths: _clean(json['myth_busters']),
      protocols: _clean(json['training_protocols']),
      tips: _clean(json['tips']),
      encouragements: _clean(json['encouragements']),
    );
  }

  static const List<String> _blacklist = [
    'Digital Accessibility',
    'Cookie',
    'Copyright',
    'Privacy Policy',
    'Terms of Service',
    'All rights reserved',
    'Subscribe',
    'Newsletter',
    'Advertisement',
    'Exercises4 Week',
    'Contact Us',
    'Sign up',
    'Log in',
  ];

  static List<String> _clean(dynamic raw) {
    if (raw is! List) return const [];
    final result = <String>[];
    for (final item in raw) {
      final text = item is String
          ? item
          : item is Map
              ? (item['text'] ?? item['content'] ?? '').toString()
              : item.toString();
      final trimmed = text
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'^[^\w\u4e00-\u9fa5]+'), '')
          .trim();
      if (trimmed.length < 18 || trimmed.length > 240) continue;
      if (_blacklist
          .any((k) => trimmed.toLowerCase().contains(k.toLowerCase()))) {
        continue;
      }
      if (result.contains(trimmed)) continue;
      result.add(trimmed);
    }
    return result;
  }

  String pickFact(Random random) =>
      _pick(facts, random, fallback: '力量训练能提升肌肉量与基础代谢，每周2-3次全身训练是很好的起点。');
  String pickResearch(Random random) =>
      _pick(research, random, fallback: '研究提示：每周90-120分钟力量训练与更好的长期健康结局相关。');
  String pickMyth(Random random) =>
      _pick(myths, random, fallback: '局部减脂并不存在，脂肪减少是全身性的；坚持热量缺口与力量训练更可靠。');
  String pickProtocol(Random random) =>
      _pick(protocols, random, fallback: '增肌期每个肌群每周安排10-20个有效组，并逐步增加重量或次数。');
  String pickTip(Random random) =>
      _pick(tips, random, fallback: '练后30-60分钟内补充蛋白质与碳水，有助于恢复与肌糖原补充。');
  String pickEncouragement(Random random) =>
      _pick(encouragements, random, fallback: '每一次力竭都是成长的信号，继续加油。');

  List<KnowledgeItem> dailySet(Random random) {
    return [
      KnowledgeItem(category: '科学快讯', text: pickFact(random), icon: '📚'),
      KnowledgeItem(category: '打破迷思', text: pickMyth(random), icon: '🧠'),
      KnowledgeItem(category: '训练方案', text: pickProtocol(random), icon: '🏋️'),
      KnowledgeItem(category: '最新研究', text: pickResearch(random), icon: '🔬'),
    ];
  }

  String _pick(List<String> list, Random random, {required String fallback}) {
    if (list.isEmpty) return fallback;
    return list[random.nextInt(list.length)];
  }
}
