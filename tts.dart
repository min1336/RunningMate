import 'dart:async';
import 'package:audioplayers/audioplayers.dart'; // MP3 재생 라이브러리
import 'package:run1220/running_screen.dart'; // 실시간 데이터 가져오기

class RunningTTS {
  final RunningScreen runningScreen;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late StreamSubscription<Map<String, dynamic>> _statsSubscription;
  bool _hasPlayedPauseAudio = false;
  bool _hasRestartAudio = false;

  RunningTTS(this.runningScreen) {
    // 실시간 데이터 구독 시작
    _statsSubscription = runningScreen.statsStream.listen((stats) {
      _handleRunningStats(stats);
    });
  }

  // 특정 조건 충족 시 MP3 재생
  void _handleRunningStats(Map<String, dynamic> stats) {
    int elapsedTime = stats['elapsedTime'];
    double caloriesBurned = stats['caloriesBurned'];
    String pace = stats['pace'];
    double distance = stats['totalDistance'];
    bool ispaused = stats['paused'];
    bool restart = stats['restart'];

    print("경과 시간: ${elapsedTime}s | 칼로리: ${caloriesBurned}kcal | 페이스: $pace | 거리: $distance");


    //--------------- 밑으로 조건문 추가 -------------

    // 시작 후 3초 후 재생
    if (elapsedTime == 1) {
      _playAudio("TTS/start1.mp3");
    }

    // 정지하면 재생
    if (ispaused && !_hasPlayedPauseAudio) {
      _playAudio("TTS/pause_run.mp3");
      _hasPlayedPauseAudio = true;
      _hasRestartAudio = true;
    }
    // 정지 후 중복 재생 방지
    if (!ispaused) {
      _hasPlayedPauseAudio = false;
    }

    if (restart && _hasRestartAudio) {
      _playAudio("TTS/restart_run.mp3");
      _hasRestartAudio = false;
    }
  }

  // MP3 파일 재생 함수
  Future<void> _playAudio(String filePath) async {
    try {
      await _audioPlayer.play(AssetSource(filePath));
      print("MP3 파일 재생: $filePath");
    } catch (e) {
      print("MP3 재생 오류: $e");
    }
  }

  // 종료 시 구독 해제
  void dispose() {
    _statsSubscription.cancel();
    _audioPlayer.dispose();
  }
}
