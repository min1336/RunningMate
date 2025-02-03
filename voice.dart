import 'package:flutter/material.dart'; // Flutter UI 패키지
import 'package:audioplayers/audioplayers.dart'; // 오디오 재생을 위한 패키지
import 'services/elevenlabs_service.dart'; // Eleven Labs TTS API 호출을 위한 서비스 파일

void main() {
  runApp(MyApp()); // MyApp 위젯 실행
}

class MyApp extends StatelessWidget { // 앱의 루트 위젯
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eleven Labs TTS', // 앱 타이틀 설정
      home: TTSPage(), // 홈 화면을 TTSPage로 설정
    );
  }
}

class TTSPage extends StatefulWidget { // 상태를 가지는 위젯 선언
  @override
  _TTSPageState createState() => _TTSPageState(); // 상태 관리 클래스 생성
}

class _TTSPageState extends State<TTSPage> {
  // Eleven Labs TTS API 사용을 위한 서비스 객체 생성
  final ElevenLabsService ttsService = ElevenLabsService("sk_c8e5a1fc3c00a8cf0f98b69e138db0ca1c2aff0583ba5b9a");

  final AudioPlayer audioPlayer = AudioPlayer(); // 오디오 재생을 위한 객체 생성
  final TextEditingController textController = TextEditingController(); // 텍스트 입력 필드 컨트롤러
  final String voiceId = "4JJwo477JUAx3HV0T7n7"; // Eleven Labs에서 제공한 음성 ID

  bool isLoading = false; // TTS 변환 중인지 확인하는 변수

  void playRecordedAudio() async {
    try {
      await audioPlayer.play(AssetSource("voice/pace_down.mp3")); // 올바른 경로
    } catch (e) {
      print("녹음된 음성을 재생하는 동안 오류 발생: $e");
    }
  }

  @override
  void dispose() {
    audioPlayer.dispose(); // 오디오 플레이어 자원 해제
    super.dispose(); // 부모 클래스의 dispose 호출
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Eleven Labs TTS"), // 앱바 제목 설정
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0), // 화면에 패딩 추가
        child: Column(
          children: [
            SizedBox(height: 16), // 간격 추가
            ElevatedButton(
              onPressed: playRecordedAudio, // 버튼 클릭 시 녹음된 오디오 재생
              child: Text("녹음된 음성 출력"),
            ),
          ],
        ),
      ),
    );
  }
}
