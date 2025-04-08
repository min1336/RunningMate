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
  String _name = '홍길동';
  String _height = '';
  String _weight = '';
  String _workoutPerWeek = '';
  String _averageDistance = '';
  final _nicknameController = TextEditingController();
  String _nicknameMessage = '';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _loadUserInfo();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('name') ?? '홍길동';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('마이페이지')),
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
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _editUserInfo,
              child: Text('정보 수정하기'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black87),
              onPressed: () => _deleteAccountWithReauth(context),
              child: Text('계정 삭제', style: TextStyle(color: Colors.white)),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                  );
                }
              },
              child: Text('로그아웃', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
