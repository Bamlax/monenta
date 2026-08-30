import 'package:flutter/material.dart';
import 'version_history_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('设置', style: TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.lightBlue),
            title: const Text('版本记录', style: TextStyle(fontSize: 15)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const VersionHistoryPage()));
            },
          ),
          const Divider(height: 1, indent: 56),
          // 以后想加什么关于我们、反馈意见、主题颜色都在这里接着写就行
          ListTile(
            leading: const Icon(Icons.help_outline, color: Colors.grey),
            title: const Text('关于 Monenta', style: TextStyle(fontSize: 15, color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            onTap: () {
              // TODO: 关于页面
            },
          ),
        ],
      ),
    );
  }
}