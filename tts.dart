import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:run1220/running_screen.dart';

class RunningTTS {
  final RunningScreen runningScreen;

  final ValueNotifier<String?> currentBGMNotifier = ValueNotifier(null);

  final AudioPlayer _ttsPlayer = AudioPlayer(); // TTS 전용
  final AudioPlayer _bgmPlayer = AudioPlayer(); // BGM 전용

  final ValueNotifier<double> volumeNotifier = ValueNotifier(1.0);

  late StreamSubscription<Map<String, dynamic>> _statsSubscription;

  bool _hasPlayedPauseAudio = false;
  bool _hasRestartAudio = false;
  bool _hasStartAudio = false;
  bool _hasStopAudio = false;
  bool _isPlaying = false;

  String? _currentBGM;
  Duration? _currentPosition;

  final List<String> _musicList = [
    'music/opening/Rebel.mp3',
    'music/opening/Untitled.mp3',
    // 필요하면 더 추가
  ];

  RunningTTS(this.runningScreen) {
    print("🔥 RunningTTS 생성됨!");

    _statsSubscription = runningScreen.statsStream.listen(
          (stats) {
        _handleRunningStats(stats);
      },
      onError: (error) {
        print("❌ Stream 오류: $error");
      },
      onDone: () {
        print("✅ Stream 종료됨");
      },
    );
  }

  void _handleRunningStats(Map<String, dynamic> stats) {
    int elapsedTime = stats['elapsedTime'];
    double caloriesBurned = stats['caloriesBurned'];
    String pace = stats['pace'];
    double distance = stats['totalDistance'];
    bool isPaused = stats['paused'];
    bool restart = stats['restart'];
    bool stop = stats['stop'];
    bool start = stats['start'];

    // 시작 시
    if (start && !_hasStartAudio) {
      _hasStartAudio = true;
      _playTTS("TTS/start1.mp3").then((_) {
        _playRandomBGM(); // TTS 완료 후 실행
      });
    }

    // 종료 시
    if (stop && !_hasStopAudio) {
      _hasStopAudio = true;
      _playTTS("TTS/finish.mp3");
      stopBGM();
    }

    // 일시정지 시
    if (isPaused && !_hasPlayedPauseAudio) {
      _hasPlayedPauseAudio = true;
      _hasRestartAudio = false;

      _playTTS("TTS/pause_run.mp3");
      _saveBGMPosition();
      stopBGM();
    }

    // 다시 시작 시
    if (restart && !_hasRestartAudio && !start) {
      _hasRestartAudio = true;

      _playTTS("TTS/restart_run.mp3").then((_) {
        if (_currentBGM != null && _currentPosition != null) {
          _resumeBGM(); // 이어서 재생
        } else {
          _playRandomBGM(); // 새로 랜덤
        }
      });
    }

    // 일시정지 해제 감지
    if (!isPaused) {
      _hasPlayedPauseAudio = false;
    }
  }

  // 🎵 최적화된 MP3 파일 재생 함수
  Future<void> _playTTS(String filePath) async {
    try {
      await _ttsPlayer.stop();
      await _ttsPlayer.play(AssetSource(filePath));
      print("📢 TTS 재생 시작: $filePath");

      // 🎯 재생 완료까지 대기
      await _ttsPlayer.onPlayerComplete.first;
      print("📢 TTS 재생 완료: $filePath");
    } catch (e) {
      print("❌ TTS 재생 오류: $e");
    }
  }

  Future<void> _playRandomBGM() async {
    if (_isPlaying) return;
    _isPlaying = true;
    _currentBGM = (_musicList..shuffle()).first;
    currentBGMNotifier.value = _currentBGM;
    _currentPosition = Duration.zero;

    try {
      await _bgmPlayer.stop();
      await _bgmPlayer.play(AssetSource(_currentBGM!));
      print("🎧 BGM 재생: $_currentBGM");

      _bgmPlayer.onPlayerComplete.listen((_) {
        _isPlaying = false;
        _playRandomBGM(); // 반복
      });

      _bgmPlayer.onPositionChanged.listen((position) {
        _currentPosition = position;
      });
    } catch (e) {
      print("❌ BGM 재생 오류: $e");
      _isPlaying = false;
    }
  }

  // ⏹️ BGM 멈춤
  Future<void> stopBGM() async {
    try {
      await _bgmPlayer.stop();
      currentBGMNotifier.value = null;
      _isPlaying = false;
      print("⏹️ BGM 정지");
    } catch (e) {
      print("❌ BGM 정지 오류: $e");
    }
  }

  // 💾 BGM 재생 위치 저장
  void _saveBGMPosition() {
    _bgmPlayer.getCurrentPosition().then((position) {
      _currentPosition = position;
      print("💾 저장된 위치: $_currentPosition");
    });
  }

  // ▶️ BGM 이어서 재생
  Future<void> _resumeBGM() async {
    if (_currentBGM == null || _currentPosition == null) return;
    currentBGMNotifier.value = _currentBGM;

    try {
      await _bgmPlayer.play(
        AssetSource(_currentBGM!),
        position: _currentPosition!,
      );
      _isPlaying = true;
      print("▶️ BGM 이어 재생: $_currentBGM from $_currentPosition");
    } catch (e) {
      print("❌ 이어 재생 오류: $e");
    }
  }

  void setBGMVolume(double volume) {
    _bgmPlayer.setVolume(volume);
    volumeNotifier.value = volume;
  }

  void dispose() {
    _statsSubscription.cancel();
    _ttsPlayer.dispose();
    _bgmPlayer.dispose();
  }
}
