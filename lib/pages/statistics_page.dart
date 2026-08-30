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
          // 1. 根据选择的时间范围计算开始日期
          DateTime now = DateTime.now();
          DateTime startDate = now;
          if (selectedRange == '7天') startDate = now.subtract(const Duration(days: 7));
          else if (selectedRange == '30天') startDate = now.subtract(const Duration(days: 30));
          else if (selectedRange == '3月') startDate = DateTime(now.year, now.month - 3, now.day);
          else if (selectedRange == '半年') startDate = DateTime(now.year, now.month - 6, now.day);
          else if (selectedRange == '一年') startDate = DateTime(now.year - 1, now.month, now.day);

          // 2. 遍历获取范围内的所有待办及折线图数据
          List<Task> rangeTasks = [];
          List<int> lineData = []; 
          List<String> lineLabels = []; // 🔴 新增：X轴标签
          
          int daysCount = now.difference(startDate).inDays;
          if (daysCount <= 0) daysCount = 1;

          for (int i = 0; i <= daysCount; i++) {
            DateTime d = startDate.add(Duration(days: i));
            lineLabels.add('${d.month}/${d.day}'); // 生成如 "5/12" 的标签
            List<Task> dayTasks = taskData.getTasksByDate(d);
            rangeTasks.addAll(dayTasks);
            lineData.add(dayTasks.where((t) => t.isDone).length);
          }

          // 3. 计算完成率
          final todoRangeTasks = rangeTasks.where((t) => !t.isEvent).toList();
          int doneCount = todoRangeTasks.where((t) => t.isDone).length;
          int undoneCount = todoRangeTasks.where((t) => !t.isDone).length;
          int totalCount = doneCount + undoneCount;
          double doneRate = totalCount == 0 ? 0 : (doneCount / totalCount);

          // 4. 计算各清单的完成分布
          Map<String, int> listCounts = {};
          for (var t in rangeTasks.where((t) => t.isDone && !t.isEvent)) {
            String listName = t.listName ?? '默认';
            listCounts[listName] = (listCounts[listName] ?? 0) + 1;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('每日完成趋势 (共 $doneCount 件)'),
                const SizedBox(height: 20),
                SizedBox(
                  height: 180, // 稍微增加高度以容纳坐标轴文字
                  width: double.infinity,
                  // 🔴 传入数据和标签
                  child: CustomPaint(painter: LineChartPainter(lineData, lineLabels)),
                ),
                const SizedBox(height: 40),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 事件完成率饼图
                    Expanded(
                      child: Column(
                        children: [
                          _buildSectionTitle('事件完成率'),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 120, width: 120,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CustomPaint(
                                  size: const Size(120, 120),
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
                    // 清单分布饼图 + 🔴 下方图例
                    Expanded(
                      child: Column(
                        children: [
                          _buildSectionTitle('清单分布 (已完成)'),
                          const SizedBox(height: 20),
                          if (listCounts.isEmpty)
                            const SizedBox(height: 120, child: Center(child: Text('暂无完成记录', style: TextStyle(color: Colors.grey))))
                          else ...[
                            SizedBox(
                              height: 100, width: 100,
                              child: CustomPaint(
                                size: const Size(100, 100),
                                painter: PieChartPainter(
                                  listCounts.values.map((v) => v.toDouble()).toList(),
                                  listCounts.keys.map((k) => taskData.getListColor(k)).toList(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            // 🔴 图例直接放在饼图正下方
                            Wrap(
                              spacing: 8, runSpacing: 6,
                              alignment: WrapAlignment.center,
                              children: listCounts.entries.map((e) {
                                Color c = taskData.getListColor(e.key);
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle, size: 8, color: c),
                                    const SizedBox(width: 4),
                                    Text('${e.key} (${e.value})', style: const TextStyle(fontSize: 11, color: Colors.black87)),
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
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87));
  }
}

// ================= 画板：带坐标轴的极简折线图 =================
class LineChartPainter extends CustomPainter {
  final List<int> data;
  final List<String> labels;

  LineChartPainter(this.data, this.labels);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // 1. 计算“漂亮”的Y轴最大整数刻度
    double rawMax = data.reduce(max).toDouble();
    if (rawMax == 0) rawMax = 4; 
    double stepVal = (rawMax / 4).ceilToDouble();
    if (stepVal == 0) stepVal = 1;
    double niceMax = stepVal * 4;

    // 2. 预留坐标轴文字空间
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

    // 3. 绘制 Y 轴刻度和水平网格线
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

    // 4. 绘制 X 轴标签 (数据多时自动抽样)
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
    // 确保最后一个标签始终显示
    if ((xLabelCount - 1) % step != 0 && xLabelCount > 1) {
      double x = paddingLeft + chartWidth;
      textPainter.text = TextSpan(
        text: labels.last,
        style: const TextStyle(color: Colors.grey, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, paddingTop + chartHeight + 4));
    }

    // 5. 绘制折线和渐变填充
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
    
    // 6. 绘制数据点（数据量 <= 30 天时显示小圆圈，提升精致感）
    if (data.length <= 30) {
      Paint pointPaint = Paint()..color = Colors.white;
      Paint pointBorderPaint = Paint()..color = Colors.lightBlue..strokeWidth = 2..style = PaintingStyle.stroke;
      for (int i = 0; i < data.length; i++) {
        double x = paddingLeft + i * stepX;
        double y = paddingTop + chartHeight - (data[i] / niceMax) * chartHeight;
        canvas.drawCircle(Offset(x, y), 3, pointPaint);
        canvas.drawCircle(Offset(x, y), 3, pointBorderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) => oldDelegate.data != data || oldDelegate.labels != labels;
}

// ================= 画板：极简饼图 =================
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

