import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'edit_personal_info.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _profileImage;
  String _height = '';
  String _weight = '';
  String _workoutPerWeek = '';
  String _averageDistance = '';
  final _nicknameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _loadUserInfo();
    _loadRunStats(); // ✅ 통계 로딩 추가
  }

  Future<List<Map<String, dynamic>>> _fetchMyRunRecords() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('run_records')
        .where('userId', isEqualTo: uid)
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Map<String, double> _calculateDistances(List<Map<String, dynamic>> records) {
    final now = DateTime.now();
    double total = 0, monthly = 0, weekly = 0, daily = 0;

    for (final record in records) {
      final dateStr = record['date'];
      final distance = record['distance'] ?? 0.0;
      final recordDate = DateTime.tryParse(dateStr);

      if (recordDate == null) continue;

      total += distance;

      if (recordDate.year == now.year && recordDate.month == now.month) {
        monthly += distance;
      }

      if (now.difference(recordDate).inDays < 7) {
        weekly += distance;
      }

      if (recordDate.year == now.year &&
          recordDate.month == now.month &&
          recordDate.day == now.day) {
        daily += distance;
      }
    }

    return {
      '전체': total,
      '월간': monthly,
      '주간': weekly,
      '일일': daily,
    };
  }

  double _totalDistance = 0;
  double _monthlyDistance = 0;
  double _weeklyDistance = 0;
  double _dailyDistance = 0;

  Future<void> _loadRunStats() async {
    final records = await _fetchMyRunRecords();
    final distances = _calculateDistances(records);

    setState(() {
      _totalDistance = distances['전체']!;
      _monthlyDistance = distances['월간']!;
      _weeklyDistance = distances['주간']!;
      _dailyDistance = distances['일일']!;
    });
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final profileImagePath = prefs.getString('profileImage');
      if (profileImagePath != null && profileImagePath.isNotEmpty) {
        _profileImage = File(profileImagePath);
      }
    });
  }

  Future<void> _loadUserInfo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    if (data != null) {
      setState(() {
        _nicknameController.text = data['nickname'] ?? '';
        _height = data['height'] ?? '';
        _weight = data['weight'] ?? '';
        _workoutPerWeek = data['workoutPerWeek'] ?? '';
        _averageDistance = data['averageDistance'] ?? '';
      });
    }
  }

  Future<void> _saveUserInfo(Map<String, String> newData) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).update(newData);
    await _loadUserInfo();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profileImage', _profileImage!.path);
      }
    } catch (e) {}
  }

  Future<void> _editUserInfo() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPersonalInfoScreen(
          nickname: _nicknameController.text,
          height: _height,
          weight: _weight,
          workoutPerWeek: _workoutPerWeek,
          averageDistance: _averageDistance,
        ),
      ),
    );

    if (result != null && result is Map<String, String>) {
      await _saveUserInfo(result);
    }
  }

  Future<void> _deleteAccountWithReauth(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    if (user == null || uid == null) return;

    try {

      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('email');
      final savedPassword = prefs.getString('password');

      if (savedEmail != null && savedPassword != null) {
        try {
          final credential = EmailAuthProvider.credential(
            email: savedEmail,
            password: savedPassword,
          );
          await user.reauthenticateWithCredential(credential);
          print("🔑 자동 재인증 성공");
        } catch (e) {
          print("⚠️ 자동 재인증 실패, 다이얼로그로 전환");
          _showReauthDialog(context, user);
          return; // 재인증 실패 시 아래 삭제 로직 중단
        }
      }

      final allUsers = await FirebaseFirestore.instance.collection('users').get();
      for (final doc in allUsers.docs) {
        final otherUid = doc.id;
        if (otherUid == uid) continue;

        await FirebaseFirestore.instance.collection('users').doc(otherUid).update({
          'friends': FieldValue.arrayRemove([uid]),
          'friendRequests': FieldValue.arrayRemove([uid]),
          'sentRequests': FieldValue.arrayRemove([uid]),
        });
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      await user.delete();

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showReauthDialog(context, user);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: ${e.message}')),
        );
      }
    }
  }

  void _showReauthDialog(BuildContext context, User user) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("다시 로그인해주세요"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: '이메일')),
            TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: '비밀번호')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              final credential = EmailAuthProvider.credential(
                email: emailController.text.trim(),
                password: passwordController.text.trim(),
              );

              try {
                await user.reauthenticateWithCredential(credential);

                // ✅ 여기 추가: 입력한 값을 저장
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('email', emailController.text.trim());
                await prefs.setString('password', passwordController.text.trim());

                Navigator.pop(context);
                await _deleteAccountWithReauth(context); // 재시도
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('재인증 실패: $e')),
                );
              }
            },
            child: const Text('확인', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('마이페이지'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'edit') {
                await _editUserInfo();
              } else if (value == 'logout') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("로그아웃 하시겠어요?"),
                    content: const Text("앱에서 로그아웃됩니다."),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("취소"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text("로그아웃", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false,
                    );
                  }
                }
              }
              else if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("정말 삭제할까요?"),
                    content: const Text("계정을 삭제하면 복구할 수 없습니다.\n계속 진행하시겠습니까?"),
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
                  await _deleteAccountWithReauth(context);
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('정보 수정')),
              const PopupMenuItem(value: 'logout', child: Text('로그아웃')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('계정 삭제', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    backgroundImage: _profileImage != null
                        ? FileImage(_profileImage!)
                        : AssetImage('assets/images/default_profile.png') as ImageProvider,
                    radius: 40,
                  ),
                ),
                SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_nicknameController.text, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 5),
                    Text('키: $_height, 체중: $_weight'),
                    Text('주당 운동 횟수: $_workoutPerWeek'),
                    Text('평균 달리기 거리: $_averageDistance km'),
                  ],
                ),
              ],
            ),
            SizedBox(height: 40),
            Text('🏃 러닝 거리 통계', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 8),
            Text('• 전체 거리: ${_totalDistance.toStringAsFixed(2)} km'),
            Text('• 월간 거리: ${_monthlyDistance.toStringAsFixed(2)} km'),
            Text('• 주간 거리: ${_weeklyDistance.toStringAsFixed(2)} km'),
            Text('• 오늘 거리: ${_dailyDistance.toStringAsFixed(2)} km'),
          ],
        ),
      ),
    );
  }
}