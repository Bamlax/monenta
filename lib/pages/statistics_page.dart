import 'package:flutter/material.dart';
import 'dart:math';
import '../models/task_data.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  String selectedRange = '7天';
  final List<String> ranges = ['7天', '30天', '3月', '半年', '一年'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('数据统计', style: TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: DropdownButton<String>(
              value: selectedRange,
              underline: const SizedBox(),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.lightBlue),
              style: const TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold),
              items: ranges.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => selectedRange = val);
              },
            ),
          )
        ],
      ),
      body: ListenableBuilder(
        listenable: taskData,
        builder: (context, child) {
          DateTime now = DateTime.now();
          DateTime startDate = now;
          if (selectedRange == '7天') startDate = now.subtract(const Duration(days: 7));
          else if (selectedRange == '30天') startDate = now.subtract(const Duration(days: 30));
          else if (selectedRange == '3月') startDate = DateTime(now.year, now.month - 3, now.day);
          else if (selectedRange == '半年') startDate = DateTime(now.year, now.month - 6, now.day);
          else if (selectedRange == '一年') startDate = DateTime(now.year - 1, now.month, now.day);

          List<Task> rangeTasks = [];
          List<int> lineData = [];
          List<String> lineLabels = [];

          int daysCount = now.difference(startDate).inDays;
          if (daysCount <= 0) daysCount = 1;

          for (int i = 0; i <= daysCount; i++) {
            DateTime d = startDate.add(Duration(days: i));
            lineLabels.add('${d.month}/${d.day}');
            List<Task> dayTasks = taskData.getTasksByDate(d);
            rangeTasks.addAll(dayTasks);
            lineData.add(dayTasks.where((t) => t.isDone).length);
          }

          final todoRangeTasks = rangeTasks.where((t) => !t.isEvent).toList();
          int doneCount = todoRangeTasks.where((t) => t.isDone).length;
          int undoneCount = todoRangeTasks.where((t) => !t.isDone).length;
          int totalCount = doneCount + undoneCount;
          double doneRate = totalCount == 0 ? 0 : (doneCount / totalCount);

          Map<String, int> listCounts = {};
          for (var t in rangeTasks.where((t) => t.isDone && !t.isEvent)) {
            String listName = t.listName ?? '默认';
            listCounts[listName] = (listCounts[listName] ?? 0) + 1;
          }

          // 逾期指标统计计算
          int totalOverdue = 0;
          Map<String, int> listOverdueCounts = {};
          final allTodos = taskData.allTasks.where((t) => !t.isEvent && !t.isReadOnly).toList();
          for (var t in allTodos) {
            if (t.overdueCount > 0) {
              totalOverdue += t.overdueCount;
              String lName = t.listName ?? '无清单';
              listOverdueCounts[lName] = (listOverdueCounts[lName] ?? 0) + t.overdueCount;
            }
          }
          double avgOverdue = allTodos.isEmpty ? 0.00 : (totalOverdue / allTodos.length);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('每日完成趋势 (共 $doneCount 件)'),
                const SizedBox(height: 20),
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: CustomPaint(painter: LineChartPainter(lineData, lineLabels)),
                ),
                const SizedBox(height: 35),

                // 完成率与清单完成分布 (左右并排)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _buildSectionTitle('事件完成率'),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 110,
                            width: 110,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CustomPaint(
                                  size: const Size(110, 110),
                                  painter: PieChartPainter(
                                    [doneCount.toDouble(), undoneCount.toDouble()],
                                    [Colors.lightBlue, Colors.grey.shade200],
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${(doneRate * 100).toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const Text('已完成', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          _buildSectionTitle('清单分布 (已完成)'),
                          const SizedBox(height: 20),
                          if (listCounts.isEmpty)
                            const SizedBox(height: 110, child: Center(child: Text('暂无完成记录', style: TextStyle(color: Colors.grey, fontSize: 12))))
                          else ...[
                            SizedBox(
                              height: 100,
                              width: 100,
                              child: CustomPaint(
                                size: const Size(100, 100),
                                painter: PieChartPainter(
                                  listCounts.values.map((v) => v.toDouble()).toList(),
                                  listCounts.keys.map((k) => taskData.getListColor(k)).toList(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              alignment: WrapAlignment.center,
                              children: listCounts.entries.map((e) {
                                Color c = taskData.getListColor(e.key);
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle, size: 7, color: c),
                                    const SizedBox(width: 4),
                                    Text('${e.key} (${e.value})', style: const TextStyle(fontSize: 10, color: Colors.black87)),
                                  ],
                                );
                              }).toList(),
                            )
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 35),

                // 逾期统计指标与清单逾期分布 (左右并排)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 左边：逾期统计指标卡片
                    Expanded(
                      child: Column(
                        children: [
                          _buildSectionTitle('逾期统计分析'),
                          const SizedBox(height: 20),
                          Container(
                            height: 150,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FBFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      avgOverdue.toStringAsFixed(2),
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text('平均逾期/任务', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                                Divider(height: 12, color: Colors.grey.shade200, indent: 20, endIndent: 20),
                                Column(
                                  children: [
                                    Text(
                                      '$totalOverdue 次',
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text('总逾期次数', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 右边：清单逾期分布饼图
                    Expanded(
                      child: Column(
                        children: [
                          _buildSectionTitle('各清单逾期分布'),
                          const SizedBox(height: 20),
                          if (listOverdueCounts.isEmpty)
                            Container(
                              height: 150,
                              alignment: Alignment.center,
                              child: const Text('暂无逾期记录\n执行力极佳~', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4)),
                            )
                          else ...[
                            SizedBox(
                              height: 100,
                              width: 100,
                              child: CustomPaint(
                                size: const Size(100, 100),
                                painter: PieChartPainter(
                                  listOverdueCounts.values.map((v) => v.toDouble()).toList(),
                                  listOverdueCounts.keys.map((k) => taskData.getListColor(k)).toList(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              alignment: WrapAlignment.center,
                              children: listOverdueCounts.entries.map((e) {
                                Color c = taskData.getListColor(e.key);
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle, size: 7, color: c),
                                    const SizedBox(width: 4),
                                    Text('${e.key} (${e.value}次)', style: const TextStyle(fontSize: 10, color: Colors.black87)),
                                  ],
                                );
                              }).toList(),
                            )
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87));
  }
}

class LineChartPainter extends CustomPainter {
  final List<int> data;
  final List<String> labels;

  LineChartPainter(this.data, this.labels);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    double rawMax = data.reduce(max).toDouble();
    if (rawMax == 0) rawMax = 4;
    double stepVal = (rawMax / 4).ceilToDouble();
    if (stepVal == 0) stepVal = 1;
    double niceMax = stepVal * 4;

    double paddingLeft = 30;
    double paddingBottom = 25;
    double paddingTop = 10;
    double paddingRight = 10;

    double chartWidth = size.width - paddingLeft - paddingRight;
    double chartHeight = size.height - paddingBottom - paddingTop;

    Paint gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    );

    int ySteps = 4;
    for (int i = 0; i <= ySteps; i++) {
      double y = paddingTop + chartHeight - (i / ySteps) * chartHeight;
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width - paddingRight, y), gridPaint);

      double val = stepVal * i;
      String valStr = val.toInt().toString();
      textPainter.text = TextSpan(
        text: valStr,
        style: const TextStyle(color: Colors.grey, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(paddingLeft - textPainter.width - 4, y - textPainter.height / 2));
    }

    int xLabelCount = labels.length;
    int step = 1;
    if (xLabelCount > 10) step = (xLabelCount / 6).ceil();

    for (int i = 0; i < xLabelCount; i += step) {
      double x = paddingLeft + (xLabelCount > 1 ? (i / (xLabelCount - 1)) * chartWidth : chartWidth / 2);
      textPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(color: Colors.grey, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, paddingTop + chartHeight + 4));
    }
    if ((xLabelCount - 1) % step != 0 && xLabelCount > 1) {
      double x = paddingLeft + chartWidth;
      textPainter.text = TextSpan(
        text: labels.last,
        style: const TextStyle(color: Colors.grey, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, paddingTop + chartHeight + 4));
    }

    Paint linePaint = Paint()
      ..color = Colors.lightBlue
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Paint fillPaint = Paint()
      ..color = Colors.lightBlue.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    Path path = Path();
    Path fillPath = Path();

    double stepX = xLabelCount > 1 ? chartWidth / (xLabelCount - 1) : 0;
    double startX = paddingLeft;
    double startY = paddingTop + chartHeight - (data[0] / niceMax) * chartHeight;

    path.moveTo(startX, startY);
    fillPath.moveTo(startX, paddingTop + chartHeight);
    fillPath.lineTo(startX, startY);

    for (int i = 1; i < data.length; i++) {
      double x = paddingLeft + i * stepX;
      double y = paddingTop + chartHeight - (data[i] / niceMax) * chartHeight;
      path.lineTo(x, y);
      fillPath.lineTo(x, y);
    }

    fillPath.lineTo(paddingLeft + (data.length - 1) * stepX, paddingTop + chartHeight);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    if (data.length <= 30) {
      Paint pointPaint = Paint()..color = Colors.white;
      Paint pointBorderPaint = Paint()
        ..color = Colors.lightBlue
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      for (int i = 0; i < data.length; i++) {
        double x = paddingLeft + i * stepX;
        double y = paddingTop + chartHeight - (data[i] / niceMax) * chartHeight;
        canvas.drawCircle(Offset(x, y), 3, pointPaint);
        canvas.drawCircle(Offset(x, y), 3, pointBorderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.labels != labels;
}

class PieChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  PieChartPainter(this.values, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    double total = values.fold(0, (a, b) => a + b);
    if (total == 0) {
      canvas.drawCircle(size.center(Offset.zero), size.width / 2, Paint()..color = Colors.grey.shade100);
      return;
    }
    double startAngle = -pi / 2;
    Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    for (int i = 0; i < values.length; i++) {
      double sweepAngle = (values[i] / total) * 2 * pi;
      Paint paint = Paint()..color = colors[i]..style = PaintingStyle.fill;
      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}