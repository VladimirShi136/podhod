import 'package:flutter/widgets.dart';

/// Даёт страницам доступ к навигации по тетради:
///   NotebookScope.of(context).goTo(kSettingsPage);
class NotebookScope extends InheritedWidget {
  const NotebookScope({
    super.key,
    required this.goTo,
    required this.goBack,
    required super.child,
  });

  /// Перелистнуть к странице с индексом.
  final void Function(int index) goTo;

  /// Вернуться на страницу, с которой открыли настройки.
  final VoidCallback goBack;

  static NotebookScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<NotebookScope>();
    assert(scope != null, 'NotebookScope не найден в дереве виджетов');
    return scope!;
  }

  // Функции ведут в State, который живёт всё время, поэтому уведомлять не нужно.
  @override
  bool updateShouldNotify(NotebookScope oldWidget) => false;
}
