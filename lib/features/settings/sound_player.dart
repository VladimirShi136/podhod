import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'rest_sound.dart';

/// Проигрывает звуки внутри приложения (когда оно открыто): без уведомлений
/// в шторке. Один плеер на всё приложение: новый звук сразу заменяет
/// предыдущий, поэтому звуки не накладываются и не обрываются друг другом.
/// Если пакет изменит интерфейс, править нужно только этот файл.
class SoundPlayer {
  final AudioPlayer _player = AudioPlayer();
  bool _configured = false;
  int _generation = 0;

  Future<void> play(RestSound sound) async {
    final mine = ++_generation;
    try {
      if (!_configured) {
        _configured = true;
        // Громкость уведомлений, музыка лишь на время приглушается.
        await _player.setAudioContext(
          AudioContext(
            android: AudioContextAndroid(
              usageType: AndroidUsageType.notification,
              contentType: AndroidContentType.sonification,
              audioFocus: AndroidAudioFocus.gainTransientMayDuck,
            ),
          ),
        );
      }
      await _player.stop();
      if (mine != _generation) return; // за это время запустили другой звук
      await _player.play(AssetSource('sounds/${sound.resource}.ogg'));
    } catch (e) {
      debugPrint('Не удалось воспроизвести звук: $e');
    }
  }

  Future<void> dispose() => _player.dispose();
}

final soundPlayerProvider = Provider<SoundPlayer>((ref) {
  final player = SoundPlayer();
  ref.onDispose(player.dispose);
  return player;
});
