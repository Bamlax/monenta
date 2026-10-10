import 'package:flutter/material.dart';
import '../models/task_data.dart';
import 'home_page.dart';
import 'calendar_page.dart';
import 'focus_page.dart';
import 'chain_page.dart'; // 引入新建的链页面
import 'statistics_page.dart';
import 'settings_page.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const HomePage(),
      const CalendarPage(),
      const FocusPage(), 
      const ChainPage(), // 插入在专注与统计之间 (索引 3)
      const StatisticsPage(), 
      const SettingsPage(),
    ];

    return ValueListenableBuilder<int>(
      valueListenable: appTabIndex,
      builder: (context, index, child) {
        return Scaffold(
          body: pages[index],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: index,
            onTap: (i) => appTabIndex.value = i, 
            showSelectedLabels: false,   
            showUnselectedLabels: false, 
            iconSize: 24,                
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
              BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: ''),
              BottomNavigationBarItem(icon: Icon(Icons.timer_outlined), label: ''), 
              BottomNavigationBarItem(icon: Icon(Icons.link), label: ''), // 链图标
              BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: ''), 
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: ''),
            ],
          ),
        );
      }
    );
  }
}