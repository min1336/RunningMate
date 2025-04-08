import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'crew_detail_screen.dart';

class CrewScreen extends StatelessWidget {
  const CrewScreen({super.key});

  Future<void> _showCreateCrewDialog(BuildContext context) async {
    final controller = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('크루 생성'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(hintText: '크루 이름 입력'),
            ),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(hintText: '크루 소개 입력'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('취소')),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              final desc = descriptionController.text.trim();

              final user = FirebaseAuth.instance.currentUser; // ✅ 로그인 사용자 정보 가져오기

              if (name.isNotEmpty) {
                await FirebaseFirestore.instance.collection('crews').add({
                  'name': name,
                  'description': desc,
                  'createdAt': Timestamp.now(),
                  'createdBy': user?.email ?? '익명',     // 이메일 저장
                  'members': [user?.uid],               // 🔥 UID 리스트로 나 자신 자동 가입
                });
              }

              Navigator.pop(context);
            },
            child: Text('생성'),
          ),
        ],
      ),
    );

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('🏃‍♂️ 전체 크루')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('crews')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(child: Text('등록된 크루가 없습니다.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return ListTile(
                leading: Icon(Icons.flag, color: Colors.redAccent),
                title: Text(data['name'] ?? '이름 없음'),
                trailing: Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CrewDetailScreen(crewName: data['name']),
                    ),
                  );
                },
                onLongPress: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('크루 삭제'),
                      content: Text('정말 이 크루를 삭제하시겠습니까?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('취소')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: Text('삭제')),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await docs[index].reference.delete();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${data['name']} 크루 삭제됨')),
                    );
                  }
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateCrewDialog(context),
        child: Icon(Icons.add),
        backgroundColor: Colors.red,
      ),
    );
  }
}