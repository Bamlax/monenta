import 'package:flutter/material.dart';

import '../models/task_data.dart';
import 'day_detail_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
  });

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _baseMonth;
  late DateTime _focusedMonth;

  final PageController _pageController = PageController(
    initialPage: 500,
  );

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _baseMonth = DateTime(
      now.year,
      now.month,
      1,
    );

    _focusedMonth = _baseMonth;
  }

  void _openDayDetails(
    DateTime date,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DayDetailPage(
          date: date,
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Center(
                child: Text(
                  '${_focusedMonth.year}年 ${_focusedMonth.month}月',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            Container(
              height: 24,
              color: Colors.white.withOpacity(0.6),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text(
                    '一',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '二',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '三',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '四',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '五',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '六',
                    style: TextStyle(
                      color: Colors.lightBlue,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '日',
                    style: TextStyle(
                      color: Colors.lightBlue,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (
                  context,
                  constraints,
                ) {
                  return PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      final offset = index - 500;
                      final newMonth = DateTime(
                        _baseMonth.year,
                        _baseMonth.month + offset,
                        1,
                      );

                      setState(() {
                        _focusedMonth = newMonth;
                      });

                      // 切换到对应年份时自动检查并异步拉取节假日数据
                      taskData.ensureHolidaysForYear(newMonth.year);
                    },
                    itemBuilder: (
                      context,
                      pageIndex,
                    ) {
                      final offset = pageIndex - 500;

                      final currentMonthDate = DateTime(
                        _baseMonth.year,
                        _baseMonth.month + offset,
                        1,
                      );

                      final daysInMonth = DateUtils.getDaysInMonth(
                        currentMonthDate.year,
                        currentMonthDate.month,
                      );

                      final firstWeekday = currentMonthDate.weekday;

                      final dayOffset = firstWeekday - 1;

                      final totalCells = dayOffset + daysInMonth;

                      final rowCount = (totalCells / 7).ceil();

                      final cellWidth = constraints.maxWidth / 7;

                      final cellHeight = constraints.maxHeight / rowCount;

                      final aspectRatio = cellWidth / cellHeight;

                      return ListenableBuilder(
                        listenable: taskData,
                        builder: (
                          context,
                          child,
                        ) {
                          return GridView.builder(
                            padding: EdgeInsets.zero,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              childAspectRatio: aspectRatio,
                              crossAxisSpacing: 0,
                              mainAxisSpacing: 0,
                            ),
                            itemCount: rowCount * 7,
                            itemBuilder: (
                              context,
                              index,
                            ) {
                              if (index < dayOffset || index >= totalCells) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(
                                      0.3,
                                    ),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                      width: 0.3,
                                    ),
                                  ),
                                );
                              }

                              final day = index - dayOffset + 1;

                              final cellDate = DateTime(
                                currentMonthDate.year,
                                currentMonthDate.month,
                                day,
                              );

                              final dailyTasks = taskData.getTasksByDate(
                                cellDate,
                              );

                              final isToday = cellDate.year ==
                                      DateTime.now().year &&
                                  cellDate.month == DateTime.now().month &&
                                  cellDate.day == DateTime.now().day;

                              return GestureDetector(
                                onTap: () => _openDayDetails(
                                  cellDate,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      color: isToday
                                          ? Colors.lightBlue
                                          : Colors.grey.shade200,
                                      width: isToday ? 1.0 : 0.3,
                                    ),
                                  ),
                                  padding: const EdgeInsets.only(
                                    top: 2,
                                    bottom: 2,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Container(
                                          padding: const EdgeInsets.only(
                                            right: 4,
                                            top: 1,
                                            bottom: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isToday
                                                ? Colors.lightBlue
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            '$day',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: isToday
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                              color: isToday
                                                  ? Colors.white
                                                  : (index % 7 >= 5
                                                      ? Colors.lightBlue
                                                      : Colors.black54),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(
                                        height: 1,
                                      ),
                                      Expanded(
                                        child: ClipRect(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              ...dailyTasks
                                                  .take(
                                                6,
                                              )
                                                  .map(
                                                (t) {
                                                  // 法定节假日使用柔和橙色标签背景
                                                  final listColor = t.isReadOnly
                                                      ? Colors.orange
                                                      : taskData.getListColor(
                                                          t.listName ?? '',
                                                        );

                                                  return Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                      bottom: 1,
                                                    ),
                                                    padding:
                                                        const EdgeInsets.only(
                                                      left: 2,
                                                      right: 0,
                                                      top: 0.5,
                                                      bottom: 0.5,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: t.isEvent
                                                          ? listColor.withOpacity(
                                                              0.10,
                                                            )
                                                          : (t.isDone
                                                              ? Colors.grey
                                                                  .shade100
                                                              : listColor
                                                                  .withOpacity(
                                                                  0.15,
                                                                )),
                                                    ),
                                                    child: Text(
                                                      t.title,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.clip,
                                                      style: TextStyle(
                                                        fontSize: 7.5,
                                                        height: 1.0,
                                                        color: t.isReadOnly
                                                            ? Colors.orange.shade800
                                                            : (t.isEvent
                                                                ? Colors.black87
                                                                : (t.isDone
                                                                    ? Colors
                                                                        .grey
                                                                        .shade500
                                                                    : Colors
                                                                        .black87)),
                                                        decoration:
                                                            (!t.isEvent &&
                                                                    t.isDone)
                                                                ? TextDecoration
                                                                    .lineThrough
                                                                : null,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}