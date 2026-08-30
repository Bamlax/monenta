import 'dart:math';

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

  final PageController _pageController =
      PageController(initialPage: 500);

  late DateTime _baseMonday;

  final Map<String, bool> _groupExpanded = {
    '过去完成': false,
    '过去未完成': true,
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

    _baseMonday = now.subtract(
      Duration(days: now.weekday - 1),
    );
  }

  Widget _buildSegmentedDateBtn(
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 2,
        ),
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

  Widget _buildInboxTaskCard(
    Task task,
    BuildContext context,
  ) {
    final listColor =
        taskData.getListColor(task.listName ?? '');

    return Slidable(
      key: ValueKey(
        'inbox_slidable_${task.id}',
      ),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.2,
        children: [
          SlidableAction(
            onPressed: (context) {
              taskData.deleteTask(task.id);
            },
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
            bottom: BorderSide(
              color: Colors.grey.shade100,
              width: 1,
            ),
          ),
        ),
        child: InkWell(
          onTap: () {
            showTaskBottomSheet(
              context,
              existingTask: task,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment:
                      WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    if (!task.isEvent)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: task.isDone,
                          activeColor: listColor,
                          side: BorderSide(
                            color: listColor,
                            width: 2,
                          ),
                          onChanged: (_) {
                            taskData.toggleTaskDone(
                              task.id,
                            );
                          },
                        ),
                      ),
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.bold,
                        color: (!task.isEvent &&
                                task.isDone)
                            ? Colors.grey
                            : Colors.black87,
                        decoration: (!task.isEvent &&
                                task.isDone)
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (task.tags.isNotEmpty)
                      ...task.tags.map(
                        (tag) => Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 0,
                          ),
                          decoration:
                              BoxDecoration(
                            color: Colors
                                .lightBlue.shade50,
                            borderRadius:
                                BorderRadius.circular(
                              4,
                            ),
                          ),
                          child: Text(
                            '#$tag',
                            style:
                                const TextStyle(
                              fontSize: 9,
                              color:
                                  Colors.lightBlue,
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
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                    ),
                  ),
                ],
                if (task.date != null ||
                    task.time != null) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      if (task.date != null)
                        Text(
                          '${task.date!.month}/${task.date!.day}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      if (task.time != null) ...[
                        if (task.date != null)
                          const SizedBox(width: 8),
                        const Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          task.time!.format(
                            context,
                          ),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors
                              .lightBlue.shade100,
                        ),
                      ),
                      child: Row(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          _buildSegmentedDateBtn(
                            '今天',
                            () {
                              taskData.updateTaskDate(
                                task.id,
                                DateTime.now(),
                              );
                            },
                          ),
                          Container(
                            width: 1,
                            height: 10,
                            color: Colors
                                .lightBlue.shade100,
                          ),
                          _buildSegmentedDateBtn(
                            '明天',
                            () {
                              taskData.updateTaskDate(
                                task.id,
                                DateTime.now()
                                    .add(
                                  const Duration(
                                    days: 1,
                                  ),
                                ),
                              );
                            },
                          ),
                          Container(
                            width: 1,
                            height: 10,
                            color: Colors
                                .lightBlue.shade100,
                          ),
                          _buildSegmentedDateBtn(
                            '📅',
                            () async {
                              final picked =
                                  await showDatePicker(
                                context: context,
                                initialDate:
                                    DateTime.now(),
                                firstDate:
                                    DateTime(2020),
                                lastDate:
                                    DateTime(2050),
                              );

                              if (!context.mounted) {
                                return;
                              }

                              if (picked != null) {
                                taskData
                                    .updateTaskDate(
                                  task.id,
                                  picked,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 20,
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(4),
                        border: Border.all(
                          color:
                              Colors.grey.shade200,
                        ),
                      ),
                      child:
                          DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: task.listName,
                          hint: const Text(
                            '分类...',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                          icon: const Icon(
                            Icons
                                .keyboard_arrow_down,
                            size: 12,
                            color: Colors.grey,
                          ),
                          style: TextStyle(
                            fontSize: 10,
                            color: listColor,
                            fontWeight:
                                FontWeight.bold,
                          ),
                          isDense: true,
                          items: [
                            const DropdownMenuItem<
                                String>(
                              value: null,
                              child: Text(
                                '无清单',
                                style: TextStyle(
                                  color:
                                      Colors.grey,
                                ),
                              ),
                            ),
                            ...taskData.myLists.map(
                              (list) =>
                                  DropdownMenuItem<
                                      String>(
                                value: list.name,
                                child: Row(
                                  mainAxisSize:
                                      MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 6,
                                      color:
                                          list.color,
                                    ),
                                    const SizedBox(
                                      width: 4,
                                    ),
                                    Text(
                                      list.name,
                                      style:
                                          TextStyle(
                                        color:
                                            list.color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          onChanged: (newList) {
                            taskData.updateTaskList(
                              task.id,
                              newList,
                            );
                          },
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

  void _showEditListDialog(
    TaskList list,
  ) {
    final TextEditingController ctrl =
        TextEditingController(
      text: list.name,
    );

    Color selectedColor = list.color;

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.amber,
      Colors.indigo,
      Colors.cyan,
    ];

    bool showCustomColor = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final TextEditingController rCtrl =
                TextEditingController(
              text:
                  (selectedColor.r * 255.0)
                      .round()
                      .clamp(0, 255)
                      .toString(),
            );

            final TextEditingController gCtrl =
                TextEditingController(
              text:
                  (selectedColor.g * 255.0)
                      .round()
                      .clamp(0, 255)
                      .toString(),
            );

            final TextEditingController bCtrl =
                TextEditingController(
              text:
                  (selectedColor.b * 255.0)
                      .round()
                      .clamp(0, 255)
                      .toString(),
            );

            Widget buildRgbInput(
              String label,
              TextEditingController
                  textCtrl,
            ) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 6,
                ),
                child: Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style:
                          const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 42,
                      height: 32,
                      child: TextField(
                        controller: textCtrl,
                        keyboardType:
                            TextInputType.number,
                        textAlign:
                            TextAlign.center,
                        style:
                            const TextStyle(
                          fontSize: 13,
                        ),
                        decoration:
                            InputDecoration(
                          contentPadding:
                              EdgeInsets.zero,
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              6,
                            ),
                          ),
                        ),
                        onChanged: (_) {
                          final r =
                              int.tryParse(
                                    rCtrl.text,
                                  ) ??
                                  (selectedColor.r *
                                          255.0)
                                      .round();

                          final g =
                              int.tryParse(
                                    gCtrl.text,
                                  ) ??
                                  (selectedColor.g *
                                          255.0)
                                      .round();

                          final b =
                              int.tryParse(
                                    bCtrl.text,
                                  ) ??
                                  (selectedColor.b *
                                          255.0)
                                      .round();

                          setState(() {
                            selectedColor =
                                Color.fromARGB(
                              255,
                              r.clamp(0, 255),
                              g.clamp(0, 255),
                              b.clamp(0, 255),
                            );
                          });
                        },
                      ),
                    ),
                  ],
                ),
              );
            }

            void updateFromWheel(
              double hue,
              double saturation,
            ) {
              setState(() {
                selectedColor =
                    HSVColor.fromAHSV(
                  1.0,
                  hue,
                  saturation,
                  1.0,
                ).toColor();

                rCtrl.text =
                    (selectedColor.r * 255.0)
                        .round()
                        .clamp(0, 255)
                        .toString();

                gCtrl.text =
                    (selectedColor.g * 255.0)
                        .round()
                        .clamp(0, 255)
                        .toString();

                bCtrl.text =
                    (selectedColor.b * 255.0)
                        .round()
                        .clamp(0, 255)
                        .toString();
              });
            }

            return AlertDialog(
              title: const Text(
                '编辑清单',
                style: TextStyle(
                  color: Colors.lightBlue,
                ),
              ),
              content: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    decoration:
                        const InputDecoration(
                      hintText: '清单名称',
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!showCustomColor)
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ...colors.map(
                          (c) => GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedColor = c;

                                rCtrl.text =
                                    (c.r * 255.0)
                                        .round()
                                        .clamp(0, 255)
                                        .toString();

                                gCtrl.text =
                                    (c.g * 255.0)
                                        .round()
                                        .clamp(0, 255)
                                        .toString();

                                bCtrl.text =
                                    (c.b * 255.0)
                                        .round()
                                        .clamp(0, 255)
                                        .toString();
                              });
                            },
                            child:
                                CircleAvatar(
                              backgroundColor: c,
                              radius: 16,
                              child:
                                  selectedColor ==
                                          c
                                      ? const Icon(
                                          Icons.check,
                                          color:
                                              Colors.white,
                                          size: 16,
                                        )
                                      : null,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              showCustomColor =
                                  true;
                            });
                          },
                          child:
                              const CircleAvatar(
                            backgroundColor:
                                Colors.grey,
                            radius: 16,
                            child: Icon(
                              Icons.palette,
                              color:
                                  Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        Stack(
                          alignment:
                              Alignment.center,
                          children: [
                            GestureDetector(
                              onPanUpdate:
                                  (details) {
                                const radius =
                                    75.0;

                                final dx =
                                    details
                                            .localPosition
                                            .dx -
                                        radius;

                                final dy =
                                    details
                                            .localPosition
                                            .dy -
                                        radius;

                                double angle =
                                    atan2(
                                  dy,
                                  dx,
                                );

                                if (angle < 0) {
                                  angle +=
                                      2 * pi;
                                }

                                final hue =
                                    angle *
                                        180 /
                                        pi;

                                final distance =
                                    sqrt(
                                  dx * dx +
                                      dy * dy,
                                );

                                final saturation =
                                    (distance /
                                            radius)
                                        .clamp(
                                  0.0,
                                  1.0,
                                );

                                updateFromWheel(
                                  hue,
                                  saturation,
                                );
                              },
                              onTapDown:
                                  (details) {
                                const radius =
                                    75.0;

                                final dx =
                                    details
                                            .localPosition
                                            .dx -
                                        radius;

                                final dy =
                                    details
                                            .localPosition
                                            .dy -
                                        radius;

                                double angle =
                                    atan2(
                                  dy,
                                  dx,
                                );

                                if (angle < 0) {
                                  angle +=
                                      2 * pi;
                                }

                                final hue =
                                    angle *
                                        180 /
                                        pi;

                                final distance =
                                    sqrt(
                                  dx * dx +
                                      dy * dy,
                                );

                                final saturation =
                                    (distance /
                                            radius)
                                        .clamp(
                                  0.0,
                                  1.0,
                                );

                                updateFromWheel(
                                  hue,
                                  saturation,
                                );
                              },
                              child: Container(
                                width: 150,
                                height: 150,
                                decoration:
                                    BoxDecoration(
                                  shape:
                                      BoxShape.circle,
                                  gradient:
                                      SweepGradient(
                                    colors: [
                                      HSVColor.fromAHSV(
                                        1.0,
                                        0.0,
                                        1.0,
                                        1.0,
                                      ).toColor(),
                                      HSVColor.fromAHSV(
                                        1.0,
                                        60.0,
                                        1.0,
                                        1.0,
                                      ).toColor(),
                                      HSVColor.fromAHSV(
                                        1.0,
                                        120.0,
                                        1.0,
                                        1.0,
                                      ).toColor(),
                                      HSVColor.fromAHSV(
                                        1.0,
                                        180.0,
                                        1.0,
                                        1.0,
                                      ).toColor(),
                                      HSVColor.fromAHSV(
                                        1.0,
                                        240.0,
                                        1.0,
                                        1.0,
                                      ).toColor(),
                                      HSVColor.fromAHSV(
                                        1.0,
                                        300.0,
                                        1.0,
                                        1.0,
                                      ).toColor(),
                                      HSVColor.fromAHSV(
                                        1.0,
                                        360.0,
                                        1.0,
                                        1.0,
                                      ).toColor(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Builder(
                              builder: (context) {
                                final hsv =
                                    HSVColor
                                        .fromColor(
                                  selectedColor,
                                );

                                final angle =
                                    hsv.hue *
                                        pi /
                                        180;

                                final distance =
                                    hsv.saturation *
                                        75;

                                return Transform
                                    .translate(
                                  offset: Offset(
                                    distance *
                                        cos(
                                      angle,
                                    ),
                                    distance *
                                        sin(
                                      angle,
                                    ),
                                  ),
                                  child:
                                      Container(
                                    width: 20,
                                    height: 20,
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          selectedColor,
                                      shape:
                                          BoxShape.circle,
                                      border:
                                          Border.all(
                                        color:
                                            Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color:
                                              Colors.black26,
                                          blurRadius:
                                              4,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center,
                          children: [
                            buildRgbInput(
                              'R',
                              rCtrl,
                            ),
                            buildRgbInput(
                              'G',
                              gCtrl,
                            ),
                            buildRgbInput(
                              'B',
                              bCtrl,
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    taskData.deleteList(
                      list.name,
                    );
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    '删除',
                    style: TextStyle(
                      color: Colors.red,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(ctx),
                  child: const Text(
                    '取消',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (ctrl.text
                        .trim()
                        .isNotEmpty) {
                      taskData.editList(
                        list.name,
                        ctrl.text.trim(),
                        selectedColor,
                      );
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text(
                    '保存',
                    style: TextStyle(
                      color: Colors.lightBlue,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditTagDialog(
    String tag,
  ) {
    final TextEditingController ctrl =
        TextEditingController(
      text: tag,
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text(
            '编辑标签',
            style: TextStyle(
              color: Colors.lightBlue,
            ),
          ),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration:
                const InputDecoration(
              hintText: '标签名称',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                taskData.deleteTag(tag);
                Navigator.pop(ctx);
              },
              child: const Text(
                '删除',
                style:
                    TextStyle(
                  color: Colors.red,
                ),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(ctx),
              child: const Text(
                '取消',
                style:
                    TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                if (ctrl.text
                    .trim()
                    .isNotEmpty) {
                  taskData.editTag(
                    tag,
                    ctrl.text.trim(),
                  );
                  Navigator.pop(ctx);
                }
              },
              child: const Text(
                '保存',
                style:
                    TextStyle(
                  color: Colors.lightBlue,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showInboxMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder:
              (
            context,
            scrollController,
          ) {
            return Container(
              decoration:
                  const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () =>
                        Navigator.pop(context),
                    behavior:
                        HitTestBehavior.opaque,
                    child: Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets
                              .symmetric(
                        vertical: 12,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            decoration:
                                BoxDecoration(
                              color: Colors
                                  .grey
                                  .shade300,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                2,
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 12,
                          ),
                          const Text(
                            '待办箱',
                            style:
                                TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.bold,
                              color:
                                  Colors.lightBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(
                    height: 1,
                  ),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: taskData,
                      builder:
                          (
                        context,
                        child,
                      ) {
                        final tasks =
                            taskData.inboxTasks;

                        if (tasks.isEmpty) {
                          return const Center(
                            child: Text(
                              '待办箱已清空~\n随时记录你的闪念，然后在这里分配',
                              textAlign:
                                  TextAlign.center,
                              style:
                                  TextStyle(
                                color:
                                    Colors.grey,
                                height:
                                    1.6,
                              ),
                            ),
                          );
                        }

                        return ReorderableListView
                            .builder(
                          scrollController:
                              scrollController,
                          itemCount:
                              tasks.length,
                          onReorder:
                              (
                            oldIndex,
                            newIndex,
                          ) =>
                                  taskData
                                      .reorderInboxTasks(
                            oldIndex,
                            newIndex,
                          ),
                          itemBuilder:
                              (
                            context,
                            index,
                          ) {
                            final task =
                                tasks[index];

                            return _buildInboxTaskCard(
                              task,
                              context,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    const bgColor =
        Colors.white;

    return ListenableBuilder(
      listenable: taskData,
      builder:
          (
        context,
        child,
      ) {
        String appBarTitle =
            'Monenta';

        Color appBarColor =
            Colors.lightBlue;

        if (taskData.currentHomeMode ==
            'recent') {
          appBarTitle =
              '最近代办';
        } else if (taskData
                .currentHomeMode ==
            'list') {
          appBarTitle =
              taskData.currentHomeParam ??
                  '';

          appBarColor =
              taskData.getListColor(
            appBarTitle,
          );
        } else if (taskData
                .currentHomeMode ==
            'tag') {
          appBarTitle =
              '#${taskData.currentHomeParam ?? ''}';
        }

        return Scaffold(
          backgroundColor: bgColor,

          drawer: Drawer(
            shape:
                const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.zero,
            ),
            backgroundColor:
                Colors.white,
            child: ListView(
              padding:
                  EdgeInsets.zero,
              children: [
                const DrawerHeader(
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.lightBlue,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    mainAxisAlignment:
                        MainAxisAlignment.end,
                    children: [
                      Text(
                        'Monenta',
                        style:
                            TextStyle(
                          color:
                              Colors.white,
                          fontSize:
                              28,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      SizedBox(
                        height: 8,
                      ),
                      Text(
                        '你的待办与笔记',
                        style:
                            TextStyle(
                          color:
                              Colors.white70,
                          fontSize:
                              14,
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading:
                      const Icon(
                    Icons.check_circle_outline,
                    color:
                        Colors.lightBlue,
                  ),
                  title:
                      const Text(
                    'TODO',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    taskData.setHomeMode(
                      'todo',
                    );
                    Navigator.pop(
                      context,
                    );
                  },
                ),
                ListTile(
                  leading:
                      const Icon(
                    Icons.access_time,
                    color:
                        Colors.orange,
                  ),
                  title:
                      const Text(
                    '最近代办',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    taskData.setHomeMode(
                      'recent',
                    );
                    Navigator.pop(
                      context,
                    );
                  },
                ),
                if (taskData
                    .myLists
                    .isNotEmpty) ...[
                  const Divider(
                    height: 20,
                    indent: 16,
                    endIndent: 16,
                  ),
                  const Padding(
                    padding:
                        EdgeInsets.only(
                      left: 16,
                      top: 4,
                      bottom: 4,
                    ),
                    child: Text(
                      '我的清单',
                      style:
                          TextStyle(
                        color:
                            Colors.grey,
                        fontWeight:
                            FontWeight.bold,
                        fontSize:
                            12,
                      ),
                    ),
                  ),
                  ...taskData.myLists.map(
                    (list) => ListTile(
                      leading: Icon(
                        Icons.circle,
                        size: 10,
                        color:
                            list.color,
                      ),
                      title: Text(
                        list.name,
                        style:
                            const TextStyle(
                          fontSize: 14,
                        ),
                      ),
                      dense: true,
                      visualDensity:
                          const VisualDensity(
                        horizontal: 0,
                        vertical: -4,
                      ),
                      contentPadding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 24,
                      ),
                      onTap: () {
                        taskData
                            .setHomeMode(
                          'list',
                          param:
                              list.name,
                        );
                        Navigator.pop(
                          context,
                        );
                      },
                      onLongPress: () =>
                          _showEditListDialog(
                        list,
                      ),
                    ),
                  ),
                ],
                if (taskData.myTags
                    .isNotEmpty) ...[
                  const Divider(
                    height: 20,
                    indent: 16,
                    endIndent: 16,
                  ),
                  const Padding(
                    padding:
                        EdgeInsets.only(
                      left: 16,
                      top: 4,
                      bottom: 8,
                    ),
                    child: Text(
                      '我的标签',
                      style:
                          TextStyle(
                        color:
                            Colors.grey,
                        fontWeight:
                            FontWeight.bold,
                        fontSize:
                            12,
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 16,
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children:
                          taskData.myTags
                              .map(
                        (tagName) =>
                            GestureDetector(
                          onTap: () {
                            taskData
                                .setHomeMode(
                              'tag',
                              param:
                                  tagName,
                            );
                            Navigator.pop(
                              context,
                            );
                          },
                          onLongPress:
                              () =>
                                  _showEditTagDialog(
                            tagName,
                          ),
                          child:
                              Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal:
                                  12,
                              vertical:
                                  8,
                            ),
                            decoration:
                                BoxDecoration(
                              color: Colors
                                  .lightBlue
                                  .shade50,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                16,
                              ),
                            ),
                            child: Text(
                              tagName,
                              style:
                                  const TextStyle(
                                fontSize:
                                    12,
                                color:
                                    Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      )
                              .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),

          appBar: AppBar(
            elevation: 0,
            backgroundColor:
                const Color(
              0xFFE6F1FB,
            ),
            iconTheme:
                const IconThemeData(
              color:
                  Colors.lightBlue,
            ),
            centerTitle:
                taskData.currentHomeMode !=
                    'todo',
            title: Text(
              appBarTitle,
              style:
                  TextStyle(
                color:
                    appBarColor,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                icon: Badge(
                  isLabelVisible:
                      taskData
                          .inboxTasks
                          .isNotEmpty,
                  backgroundColor:
                      Colors.lightBlue,
                  label: Text(
                    '${taskData.inboxTasks.length}',
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontSize:
                          11,
                    ),
                  ),
                  child:
                      const Icon(
                    Icons.inbox,
                  ),
                ),
                onPressed:
                    _showInboxMenu,
              ),
            ],
          ),

          body:
              taskData.currentHomeMode ==
                      'todo'
                  ? _buildTodoBody()
                  : _buildGroupedBody(),

          floatingActionButton:
              FloatingActionButton(
            elevation: 2,
            backgroundColor:
                Colors.lightBlue,
            foregroundColor:
                Colors.white,
            onPressed: () {
              showTaskBottomSheet(
                context,
                defaultDate:
                    taskData.currentHomeMode ==
                            'todo'
                        ? _selectedDate
                        : DateTime.now(),
                defaultList:
                    taskData.currentHomeMode ==
                            'list'
                        ? taskData
                            .currentHomeParam
                        : null,
                defaultTags:
                    taskData.currentHomeMode ==
                            'tag'
                        ? [
                            taskData
                                .currentHomeParam!
                          ]
                        : null,
              );
            },
            child: const Icon(
              Icons.add,
              size: 28,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTodoBody() {
    final weekStrings = [
      '一',
      '二',
      '三',
      '四',
      '五',
      '六',
      '日',
    ];

    return Column(
      children: [
        Container(
          color:
              const Color(0xFFE6F1FB),
          padding:
              const EdgeInsets.only(
            bottom: 16,
          ),
          child: Container(
            height: 70,
            constraints:
                const BoxConstraints(
              maxHeight: 70,
            ),
            child:
                PageView.builder(
              controller:
                  _pageController,
              itemBuilder:
                  (
                context,
                pageIndex,
              ) {
                final offset =
                    pageIndex - 500;

                final monday =
                    _baseMonday.add(
                  Duration(
                    days:
                        offset * 7,
                  ),
                );

                final weekDays =
                    List.generate(
                  7,
                  (i) =>
                      monday.add(
                    Duration(
                      days: i,
                    ),
                  ),
                );

                return Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceEvenly,
                  children:
                      weekDays.map(
                    (date) {
                      final isSelected =
                          date.year ==
                                  _selectedDate
                                      .year &&
                              date.month ==
                                  _selectedDate
                                      .month &&
                              date.day ==
                                  _selectedDate
                                      .day;

                      final isToday =
                          date.year ==
                                  DateTime.now()
                                      .year &&
                              date.month ==
                                  DateTime.now()
                                      .month &&
                              date.day ==
                                  DateTime.now()
                                      .day;

                      return GestureDetector(
                        onTap: () {
                          setState(
                            () {
                              _selectedDate =
                                  date;
                            },
                          );
                        },
                        child:
                            Container(
                          width: 40,
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            vertical:
                                4,
                          ),
                          decoration:
                              BoxDecoration(
                            color: isSelected
                                ? Colors
                                    .lightBlue
                                : Colors
                                    .transparent,
                            borderRadius:
                                BorderRadius
                                    .circular(
                              8,
                            ),
                          ),
                          child:
                              Column(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .center,
                            children: [
                              Text(
                                weekStrings[
                                    date.weekday -
                                        1],
                                style:
                                    TextStyle(
                                  fontSize:
                                      10,
                                  color: isSelected
                                      ? Colors.white
                                      : (date.weekday >= 6
                                          ? Colors.lightBlue
                                          : Colors.grey),
                                ),
                              ),
                              const SizedBox(
                                height: 4,
                              ),
                              Text(
                                '${date.day}',
                                style:
                                    TextStyle(
                                  fontSize:
                                      16,
                                  fontWeight:
                                      isToday
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(
                                height: 2,
                              ),
                              if (isToday)
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration:
                                      const BoxDecoration(
                                    color:
                                        Colors.lightBlue,
                                    shape:
                                        BoxShape.circle,
                                  ),
                                )
                              else
                                const SizedBox(
                                  height: 4,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ).toList(),
                );
              },
            ),
          ),
        ),

        Expanded(
          child: Builder(
            builder: (context) {
              final dailyTasks =
                  taskData.getTasksByDate(
                _selectedDate,
              );

              if (dailyTasks.isEmpty) {
                return const Center(
                  child: Text(
                    '这天没有安排待办',
                    style:
                        TextStyle(
                      color:
                          Colors.grey,
                    ),
                  ),
                );
              }

              return ReorderableListView.builder(
                padding:
                    EdgeInsets.zero,
                itemCount:
                    dailyTasks.length,
                onReorder:
                    (
                  oldIndex,
                  newIndex,
                ) =>
                        taskData
                            .reorderDailyTasks(
                  _selectedDate,
                  oldIndex,
                  newIndex,
                ),
                itemBuilder:
                    (
                  context,
                  index,
                ) {
                  final task =
                      dailyTasks[index];

                  return Material(
                    key: ValueKey(
                      'todo_mat_${task.id}',
                    ),
                    color:
                        Colors.transparent,
                    child:
                        _buildTaskTile(
                      task,
                      _selectedDate,
                    ),
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
    final tasks =
        taskData.allTasks.where(
      (t) {
        if (taskData.currentHomeMode ==
                'list' &&
            t.listName !=
                taskData.currentHomeParam) {
          return false;
        }

        if (taskData.currentHomeMode ==
                'tag' &&
            !t.tags.contains(
              taskData.currentHomeParam,
            )) {
          return false;
        }

        return true;
      },
    ).toList();

    if (tasks.isEmpty) {
      return const Center(
        child: Text(
          '这里空空如也~',
          style:
              TextStyle(
            color: Colors.grey,
          ),
        ),
      );
    }

    final pastDone =
        <Task>[];

    final pastUndone =
        <Task>[];

    final todayT =
        <Task>[];

    final tomorrowT =
        <Task>[];

    final dayAfterT =
        <Task>[];

    final laterT =
        <Task>[];

    final noDateT =
        <Task>[];

    final now =
        DateTime.now();

    final today =
        DateTime(
      now.year,
      now.month,
      now.day,
    );

    final tomorrow =
        today.add(
      const Duration(days: 1),
    );

    final dayAfter =
        today.add(
      const Duration(days: 2),
    );

    for (final t in tasks) {
      if (t.date == null) {
        noDateT.add(t);
        continue;
      }

      final d = DateTime(
        t.date!.year,
        t.date!.month,
        t.date!.day,
      );

      if (d.isBefore(today)) {
        /*
         * 事件没有完成状态。
         * 所以不会进入“过去完成 / 过去未完成”。
         */
        if (t.isEvent) {
          laterT.add(t);
        } else if (t.isDone) {
          pastDone.add(t);
        } else {
          pastUndone.add(t);
        }
      } else if (d.isAtSameMomentAs(
        today,
      )) {
        todayT.add(t);
      } else if (d.isAtSameMomentAs(
        tomorrow,
      )) {
        tomorrowT.add(t);
      } else if (d.isAtSameMomentAs(
        dayAfter,
      )) {
        dayAfterT.add(t);
      } else {
        laterT.add(t);
      }
    }

    final List<dynamic>
        flatItems = [];

    void addGroup(
      String title,
      List<Task> list,
    ) {
      if (list.isEmpty) {
        return;
      }

      flatItems.add(title);

      if (_groupExpanded[title] ==
          true) {
        flatItems.addAll(list);
      }
    }

    addGroup(
      '过去完成',
      pastDone,
    );
    addGroup(
      '过去未完成',
      pastUndone,
    );
    addGroup(
      '今天',
      todayT,
    );
    addGroup(
      '明天',
      tomorrowT,
    );
    addGroup(
      '后天',
      dayAfterT,
    );
    addGroup(
      '后续',
      laterT,
    );
    addGroup(
      '无日期 (待办箱)',
      noDateT,
    );

    return ReorderableListView.builder(
      padding:
          const EdgeInsets.only(
        bottom: 80,
      ),
      buildDefaultDragHandles:
          false,
      itemCount:
          flatItems.length,
      onReorder:
          (
        oldIndex,
        newIndex,
      ) {
        if (oldIndex <
            newIndex) {
          newIndex -= 1;
        }

        final item =
            flatItems[oldIndex];

        if (item is String) {
          return;
        }

        final task =
            item as Task;

        String? newGroupName;

        for (
          int i = newIndex;
          i >= 0;
          i--
        ) {
          if (i <
                  flatItems
                      .length &&
              flatItems[i] is String) {
            newGroupName =
                flatItems[i] as String;
            break;
          }
        }

        newGroupName ??=
            '今天';

        Task? anchorTask;
        bool insertAfter = false;

        if (newIndex <
                flatItems.length &&
            flatItems[newIndex] is Task) {
          anchorTask =
              flatItems[newIndex]
                  as Task;

          insertAfter = false;
        } else if (newIndex - 1 >=
                0 &&
            flatItems[newIndex - 1]
                is Task) {
          anchorTask =
              flatItems[newIndex - 1]
                  as Task;

          insertAfter = true;
        }

        DateTime? targetDate =
            task.date;

        if (newGroupName ==
            '今天') {
          targetDate =
              today;
        } else if (newGroupName ==
            '明天') {
          targetDate =
              today.add(
            const Duration(
              days: 1,
            ),
          );
        } else if (newGroupName ==
            '后天') {
          targetDate =
              today.add(
            const Duration(
              days: 2,
            ),
          );
        } else if (newGroupName ==
            '后续') {
          targetDate =
              today.add(
            const Duration(
              days: 3,
            ),
          );
        } else if (newGroupName ==
            '无日期 (待办箱)') {
          targetDate = null;
        } else if (newGroupName ==
                '过去未完成' ||
            newGroupName ==
                '过去完成') {
          if (task.date == null ||
              task.date!.isAfter(
                today,
              ) ||
              task.date!
                  .isAtSameMomentAs(
                today,
              )) {
            targetDate =
                today.subtract(
              const Duration(
                days: 1,
              ),
            );
          }
        }

        taskData.moveTaskGlobally(
          task,
          targetDate,
          anchorTask,
          insertAfter,
        );
      },
      itemBuilder:
          (context, index) {
        final item =
            flatItems[index];

        if (item is String) {
          return Container(
            key: ValueKey(
              'header_$item',
            ),
            color:
                Colors.white,
            child: ListTile(
              title: Text(
                '$item',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              trailing: Icon(
                _groupExpanded[item] ==
                        true
                    ? Icons.expand_less
                    : Icons.expand_more,
                color:
                    Colors.grey,
              ),
              onTap: () {
                setState(
                  () {
                    _groupExpanded[
                            item] =
                        !_groupExpanded[
                            item]!;
                  },
                );
              },
            ),
          );
        }

        final task =
            item as Task;

        return ReorderableDelayedDragStartListener(
          key: ValueKey(
            'task_drag_${task.id}',
          ),
          index: index,
          child: Material(
            color:
                Colors.transparent,
            child:
                _buildTaskTile(
              task,
              task.date,
            ),
          ),
        );
      },
    );
  }

  Future<bool?> _askRepeatAction(
    BuildContext context,
    String actionName,
  ) async {
    return showDialog<bool>(
      context: context,
      builder: (c) =>
          AlertDialog(
        title: Text(
          actionName,
          style:
              const TextStyle(
            color:
                Colors.lightBlue,
          ),
        ),
        content:
            const Text(
          '这是一个重复事件，您希望将操作应用到哪些事件？',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(
              c,
              false,
            ),
            child:
                const Text(
              '仅当前事件',
              style:
                  TextStyle(
                color:
                    Colors.black87,
              ),
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(
              c,
              true,
            ),
            child:
                const Text(
              '所有后续事件',
              style:
                  TextStyle(
                color:
                    Colors.lightBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTile(
    Task task,
    DateTime? defaultDate,
  ) {
    final listColor =
        taskData.getListColor(
      task.listName ?? '',
    );

    return Slidable(
      key: ValueKey(
        'slidable_${task.id}',
      ),
      endActionPane:
          ActionPane(
        motion:
            const ScrollMotion(),
        extentRatio:
            0.6,
        children: [
          SlidableAction(
            onPressed:
                (context) async {
              bool doAll = false;

              if (task.repeatGroupId !=
                  null) {
                final result =
                    await _askRepeatAction(
                  context,
                  '置顶',
                );

                if (result == null) {
                  return;
                }

                doAll = result;
              }

              taskData.pinTaskGlobally(
                task,
                true,
                pinAllFuture:
                    doAll,
              );
            },
            backgroundColor:
                Colors.blue.shade400,
            foregroundColor:
                Colors.white,
            icon:
                Icons.vertical_align_top,
            label:
                '置顶',
          ),
          SlidableAction(
            onPressed:
                (context) async {
              bool doAll = false;

              if (task.repeatGroupId !=
                  null) {
                final result =
                    await _askRepeatAction(
                  context,
                  '置底',
                );

                if (result == null) {
                  return;
                }

                doAll = result;
              }

              taskData.pinTaskGlobally(
                task,
                false,
                pinAllFuture:
                    doAll,
              );
            },
            backgroundColor:
                Colors.grey.shade600,
            foregroundColor:
                Colors.white,
            icon:
                Icons.vertical_align_bottom,
            label:
                '置底',
          ),
          SlidableAction(
            onPressed:
                (context) async {
              bool doAll = false;

              if (task.repeatGroupId !=
                  null) {
                final result =
                    await _askRepeatAction(
                  context,
                  '删除',
                );

                if (result == null) {
                  return;
                }

                doAll = result;
              }

              taskData.deleteTask(
                task.id,
                deleteAllFuture:
                    doAll,
              );
            },
            backgroundColor:
                Colors.red.shade400,
            foregroundColor:
                Colors.white,
            icon:
                Icons.delete,
            label:
                '删除',
          ),
        ],
      ),
      child: Container(
        decoration:
            BoxDecoration(
          color:
              Colors.white,
          border:
              Border(
            bottom:
                BorderSide(
              color: Colors
                  .grey
                  .shade100,
              width: 1,
            ),
          ),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets
                  .symmetric(
            horizontal: 16,
          ),
          minLeadingWidth: 24,

          /*
           * 事件不显示完成按钮。
           */
          leading: task.isEvent
              ? const SizedBox(
                  width: 24,
                  height: 24,
                )
              : SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value:
                        task.isDone,
                    activeColor:
                        listColor,
                    side:
                        BorderSide(
                      color:
                          listColor,
                      width: 2,
                    ),
                    onChanged:
                        (_) =>
                            taskData
                                .toggleTaskDone(
                      task.id,
                    ),
                  ),
                ),

          onTap: () =>
              showTaskBottomSheet(
            context,
            existingTask:
                task,
            defaultDate:
                defaultDate,
          ),

          title: Wrap(
            crossAxisAlignment:
                WrapCrossAlignment
                    .center,
            spacing: 6,
            children: [
              Text(
                task.title,
                style:
                    TextStyle(
                  decoration:
                      (!task.isEvent &&
                              task.isDone)
                          ? TextDecoration
                              .lineThrough
                          : null,
                  color:
                      task.isEvent
                          ? Colors
                              .black87
                          : (task.isDone
                              ? Colors
                                  .grey
                              : Colors
                                  .black87),
                ),
              ),

              if (task.repeatGroupId !=
                  null)
                const Icon(
                  Icons.repeat,
                  size: 14,
                  color:
                      Colors.lightBlue,
                ),

              ...task.tags.map(
                (tag) =>
                    Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Colors
                        .lightBlue
                        .shade50,
                    borderRadius:
                        BorderRadius
                            .circular(
                      4,
                    ),
                  ),
                  child: Text(
                    tag,
                    style:
                        const TextStyle(
                      fontSize: 10,
                      color: Colors
                          .lightBlue,
                    ),
                  ),
                ),
              ),
            ],
          ),

          subtitle:
              (task.description
                          .isNotEmpty ||
                      task.time != null ||
                      task.repeatRuleText !=
                          null)
                  ? Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        if (task.description
                            .isNotEmpty)
                          Text(
                            task.description,
                            style:
                                const TextStyle(
                              fontSize:
                                  13,
                            ),
                          ),
                        Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                            top: 4,
                            bottom: 4,
                          ),
                          child:
                              Row(
                            children: [
                              if (task.time !=
                                  null) ...[
                                const Icon(
                                  Icons
                                      .access_time,
                                  size:
                                      12,
                                  color: Colors
                                      .grey,
                                ),
                                const SizedBox(
                                  width:
                                      4,
                                ),
                                Text(
                                  task.time!
                                      .format(
                                    context,
                                  ),
                                  style:
                                      const TextStyle(
                                    fontSize:
                                        12,
                                    color:
                                        Colors.grey,
                                  ),
                                ),
                              ],
                              if (task.repeatRuleText !=
                                  null) ...[
                                if (task.time !=
                                    null)
                                  const SizedBox(
                                    width:
                                        8,
                                  ),
                                Text(
                                  task.repeatRuleText!,
                                  style:
                                      const TextStyle(
                                    fontSize:
                                        12,
                                    color: Colors
                                        .lightBlue,
                                  ),
                                ),
                              ],
                              if (task.addToCalendar) ...[
                                const SizedBox(
                                  width:
                                      8,
                                ),
                                const Icon(
                                  Icons
                                      .event_available,
                                  size:
                                      12,
                                  color:
                                      Colors.green,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    )
                  : null,

          /*
           * 事件不显示专注按钮。
           */
          trailing: task.isEvent
              ? null
              : IconButton(
                  icon:
                      const Icon(
                    Icons.alarm,
                    color:
                        Colors.lightBlue,
                  ),
                  onPressed: () {
                    taskData.setFocusTask(
                      task,
                    );

                    appTabIndex.value =
                        2;
                  },
                ),
        ),
      ),
    );
  }
}
