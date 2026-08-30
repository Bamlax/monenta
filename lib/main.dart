import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'models/task_data.dart';
import 'pages/main_page.dart';
import 'services/focus_timer_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterForegroundTask.initCommunicationPort();

  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'monenta_focus',
      channelName: 'Monenta 专注计时',
      channelDescription: '显示 Monenta 当前专注计时状态。',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
      playSound: false,
      enableVibration: false,
      showWhen: false,
      showBadge: false,
      onlyAlertOnce: true,
      visibility: NotificationVisibility.VISIBILITY_PUBLIC,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(1000),
      autoRunOnBoot: false,
      autoRunOnMyPackageReplaced: false,
      allowWakeLock: true,
      allowWifiLock: false,
    ),
  );

  final permission =
      await FlutterForegroundTask.checkNotificationPermission();

  if (permission != NotificationPermission.granted) {
    await FlutterForegroundTask.requestNotificationPermission();
  }

  await taskData.loadData();
  await FocusTimerService.instance.initialize();

  runApp(const MonentaApp());
}

class MonentaApp extends StatelessWidget {
  const MonentaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Monenta',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      locale: const Locale('zh', 'CN'),
      theme: ThemeData(
        useMaterial3: false,
        primarySwatch: Colors.lightBlue,
        scaffoldBackgroundColor: const Color(0xFFE6F1FB),
        floatingActionButtonTheme:
            const FloatingActionButtonThemeData(
          backgroundColor: Colors.lightBlue,
        ),
        bottomNavigationBarTheme:
            const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.lightBlue,
          unselectedItemColor: Colors.grey,
        ),
      ),
      home: const MainPage(),
    );
  }
}