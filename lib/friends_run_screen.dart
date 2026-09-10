import 'package:flutter/material.dart';
import 'firestore_service.dart';
import 'dart:convert'; // base64Decode 함수 사용

class FriendsRunScreen extends StatefulWidget {
  final String targetUid;

  const FriendsRunScreen({super.key, required this.targetUid});

  @override
  State<FriendsRunScreen> createState() => _FriendsRunScreenState();
}

class _FriendsRunScreenState extends State<FriendsRunScreen> {
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final result = await fetchRunRecordsForUser(widget.targetUid);
    setState(() {
      _records = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("친구들의 러닝 기록")),
      body: _records.isEmpty
          ? const Center(child: Text("아직 친구 기록이 없습니다."))
          : ListView.builder(
              itemCount: _records.length,
              itemBuilder: (context, index) {
                final record = _records[index];
                final base64Image = record['routeImage'];
                final imageWidget = base64Image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          base64Decode(base64Image),
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Text("🖼️ 경로 이미지 없음",
                        style: TextStyle(color: Colors.grey));

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.run_circle_outlined),
                        title: Text("📅 ${record['date']}"),
                        subtitle: Text(
                            "🏃 ${record['distance']}km | 🕒 ${record['time']} | 🔥 ${record['calories']}kcal"),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: imageWidget,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
