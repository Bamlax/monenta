import 'package:flutter/material.dart';
import '../models/task_data.dart';
import 'version_history_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('设置', style: TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
      ),
      body: ListenableBuilder(
        listenable: taskData,
        builder: (context, child) {
          return ListView(
            children: [
              const SizedBox(height: 10),
              SwitchListTile(
                secondary: const Icon(Icons.celebration, color: Colors.orange),
                title: const Text('法定节假日', style: TextStyle(fontSize: 15)),
                subtitle: const Text('在对应日期显示法定节假日', style: TextStyle(fontSize: 12, color: Colors.grey)),
                value: taskData.enableHolidays,
                activeColor: Colors.lightBlue,
                onChanged: (val) {
                  taskData.toggleHolidays(val);
                },
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.lightBlue),
                title: const Text('版本记录', style: TextStyle(fontSize: 15)),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const VersionHistoryPage()));
                },
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.help_outline, color: Colors.grey),
                title: const Text('关于 Monenta', style: TextStyle(fontSize: 15, color: Colors.grey)),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                onTap: () {
                  // TODO: 关于页面
                },
              ),
            ],
          );
        },
      ),
    );
  }
}