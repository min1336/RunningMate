import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminMarathonManagerScreen extends StatefulWidget {
  const AdminMarathonManagerScreen({super.key});

  @override
  State<AdminMarathonManagerScreen> createState() => _AdminMarathonManagerScreenState();
}

class _AdminMarathonManagerScreenState extends State<AdminMarathonManagerScreen> {
  final _titleController = TextEditingController();
  final _dateController = TextEditingController();
  final _locationController = TextEditingController();
  final _distanceController = TextEditingController();
  final _posterController = TextEditingController(); // asset 경로 입력

  List<Map<String, dynamic>> _marathons = [];
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminAndLoad();
  }

  Future<void> _checkAdminAndLoad() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    setState(() => _isAdmin = doc.data()?['isAdmin'] == true);
    if (_isAdmin) await _loadMarathons();
  }

  Future<void> _loadMarathons() async {
    final snapshot = await FirebaseFirestore.instance.collection('marathons').get();
    setState(() {
      _marathons = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    });
  }

  Future<void> _addMarathon() async {
    final title = _titleController.text.trim();
    final date = _dateController.text.trim();
    final location = _locationController.text.trim();
    final distance = _distanceController.text.trim();
    final poster = _posterController.text.trim();

    if ([title, date, location, distance, poster].any((v) => v.isEmpty)) return;

    final data = {
      'title': title,
      'date': date,
      'location': location,
      'distance': distance,
      'poster': poster,
      'participants': [],
    };

    await FirebaseFirestore.instance.collection('marathons').add(data);
    _clearInputs();
    _loadMarathons();
  }


  Future<void> _deleteMarathon(String marathonId) async {
    await FirebaseFirestore.instance.collection('marathons').doc(marathonId).delete();
    _loadMarathons();
  }

  void _clearInputs() {
    _titleController.clear();
    _dateController.clear();
    _locationController.clear();
    _distanceController.clear();
    _posterController.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text("관리자 전용")),
        body: const Center(child: Text("🔒 관리자만 접근 가능합니다.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("마라톤 관리자")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: '제목')),
            TextField(controller: _dateController, decoration: const InputDecoration(labelText: '날짜 (2025년 6월 1일)'),),
            TextField(controller: _locationController, decoration: const InputDecoration(labelText: '장소')),
            TextField(controller: _distanceController, decoration: const InputDecoration(labelText: '거리 (ex. 5km / Half)'),),
            TextField(controller: _posterController, decoration: const InputDecoration(labelText: '포스터 asset 경로'),),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _addMarathon,
              icon: const Icon(Icons.add),
              label: const Text("마라톤 추가"),
            ),
            const Divider(height: 30),
            Expanded(
              child: ListView(
                children: _marathons.map((m) {
                  return ListTile(
                    title: Text(m['title']),
                    subtitle: Text("${m['date']} • ${m['location']}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteMarathon(m['id']),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
