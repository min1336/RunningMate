import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'login_screen.dart';
import 'home_screen.dart'; // 🔥 새로 만든 홈 스크린 파일 import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initialize();
  await Firebase.initializeApp();
  await initializeDateFormatting('ko_KR', null);
  runApp(const MyApp());
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
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData && snapshot.data!.emailVerified) {
          return const HomeScreen(); // ✅ 로그인한 경우 진입
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}