import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:run1220/route_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile.dart';
import 'Calendar.dart';
import 'naver.dart';
import 'package:run1220/marathon_screen.dart';
import 'package:run1220/friend_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 2;
  final List<Widget> _screens = [
    MarathonScreen(),
    FriendScreen(),
    MainScreen(),
    RouteScreen(),
    CalendarScreen(),
  ];

  Future<void> _updateUserStatus(String status) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'status': status,
      'lastActive': FieldValue.serverTimestamp(),
    });
  }

  String _profileName = '사용자 프로필';
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // ✅ 추가
    _loadProfileData();
    _updateUserStatus('online');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // ✅ 추가
    _updateUserStatus('offline'); // 앱 종료 처리
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _updateUserStatus('offline');
    } else if (state == AppLifecycleState.resumed) {
      _updateUserStatus('online');
    }
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _profileName = prefs.getString('name') ?? '사용자 프로필';
      String? imagePath = prefs.getString('profileImage');
      if (imagePath != null && imagePath.isNotEmpty) {
        _profileImage = File(imagePath);
      }
    });
  }

  Future<void> _navigateToProfileScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfileScreen()),
    );

    if (result != null && result is bool && result) {
      _loadProfileData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepOrange),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _navigateToProfileScreen,
                    child: CircleAvatar(
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!)
                          : AssetImage('assets/images/default_profile.png') as ImageProvider,
                      radius: 40,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    _profileName,
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('홈'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.people), // 기존: Icons.flag
              title: Text('친구'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FriendScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('설정'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsScreen()),
                );
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        actions: [
          GestureDetector(
            onTap: _navigateToProfileScreen,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: CircleAvatar(
                backgroundImage: _profileImage != null
                    ? FileImage(_profileImage!)
                    : AssetImage('assets/images/default_profile.png') as ImageProvider,
                radius: 20,
              ),
            ),
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.sports),
            label: '마라톤',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people), // 기존: Icons.flag
            label: '친구',             // 기존: '크루'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_run),
            label: '달리기',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.route),
            label: '루트',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: '캘린더',
          ),
        ],
      ),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  Future<String> getUserLevel() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return '';

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();

    final workouts = int.tryParse(data?['workoutPerWeek'] ?? '0') ?? 0;
    final distance = double.tryParse(data?['averageDistance'] ?? '0') ?? 0;

    if (workouts <= 2) return '초급';
    if (workouts <= 4 && distance <= 5) return '중급';
    if (workouts >= 5 && distance > 5) return '고급';

    return '';
  }

  Widget buildRecommendation(String level) {
    switch (level) {
      case '초급':
        return Text('🏃‍♂️ 초급자용 짧고 쉬운 코스를 추천합니다.', style: TextStyle(fontSize: 16));
      case '중급':
        return Text('🔥 중급자를 위한 코스를 추천합니다!', style: TextStyle(fontSize: 16));
      case '고급':
        return Text('💪 고강도 장거리 러닝 코스를 추천합니다!', style: TextStyle(fontSize: 16));
      default:
        return Text('설문을 먼저 작성해주세요.', style: TextStyle(fontSize: 16));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 40),
            FutureBuilder<String>(
              future: getUserLevel(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator();
                }
                final level = snapshot.data ?? '';
                return buildRecommendation(level);
              },
            ),
            SizedBox(height: 30),
            Center(
              child: Image.asset(
                'assets/images/character.png',
                width: 300,
                height: 300,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => NaverMapApp()),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              child: Text('🏃 달리기 시작'),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class BattleScreen extends StatelessWidget {
  const BattleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('대결 페이지')),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('설정')),
      body: Center(child: Text('설정 페이지')),
    );
  }
}