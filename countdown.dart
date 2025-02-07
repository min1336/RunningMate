import 'dart:async'; // 비동기 작업 (Future, Stream) 처리
import 'package:flutter/material.dart'; // Flutter UI 구성

class CountdownScreen extends StatefulWidget {
  final VoidCallback onCountdownComplete;

  const CountdownScreen({required this.onCountdownComplete, super.key});

  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen> {
  int _countdown = 3; // 초기 카운트다운 숫자

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          timer.cancel(); // 타이머 종료
          widget.onCountdownComplete(); // 완료 콜백 호출
        }
      });
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // 전체 화면 배경색
      body: Center(
        child: Text(
          '$_countdown', // 카운트다운 숫자
          style: const TextStyle(
            fontSize: 100,
            fontWeight: FontWeight.bold,
            color: Colors.white, // 텍스트 색상
          ),
        ),
      ),
    );
  }
}