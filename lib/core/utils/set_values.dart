/// Подпись значений подходов: «6×10», если все одинаковые,
/// иначе «6·7·10·11» (для времени добавляется «с»).
String formatSetValues(List<int> values, {required bool isTime}) {
  if (values.isEmpty) return '—';
  final unit = isTime ? 'с' : '';
  if (values.every((v) => v == values.first)) {
    return '${values.length}×${values.first}$unit';
  }
  return '${values.join('·')}$unit';
}

/// «6,7,10» → [6, 7, 10]. Пустая или испорченная строка даёт null.
List<int>? decodeSetValues(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  final result = <int>[];
  for (final part in text.split(',')) {
    final n = int.tryParse(part.trim());
    if (n == null || n < 1) return null;
    result.add(n);
  }
  return result.isEmpty ? null : result;
}

String encodeSetValues(List<int> values) => values.join(',');
