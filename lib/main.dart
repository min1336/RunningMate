import 'package:flutter/material.dart';

import 'app/app_bootstrap.dart';
import 'app/running_mate_app.dart';

void main() async {
  await AppBootstrap.initialize();
  runApp(const RunningMateApp());
}
