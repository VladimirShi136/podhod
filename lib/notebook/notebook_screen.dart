import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/paper_page.dart';
import '../features/calendar/calendar_page.dart';
import '../features/programs/programs_page.dart';
import '../features/progress/progress_page.dart';
import '../features/settings/settings_page.dart';
import '../features/today/today_page.dart';
import 'book_cover.dart';
import 'bookmark_bar.dart';
import 'notebook_page_def.dart';
import 'notebook_scope.dart';
import 'spiral_painter.dart';

/// Порядок страниц = порядок в тетради. Первые четыре имеют закладки.
final List<NotebookPageDef> _defs = [
  const NotebookPageDef(
    label: 'Сегодня',
    icon: Icons.edit_note,
    page: TodayPage(),
    tabColor: Color(0xFFE8B84A),
  ),
  const NotebookPageDef(
    label: 'Календарь',
    icon: Icons.calendar_month,
    page: CalendarPage(),
    tabColor: Color(0xFFC8553D),
  ),
  const NotebookPageDef(
    label: 'Прогресс',
    icon: Icons.bar_chart,
    page: ProgressPage(),
    tabColor: Color(0xFF4F7F5B),
  ),
  const NotebookPageDef(
    label: 'Программы',
    icon: Icons.bookmarks_outlined,
    page: ProgramsPage(),
    tabColor: Color(0xFF3F5E9E),
  ),
  const NotebookPageDef(
    label: 'Настройки',
    icon: Icons.settings_outlined,
    page: SettingsPage(),
    inTabs: false,
  ),
];

const _bookRadius = BorderRadius.only(
  topLeft: Radius.circular(6),
  bottomLeft: Radius.circular(6),
  topRight: Radius.circular(22),
  bottomRight: Radius.circular(22),
);

/// Главный экран: тетрадь со страницами, спиралью и закладками.
///
/// Вся навигация сводится к одному числу [_pos]: 0 — открыта первая страница,
/// 1 — вторая и т. д. Дробное значение означает «страница в процессе
/// перелистывания». Страница i повёрнута на угол, пропорциональный
/// clamp(_pos - i, 0, 1).
class NotebookScreen extends StatefulWidget {
  const NotebookScreen({super.key, this.playIntro = true});

  /// Показывать ли обложку при запуске (в тестах можно отключить).
  final bool playIntro;

  @override
  State<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends State<NotebookScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pos =
      AnimationController.unbounded(vsync: this, value: 0);

  /// Полоска загрузки на обложке и открытие обложки.
  late final AnimationController _load = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playIntro) {
      // Пока обложка «загружается». Позже здесь будем ждать открытия базы данных.
      _load.forward().then((_) {
        if (mounted) _intro.forward();
      });
    }
  }

  // Страницы с бумагой создаются один раз, чтобы не перестраиваться на каждом кадре.
  late final List<Widget> _papers = [
    for (final d in _defs) PaperPage(child: d.page),
  ];

  late final List<BookmarkTab> _tabs = [
    for (var i = 0; i < _defs.length; i++)
      if (_defs[i].inTabs)
        BookmarkTab(
          label: _defs[i].label,
          icon: _defs[i].icon,
          pageIndex: i,
          color: _defs[i].tabColor,
        ),
  ];

  /// Страница, на которой тетрадь остановилась в последний раз.
  int _settled = 0;

  /// Куда вернуться из настроек.
  int _returnIndex = 0;

  double get _maxPos => (_defs.length - 1).toDouble();

  @override
  void dispose() {
    _pos.dispose();
    _load.dispose();
    _intro.dispose();
    super.dispose();
  }

  /// Плавно перелистывает к странице [target] (хоть через несколько страниц).
  void _animateTo(int target) {
    target = math.min(math.max(target, 0), _defs.length - 1);
    final distance = (target - _pos.value).abs();

    if (target == kSettingsPage && _settled != kSettingsPage) {
      _returnIndex = _settled;
    }
    _settled = target;

    if (distance < 0.001) return;

    // Одна страница — ~420 мс, далёкий прыжок чуть дольше.
    final ms = (distance <= 1
            ? 120 + 300 * distance
            : 420 + 220 * math.min(distance - 1, 4))
        .round();

    _pos.animateTo(
      target.toDouble(),
      duration: Duration(milliseconds: ms),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onDragStart(DragStartDetails details) => _pos.stop();

  void _onDragUpdate(DragUpdateDetails details, double width) {
    // Палец идёт влево — страница переворачивается вперёд.
    final delta = -details.delta.dx / (width * 0.85);
    _pos.value = (_pos.value + delta).clamp(0.0, _maxPos).toDouble();
  }

  void _onDragEnd(DragEndDetails details) {
    final v = details.velocity.pixelsPerSecond.dx;
    final pos = _pos.value;

    final int target;
    if (v < -500) {
      target = pos.ceil();
    } else if (v > 500) {
      target = pos.floor();
    } else {
      target = pos.round();
    }
    _animateTo(target);
  }

  @override
  Widget build(BuildContext context) {
    return NotebookScope(
      goTo: _animateTo,
      goBack: () => _animateTo(_returnIndex),
      child: Scaffold(
        backgroundColor: AppColors.cover,
        body: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
          child: Stack(
            children: [
              // Закладки рисуются первыми, то есть ПОД тетрадью:
              // верхняя часть каждой спрятана, торчит только нижняя.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: BookmarkBar.height,
                child: AnimatedBuilder(
                  animation: _pos,
                  builder: (context, _) => BookmarkBar(
                    tabs: _tabs,
                    activeIndex: _pos.value.round(),
                    onTap: _animateTo,
                  ),
                ),
              ),
              Positioned.fill(
                bottom: BookmarkBar.height,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: _buildBook(),
                ),
              ),
            ],
          ),
        ),
            // Обложка поверх всего, открывается при запуске.
            if (widget.playIntro) IntroOverlay(open: _intro, loading: _load),
          ],
        ),
      ),
    );
  }

  Widget _buildBook() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: (d) => _onDragUpdate(d, width),
          onHorizontalDragEnd: _onDragEnd,
          // Тень тетради падает на закладки, и видно, что они лежат под ней.
          child: DecoratedBox(
            decoration: const BoxDecoration(
              borderRadius: _bookRadius,
              boxShadow: [
                BoxShadow(
                  color: Color(0x66000000),
                  offset: Offset(0, 3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ClipRRect(
            borderRadius: _bookRadius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFFD8D0BE)),
                AnimatedBuilder(
                  animation: _pos,
                  builder: (context, _) => _buildPages(),
                ),
                const IgnorePointer(
                  child: CustomPaint(painter: SpiralPainter()),
                ),
              ],
            ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPages() {
    final pos = _pos.value;
    final top = pos.floor();
    final current = pos.round();

    // Нижняя страница — последняя, верхняя — первая.
    // Перелистанные страницы остаются в дереве (Offstage), чтобы не терять состояние.
    final children = <Widget>[
      for (var i = _defs.length - 1; i >= 0; i--)
        _FlippingPage(
          key: ValueKey(i),
          progress: (pos - i).clamp(0.0, 1.0).toDouble(),
          offstage: pos - i >= 1.0 || i > top + 1,
          interactive: i == current,
          child: _papers[i],
        ),
    ];
    return Stack(fit: StackFit.expand, children: children);
  }
}

/// Страница, которая поворачивается вокруг левого края (переплёта).
class _FlippingPage extends StatelessWidget {
  const _FlippingPage({
    super.key,
    required this.progress,
    required this.offstage,
    required this.interactive,
    required this.child,
  });

  /// 0 — лежит ровно, 1 — полностью перелистнута.
  final double progress;
  final bool offstage;
  final bool interactive;
  final Widget child;

  // Сила перспективы. Если лист «улетает» от глаз, а не приподнимается к вам,
  // поменяйте знак поворота (math.pi → -math.pi).
  static const double _perspective = 0.0012;

  @override
  Widget build(BuildContext context) {
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, _perspective)
      ..rotateY(math.pi * progress);

    return Offstage(
      offstage: offstage,
      child: IgnorePointer(
        ignoring: !interactive,
        child: Transform(
          alignment: Alignment.centerLeft,
          transform: matrix,
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              // Лист темнеет по мере поворота.
              IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.3 * progress),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
