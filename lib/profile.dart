import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'edit_personal_info.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _profileImage;
  String _name = '홍길동';
  String _height = '178cm';
  String _weight = '75kg';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  /// `SharedPreferences`에서 프로필 데이터 불러오기
  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('name') ?? '홍길동';
      _height = prefs.getString('height') ?? '178cm';
      _weight = prefs.getString('weight') ?? '75kg';
      final profileImagePath = prefs.getString('profileImage');
      if (profileImagePath != null && profileImagePath.isNotEmpty) {
        _profileImage = File(profileImagePath);
      }
    });
  }

  /// `SharedPreferences`에 프로필 데이터 저장
  Future<void> _saveProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', _name);
    await prefs.setString('height', _height);
    await prefs.setString('weight', _weight);
    if (_profileImage != null) {
      await prefs.setString('profileImage', _profileImage!.path);
    }

    setState(() {
    });
  }

  /// 이미지 선택 및 저장
  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
        await _saveProfileData(); // 프로필 사진 저장
      } else {
      }
    // ignore: empty_catches
    } catch (e) {
    }
  }

  /// 개인정보 수정 화면으로 이동 후 데이터 반영
  Future<void> _updateProfileData() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPersonalInfoScreen(
          name: _name,
          height: _height,
          weight: _weight,
        ),
      ),
    );

    if (result != null && result is Map<String, String>) {
      setState(() {
        _name = result['name'] ?? _name;
        _height = result['height'] ?? _height;
        _weight = result['weight'] ?? _weight;
      });

      await _saveProfileData();
    }
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
                        : AssetImage('assets/images/default_profile.png')
                    as ImageProvider,
                    radius: 40,
                  ),
                ),
                SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          '키: $_height',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(width: 10),
                        Text(
                          '체중: $_weight',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _updateProfileData,
                child: Text('프로필 편집하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}