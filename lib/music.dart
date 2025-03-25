import 'package:audioplayers/audioplayers.dart';

class MusicPlayer {
  static final AudioPlayer _player = AudioPlayer();
  static double _volume = 1.0; // 🔊 기본 음량 (0.0 ~ 1.0)

  static Future<void> playMusic() async {
    await _player.setSource(AssetSource('music/Rebel in the Rhythms.mp3'));
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(_volume); // 🔊 현재 볼륨 설정
    await _player.resume();
  }

  static Future<void> stopMusic() async {
    await _player.stop();
  }

  static void setVolume(double volume) {
    _volume = volume;
    _player.setVolume(volume);
  }

  static double get volume => _volume;
}
