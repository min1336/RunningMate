import 'dart:async';
import 'package:audioplayers/audioplayers.dart'; // MP3 재생 라이브러리
import 'package:run1220/running_screen.dart'; // 실시간 데이터 가져오기

class RunningTTS {
  final RunningScreen runningScreen;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late StreamSubscription<Map<String, dynamic>> _statsSubscription;

  RunningTTS(this.runningScreen) {
    print("121323");
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

    print("경과 시간: ${elapsedTime}s | 칼로리: ${caloriesBurned}kcal | 페이스: $pace");

    // 10분 경과 시 TTS 실행
    if (elapsedTime == 3) { // 10분 = 600초
      _playAudio("TTS/start1.mp3"); // 10분 경과 알림 MP3
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
