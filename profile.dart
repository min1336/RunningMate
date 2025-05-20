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
  int _monthlyCash = 0;
  final _nicknameController = TextEditingController();

  double _totalDistance = 0;
  double _monthlyDistance = 0;
  double _weeklyDistance = 0;
  double _dailyDistance = 0;
  String _cashBadge = '없음';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _loadUserInfo();
    _loadRunStats();
    _loadMonthlyCash();
  }

  Future<void> _loadMonthlyCash() async {
    final earned = await _getMonthlyCashEarned();
    setState(() => _monthlyCash = earned);
  }

  Future<int> _getMonthlyCashEarned() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;

    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cash_logs')
        .where('timestamp', isGreaterThanOrEqualTo: firstOfMonth)
        .get();

    int total = 0;
    for (var doc in snapshot.docs) {
      total += (doc['total'] as num).toInt();
    }
    return total;
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

        final cash = data['cash'] ?? 0;
        if (cash >= 300) _cashBadge = '🏆 플래티넘';
        else if (cash >= 150) _cashBadge = '🥇 골드';
        else if (cash >= 50) _cashBadge = '🥈 실버';
        else _cashBadge = '🥉 브론즈';
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
        } catch (e) {
          _showReauthDialog(context, user);
          return;
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
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('email', emailController.text.trim());
                await prefs.setString('password', passwordController.text.trim());

                Navigator.pop(context);
                await _deleteAccountWithReauth(context);
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

  void _showPokeListDialog() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('pokes')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .get();

    final List<Map<String, dynamic>> pokes = [];

    for (final doc in snapshot.docs) {
      final senderUid = doc.id;
      final senderDoc = await FirebaseFirestore.instance.collection('users').doc(senderUid).get();
      if (!senderDoc.exists) continue;
      final nickname = senderDoc['nickname'] ?? '알 수 없음';
      final time = (doc['timestamp'] as Timestamp).toDate();
      pokes.add({'nickname': nickname, 'timestamp': time});
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('👆 받은 콕찌르기'),
        content: SizedBox(
          width: double.maxFinite,
          child: pokes.isEmpty
              ? const Text('최근 받은 콕찌르기가 없습니다.')
              : ListView.builder(
            itemCount: pokes.length,
            shrinkWrap: true,
            itemBuilder: (context, index) {
              final poke = pokes[index];
              return ListTile(
                leading: const Icon(Icons.touch_app, color: Colors.pink),
                title: Text('${poke['nickname']}님이 콕 찔렀어요!'),
                subtitle: Text(
                  timeAgo(poke['timestamp']),
                  style: const TextStyle(fontSize: 12),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("닫기"),
          )
        ],
      ),
    );
  }

  String timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('마이페이지'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            tooltip: '받은 콕찌르기',
            onPressed: _showPokeListDialog,
          ),
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            children: [
              // 프로필 카드
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          backgroundImage: _profileImage != null
                              ? FileImage(_profileImage!)
                              : const AssetImage('assets/images/default_profile.png') as ImageProvider,
                          radius: 48,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _nicknameController.text,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text('키: $_height, 체중: $_weight', style: TextStyle(color: Colors.grey[700])),
                      Text('주당 운동: $_workoutPerWeek회, 평균: $_averageDistance km', style: TextStyle(color: Colors.grey[700])),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 러닝 통계 카드
              InfoCard(
                title: '🏃 러닝 거리 통계',
                children: [
                  StatRow(label: '전체', value: '${_totalDistance.toStringAsFixed(2)} km'),
                  StatRow(label: '월간', value: '${_monthlyDistance.toStringAsFixed(2)} km'),
                  StatRow(label: '주간', value: '${_weeklyDistance.toStringAsFixed(2)} km'),
                  StatRow(label: '오늘', value: '${_dailyDistance.toStringAsFixed(2)} km'),
                ],
              ),
              const SizedBox(height: 18),

              // 캐시 정보 카드
              InfoCard(
                title: '💰 이번 달 캐시 보상',
                children: [
                  StatRow(label: '적립 캐시', value: '$_monthlyCash 캐시'),
                ],
              ),
              const SizedBox(height: 18),

              // 뱃지 카드
              InfoCard(
                title: '🎖 누적 캐시 뱃지',
                children: [
                  StatRow(label: '현재 등급', value: _cashBadge),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 재사용 가능한 카드 위젯
class InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const InfoCard({required this.title, required this.children, super.key});
  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

// 재사용 가능한 통계 행 위젯
class StatRow extends StatelessWidget {
  final String label;
  final String value;
  const StatRow({required this.label, required this.value, super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('• $label', style: const TextStyle(fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}
