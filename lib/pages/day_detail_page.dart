import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/task_data.dart';
import '../services/focus_timer_service.dart';
import '../widgets/task_sheet.dart';

class DayDetailPage extends StatefulWidget {
  final DateTime date;

  const DayDetailPage({
    super.key,
    required this.date,
  });

  @override
  State<DayDetailPage> createState() => _DayDetailPageState();
}

class _DayDetailPageState extends State<DayDetailPage> {
  static const _weekStrings = ['一', '二', '三', '四', '五', '六', '日'];

  String _formatFocusDuration(int totalSeconds) {
    if (totalSeconds < 60) return '${totalSeconds}秒';
    final minutes = totalSeconds ~/ 60;
    if (minutes < 60) return '$minutes分钟';
    final hours = minutes ~/ 60;
    final remainM = minutes % 60;
    return remainM > 0 ? '${hours}小时${remainM}分' : '$hours小时';
  }

  Future<bool?> _askRepeatAction(BuildContext context, String actionName) {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(actionName, style: const TextStyle(color: Colors.lightBlue)),
        content: const Text('这是一个重复事件，您希望将操作应用到哪些事件？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('仅当前事件', style: TextStyle(color: Colors.black87)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('所有后续事件', style: TextStyle(color: Colors.lightBlue)),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTile(Task task) {
    final listColor = taskData.getListColor(task.listName ?? '');
    final timeText = task.time != null ? task.time!.format(context) : null;

    if (task.isReadOnly) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          minLeadingWidth: 24,
          leading: const SizedBox(width: 24, height: 24),
          title: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Text(
                task.title,
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.normal),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('节假日', style: TextStyle(fontSize: 10, color: Colors.orange.shade700)),
              ),
            ],
          ),
        ),
      );
    }

    return Slidable(
      key: ValueKey('detail_slidable_${task.id}'),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.6,
        children: [
          SlidableAction(
            onPressed: (context) async {
              var doAll = false;
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
              var doAll = false;
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
              var doAll = false;
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
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          minLeadingWidth: 24,
          leading: task.isEvent
              ? const SizedBox(width: 24, height: 24)
              : SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: task.isDone,
                    activeColor: listColor,
                    side: BorderSide(color: listColor, width: 2),
                    onChanged: (_) => taskData.toggleTaskDone(task.id),
                  ),
                ),
          onTap: () => showTaskBottomSheet(context, existingTask: task, defaultDate: widget.date),
          title: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Text(
                task.title,
                style: TextStyle(
                  decoration: (!task.isEvent && task.isDone) ? TextDecoration.lineThrough : null,
                  color: task.isEvent ? Colors.black87 : (task.isDone ? Colors.grey : Colors.black87),
                ),
              ),
              if (task.focusDurationSeconds > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green.shade200, width: 0.6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined, size: 10, color: Colors.green.shade700),
                      const SizedBox(width: 2),
                      Text(
                        _formatFocusDuration(task.focusDurationSeconds),
                        style: TextStyle(fontSize: 9, color: Colors.green.shade700, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              if (!task.isEvent && task.overdueCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.shade200, width: 0.6),
                  ),
                  child: Text(
                    '逾期 ${task.overdueCount} 次',
                    style: TextStyle(fontSize: 9, color: Colors.red.shade700, fontWeight: FontWeight.bold),
                  ),
                ),
              if (task.repeatGroupId != null)
                const Icon(Icons.repeat, size: 14, color: Colors.lightBlue),
              ...task.tags.map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: Colors.lightBlue.shade50, borderRadius: BorderRadius.circular(4)),
                child: Text(tag, style: const TextStyle(fontSize: 10, color: Colors.lightBlue)),
              )),
            ],
          ),
          subtitle: (task.description.isNotEmpty || timeText != null || task.repeatRuleText != null)
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (task.description.isNotEmpty)
                      Text(task.description, style: const TextStyle(fontSize: 13)),
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: Row(
                        children: [
                          if (timeText != null) ...[
                            const Icon(Icons.access_time, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(timeText, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                          if (task.repeatRuleText != null) ...[
                            if (timeText != null) const SizedBox(width: 8),
                            Text(task.repeatRuleText!, style: const TextStyle(fontSize: 12, color: Colors.lightBlue)),
                          ],
                          if (task.addToCalendar) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.event_available, size: 12, color: Colors.green),
                          ],
                        ],
                      ),
                    ),
                  ],
                )
              : null,
          trailing: task.isEvent
              ? null
              : IconButton(
                  icon: const Icon(Icons.alarm, color: Colors.lightBlue),
                  onPressed: () {
                    taskData.setFocusTask(task);
                    FocusTimerService.instance.setTask(
                      taskId: task.id,
                      title: task.title,
                    );
                    appTabIndex.value = 2;
                    Navigator.pop(context); // 回到主界面进入专注页
                  },
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weekdayStr = _weekStrings[widget.date.weekday - 1];
    final titleText = '${widget.date.month}月${widget.date.day}日 星期$weekdayStr';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.lightBlue, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          titleText,
          style: const TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: ListenableBuilder(
        listenable: taskData,
        builder: (context, _) {
          final dailyTasks = taskData.getTasksByDate(widget.date);

          if (dailyTasks.isEmpty) {
            return const Center(
              child: Text('这天没有安排待办', style: TextStyle(color: Colors.grey)),
            );
          }

          // 未开启分栏时直接展示单日列表
          if (!taskData.enableTimeBuckets) {
            return ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: dailyTasks.length,
              onReorder: (oldIndex, newIndex) => taskData.reorderDailyTasks(widget.date, oldIndex, newIndex),
              itemBuilder: (context, index) {
                final task = dailyTasks[index];
                return Material(
                  key: ValueKey('day_detail_mat_${task.id}'),
                  color: Colors.transparent,
                  child: _buildTaskTile(task),
                );
              },
            );
          }

          // 开启每日分栏后按各分栏组织数据流
          final List<dynamic> bucketFlatItems = [];
          final Map<String, List<Task>> bucketTaskMap = {};

          for (final b in taskData.timeBuckets) {
            bucketTaskMap[b] = [];
          }
          final List<Task> unbucketedTasks = [];

          for (final t in dailyTasks) {
            if (t.timeBucket != null && bucketTaskMap.containsKey(t.timeBucket)) {
              bucketTaskMap[t.timeBucket]!.add(t);
            } else {
              unbucketedTasks.add(t);
            }
          }

          for (final b in taskData.timeBuckets) {
            bucketFlatItems.add(b);
            bucketFlatItems.addAll(bucketTaskMap[b]!);
          }

          bucketFlatItems.add('未分栏');
          bucketFlatItems.addAll(unbucketedTasks);

          return ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            buildDefaultDragHandles: false,
            itemCount: bucketFlatItems.length,
            onReorder: (oldIndex, newIndex) {
              final item = bucketFlatItems[oldIndex];
              if (item is String) return;

              final movedTask = item as Task;
              if (movedTask.isReadOnly) return;

              final listCopy = List<dynamic>.from(bucketFlatItems);
              listCopy.removeAt(oldIndex);

              int insertIndex = newIndex;
              if (oldIndex < newIndex) {
                insertIndex--;
              }
              if (insertIndex < 0) insertIndex = 0;
              if (insertIndex > listCopy.length) insertIndex = listCopy.length;

              String? targetBucket;

              // 拖到最顶部吸附至首个分栏
              if (insertIndex == 0) {
                final firstHeader = listCopy.firstWhere((e) => e is String, orElse: () => null);
                if (firstHeader != null && firstHeader != '未分栏') {
                  targetBucket = firstHeader as String;
                }
              } else {
                for (int i = insertIndex - 1; i >= 0; i--) {
                  if (listCopy[i] is String) {
                    final title = listCopy[i] as String;
                    targetBucket = title == '未分栏' ? null : title;
                    break;
                  }
                }
              }

              Task? anchorTask;
              bool insertAfter = false;

              if (insertIndex < listCopy.length && listCopy[insertIndex] is Task) {
                anchorTask = listCopy[insertIndex] as Task;
                insertAfter = false;
              } else if (insertIndex - 1 >= 0 && listCopy[insertIndex - 1] is Task) {
                anchorTask = listCopy[insertIndex - 1] as Task;
                insertAfter = true;
              }

              taskData.reorderBucketTasks(widget.date, movedTask, targetBucket, anchorTask, insertAfter);
            },
            itemBuilder: (context, index) {
              final item = bucketFlatItems[index];

              // 极简分栏标题栏
              if (item is String) {
                final isFirst = index == 0;
                final isUnbucketed = item == '未分栏';

                return Container(
                  key: ValueKey('day_bucket_header_$item'),
                  color: Colors.white,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isFirst)
                        Container(
                          height: 0.5,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          color: Colors.black.withOpacity(0.06),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 12, 6),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isUnbucketed ? const Color(0xFFF3F4F6) : const Color(0xFFECEFF1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF374151),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (!isUnbucketed)
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => showTaskBottomSheet(
                                  context,
                                  defaultDate: widget.date,
                                  defaultTimeBucket: item,
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.add,
                                    size: 18,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              final task = item as Task;
              return ReorderableDelayedDragStartListener(
                key: ValueKey('day_detail_task_${task.id}'),
                index: index,
                child: Material(
                  color: Colors.transparent,
                  child: _buildTaskTile(task),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        elevation: 2,
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
        onPressed: () => showTaskBottomSheet(
          context,
          defaultDate: widget.date,
        ),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}