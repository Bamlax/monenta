import 'package:flutter/material.dart';
import '../models/task_data.dart';
import '../widgets/task_sheet.dart';

class ChainPageItem {
  final Task task;
  final int displayNumber; // 显示的 # 编号
  final bool isBreakPoint; // 是否中断
  final String? breakReason; // 中断原因
  final DateTime date;

  ChainPageItem({
    required this.task,
    required this.displayNumber,
    required this.isBreakPoint,
    this.breakReason,
    required this.date,
  });
}

class ChainPage extends StatefulWidget {
  const ChainPage({super.key});

  @override
  State<ChainPage> createState() => _ChainPageState();
}

class _ChainPageState extends State<ChainPage> {
  String selectedChainId = '__all__'; // '__all__' 代表最左侧的全部

  String _formatDateHeader(DateTime d) {
    return '${d.year}年${d.month}月${d.day}日';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text('链', style: TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
      ),
      body: ListenableBuilder(
        listenable: taskData,
        builder: (context, _) {
          // 1. 顶部选择器标签：最左侧为全部
          final allChains = taskData.myChains;

          // 2. 计算展示数据源
          final List<ChainPageItem> chainItems = [];

          if (selectedChainId == '__all__') {
            // 全部链合并统计：只要遇到任意一个链断裂，即从头开始统计 (计数重置为 1)
            final allChainTasks = taskData.allTasks
                .where((t) => t.chainId != null && (t.isDone || t.isFailed))
                .toList();

            // 按完成时间或所属日期升序排列，模拟链推进过程
            allChainTasks.sort((a, b) {
              final da = a.doneDate ?? a.date ?? DateTime(2000);
              final db = b.doneDate ?? b.date ?? DateTime(2000);
              return da.compareTo(db);
            });

            int globalCounter = 1;
            for (final t in allChainTasks) {
              final itemDate = t.doneDate ?? t.date ?? DateTime.now();
              if (t.isFailed) {
                // 中断
                chainItems.add(ChainPageItem(
                  task: t,
                  displayNumber: 0,
                  isBreakPoint: true,
                  breakReason: t.failRemark ?? '未说明原因',
                  date: itemDate,
                ));
                globalCounter = 1; // 遇到任何一个链断了即从头开始统计
              } else if (t.isDone) {
                chainItems.add(ChainPageItem(
                  task: t,
                  displayNumber: globalCounter,
                  isBreakPoint: false,
                  date: itemDate,
                ));
                globalCounter++;
              }
            }
          } else {
            // 单独某个链统计
            final singleChainTasks = taskData.allTasks
                .where((t) => t.chainId == selectedChainId && (t.isDone || t.isFailed))
                .toList();

            singleChainTasks.sort((a, b) {
              final da = a.doneDate ?? a.date ?? DateTime(2000);
              final db = b.doneDate ?? b.date ?? DateTime(2000);
              return da.compareTo(db);
            });

            int chainCounter = 1;
            for (final t in singleChainTasks) {
              final itemDate = t.doneDate ?? t.date ?? DateTime.now();
              if (t.isFailed) {
                chainItems.add(ChainPageItem(
                  task: t,
                  displayNumber: 0,
                  isBreakPoint: true,
                  breakReason: t.failRemark ?? '未说明原因',
                  date: itemDate,
                ));
                chainCounter = 1;
              } else if (t.isDone) {
                chainItems.add(ChainPageItem(
                  task: t,
                  displayNumber: t.chainNumber ?? chainCounter,
                  isBreakPoint: false,
                  date: itemDate,
                ));
                chainCounter++;
              }
            }
          }

          // 3. 将待办按日期分栏分组（用日期分栏分割）
          final Map<String, List<ChainPageItem>> groupedByDate = {};
          for (final item in chainItems) {
            final header = _formatDateHeader(item.date);
            groupedByDate.putIfAbsent(header, () => []).add(item);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部选择器标签栏
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // 最左侧是全部
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
                          selectedChainId == '__all__' ? '暂无链完成或中断记录' : '该链暂无记录',
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
                              // 日期分栏头
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

                              // 该日期下的链项列表
                              ...itemsInDate.map((ci) {
                                final task = ci.task;
                                final listColor = taskData.getListColor(task.listName ?? '');

                                if (ci.isBreakPoint) {
                                  // 中断项
                                  return InkWell(
                                    onTap: () => showTaskBottomSheet(context, existingTask: task),
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
                                                  ci.breakReason ?? '未完成',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.red.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                // 正常按从上到下 # 顺序推进的完成项
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