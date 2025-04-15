import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'survey_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nicknameController = TextEditingController();

  String message = '';
  bool isLogin = true;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && user.emailVerified) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final isSurveyDone = userDoc.data()?['surveyDone'] ?? false;

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => isSurveyDone ? const HomeScreen() : const SurveyScreen(),
        ),
      );
    }
  }

  Future<void> _handleAuth() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final nickname = nicknameController.text.trim();

    if (email.isEmpty || password.isEmpty || (!isLogin && nickname.isEmpty)) {
      setState(() => message = '모든 필드를 입력해주세요.');
      return;
    }

    try {
      if (isLogin) {
        final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('email', email);
        await prefs.setString('password', password);

        if (!userCredential.user!.emailVerified) {
          setState(() => message = '이메일 인증을 완료해주세요.');
          return;
        }

        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).get();
        final isSurveyDone = userDoc.data()?['surveyDone'] ?? false;

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => isSurveyDone ? const HomeScreen() : const SurveyScreen(),
          ),
        );
      } else {
        if (await _isNicknameTaken(nickname)) {
          setState(() => message = '이미 사용 중인 닉네임입니다.');
          return;
        }

        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('email', email);
        await prefs.setString('password', password);

        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'email': email,
          'nickname': nickname,
          'surveyDone': false,
          'friends': [],
          'friendRequests': [],
          'sentRequests': [],
          'isAdmin' : false,
          'cash': 0,
        });

        await userCredential.user!.sendEmailVerification();

        setState(() => message = '가입 완료! 이메일 인증 후 로그인해주세요.');
      }
    } on FirebaseAuthException catch (e) {
      setState(() => message = _getErrorMessage(e.code));
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return '등록된 사용자가 없습니다.';
      case 'wrong-password':
        return '비밀번호가 틀렸습니다.';
      case 'email-already-in-use':
        return '이미 가입된 이메일입니다.';
      case 'weak-password':
        return '비밀번호는 6자 이상이어야 합니다.';
      case 'invalid-email':
        return '잘못된 이메일 형식입니다.';
      default:
        return '알 수 없는 오류: $code';
    }
  }

  Future<bool> _isNicknameTaken(String nickname) async {
    final result = await FirebaseFirestore.instance
        .collection('users')
        .where('nickname', isEqualTo: nickname)
        .limit(1)
        .get();
    return result.docs.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isLogin ? '로그인' : '회원가입',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: '이메일'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: '비밀번호'),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                if (!isLogin)
                  TextField(
                    controller: nicknameController,
                    decoration: const InputDecoration(labelText: '닉네임'),
                  ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _handleAuth,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: Text(isLogin ? '로그인' : '회원가입'),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () async {
                        if (emailController.text.trim().isEmpty) {
                          setState(() => message = '이메일을 입력해주세요.');
                          return;
                        }
                        try {
                          await FirebaseAuth.instance.sendPasswordResetEmail(email: emailController.text.trim());
                          setState(() => message = '비밀번호 재설정 메일을 보냈습니다.');
                        } catch (e) {
                          setState(() => message = '메일 전송 실패: ${e.toString()}');
                        }
                      },
                      child: Text('비밀번호 재설정', style: TextStyle(color: Colors.grey[600])),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        isLogin = !isLogin;
                        message = '';
                      }),
                      child: Text(
                        isLogin ? '계정이 없으신가요? 회원가입' : '이미 계정이 있으신가요? 로그인',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
                if (message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
