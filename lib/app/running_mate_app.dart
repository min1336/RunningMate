import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'auth_gate.dart';

class RunningMateApp extends StatelessWidget {
  const RunningMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '러닝메이트',
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}
