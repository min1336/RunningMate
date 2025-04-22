import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'marathon_calendar_screen.dart';


class MarathonScreen extends StatefulWidget {
  const MarathonScreen({super.key});

  @override
  State<MarathonScreen> createState() => _MarathonScreenState();
}

class _MarathonScreenState extends State<MarathonScreen> {
  late List<Map<String, dynamic>> marathonList = [];

  List<String> appliedTitles = [];

  @override
  void initState() {
    super.initState();
    _loadMarathons();
    _loadAppliedMarathons();
  }

  Future<void> _loadMarathons() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance.collection('marathons').get();
    final List<Map<String, dynamic>> marathons = [];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final participants = List<String>.from(data['participants'] ?? []);

      final isApplied = participants.contains(uid);

      marathons.add({
        ...data,
        'id': doc.id,
        'isApplied': isApplied, // 🔥 참가 여부 추가
      });
    }

    setState(() {
      marathonList = marathons;
    });
  }

  Future<void> _applyForMarathon(String marathonId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('marathons').doc(marathonId).update({
      'participants': FieldValue.arrayUnion([uid])
    });
    await _loadMarathons(); // 상태 동기화
    setState(() {}); // 화면 갱신
  }

  Future<void> _cancelMarathon(String marathonId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('marathons').doc(marathonId).update({
      'participants': FieldValue.arrayRemove([uid])
    });
    await _loadMarathons(); // 상태 갱신
    setState(() {});
  }



  Future<List<Map<String, dynamic>>> getFriendsInMarathon(String marathonId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final friends = List<String>.from(userDoc['friends'] ?? []);

    final marathonDoc = await FirebaseFirestore.instance.collection('marathons').doc(marathonId).get();
    final participants = List<String>.from(marathonDoc['participants'] ?? []);

    final List<Map<String, dynamic>> result = [];

    for (final friendUid in friends) {
      if (participants.contains(friendUid)) {
        final friendDoc = await FirebaseFirestore.instance.collection('users').doc(friendUid).get();
        result.add({
          'uid': friendUid,
          'nickname': friendDoc['nickname'] ?? '알 수 없음',
        });
      }
    }

    return result;
  }

  Future<bool> isUserParticipating(String marathonId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    final doc = await FirebaseFirestore.instance.collection('marathons').doc(marathonId).get();
    final participants = List<String>.from(doc.data()?['participants'] ?? []);
    return participants.contains(uid);
  }

  Future<void> _loadAppliedMarathons() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      appliedTitles = prefs.getStringList('appliedMarathons') ?? [];
    });
  }

  void _showMarathonDialog(BuildContext context, Map<String, dynamic> marathon) {
    final now = DateTime.now();
    final marathonId = marathon['id']; // 🔥 여기서 id 꺼냄
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isApplied = (marathon['participants'] as List<dynamic>).contains(uid);
    DateTime? parsedDate;
    try {
      parsedDate = DateFormat("yyyy년 M월 d일").parseStrict(marathon["date"]);
    } catch (e) {
      parsedDate = null;
    }
    final dDay = parsedDate?.difference(now).inDays;

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Center(
                          child: dDay != null
                              ? Text(
                            "D-${dDay >= 0 ? dDay : 0}",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                            ),
                          )
                              : const SizedBox(),
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$value 기능은 준비 중입니다.')),
                          );
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem(value: '공유하기', child: Text('공유하기')),
                          const PopupMenuItem(value: '대회규정', child: Text('대회규정')),
                          const PopupMenuItem(value: '공식사이트', child: Text('공식사이트')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.asset(marathon["poster"], height: 200, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    marathon["title"],
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(marathon["date"]),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.place, size: 18, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(marathon["location"]),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.directions_run, size: 18, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(marathon["distance"]),
                    ],
                  ),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: getFriendsInMarathon(marathonId),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();

                      final friends = snapshot.data!;
                      if (friends.isEmpty) return const Text("🙈 참가 중인 친구 없음");

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          const Text("👟 친구 중 참가자", style: TextStyle(fontWeight: FontWeight.bold)),
                          ...friends.map((f) => Text("• ${f['nickname']}")).toList(),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final isApplied = await isUserParticipating(marathonId);
                      if (isApplied) {
                        await _cancelMarathon(marathonId);
                      } else {
                        await _applyForMarathon(marathonId);
                      }

                      Navigator.pop(context); // 다이얼로그 닫기
                      setState(() {}); // 재랜더링
                    },
                    icon: Icon(Icons.check),
                    label: Text(isApplied ? "신청 취소하기" : "마라톤 신청하기"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isApplied ? Colors.grey : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appliedMarathons = marathonList.where((m) => m['isApplied'] == true).toList();
    final availableMarathons = marathonList.where((m) => m['isApplied'] == false).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("🏁 마라톤 신청"),
        backgroundColor: Colors.redAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: '마라톤 일정 보기',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MarathonCalendarScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (appliedMarathons.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("✅ 참가중인 마라톤", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...appliedMarathons.map((m) => _buildMarathonCard(context, m, isApplied: true)),
                const SizedBox(height: 30),
              ],
            ),
          const Text("📋 신청 가능한 마라톤", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...availableMarathons.map((m) => _buildMarathonCard(context, m, isApplied: false)),
        ],
      ),
    );
  }

  Widget _buildMarathonCard(BuildContext context, Map<String, dynamic> marathon, {required bool isApplied}) {
    DateTime? parsedDate;
    try {
      parsedDate = DateFormat("yyyy년 M월 d일").parseStrict(marathon["date"]);
    } catch (e) {
      parsedDate = null;
    }
    final dDay = parsedDate?.difference(DateTime.now()).inDays;

    return GestureDetector(
      onTap: () => _showMarathonDialog(context, marathon),
      child: Card(
        color: isApplied ? Colors.grey[350] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(marathon["poster"], width: 80, height: 80, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      marathon["title"],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isApplied ? Colors.grey[700] : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${marathon["date"]} • ${marathon["location"]}",
                      style: TextStyle(
                        color: isApplied ? Colors.grey[600] : Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (dDay != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: dDay <= 3 ? Colors.red : Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "D-${dDay >= 0 ? dDay : 0}",
                    style: TextStyle(
                      color: dDay <= 3 ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<List<Map<String, dynamic>>> getFriendsInMarathon(String marathonId) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return [];

  final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  final friends = List<String>.from(userDoc['friends'] ?? []);

  final marathonDoc = await FirebaseFirestore.instance.collection('marathons').doc(marathonId).get();
  final participants = List<String>.from(marathonDoc['participants'] ?? []);

  final List<Map<String, dynamic>> result = [];

  for (final friendUid in friends) {
    if (participants.contains(friendUid)) {
      final friendDoc = await FirebaseFirestore.instance.collection('users').doc(friendUid).get();
      result.add({
        'uid': friendUid,
        'nickname': friendDoc['nickname'] ?? '알 수 없음',
      });
    }
  }

  return result;
}