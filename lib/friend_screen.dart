import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'friends_run_screen.dart';

class FriendScreen extends StatefulWidget {
  const FriendScreen({super.key});

  @override
  _FriendScreenState createState() => _FriendScreenState();
}

class _FriendScreenState extends State<FriendScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  List<Map<String, dynamic>> _receivedRequests = [];

  Future<void> _loadFriendRequests() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final friendUids = List<String>.from(doc['friends'] ?? []);
    final requestUids = List<String>.from(doc['friendRequests'] ?? []);

    print("🔥 받은 친구 요청 UID: $requestUids");

    final List<Map<String, dynamic>> fetchedRequests = [];
    for (final requestUid in requestUids) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(requestUid).get();
        if (!userDoc.exists) continue;

        fetchedRequests.add({
          'uid': requestUid,
          'nickname': userDoc['nickname'] ?? '알 수 없음',
        });
      } catch (e) {
        print("❌ 친구 요청 로딩 실패: $e");
      }
    }

    setState(() {
      _receivedRequests = fetchedRequests;
    });

    // 기존 친구 목록도 불러오기
    final List<Map<String, dynamic>> fetchedFriends = [];
    for (final friendUid in friendUids) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(friendUid).get();
        if (!userDoc.exists) continue;

        fetchedFriends.add({
          'uid': friendUid,
          'nickname': userDoc['nickname'] ?? '알 수 없음',
          'status': userDoc['status'] ?? 'offline',
        });
      } catch (e) {
        print("❌ 친구 문서 로딩 실패: $e");
      }
    }

    setState(() => _myFriends = fetchedFriends);
  }


  Color _getStatusColor(String? status) {
    switch (status) {
      case 'running':
        return Colors.green;
      case 'online':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _sendFriendRequest() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final nickname = _nicknameController.text.trim();

    if (nickname.isEmpty || myUid == null) return;

    // 1. 닉네임으로 사용자 조회
    final result = await FirebaseFirestore.instance
        .collection('users')
        .where('nickname', isEqualTo: nickname)
        .limit(1)
        .get();

    if (result.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("닉네임을 찾을 수 없습니다.")));
      return;
    }

    final targetUid = result.docs.first.id;

    if (targetUid == myUid) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("자기 자신에게는 요청할 수 없습니다.")));
      return;
    }

    // 🔒 이미 친구인지 확인
    final myDoc = await FirebaseFirestore.instance.collection('users').doc(myUid).get();
    final myFriends = List<String>.from(myDoc['friends'] ?? []);
    if (myFriends.contains(targetUid)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("이미 친구입니다.")));
      return;
    }

    // 🔒 이미 보낸 요청인지 확인
    final mySent = List<String>.from(myDoc['sentRequests'] ?? []);
    if (mySent.contains(targetUid)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("이미 요청을 보냈습니다.")));
      return;
    }

    // 🔒 상대방이 이미 요청을 보냈는지도 체크하면 좋음 (상호 요청 시)
    final targetDoc = await FirebaseFirestore.instance.collection('users').doc(targetUid).get();
    final targetSent = List<String>.from(targetDoc['sentRequests'] ?? []);
    if (targetSent.contains(myUid)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("상대가 이미 요청을 보냈습니다.")));
      return;
    }

    // 요청 전송
    await FirebaseFirestore.instance.collection('users').doc(targetUid).update({
      'friendRequests': FieldValue.arrayUnion([myUid]),
    });

    await FirebaseFirestore.instance.collection('users').doc(myUid).update({
      'sentRequests': FieldValue.arrayUnion([targetUid]),
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("요청을 보냈습니다.")));
    _nicknameController.clear();
  }


  Future<void> _acceptRequest(String requesterUid) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    // 1. 친구로 등록
    await FirebaseFirestore.instance.collection('users').doc(myUid).update({
      'friends': FieldValue.arrayUnion([requesterUid]),
      'friendRequests': FieldValue.arrayRemove([requesterUid]),
    });
    await FirebaseFirestore.instance.collection('users').doc(requesterUid).update({
      'friends': FieldValue.arrayUnion([myUid]),
      'sentRequests': FieldValue.arrayRemove([myUid]),
    });

    _loadFriendRequests();
  }

  Future<void> _rejectRequest(String requesterUid) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    await FirebaseFirestore.instance.collection('users').doc(myUid).update({
      'friendRequests': FieldValue.arrayRemove([requesterUid]),
    });
    await FirebaseFirestore.instance.collection('users').doc(requesterUid).update({
      'sentRequests': FieldValue.arrayRemove([myUid]),
    });

    _loadFriendRequests();
  }

  List<Map<String, dynamic>> _myFriends = [];

  Future<void> _loadFriends() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final friendUids = List<String>.from(doc['friends'] ?? []); // ✅ 친구 uid 목록 가져오기

    final List<Map<String, dynamic>> fetchedFriends = []; // ✅ friends 리스트 정의

    for (final friendUid in friendUids) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(friendUid).get();
      if (userDoc.exists) {
        fetchedFriends.add({
          'uid': friendUid,
          'nickname': userDoc['nickname'],
          'status': userDoc['status'] ?? 'offline', // 상태도 포함할 경우
        });
      }
    }

    setState(() => _myFriends = fetchedFriends); // ✅ 상태에 반영
  }

  Future<void> _removeFriend(String friendUid) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    await FirebaseFirestore.instance.collection('users').doc(myUid).update({
      'friends': FieldValue.arrayRemove([friendUid]),
    });

    await FirebaseFirestore.instance.collection('users').doc(friendUid).update({
      'friends': FieldValue.arrayRemove([myUid]),
    });

    _loadFriends();
  }

  @override
  void initState() {
    super.initState();
    _loadFriendRequests();
    _loadFriends(); // ← 친구 목록도 불러오기
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("친구 관리")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nicknameController,
              decoration: InputDecoration(
                labelText: "닉네임으로 친구 요청",
                hintText: "친구 닉네임 입력",
                prefixIcon: Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendFriendRequest,
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
            SizedBox(height: 20),
            Text("📥 받은 친구 요청", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

            ..._receivedRequests.map((r) => Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: Icon(Icons.person_add, color: Colors.orange),
                title: Text(r['nickname'], style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.check, color: Colors.green),
                      onPressed: () => _acceptRequest(r['uid']),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.red),
                      onPressed: () => _rejectRequest(r['uid']),
                    ),
                  ],
                ),
              ),
            ))
            ,
            SizedBox(height: 30),
            Text("👥 나의 친구 목록", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

            ..._myFriends.map((f) => Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 5,
                      backgroundColor: _getStatusColor(f['status']), // ✅ 상태에 따라 색상
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.person, color: Colors.blue),
                  ],
                ),
                title: Text(f['nickname'], style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FriendsRunScreen(targetUid: f['uid']),
                    ),
                  );
                },
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.grey),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("친구 삭제"),
                        content: const Text("정말 이 친구를 삭제하시겠습니까?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("취소"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("삭제", style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      _removeFriend(f['uid']);
                    }
                  },
                ),
              ),
            ))

          ],
        ),
      ),
    );
  }
}
