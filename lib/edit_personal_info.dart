import 'package:flutter/material.dart';

class EditPersonalInfoScreen extends StatefulWidget {
  final String nickname;
  final String height;
  final String weight;
  final String workoutPerWeek;
  final String averageDistance;

  const EditPersonalInfoScreen({
    super.key,
    required this.nickname,
    required this.height,
    required this.weight,
    required this.workoutPerWeek,
    required this.averageDistance,
  });

  @override
  State<EditPersonalInfoScreen> createState() => _EditPersonalInfoScreenState();
}

class _EditPersonalInfoScreenState extends State<EditPersonalInfoScreen> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _workoutPerWeekController;
  late final TextEditingController _averageDistanceController;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.nickname);
    _heightController = TextEditingController(text: widget.height);
    _weightController = TextEditingController(text: widget.weight);
    _workoutPerWeekController = TextEditingController(text: widget.workoutPerWeek);
    _averageDistanceController = TextEditingController(text: widget.averageDistance);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _workoutPerWeekController.dispose();
    _averageDistanceController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(context, {
      'nickname': _nicknameController.text.trim(),
      'height': _heightController.text.trim(),
      'weight': _weightController.text.trim(),
      'workoutPerWeek': _workoutPerWeekController.text.trim(),
      'averageDistance': _averageDistanceController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('정보 수정')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nicknameController,
                decoration: const InputDecoration(labelText: '닉네임'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _heightController,
                decoration: const InputDecoration(labelText: '키 (cm)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _weightController,
                decoration: const InputDecoration(labelText: '몸무게 (kg)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _workoutPerWeekController,
                decoration: const InputDecoration(labelText: '주당 운동 횟수'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _averageDistanceController,
                decoration: const InputDecoration(labelText: '평균 달리기 거리 (km)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('저장하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
