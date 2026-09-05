import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/task_data.dart';
import '../widgets/task_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime _selectedDate = DateTime.now();
  final PageController _pageController = PageController(initialPage: 500);
  late DateTime _baseMonday;

  final Map<String, bool> _groupExpanded = {
    '过去完成': false,
    '过去未完成': true,
    '过去事件': true,
    '今天': true,
    '明天': true,
    '后天': true,
    '后续': true,
    '无日期 (待办箱)': true,
  };

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _baseMonday = now.subtract(Duration(days: now.weekday - 1));
  }

  Future<void> confirmSkipOverdueDialog(
    BuildContext ctx,
    VoidCallback onConfirm,
  ) async {
    await showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text(
          '提示',
          style: TextStyle(
            color: Colors.lightBlue,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text('长按更改日期不会统计逾期'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(c);
            },
            child: const Text('确定', style: TextStyle(color: Colors.lightBlue)),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedDateBtn(
    String label,
    VoidCallback onTap, {
    VoidCallback? onLongPress,
  }) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.lightBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildInboxTaskCard(Task task, BuildContext context) {
    final listColor = taskData.getListColor(task.listName ?? '');

    return Slidable(
      key: ValueKey('inbox_slidable_${task.id}'),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.2,
        children: [
          SlidableAction(
            onPressed: (context) => taskData.deleteTask(task.id),
            backgroundColor: Colors.red.shade400,
            foregroundColor: Colors.white,
            icon: Icons.delete,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade100, width: 1),
          ),
        ),
        child: InkWell(
          onTap: () => showTaskBottomSheet(context, existingTask: task),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    if (!task.isEvent)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: task.isDone,
                          activeColor: listColor,
                          side: BorderSide(color: listColor, width: 2),
                          onChanged: (_) => taskData.toggleTaskDone(task.id),
                        ),
                      ),
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: (!task.isEvent && task.isDone)
                            ? Colors.grey
                            : Colors.black87,
                        decoration: (!task.isEvent && task.isDone)
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    ...task.tags.map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.lightBlue.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#$tag',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.lightBlue,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    task.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.lightBlue.shade100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSegmentedDateBtn(
                            '今天',
                            () => taskData.updateTaskDate(
                              task.id,
                              DateTime.now(),
                            ),
                            onLongPress: () => confirmSkipOverdueDialog(
                              context,
                              () => taskData.updateTaskDate(
                                task.id,
                                DateTime.now(),
                                skipOverdueCount: true,
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 10,
                            color: Colors.lightBlue.shade100,
                          ),
                          _buildSegmentedDateBtn(
                            '明天',
                            () => taskData.updateTaskDate(
                              task.id,
                              DateTime.now().add(const Duration(days: 1)),
                            ),
                            onLongPress: () => confirmSkipOverdueDialog(
                              context,
                              () => taskData.updateTaskDate(
                                task.id,
                                DateTime.now().add(const Duration(days: 1)),
                                skipOverdueCount: true,
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 10,
                            color: Colors.lightBlue.shade100,
                          ),
                          _buildSegmentedDateBtn(
                            '📅',
                            () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2050),
                              );
                              if (!context.mounted) return;
                              if (picked != null)
                                taskData.updateTaskDate(task.id, picked);
                            },
                            onLongPress: () {
                              confirmSkipOverdueDialog(context, () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2050),
                                );
                                if (picked != null)
                                  taskData.updateTaskDate(
                                    task.id,
                                    picked,
                                    skipOverdueCount: true,
                                  );
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: task.listName,
                          hint: const Text(
                            '分类...',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            size: 12,
                            color: Colors.grey,
                          ),
                          style: TextStyle(
                            fontSize: 10,
                            color: listColor,
                            fontWeight: FontWeight.bold,
                          ),
                          isDense: true,
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text(
                                '无清单',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                            ...taskData.myLists.map(
                              (list) => DropdownMenuItem<String>(
                                value: list.name,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 6,
                                      color: list.color,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      list.name,
                                      style: TextStyle(color: list.color),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          onChanged: (newList) =>
                              taskData.updateTaskList(task.id, newList),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showInboxMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '待办箱',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.lightBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListenableBuilder(
                  listenable: taskData,
                  builder: (context, child) {
                    final tasks = taskData.inboxTasks;
                    if (tasks.isEmpty) {
                      return const Center(
                        child: Text(
                          '待办箱已清空~\n随时记录你的闪念，然后在这里分配',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, height: 1.6),
                        ),
                      );
                    }

                    return ReorderableListView.builder(
                      scrollController: scrollController,
                      itemCount: tasks.length,
                      onReorder: (oldIndex, newIndex) =>
                          taskData.reorderInboxTasks(oldIndex, newIndex),
                      itemBuilder: (context, index) =>
                          _buildInboxTaskCard(tasks[index], context),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: taskData,
      builder: (context, child) {
        var appBarTitle = 'Monenta';
        Color appBarColor = Colors.lightBlue;

        if (taskData.currentHomeMode == 'recent') {
          appBarTitle = '最近代办';
        } else if (taskData.currentHomeMode == 'list') {
          appBarTitle = taskData.currentHomeParam ?? '';
          appBarColor = taskData.getListColor(appBarTitle);
        } else if (taskData.currentHomeMode == 'tag') {
          appBarTitle = '#${taskData.currentHomeParam ?? ''}';
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: const Color(0xFFE6F1FB),
            iconTheme: const IconThemeData(color: Colors.lightBlue),
            centerTitle: taskData.currentHomeMode != 'todo',
            title: Text(
              appBarTitle,
              style: TextStyle(color: appBarColor, fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: Badge(
                  isLabelVisible: taskData.inboxTasks.isNotEmpty,
                  backgroundColor: Colors.lightBlue,
                  label: Text(
                    '${taskData.inboxTasks.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                  child: const Icon(Icons.inbox),
                ),
                onPressed: _showInboxMenu,
              ),
            ],
          ),
          body: taskData.currentHomeMode == 'todo'
              ? _buildTodoBody()
              : _buildGroupedBody(),
          floatingActionButton: FloatingActionButton(
            elevation: 2,
            backgroundColor: Colors.lightBlue,
            foregroundColor: Colors.white,
            onPressed: () => showTaskBottomSheet(
              context,
              defaultDate: taskData.currentHomeMode == 'todo'
                  ? _selectedDate
                  : DateTime.now(),
              defaultList: taskData.currentHomeMode == 'list'
                  ? taskData.currentHomeParam
                  : null,
              defaultTags: taskData.currentHomeMode == 'tag'
                  ? [taskData.currentHomeParam!]
                  : null,
            ),
            child: const Icon(Icons.add, size: 28),
          ),
        );
      },
    );
  }

  Widget _buildTodoBody() {
    final weekStrings = ['一', '二', '三', '四', '五', '六', '日'];

    return Column(
      children: [
        Container(
          color: const Color(0xFFE6F1FB),
          padding: const EdgeInsets.only(bottom: 16),
          child: SizedBox(
            height: 70,
            child: PageView.builder(
              controller: _pageController,
              itemBuilder: (context, pageIndex) {
                final offset = pageIndex - 500;
                final monday = _baseMonday.add(Duration(days: offset * 7));
                final weekDays = List.generate(
                  7,
                  (i) => monday.add(Duration(days: i)),
                );

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: weekDays.map((date) {
                    final isSelected =
                        date.year == _selectedDate.year &&
                        date.month == _selectedDate.month &&
                        date.day == _selectedDate.day;
                    final dayTasks = taskData.getTasksByDate(date);
                    final taskCount = dayTasks.length;
                    final hasUnfinishedTodo = dayTasks.any(
                      (t) => !t.isEvent && !t.isDone,
                    );

                    return GestureDetector(
                      onTap: () => setState(() => _selectedDate = date),
                      child: SizedBox(
                        width: 45,
                        height: 62,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.lightBlue : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.lightBlue.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                weekStrings[date.weekday - 1],
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${date.day}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 13,
                                child: taskCount > 0
                                    ? Center(
                                        child: Text(
                                          '$taskCount',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: isSelected
                                                ? (hasUnfinishedTodo
                                                      ? Colors.red.shade100
                                                      : Colors.white)
                                                : (hasUnfinishedTodo
                                                      ? Colors.red
                                                      : Colors.grey),
                                            fontWeight: FontWeight.bold,
                                            height: 1,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              final dailyTasks = taskData.getTasksByDate(_selectedDate);

              if (dailyTasks.isEmpty) {
                return const Center(
                  child: Text('这天没有安排待办', style: TextStyle(color: Colors.grey)),
                );
              }

              return ReorderableListView.builder(
                padding: EdgeInsets.zero,
                itemCount: dailyTasks.length,
                onReorder: (oldIndex, newIndex) => taskData.reorderDailyTasks(
                  _selectedDate,
                  oldIndex,
                  newIndex,
                ),
                itemBuilder: (context, index) {
                  final task = dailyTasks[index];
                  return Material(
                    key: ValueKey('todo_mat_${task.id}'),
                    color: Colors.transparent,
                    child: _buildTaskTile(task, _selectedDate),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGroupedBody() {
    final tasks = taskData.allTasks.where((t) {
      if (taskData.currentHomeMode == 'list' &&
          t.listName != taskData.currentHomeParam)
        return false;
      if (taskData.currentHomeMode == 'tag' &&
          !t.tags.contains(taskData.currentHomeParam))
        return false;
      return true;
    }).toList();

    if (tasks.isEmpty) {
      return const Center(
        child: Text('这里空空如也~', style: TextStyle(color: Colors.grey)),
      );
    }

    final pastDone = <Task>[];
    final pastUndone = <Task>[];
    final pastEvents = <Task>[];
    final todayT = <Task>[];
    final tomorrowT = <Task>[];
    final dayAfterT = <Task>[];
    final laterT = <Task>[];
    final noDateT = <Task>[];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dayAfter = today.add(const Duration(days: 2));

    for (final t in tasks) {
      if (t.date == null) {
        noDateT.add(t);
        continue;
      }

      final d = DateTime(t.date!.year, t.date!.month, t.date!.day);

      if (d.isBefore(today)) {
        if (t.isEvent) {
          // 过滤掉过去的法定节假日
          if (!t.isReadOnly && !t.id.startsWith('holiday_')) {
            pastEvents.add(t);
          }
        } else if (t.isDone) {
          pastDone.add(t);
        } else {
          pastUndone.add(t);
        }
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

    final flatItems = <dynamic>[];

    void addGroup(String title, List<Task> list) {
      if (list.isEmpty) return;
      flatItems.add(title);
      if (_groupExpanded[title] == true) flatItems.addAll(list);
    }

    addGroup('过去完成', pastDone);
    addGroup('过去未完成', pastUndone);
    addGroup('过去事件', pastEvents);
    addGroup('今天', todayT);
    addGroup('明天', tomorrowT);
    addGroup('后天', dayAfterT);
    addGroup('后续', laterT);
    addGroup('无日期 (待办箱)', noDateT);

    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      buildDefaultDragHandles: false,
      itemCount: flatItems.length,
      onReorder: (oldIndex, newIndex) {
        if (oldIndex < newIndex) newIndex--;
        final item = flatItems[oldIndex];
        if (item is String) return;

        final task = item as Task;
        if (task.isReadOnly) return;

        String? newGroupName;
        for (int i = newIndex; i >= 0; i--) {
          if (i < flatItems.length && flatItems[i] is String) {
            newGroupName = flatItems[i] as String;
            break;
          }
        }

        newGroupName ??= '今天';

        Task? anchorTask;
        var insertAfter = false;

        if (newIndex < flatItems.length && flatItems[newIndex] is Task) {
          anchorTask = flatItems[newIndex] as Task;
        } else if (newIndex - 1 >= 0 && flatItems[newIndex - 1] is Task) {
          anchorTask = flatItems[newIndex - 1] as Task;
          insertAfter = true;
        }

        DateTime? targetDate = task.date;
        if (newGroupName == '今天') {
          targetDate = today;
        } else if (newGroupName == '明天') {
          targetDate = tomorrow;
        } else if (newGroupName == '后天') {
          targetDate = dayAfter;
        } else if (newGroupName == '后续') {
          targetDate = today.add(const Duration(days: 3));
        } else if (newGroupName == '无日期 (待办箱)') {
          targetDate = null;
        } else if (newGroupName == '过去未完成' || newGroupName == '过去完成') {
          if (task.date == null ||
              task.date!.isAfter(today) ||
              task.date!.isAtSameMomentAs(today)) {
            targetDate = today.subtract(const Duration(days: 1));
          }
        }

        taskData.moveTaskGlobally(task, targetDate, anchorTask, insertAfter);
      },
      itemBuilder: (context, index) {
        final item = flatItems[index];

        if (item is String) {
          final isFirst = index == 0;
          return Column(
            key: ValueKey('header_$item'),
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🔴 仅在非首个分类栏上方添加明显的模块分割区（浅灰底色 + 实线）
              if (!isFirst) ...[
                Container(
                  height: 8,
                  color: const Color(0xFFF4F6F9), // 柔和的模块间隔色块
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.grey.shade300,
                ), // 模块顶部分割实线
              ],
              Container(
                color: Colors.white,
                child: ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -2),
                  title: Text(
                    item,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                  trailing: Icon(
                    _groupExpanded[item] == true
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: Colors.grey,
                    size: 18,
                  ),
                  onTap: () => setState(
                    () => _groupExpanded[item] = !_groupExpanded[item]!,
                  ),
                ),
              ),
              // 🔴 分类标题栏与下方任务内容之间的细分割线
              Divider(height: 1, thickness: 0.8, color: Colors.grey.shade200),
            ],
          );
        }

        final task = item as Task;
        return ReorderableDelayedDragStartListener(
          key: ValueKey('task_drag_${task.id}'),
          index: index,
          child: Material(
            color: Colors.transparent,
            child: _buildTaskTile(task, task.date),
          ),
        );
      },
    );
  }

  Future<bool?> _askRepeatAction(BuildContext context, String actionName) {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          actionName,
          style: const TextStyle(color: Colors.lightBlue),
        ),
        content: const Text('这是一个重复事件，您希望将操作应用到哪些事件？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('仅当前事件', style: TextStyle(color: Colors.black87)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text(
              '所有后续事件',
              style: TextStyle(color: Colors.lightBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTile(Task task, DateTime? defaultDate) {
    final listColor = taskData.getListColor(task.listName ?? '');
    final showSidebarDate = taskData.currentHomeMode != 'todo';
    final taskDateText = task.date == null
        ? null
        : '${task.date!.month}月${task.date!.day}日${task.time != null ? ' ${task.time!.format(context)}' : ''}';

    if (task.isReadOnly) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade100, width: 1),
          ),
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
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.normal,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '节假日',
                  style: TextStyle(fontSize: 10, color: Colors.orange.shade700),
                ),
              ),
            ],
          ),
          onTap: null,
        ),
      );
    }

    return Slidable(
      key: ValueKey('slidable_${task.id}'),
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
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade100, width: 1),
          ),
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
          onTap: () => showTaskBottomSheet(
            context,
            existingTask: task,
            defaultDate: defaultDate,
          ),
          title: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Text(
                task.title,
                style: TextStyle(
                  decoration: (!task.isEvent && task.isDone)
                      ? TextDecoration.lineThrough
                      : null,
                  color: task.isEvent
                      ? Colors.black87
                      : (task.isDone ? Colors.grey : Colors.black87),
                ),
              ),
              // 逾期次数红色/橙色标签提示
              if (!task.isEvent && task.overdueCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.shade200, width: 0.6),
                  ),
                  child: Text(
                    '逾期 ${task.overdueCount} 次',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (task.repeatGroupId != null)
                const Icon(Icons.repeat, size: 14, color: Colors.lightBlue),
              ...task.tags.map(
                (tag) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.lightBlue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.lightBlue,
                    ),
                  ),
                ),
              ),
            ],
          ),
          subtitle:
              (task.description.isNotEmpty ||
                  task.time != null ||
                  task.repeatRuleText != null ||
                  (showSidebarDate && taskDateText != null))
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (task.description.isNotEmpty)
                      Text(
                        task.description,
                        style: const TextStyle(fontSize: 13),
                      ),
                    if (showSidebarDate && taskDateText != null)
                      Text(
                        taskDateText,
                        style: TextStyle(
                          fontSize: 11,
                          color: task.isEvent || task.isDone
                              ? Colors.grey
                              : Colors.red,
                          fontWeight: task.isEvent || task.isDone
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: Row(
                        children: [
                          if (task.time != null) ...[
                            const Icon(
                              Icons.access_time,
                              size: 12,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              task.time!.format(context),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                          if (task.repeatRuleText != null) ...[
                            if (task.time != null) const SizedBox(width: 8),
                            Text(
                              task.repeatRuleText!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.lightBlue,
                              ),
                            ),
                          ],
                          if (task.addToCalendar) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.event_available,
                              size: 12,
                              color: Colors.green,
                            ),
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
                    appTabIndex.value = 2;
                  },
                ),
        ),
      ),
    );
  }
}
