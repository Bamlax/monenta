import 'package:flutter/material.dart';
import '../models/task_data.dart';
import 'home_page.dart';
import 'calendar_page.dart';
import 'focus_page.dart';
import 'statistics_page.dart';
import 'settings_page.dart'; // 🔴 引入新建的设置页面

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const HomePage(),
      const CalendarPage(),
      const FocusPage(), 
      const StatisticsPage(), 
      const SettingsPage(), // 🔴 将第五个页面替换为真实的设置页
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
              BottomNavigationBarItem(icon: Icon(Icons.local_fire_department), label: ''), 
              BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: ''), 
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: ''), // 设置页图标
            ],
          ),
        );
      }
    );
  }
}