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
  late PageController _pageController;

  final List<Widget> _screens = [
    MarathonScreen(),
    FriendScreen(),
    MainScreen(),
    RouteScreen(),
    CalendarScreen(),
  ];

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

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
    WidgetsBinding.instance.addObserver(this);
    _loadProfileData();
    _updateUserStatus('online');
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _updateUserStatus('offline');
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
              leading: Icon(Icons.people),
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
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _screens,
        physics: const BouncingScrollPhysics(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.sports), label: '마라톤'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: '친구'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_run), label: '달리기'),
          BottomNavigationBarItem(icon: Icon(Icons.route), label: '루트'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: '캘린더'),
        ],
      ),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  Future<double> getTotalDistance() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0.0;

    final snapshot = await FirebaseFirestore.instance
        .collection('run_records')
        .where('userId', isEqualTo: uid)
        .get();

    double total = 0.0;
    for (var doc in snapshot.docs) {
      total += (doc.data()['distance'] ?? 0.0);
    }
    return total;
  }

  _LevelInfo _getLevel(double distance) {
    if (distance < 0.3) {
      return _LevelInfo('🟤 브론즈', '실버', distance / 0.3, Colors.brown, Colors.white);
    } else if (distance < 0.5) {
      return _LevelInfo('⚪ 실버', '골드', (distance - 0.3) / 0.2, Colors.grey.shade300, Colors.black87);
    } else if (distance < 0.6) {
      return _LevelInfo('🟡 골드', '다이아', (distance - 0.5) / 0.1, Colors.amber, Colors.black87);
    } else if (distance < 0.7) {
      return _LevelInfo('🔷 다이아', '마스터', (distance - 0.6) / 0.1, Colors.lightBlue, Colors.black87);
    } else {
      return _LevelInfo('🏆 마스터', '-', 1.0, Colors.teal, Colors.white);
    }
  }


  double _getRemaining(double distance) {
    if (distance < 0.3) return 0.3 - distance;
    if (distance < 0.5) return 0.5 - distance;
    if (distance < 0.6) return 0.6 - distance;
    if (distance < 0.7) return 0.7 - distance;
    return 0.0;
  }


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
    return Text(
      switch (level) {
        '초급' => '🏃‍♂️ 초급자용 짧고 쉬운 코스를 추천합니다.',
        '중급' => '🔥 중급자를 위한 코스를 추천합니다!',
        '고급' => '💪 고강도 장거리 러닝 코스를 추천합니다!',
        _ => '설문을 먼저 작성해주세요.',
      },
      style: const TextStyle(fontSize: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FutureBuilder<String>(
              future: getUserLevel(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                final level = snapshot.data ?? '';
                return buildRecommendation(level);
              },
            ),
            const SizedBox(height: 30),

            FutureBuilder<double>(
              future: getTotalDistance(),
              builder: (context, snapshot) {
                final distance = snapshot.data ?? 0.0;
                final level = _getLevel(distance);
                final remaining = _getRemaining(distance);

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: level.bgColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(level.label,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: level.textColor)),
                      const SizedBox(height: 8),
                      Text(
                        distance.toStringAsFixed(2),
                        style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: level.textColor),
                      ),
                      Text("총 거리 (킬로미터)", style: TextStyle(fontSize: 16, color: level.textColor)),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: level.progress,
                        minHeight: 8,
                        valueColor: AlwaysStoppedAnimation<Color>(level.textColor),
                        backgroundColor: level.textColor.withOpacity(0.2),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        level.nextLabel != '-'
                            ? "다음 레벨(${level.nextLabel})까지 ${remaining.toStringAsFixed(2)} km 남음"
                            : "최고 레벨 도달 🎉",
                        style: TextStyle(fontSize: 14, color: level.textColor),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NaverMapApp()),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('🏃 달리기 시작'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _LevelInfo {
  final String label;
  final String nextLabel;
  final double progress;
  final Color bgColor;
  final Color textColor;

  _LevelInfo(this.label, this.nextLabel, this.progress, this.bgColor, this.textColor);
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
