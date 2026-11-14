import 'package:flutter/widgets.dart';

/// Индекс страницы настроек: она последняя в тетради и не имеет закладки.
const int kSettingsPage = 4;

/// Описание одной страницы тетради.
class NotebookPageDef {
  const NotebookPageDef({
    required this.label,
    required this.icon,
    required this.page,
    this.inTabs = true,
    this.tabColor = const Color(0xFF8A5F3A),
  });

  /// Подпись на закладке.
  final String label;
  final IconData icon;

  /// Содержимое страницы (без бумаги: линейку рисует PaperPage).
  final Widget page;

  /// Показывать ли закладку внизу.
  final bool inTabs;

  /// Цвет закладки, выглядывающей из-под тетради.
  final Color tabColor;
}
