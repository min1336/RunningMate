import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CrewDetailScreen extends StatefulWidget {
  final String crewName;

  const CrewDetailScreen({super.key, required this.crewName});

  @override
  State<CrewDetailScreen> createState() => _CrewDetailScreenState();
}

class _CrewDetailScreenState extends State<CrewDetailScreen> {
  String? userId;
  String? userEmail;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    userId = user?.uid;
    userEmail = user?.email;
  }

  Future<DocumentSnapshot?> _getCrewDoc() async {
    final query = await FirebaseFirestore.instance
        .collection('crews')
        .where('name', isEqualTo: widget.crewName)
        .limit(1)
        .get();
    return query.docs.isNotEmpty ? query.docs.first : null;
  }

  Future<void> _toggleJoin(DocumentSnapshot crewDoc) async {
    final docRef = crewDoc.reference;
    final data = crewDoc.data() as Map<String, dynamic>;
    final members = List<String>.from(data['members'] ?? []);

    final isMember = members.contains(userId);

    await docRef.update({
      'members': isMember
          ? FieldValue.arrayRemove([userId])
          : FieldValue.arrayUnion([userId])
    });

    setState(() {}); // UI 갱신
  }

  Future<String> _getNickname(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    return data?['nickname'] ?? '알 수 없음';
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.crewName)),
      body: FutureBuilder<DocumentSnapshot?>(
        future: _getCrewDoc(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          final crewDoc = snapshot.data!;
          final data = crewDoc.data() as Map<String, dynamic>;

          final members = List<String>.from(data['members'] ?? []);
          final isMember = members.contains(userId);

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📛 크루 이름: ${data['name']}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                Text('📝 소개: ${data['description'] ?? "소개 없음"}'),
                SizedBox(height: 10),
                Text('👤 만든 사람: ${data['createdBy'] ?? "알 수 없음"}'),
                SizedBox(height: 20),

                Text('👥 현재 멤버 수: ${members.length}', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                ...members.map((uid) => FutureBuilder<String>(
                  future: _getNickname(uid),
                  builder: (context, snapshot) {
                    final nickname = snapshot.data ?? uid;
                    return Text("🔸 $nickname", style: TextStyle(fontSize: 14));
                  },
                )),

                Spacer(),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () => _toggleJoin(crewDoc),
                    icon: Icon(isMember ? Icons.exit_to_app : Icons.group_add),
                    label: Text(isMember ? '크루 탈퇴하기' : '크루 가입하기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isMember ? Colors.grey : Colors.red,
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      textStyle: TextStyle(fontSize: 16),
                    ),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
