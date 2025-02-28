import 'dart:io';  // File 클래스 사용을 위해 추가
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';  // SharedPreferences 사용을 위해 추가
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'naver.dart';
import 'profile.dart';
import 'package:run1220/Calendar.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  await _initialize();
  await initializeDateFormatting('ko_KR', null);
  runApp(MyApp());
}

Future<void> _initialize() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NaverMapSdk.instance.initialize(clientId: 'rz7lsxe3oo');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '러닝메이트',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 2;
  final List<Widget> _screens = [
    EventScreen(),
    CrewScreen(),
    MainScreen(),
    BattleScreen(),
    CalendarScreen(),
  ];

  String _profileName = '사용자 프로필';
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  /// `SharedPreferences`에서 프로필 데이터 불러오기
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

  /// 프로필 페이지로 이동 후 데이터 변경 반영
  Future<void> _navigateToProfileScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfileScreen()),
    );

    if (result != null && result is bool && result) {
      _loadProfileData(); // 변경된 데이터 다시 불러오기
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer( // ✅ 서랍 메뉴 추가
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
              title: Text('친구'), // ✅ 친구 메뉴 추가
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FriendScreen()), // ✅ 친구 화면으로 이동
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
        leading: Builder( // ✅ 왼쪽 햄버거 메뉴 버튼 추가
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
            icon: Icon(Icons.smart_toy),
            label: '이벤트',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flag),
            label: '크루',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_run),
            label: '달리기',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: '대결',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center, // ✅ 버튼을 화면 중앙 아래로 이동
        children: [

          // 🎯 귀여운 캐릭터 이미지 추가
          Center(
            child: Image.asset(
              'assets/images/character.png', // 🔥 캐릭터 이미지 추가
              width: 300, // 이미지 크기 조정
              height: 300,
              fit: BoxFit.contain,
            ),
          ),

          SizedBox(height: 30), // ✅ 이미지와 버튼 사이 여백 추가

          // 🏃 달리기 버튼
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => NaverMapApp()),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16), // 버튼 크기 조정
                textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              child: Text('🏃 달리기 시작'),
            ),
          ),

          SizedBox(height: 10), // ✅ 버튼 아래 여백 추가
        ],
      ),
    );
  }
}

class EventScreen extends StatelessWidget {
  const EventScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('이벤트 페이지')),
    );
  }
}

class CrewScreen extends StatelessWidget {
  const CrewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('크루 페이지')),
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






class FriendScreen extends StatelessWidget {
  const FriendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('친구')),
      body: Center(child: Text('친구 목록이 여기에 표시됩니다. 😊')),
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