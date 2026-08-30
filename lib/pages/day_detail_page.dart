import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/task_data.dart';
import '../widgets/task_sheet.dart';

class DayDetailPage extends StatefulWidget {
  final DateTime date;
  const DayDetailPage({super.key, required this.date});

  @override
  State<DayDetailPage> createState() => _DayDetailPageState();
}

class _DayDetailPageState extends State<DayDetailPage> {
  late DateTime _currentDate;
  // 🔴 使用 PageController 实现无限滑动
  final PageController _pageController = PageController(initialPage: 500);

  @override
  void initState() {
    super.initState();
    _currentDate = widget.date;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<bool?> _askRepeatAction(BuildContext context, String actionName) async {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(actionName, style: const TextStyle(color: Colors.lightBlue)),
        content: const Text('这是一个重复事件，您希望将操作应用到哪些事件？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('仅当前事件', style: TextStyle(color: Colors.black87))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('所有后续事件', style: TextStyle(color: Colors.lightBlue))),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Colors.white;
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        // 🔴 标题随滑动实时变化
        title: Text('${_currentDate.month}月${_currentDate.day}日 待办', style: const TextStyle(color: Colors.lightBlue)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.lightBlue),
      ),
      // 🔴 核心改造：使用 PageView 包裹内容，实现左右滑动切换日期
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          int offset = index - 500;
          setState(() {
            // 利用 DateTime 自动处理跨月、跨年的进位逻辑
            _currentDate = DateTime(widget.date.year, widget.date.month, widget.date.day + offset);
          });
        },
        itemBuilder: (context, pageIndex) {
          int offset = pageIndex - 500;
          DateTime currentDate = DateTime(widget.date.year, widget.date.month, widget.date.day + offset);

          return ListenableBuilder(
            listenable: taskData,
            builder: (context, child) {
              final tasks = taskData.getTasksByDate(currentDate);
              if (tasks.isEmpty) {
                return const Center(child: Text('这天没有安排待办~', style: TextStyle(color: Colors.grey)));
              }
              return ReorderableListView.builder(
                padding: EdgeInsets.zero,
                itemCount: tasks.length,
                onReorder: (oldIndex, newIndex) => taskData.reorderDailyTasks(currentDate, oldIndex, newIndex),
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  final listColor = taskData.getListColor(task.listName ?? '');
                  return Slidable(
                    key: ValueKey('slidable_cal_${task.id}'),
                    endActionPane: ActionPane(
                      motion: const ScrollMotion(),
                      extentRatio: 0.6,
                      children: [
                        SlidableAction(
                          onPressed: (context) async {
                            bool doAll = false;
                            if (task.repeatGroupId != null) {
                              final result = await _askRepeatAction(context, '置顶');
                              if (result == null) return;
                              doAll = result;
                            }
                            taskData.pinTaskGlobally(task, true, pinAllFuture: doAll);
                          },
                          backgroundColor: Colors.blue.shade400,
                          foregroundColor: Colors.white,
                          icon: Icons.vertical_align_top,
                          label: '置顶',
                        ),
                        SlidableAction(
                          onPressed: (context) async {
                            bool doAll = false;
                            if (task.repeatGroupId != null) {
                              final result = await _askRepeatAction(context, '置底');
                              if (result == null) return;
                              doAll = result;
                            }
                            taskData.pinTaskGlobally(task, false, pinAllFuture: doAll);
                          },
                          backgroundColor: Colors.grey.shade600,
                          foregroundColor: Colors.white,
                          icon: Icons.vertical_align_bottom,
                          label: '置底',
                        ),
                        SlidableAction(
                          onPressed: (context) async {
                            bool doAll = false;
                            if (task.repeatGroupId != null) {
                              final result = await _askRepeatAction(context, '删除');
                              if (result == null) return;
                              doAll = result;
                            }
                            taskData.deleteTask(task.id, deleteAllFuture: doAll);
                          },
                          backgroundColor: Colors.red.shade400,
                          foregroundColor: Colors.white,
                          icon: Icons.delete,
                          label: '删除',
                        ),
                      ],
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: bgColor,
                        border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
                      ),
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
                        onTap: () => showTaskBottomSheet(context, existingTask: task, defaultDate: currentDate),
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
                            if (!task.isEvent && task.repeatGroupId != null)
                              const Icon(Icons.repeat, size: 14, color: Colors.lightBlue),
                            ...task.tags.map((tag) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(color: Colors.lightBlue.shade50, borderRadius: BorderRadius.circular(4)),
                              child: Text(tag, style: const TextStyle(fontSize: 10, color: Colors.lightBlue)),
                            ))
                          ],
                        ),
                        subtitle: (task.description.isNotEmpty || task.time != null || task.repeatRuleText != null) ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (task.description.isNotEmpty) Text(task.description, style: const TextStyle(fontSize: 13)),
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 4),
                              child: Row(
                                children: [
                                  if (task.time != null) ...[
                                    const Icon(Icons.access_time, size: 12, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(task.time!.format(context), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                  if (task.repeatRuleText != null) ...[
                                    if (task.time != null) const SizedBox(width: 8),
                                    Text(task.repeatRuleText!, style: const TextStyle(fontSize: 12, color: Colors.lightBlue)),
                                  ],
                                  if (task.addToCalendar) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.event_available, size: 12, color: Colors.green),
                                  ]
                                ],
                              ),
                            ),
                          ],
                        ) : null,
                        trailing: task.isEvent
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.alarm, color: Colors.lightBlue),
                              onPressed: () {
                                taskData.setFocusTask(task);
                                appTabIndex.value = 2;
                                Navigator.popUntil(context, (route) => route.isFirst);
                              },
                            ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      // 🔴 新增：右下角添加待办悬浮按钮
      floatingActionButton: FloatingActionButton(
        elevation: 2,
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
        onPressed: () => showTaskBottomSheet(context, defaultDate: _currentDate),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}

