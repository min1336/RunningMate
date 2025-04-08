import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _workoutPerWeekController = TextEditingController();
  final _averageDistanceController = TextEditingController();

  String _message = '';

  Future<void> _submitSurvey() async {
    final height = _heightController.text.trim();
    final weight = _weightController.text.trim();
    final workoutPerWeek = _workoutPerWeekController.text.trim();
    final averageDistance = _averageDistanceController.text.trim();

    if (height.isEmpty || weight.isEmpty || workoutPerWeek.isEmpty || averageDistance.isEmpty) {
      setState(() => _message = '모든 항목을 입력해주세요.');
      return;
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'height': height,
      'weight': weight,
      'workoutPerWeek': workoutPerWeek,
      'averageDistance': averageDistance,
      'surveyDone': true,
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('간단한 설문')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('당신에 대해 알려주세요!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            TextField(
              controller: _heightController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: '키 (cm)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _weightController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: '몸무게 (kg)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _workoutPerWeekController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: '주당 운동 횟수', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _averageDistanceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: '평균 달리기 거리 (km)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _submitSurvey,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('제출하기'),
            ),

            if (_message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _message,
                  style: TextStyle(color: Colors.red),
                ),
              )
          ],
        ),
      ),
    );
  }
}
