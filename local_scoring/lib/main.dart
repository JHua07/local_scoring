import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 强制注册帧回调，修复部分模拟器首帧黑屏
  SchedulerBinding.instance.ensureFrameCallbacksRegistered();
  runApp(const ProviderScope(child: PrivateReviewApp()));
}
