import 'package:flutter/material.dart';

class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> chatMessages = [
      {'sender': 'ai', 'text': '오늘 러닝 수고하셨습니다! 🏃‍♂️'},
      {'sender': 'ai', 'text': '전체 거리: 4.2km, 평균 페이스: 6분/km 정도네요.'},
      {'sender': 'ai', 'text': '중간에 페이스가 살짝 떨어졌지만 다시 회복하신 게 인상적이에요! 👍'},
      {'sender': 'ai', 'text': '호흡이 가빠졌던 지점에서는 조금 속도를 줄여도 좋았을 것 같아요.'},
      {'sender': 'ai', 'text': '다음 목표는 5km를 꾸준한 페이스로 완주하는 것이 어떨까요?'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('달리기 피드백')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: chatMessages.length,
        itemBuilder: (context, index) {
          final message = chatMessages[index];
          final isAI = message['sender'] == 'ai';

          return Align(
            alignment: isAI ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(12),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: isAI ? Colors.grey[200] : Colors.redAccent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message['text']!,
                style: TextStyle(
                  fontSize: 16,
                  color: isAI ? Colors.black87 : Colors.white,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
