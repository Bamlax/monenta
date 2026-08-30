import 'package:flutter/material.dart';
import '../models/task_data.dart';
import '../widgets/task_sheet.dart';
import 'focus_page.dart';

class FilteredTasksPage extends StatelessWidget {
  final String title;
  final String? listName;
  final String? tagName;

  const FilteredTasksPage({super.key, required this.title, this.listName, this.tagName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.lightBlue),
      ),
      body: ListenableBuilder(
        listenable: taskData,
        builder: (context, child) {
          // 1. 获取符合条件的所有待办
          final tasks = taskData.allTasks.where((t) {
            if (listName != null && t.listName != listName) return false;
            if (tagName != null && !t.tags.contains(tagName)) return false;
            return true;
          }).toList();

          if (tasks.isEmpty) {
            return const Center(child: Text('这里空空如也~', style: TextStyle(color: Colors.grey)));
          }

          // 2. 按时间逻辑分组
          List<Task> pastDone = [];
          List<Task> pastUndone = [];
          List<Task> todayT = [];
          List<Task> tomorrowT = [];
          List<Task> dayAfterT = [];
          List<Task> laterT = [];
          List<Task> noDateT = [];

          DateTime now = DateTime.now();
          DateTime today = DateTime(now.year, now.month, now.day);
          DateTime tomorrow = today.add(const Duration(days: 1));
          DateTime dayAfter = today.add(const Duration(days: 2));

          for (var t in tasks) {
            if (t.date == null) {
              noDateT.add(t);
            } else {
              DateTime d = DateTime(t.date!.year, t.date!.month, t.date!.day);
              if (d.isBefore(today)) {
                if (t.isDone) pastDone.add(t);
                else pastUndone.add(t);
              } else if (d.isAtSameMomentAs(today)) {
                todayT.add(t);
              } else if (d.isAtSameMomentAs(tomorrow)) {
                tomorrowT.add(t);
              } else if (d.isAtSameMomentAs(dayAfter)) {
                dayAfterT.add(t);
              } else {
                laterT.add(t);
              }
            }
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 80), // 留出底部按钮空间
            children: [
              _buildSection(context, '过去完成', pastDone, initiallyExpanded: false),
              _buildSection(context, '过去未完成', pastUndone, initiallyExpanded: true),
              _buildSection(context, '今天', todayT, initiallyExpanded: true),
              _buildSection(context, '明天', tomorrowT, initiallyExpanded: true),
              _buildSection(context, '后天', dayAfterT, initiallyExpanded: true),
              _buildSection(context, '后续', laterT, initiallyExpanded: true),
              _buildSection(context, '无日期 (待办箱)', noDateT, initiallyExpanded: true),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        elevation: 2,
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
        // 🔴 点击新建时，自动带入当前的清单或标签
        onPressed: () => showTaskBottomSheet(
          context, 
          defaultList: listName,
          defaultTags: tagName != null ? [tagName!] : null,
        ),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  // 渲染可展开/折叠的区块
  Widget _buildSection(BuildContext context, String title, List<Task> list, {required bool initiallyExpanded}) {
    if (list.isEmpty) return const SizedBox();

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent), // 去除展开时的边框线
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        iconColor: Colors.lightBlue,
        collapsedIconColor: Colors.grey,
        title: Text('$title (${list.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        children: list.map((task) {
          final listColor = taskData.getListColor(task.listName ?? '');
          return Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              minLeadingWidth: 24,
              leading: SizedBox(
                width: 24, height: 24,
                child: Checkbox(
                  value: task.isDone, 
                  activeColor: listColor, 
                  side: BorderSide(color: listColor, width: 2), 
                  onChanged: (val) => taskData.toggleTaskDone(task.id)
                ),
              ),
              onTap: () => showTaskBottomSheet(context, existingTask: task),
              title: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Text(
                    task.title, 
                    style: TextStyle(
                      decoration: (!task.isEvent && task.isDone) ? TextDecoration.lineThrough : null, 
                      color: (!task.isEvent && task.isDone) ? Colors.grey : Colors.black87,
                    ),
                  ),
                  ...task.tags.map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: Colors.lightBlue.shade50, borderRadius: BorderRadius.circular(4)),
                    child: Text(tag, style: const TextStyle(fontSize: 10, color: Colors.lightBlue)),
                  ))
                ],
              ),
              subtitle: task.description.isNotEmpty ? Text(task.description) : null,
              trailing: IconButton(
                icon: const Icon(Icons.alarm, color: Colors.lightBlue),
                onPressed: () {
                  taskData.setFocusTask(task);
                  appTabIndex.value = 2; // 跳去专注页
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

