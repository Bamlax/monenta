import 'package:flutter/material.dart';
import '../models/task_data.dart';
import '../widgets/task_sheet.dart';

enum _ChainEntryType {
  doneTask,
  failedTask,
  overdueBreak,
  archive,
}

class _ChainPageItem {
  final _ChainEntryType type;
  final Task? task;
  final ChainEvent? event;
  final int displayNumber;
  final int archivedLength;
  final DateTime timestamp;

  _ChainPageItem({
    required this.type,
    this.task,
    this.event,
    this.displayNumber = 0,
    this.archivedLength = 0,
    required this.timestamp,
  });
}

class _RawTimelineNode {
  final _ChainEntryType type;
  final Task? task;
  final ChainEvent? event;
  final DateTime timestamp;

  _RawTimelineNode({
    required this.type,
    this.task,
    this.event,
    required this.timestamp,
  });
}

class ChainPage extends StatefulWidget {
  const ChainPage({super.key});

  @override
  State<ChainPage> createState() => _ChainPageState();
}

class _ChainPageState extends State<ChainPage> {
  String selectedChainId = '__all__';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      taskData.checkOverdueChainBreaks();
    });
  }

  String _formatDateHeader(DateTime d) {
    return '${d.year}年${d.month}月${d.day}日';
  }

  void _showEndChainDialog() {
    final isAll = selectedChainId == '__all__';
    final chain = isAll ? null : taskData.getChain(selectedChainId);
    final dialogTitle = isAll ? '结束全部链' : '结束「${chain?.name ?? '当前链'}」';
    final ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          dialogTitle,
          style: const TextStyle(color: Colors.lightBlue, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '为之前的链命名',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              taskData.endCurrentChain(
                name: name,
                chainId: isAll ? null : selectedChainId,
              );
              Navigator.pop(ctx);
            },
            child: const Text('确定', style: TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditBreakReasonDialog({
    required String initialReason,
    required ValueChanged<String> onSave,
  }) {
    final ctrl = TextEditingController(text: initialReason);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '修改中断原因',
          style: TextStyle(color: Colors.lightBlue, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入中断原因',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              onSave(ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('保存', style: TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRenameArchiveDialog(ChainEvent event) {
    final ctrl = TextEditingController(text: event.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '修改链名称',
          style: TextStyle(color: Colors.lightBlue, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入链名称',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                taskData.renameChainEvent(event.id, ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('保存', style: TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  List<_ChainPageItem> _buildTimelineItems() {
    final isAll = selectedChainId == '__all__';
    final List<_RawTimelineNode> rawNodes = [];

    // 1. 收集已完成 / 已中断的待办
    for (final t in taskData.allTasks) {
      if (t.chainId == null) continue;
      if (!isAll && t.chainId != selectedChainId) continue;

      if (t.isFailed) {
        rawNodes.add(_RawTimelineNode(
          type: _ChainEntryType.failedTask,
          task: t,
          timestamp: t.failDate ?? t.date ?? DateTime(2000),
        ));
      } else if (t.isDone) {
        rawNodes.add(_RawTimelineNode(
          type: _ChainEntryType.doneTask,
          task: t,
          timestamp: t.doneDate ?? t.date ?? DateTime(2000),
        ));
      }
    }

    // 2. 收集逾期断链与归档事件
    for (final e in taskData.chainEvents) {
      if (e.type == 'overdue_break') {
        if (isAll || e.chainId == selectedChainId) {
          rawNodes.add(_RawTimelineNode(
            type: _ChainEntryType.overdueBreak,
            event: e,
            timestamp: e.timestamp,
          ));
        }
      } else if (e.type == 'archive') {
        if (isAll) {
          // 全部界面仅响应全局结束事件
          if (e.chainId == null) {
            rawNodes.add(_RawTimelineNode(
              type: _ChainEntryType.archive,
              event: e,
              timestamp: e.timestamp,
            ));
          }
        } else {
          // 单独链界面同时响应本链结束事件与全局结束事件
          if (e.chainId == selectedChainId || e.chainId == null) {
            rawNodes.add(_RawTimelineNode(
              type: _ChainEntryType.archive,
              event: e,
              timestamp: e.timestamp,
            ));
          }
        }
      }
    }

    rawNodes.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // 3. 顺序计算 # 编号与分段长度
    final List<_ChainPageItem> result = [];
    int counter = 1;
    int segmentCount = 0;

    for (final node in rawNodes) {
      switch (node.type) {
        case _ChainEntryType.doneTask:
          result.add(_ChainPageItem(
            type: _ChainEntryType.doneTask,
            task: node.task,
            displayNumber: counter,
            timestamp: node.timestamp,
          ));
          counter++;
          segmentCount++;
          break;
        case _ChainEntryType.failedTask:
          result.add(_ChainPageItem(
            type: _ChainEntryType.failedTask,
            task: node.task,
            timestamp: node.timestamp,
          ));
          counter = 1;
          segmentCount = 0;
          break;
        case _ChainEntryType.overdueBreak:
          result.add(_ChainPageItem(
            type: _ChainEntryType.overdueBreak,
            event: node.event,
            timestamp: node.timestamp,
          ));
          counter = 1;
          segmentCount = 0;
          break;
        case _ChainEntryType.archive:
          result.add(_ChainPageItem(
            type: _ChainEntryType.archive,
            event: node.event,
            archivedLength: segmentCount,
            timestamp: node.timestamp,
          ));
          counter = 1;
          segmentCount = 0;
          break;
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text('链', style: TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _showEndChainDialog,
            child: const Text(
              '结束当前链',
              style: TextStyle(color: Colors.lightBlue, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: taskData,
        builder: (context, _) {
          final allChains = taskData.myChains;
          if (selectedChainId != '__all__' && !allChains.any((c) => c.id == selectedChainId)) {
            selectedChainId = '__all__';
          }

          final chainItems = _buildTimelineItems();

          final Map<String, List<_ChainPageItem>> groupedByDate = {};
          for (final item in chainItems) {
            final header = _formatDateHeader(item.timestamp);
            groupedByDate.putIfAbsent(header, () => []).add(item);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部链选择器
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('全部', style: TextStyle(fontSize: 12)),
                          selected: selectedChainId == '__all__',
                          selectedColor: Colors.lightBlue.shade50,
                          backgroundColor: Colors.grey.shade100,
                          side: BorderSide(
                            color: selectedChainId == '__all__' ? Colors.lightBlue.shade200 : Colors.transparent,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => selectedChainId = '__all__');
                          },
                        ),
                      ),
                      ...allChains.map((c) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c.name, style: const TextStyle(fontSize: 12)),
                          selected: selectedChainId == c.id,
                          selectedColor: Colors.lightBlue.shade50,
                          backgroundColor: Colors.grey.shade100,
                          side: BorderSide(
                            color: selectedChainId == c.id ? Colors.lightBlue.shade200 : Colors.transparent,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => selectedChainId = c.id);
                          },
                        ),
                      )),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),

              // 主体列表
              Expanded(
                child: chainItems.isEmpty
                    ? Center(
                        child: Text(
                          selectedChainId == '__all__' ? '暂无链记录' : '该链暂无记录',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: groupedByDate.keys.length,
                        itemBuilder: (context, index) {
                          final dateKey = groupedByDate.keys.elementAt(index);
                          final itemsInDate = groupedByDate[dateKey]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                                color: const Color(0xFFF9FBFC),
                                child: Text(
                                  dateKey,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              Divider(height: 1, thickness: 0.5, color: Colors.grey.shade200),

                              ...itemsInDate.map((ci) {
                                // 1. 归档结束分隔条
                                if (ci.type == _ChainEntryType.archive && ci.event != null) {
                                  final ev = ci.event!;
                                  return InkWell(
                                    onLongPress: () => _showRenameArchiveDialog(ev),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE6F1FB),
                                        border: Border(bottom: BorderSide(color: Colors.lightBlue.shade100, width: 1)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.flag_outlined, size: 16, color: Colors.lightBlue.shade700),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              ev.title,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.lightBlue.shade900,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '共 ${ci.archivedLength} 环',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.lightBlue.shade800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                // 2. 逾期自动断链记录（长按修改原因）
                                if (ci.type == _ChainEntryType.overdueBreak && ci.event != null) {
                                  final ev = ci.event!;
                                  final reasonText = (ev.reason != null && ev.reason!.isNotEmpty)
                                      ? ev.reason!
                                      : '任务逾期';
                                  return InkWell(
                                    onLongPress: () => _showEditBreakReasonDialog(
                                      initialReason: ev.reason ?? '',
                                      onSave: (val) => taskData.updateChainEventReason(ev.id, val),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50.withOpacity(0.45),
                                        border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 0.8)),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade100,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '逾期',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange.shade900,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  ev.title,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    decoration: TextDecoration.lineThrough,
                                                    decorationColor: Colors.orange.shade800,
                                                    decorationThickness: 1.6,
                                                    color: Colors.orange.shade900,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  reasonText,
                                                  style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                // 3. 手动标记中断项（长按修改原因）
                                if (ci.type == _ChainEntryType.failedTask && ci.task != null) {
                                  final task = ci.task!;
                                  final reasonText = (task.failRemark != null && task.failRemark!.isNotEmpty)
                                      ? task.failRemark!
                                      : '未说明原因';
                                  return InkWell(
                                    onTap: () => showTaskBottomSheet(context, existingTask: task),
                                    onLongPress: () => _showEditBreakReasonDialog(
                                      initialReason: task.failRemark ?? '',
                                      onSave: (val) => taskData.updateTaskFailRemark(task.id, val),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50.withOpacity(0.3),
                                        border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 0.8)),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade100,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '中断',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red.shade900,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  task.title,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    decoration: TextDecoration.lineThrough,
                                                    decorationColor: Colors.red.shade700,
                                                    decorationThickness: 1.8,
                                                    color: Colors.red.shade800,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  reasonText,
                                                  style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                // 4. 正常完成项
                                final task = ci.task!;
                                final listColor = taskData.getListColor(task.listName ?? '');
                                return InkWell(
                                  onTap: () => showTaskBottomSheet(context, existingTask: task),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 0.8)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.lightBlue.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.lightBlue.shade200, width: 0.6),
                                          ),
                                          child: Text(
                                            '#${ci.displayNumber}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.lightBlue.shade800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            task.title,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                        if (task.listName != null) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: listColor.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              task.listName!,
                                              style: TextStyle(fontSize: 10, color: listColor, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}