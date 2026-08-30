import 'package:flutter/material.dart';
import '../data/version_data.dart';

class VersionHistoryPage extends StatelessWidget {
  const VersionHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.lightBlue),
        title: const Text('版本记录', style: TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: versionHistory.length,
        separatorBuilder: (context, index) => const Divider(height: 40, color: Colors.black12),
        itemBuilder: (context, index) {
          final record = versionHistory[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 版本号与日期
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(record.version, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.lightBlue)),
                  Text(record.date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),
              // 更新细节列表
              ...record.updates.map((updateText) => Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Colors.lightBlue, fontSize: 16, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(updateText, style: const TextStyle(color: Colors.black87, height: 1.5, fontSize: 14)),
                    ),
                  ],
                ),
              )),
            ],
          );
        },
      ),
    );
  }
}