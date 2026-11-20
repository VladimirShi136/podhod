/// Звуки сигнала окончания отдыха. Файлы лежат в
/// android/app/src/main/res/raw/<resource>.ogg
enum RestSound {
  bell('rest_bell', 'Колокольчик'),
  gong('rest_gong', 'Гонг'),
  beeps('rest_beeps', 'Три сигнала'),
  drop('rest_drop', 'Капля'),
  xylo('rest_xylo', 'Ксилофон');

  const RestSound(this.resource, this.label);

  /// Имя файла в res/raw без расширения.
  final String resource;
  final String label;

  static RestSound fromId(String? id) {
    for (final s in values) {
      if (s.name == id) return s;
    }
    return RestSound.bell;
  }
}
