import '../l10n/localized_material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../theme/app_theme.dart';

/// AI 回复渲染器：按 Markdown 解析标题、列表、粗体、代码与表格。
class AiMessageText extends StatelessWidget {
  final String text;
  final AppThemeSpec spec;
  final double fontSize;
  final bool selectable;

  const AiMessageText({
    super.key,
    required this.text,
    required this.spec,
    this.fontSize = 12.5,
    this.selectable = false,
  });

  @override
  Widget build(BuildContext context) {
    final data = _normalize(text);
    if (data.isEmpty) return const SizedBox.shrink();

    final base = TextStyle(
      color: spec.textPrimary,
      fontSize: fontSize,
      height: 1.65,
    );
    final heading = base.copyWith(
      color: spec.primary,
      fontWeight: FontWeight.w900,
      height: 1.35,
    );

    return MarkdownBody(
      data: data,
      selectable: selectable,
      shrinkWrap: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: base,
        pPadding: const EdgeInsets.only(bottom: 5),
        h1: heading.copyWith(fontSize: fontSize + 6),
        h1Padding: const EdgeInsets.only(top: 8, bottom: 5),
        h2: heading.copyWith(fontSize: fontSize + 4),
        h2Padding: const EdgeInsets.only(top: 8, bottom: 4),
        h3: heading.copyWith(fontSize: fontSize + 2),
        h3Padding: const EdgeInsets.only(top: 6, bottom: 3),
        h4: heading.copyWith(fontSize: fontSize + 1),
        h5: heading,
        h6: heading,
        strong: base.copyWith(fontWeight: FontWeight.w800),
        em: base.copyWith(fontStyle: FontStyle.italic),
        listBullet: base.copyWith(color: spec.primary),
        listBulletPadding: const EdgeInsets.only(right: 6),
        listIndent: 18,
        blockquote: base.copyWith(color: spec.textSecondary),
        blockquotePadding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
        blockquoteDecoration: BoxDecoration(
          color: spec.primary.withValues(alpha: .06),
          border: Border(
            left: BorderSide(
              color: spec.primary.withValues(alpha: .45),
              width: 3,
            ),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        code: base.copyWith(
          fontFamily: 'monospace',
          fontSize: fontSize - .5,
          color: spec.primary,
          backgroundColor: spec.primary.withValues(alpha: .08),
        ),
        codeblockPadding: const EdgeInsets.all(10),
        codeblockDecoration: BoxDecoration(
          color: spec.textPrimary.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: spec.textPrimary.withValues(alpha: .08),
          ),
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: spec.textPrimary.withValues(alpha: .12),
            ),
          ),
        ),
        tableHead: base.copyWith(fontWeight: FontWeight.w800),
        tableBody: base,
        tableCellsPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 5,
        ),
        tableBorder: TableBorder.all(
          color: spec.textPrimary.withValues(alpha: .12),
        ),
        blockSpacing: 4,
      ),
    );
  }

  String _normalize(String raw) {
    return raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\t', '  ')
        .replaceAll(RegExp(r'<\|[^>]*\|>'), '')
        .trim();
  }
}
