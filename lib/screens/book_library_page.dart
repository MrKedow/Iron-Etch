import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/app_providers.dart';
import '../services/epub_service.dart';
import '../widgets/app_ui.dart';
import 'epub_reader_page.dart';

class BookLibraryPage extends StatefulWidget {
  const BookLibraryPage({super.key});

  @override
  State<BookLibraryPage> createState() => _BookLibraryPageState();
}

class _BookLibraryPageState extends State<BookLibraryPage> {
  final EpubLibraryService _library = EpubLibraryService.instance;
  bool _busy = false;
  bool _preparing = true;
  String _busyMessage = '正在准备书库…';
  String? _warning;
  bool _gridView = true;
  int _shelfMaterial = 1;
  bool _introVisible = true;

  static const List<String> _shelfMaterials = [
    '玻璃',
    '木质',
    '钢质',
    '瓷质',
    '镂空',
    '藤质',
  ];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _prepareLibrary();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _gridView = prefs.getBool('library_grid_view') ?? true;
      _shelfMaterial =
          (prefs.getInt('library_shelf_material') ?? 1).clamp(0, 5);
      _introVisible = !(prefs.getBool('library_intro_hidden') ?? false);
    });
  }

  Future<void> _hideIntro() async {
    setState(() => _introVisible = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('library_intro_hidden', true);
  }

  Future<void> _toggleView() async {
    setState(() => _gridView = !_gridView);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('library_grid_view', _gridView);
  }

  Future<void> _pickMaterial() async {
    final prefs = await SharedPreferences.getInstance();
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final spec = sheetContext.watch<ThemeProvider>().currentSpec;
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                  '书架材质',
                  style: TextStyle(
                    color: spec.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(_shelfMaterials.length, (index) {
                    final active = _shelfMaterial == index;
                    return GestureDetector(
                      onTap: () => Navigator.pop(sheetContext, index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: active
                              ? spec.primary.withValues(alpha: .18)
                              : spec.textPrimary.withValues(alpha: .05),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: active
                                ? spec.primary
                                : spec.textPrimary.withValues(alpha: .1),
                          ),
                        ),
                        child: Text(
                          _shelfMaterials[index],
                          style: TextStyle(
                            color: active ? spec.primary : spec.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null) return;
    setState(() => _shelfMaterial = selected);
    await prefs.setInt('library_shelf_material', selected);
  }

  Future<void> _prepareLibrary() async {
    try {
      await _library.load();
      final defaultBook = _library.defaultBook;
      if (defaultBook != null &&
          !defaultBook.deleted &&
          !_library.isExtracted(defaultBook)) {
        if (mounted) {
          setState(() {
            _busyMessage = '首次打开需要解压内置 EPUB，约 259 MB，请稍候…';
          });
        }
        final book = await _library.ensureDefaultReady();
        unawaited(_library.buildSearchIndex(book));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _warning = '内置书准备失败：$error');
      }
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _openBook(EpubBookEntry entry) async {
    if (entry.deleted) {
      await _restoreBook(entry);
      return;
    }
    setState(() {
      _busy = true;
      _busyMessage = '正在打开《${entry.title}》…';
    });
    try {
      final book = entry.builtIn
          ? await _library.ensureDefaultReady()
          : await _library.parseEntry(entry);
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt('epub_progress_${entry.id}');
      if (!mounted) return;
      setState(() => _busy = false);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EpubReaderPage(
            book: book,
            initialChapter: saved,
          ),
        ),
      );
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage('打开失败：$error');
    }
  }

  Future<void> _restoreBook(EpubBookEntry entry) async {
    setState(() {
      _busy = true;
      _busyMessage = '正在恢复《${entry.title}》…';
    });
    try {
      final book = await _library.restoreDefault();
      if (!mounted) return;
      setState(() => _busy = false);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EpubReaderPage(book: book),
        ),
      );
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage('恢复失败：$error');
    }
  }

  Future<void> _importBook() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['epub'],
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null || path.isEmpty) {
        _showMessage('无法读取所选文件，请换一个 EPUB 试试。');
        return;
      }
      setState(() {
        _busy = true;
        _busyMessage = '正在导入并解析 EPUB…';
      });
      final entry = await _library.importBook(path);
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage('已导入《${entry.title}》');
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage('导入失败：$error');
    }
  }

  Future<void> _deleteBook(EpubBookEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final spec = dialogContext.watch<ThemeProvider>().currentSpec;
        return AlertDialog(
          backgroundColor: spec.card,
          title: Text(entry.builtIn ? '删除内置书？' : '删除这本书？'),
          content: Text(
            entry.builtIn ? '封面会保留为灰色，之后可以随时恢复内置副本。' : '书籍文件和阅读划线将被移除，此操作不可撤销。',
            style: TextStyle(color: spec.textSecondary, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    setState(() {
      _busy = true;
      _busyMessage = '正在移除书籍…';
    });
    try {
      await _library.deleteBook(entry);
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage(entry.builtIn ? '已删除，可点击灰色封面恢复' : '已删除');
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage('删除失败：$error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;

    return Scaffold(
      backgroundColor: spec.background,
      appBar: AppBar(
        backgroundColor: spec.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('铁镌书库'),
        actions: [
          IconButton(
            tooltip: _gridView ? '切换为列表' : '切换为网格',
            onPressed: _busy ? null : _toggleView,
            icon: Icon(
              _gridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
            ),
          ),
          IconButton(
            tooltip: '书架材质',
            onPressed: _busy ? null : _pickMaterial,
            icon: const Icon(Icons.format_paint_rounded),
          ),
          IconButton(
            tooltip: '导入 EPUB',
            onPressed: _busy ? null : _importBook,
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: _busy || _preparing ? null : _prepareLibrary,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _ShelfBackground(material: _shelfMaterial),
          ),
          AnimatedBuilder(
            animation: _library,
            builder: (context, _) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
                children: [
                  if (_introVisible)
                    GlassPanel(
                      padding: const EdgeInsets.all(17),
                      gradient: LinearGradient(
                        colors: [
                          spec.primary.withValues(alpha: .16),
                          spec.secondary.withValues(alpha: .06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      child: Row(
                        children: [
                          GradientIconBadge(
                            icon: Icons.menu_book_rounded,
                            colors: [spec.primary, spec.secondary],
                            size: 44,
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '让训练有迹可循',
                                  style: TextStyle(
                                    color: spec.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '内置《北科·健身全书》全 9 册，也可导入自己的 EPUB。',
                                  style: TextStyle(
                                    color: spec.textSecondary,
                                    fontSize: 11.5,
                                    height: 1.55,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _hideIntro,
                            tooltip: '关闭',
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: spec.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_warning != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316).withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFF97316).withValues(alpha: .22),
                        ),
                      ),
                      child: Text(
                        _warning!,
                        style: TextStyle(
                          color: spec.textSecondary,
                          fontSize: 11.5,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                  SectionHeader(
                    title: '书架',
                    subtitle: '轻点封面开始阅读，长按管理书籍',
                    trailing: Pill(
                      label: '${_library.books.length} 本',
                      icon: Icons.auto_stories_rounded,
                    ),
                    padding: const EdgeInsets.fromLTRB(2, 24, 2, 12),
                  ),
                  if (_library.books.isEmpty)
                    GlassPanel(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.import_contacts_rounded,
                            size: 36,
                            color: spec.textSecondary,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '书架还是空的',
                            style: TextStyle(
                              color: spec.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '点击右上角 + 导入一本 EPUB。',
                            style: TextStyle(
                              color: spec.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_gridView)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _library.books.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 20,
                        childAspectRatio: .5,
                      ),
                      itemBuilder: (context, index) {
                        final entry = _library.books[index];
                        return _BookCard(
                          entry: entry,
                          material: _shelfMaterial,
                          onTap: _busy ? null : () => _openBook(entry),
                          onDelete: _busy ? null : () => _deleteBook(entry),
                        );
                      },
                    )
                  else
                    Column(
                      children: [
                        for (var index = 0;
                            index < _library.books.length;
                            index++)
                          _BookListTile(
                            entry: _library.books[index],
                            onTap: _busy
                                ? null
                                : () => _openBook(_library.books[index]),
                            onDelete: _busy
                                ? null
                                : () => _deleteBook(_library.books[index]),
                          ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  Text(
                    '支持 EPUB 2 / EPUB 3。划线、目录、全书查找和阅读进度会自动保存在本机。',
                    style: TextStyle(
                      color: spec.textSecondary.withValues(alpha: .75),
                      fontSize: 10.5,
                      height: 1.5,
                    ),
                  ),
                ],
              );
            },
          ),
          if (_busy || _preparing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: .46),
                alignment: Alignment.center,
                child: Container(
                  width: 246,
                  margin: const EdgeInsets.symmetric(horizontal: 28),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                  decoration: BoxDecoration(
                    color: spec.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: spec.textPrimary.withValues(alpha: .08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .25),
                        blurRadius: 32,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          strokeWidth: 3.2,
                          color: spec.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _busyMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: spec.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final EpubBookEntry entry;
  final int material;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _BookCard({
    required this.entry,
    required this.material,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final coverFile = entry.coverPath == null ? null : File(entry.coverPath!);
    final hasCover = coverFile != null && coverFile.existsSync();

    Widget cover = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            spec.primary.withValues(alpha: .82),
            spec.secondary.withValues(alpha: .66),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -20,
            top: -16,
            child: Icon(
              Icons.menu_book_rounded,
              size: 112,
              color: Colors.white.withValues(alpha: .14),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                const Spacer(),
                Text(
                  entry.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.35,
                  ),
                ),
                if (entry.author.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    entry.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .72),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (entry.builtIn)
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .26),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '内置',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (hasCover) {
      cover = Image.file(
        coverFile,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => cover,
      );
    }
    if (entry.deleted) {
      cover = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          .2126,
          .7152,
          .0722,
          0,
          0,
          .2126,
          .7152,
          .0722,
          0,
          0,
          .2126,
          .7152,
          .0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: cover,
      );
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0012)
                      ..rotateX(0.28),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: spec.textPrimary.withValues(alpha: .1),
                              ),
                            ),
                            child: cover,
                          ),
                        ),
                        if (entry.deleted)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                color: Colors.black.withValues(alpha: .28),
                                alignment: Alignment.center,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: .48),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: .28),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.refresh_rounded,
                                        color: Colors.white,
                                        size: 15,
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        '点击恢复',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          right: 3,
                          top: 3,
                          child: Material(
                            color: Colors.black.withValues(alpha: .28),
                            shape: const CircleBorder(),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: PopupMenuButton<String>(
                                tooltip: '管理书籍',
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.more_horiz_rounded,
                                  color: Colors.white,
                                  size: 15,
                                ),
                                onSelected: (_) => onDelete?.call(),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('删除书籍'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  height: 8,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _shelfSpecs[material.clamp(0, _shelfSpecs.length - 1)]
                            .boardEdge,
                        _shelfSpecs[material.clamp(0, _shelfSpecs.length - 1)]
                            .board,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entry.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: spec.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            entry.deleted
                ? '已删除 · 可恢复'
                : (entry.author.isEmpty ? 'EPUB' : entry.author),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:
                  entry.deleted ? const Color(0xFFF97316) : spec.textSecondary,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShelfSpec {
  final List<Color> gradient;
  final Color board;
  final Color boardEdge;
  const _ShelfSpec(this.gradient, this.board, this.boardEdge);
}

const List<_ShelfSpec> _shelfSpecs = [
  _ShelfSpec([Color(0xFF2A3B4C), Color(0xFF18242F)], Color(0xFF335066),
      Color(0xFF22394D)),
  _ShelfSpec([Color(0xFF7A4E28), Color(0xFF4A2C14)], Color(0xFF8A5A30),
      Color(0xFF5E3B1C)),
  _ShelfSpec([Color(0xFF3C424B), Color(0xFF23272E)], Color(0xFF4A515C),
      Color(0xFF31363F)),
  _ShelfSpec([Color(0xFFEAE2D4), Color(0xFFCFC4B0)], Color(0xFFF4EEE2),
      Color(0xFFC3B7A0)),
  _ShelfSpec([Color(0xFF22262C), Color(0xFF101318)], Color(0xFF2C3138),
      Color(0xFF1A1E23)),
  _ShelfSpec([Color(0xFFB98E4F), Color(0xFF86642F)], Color(0xFFC89A58),
      Color(0xFF8F6C35)),
];

class _ShelfBackground extends StatelessWidget {
  final int material;
  const _ShelfBackground({required this.material});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter:
          _ShelfPainter(_shelfSpecs[material.clamp(0, _shelfSpecs.length - 1)]),
    );
  }
}

class _ShelfPainter extends CustomPainter {
  final _ShelfSpec spec;
  _ShelfPainter(this.spec);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: spec.gradient,
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    final plank = Paint()
      ..color = Colors.black.withValues(alpha: .06)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 64) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), plank);
    }

    final shelf = Paint()
      ..color = Colors.black.withValues(alpha: .14)
      ..strokeWidth = 2;
    for (double y = 0; y < size.height; y += 220) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), shelf);
    }
  }

  @override
  bool shouldRepaint(covariant _ShelfPainter oldDelegate) =>
      oldDelegate.spec != spec;
}

class _BookListTile extends StatelessWidget {
  final EpubBookEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _BookListTile({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final coverFile = entry.coverPath == null ? null : File(entry.coverPath!);
    final hasCover = coverFile != null && coverFile.existsSync();

    Widget thumb = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            spec.primary.withValues(alpha: .82),
            spec.secondary.withValues(alpha: .66),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.auto_stories_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
    if (hasCover) {
      thumb = Image.file(
        coverFile,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => thumb,
      );
    }
    if (entry.deleted) {
      thumb = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          .2126,
          .7152,
          .0722,
          0,
          0,
          .2126,
          .7152,
          .0722,
          0,
          0,
          .2126,
          .7152,
          .0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: thumb,
      );
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: spec.textPrimary.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: spec.textPrimary.withValues(alpha: .07)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 40,
                height: 56,
                child: thumb,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: spec.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.deleted
                        ? '已删除 · 可恢复'
                        : (entry.author.isEmpty ? 'EPUB' : entry.author),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: entry.deleted
                          ? const Color(0xFFF97316)
                          : spec.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.more_vert_rounded,
              size: 18,
              color: spec.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
