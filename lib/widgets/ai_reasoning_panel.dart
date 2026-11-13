import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ai_message_text.dart';

/// 折叠式思考过程：收起时单行滚动轮播，展开后显示完整 Markdown。
class AiReasoningPanel extends StatefulWidget {
  final String reasoning;
  final AppThemeSpec spec;

  const AiReasoningPanel({
    super.key,
    required this.reasoning,
    required this.spec,
  });

  @override
  State<AiReasoningPanel> createState() => _AiReasoningPanelState();
}

class _AiReasoningPanelState extends State<AiReasoningPanel> {
  final ScrollController _scrollController = ScrollController();
  bool _expanded = false;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _startMarquee();
  }

  Future<void> _startMarquee() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    while (!_cancelled && mounted) {
      if (!_scrollController.hasClients) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        continue;
      }
      final max = _scrollController.position.maxScrollExtent;
      if (max <= 0) {
        await Future<void>.delayed(const Duration(seconds: 1));
        continue;
      }
      final duration = Duration(
        milliseconds: (max * 24).clamp(2600, 14000).toInt(),
      );
      await _scrollController.animateTo(
        max,
        duration: duration,
        curve: Curves.linear,
      );
      if (_cancelled) return;
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (_cancelled) return;
      await _scrollController.animateTo(
        0,
        duration: duration,
        curve: Curves.linear,
      );
      if (_cancelled) return;
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }
  }

  @override
  void dispose() {
    _cancelled = true;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final text = widget.reasoning.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: spec.primary.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: spec.primary.withValues(alpha: .14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.psychology_alt_rounded,
                    size: 15,
                    color: spec.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '思考过程',
                    style: TextStyle(
                      color: spec.primary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _expanded
                        ? Text(
                            '已展开',
                            style: TextStyle(
                              color: spec.textSecondary.withValues(alpha: .75),
                              fontSize: 10,
                            ),
                          )
                        : ClipRect(
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              scrollDirection: Axis.horizontal,
                              physics: const NeverScrollableScrollPhysics(),
                              child: Text(
                                text.replaceAll(RegExp(r'\s+'), ' '),
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  color:
                                      spec.textSecondary.withValues(alpha: .82),
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: spec.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _expanded
                ? Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 260),
                    padding: const EdgeInsets.fromLTRB(11, 0, 11, 11),
                    child: SingleChildScrollView(
                      child: AiMessageText(
                        text: text,
                        spec: spec,
                        fontSize: 11,
                        selectable: true,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
