import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart'
    as dc;
import 'package:timezone/data/latest_all.dart'
    as tz;
import 'package:timezone/timezone.dart'
    as tz;

import '../models/task_data.dart';

bool _calendarTimeZonesInitialized =
    false;

void _ensureCalendarTimeZones() {
  if (!_calendarTimeZonesInitialized) {
    tz.initializeTimeZones();
    _calendarTimeZonesInitialized =
        true;
  }
}

String _calendarErrors(
  dc.Result<dynamic>? result,
) {
  if (result == null) {
    return '未知错误：插件没有返回结果';
  }

  if (result.errors.isEmpty) {
    return '未知错误';
  }

  return result.errors
      .map(
        (e) => e.errorMessage,
      )
      .join('；');
}

void _showCalendarSnackBar(
  BuildContext context,
  String message,
) {
  if (!context.mounted) {
    return;
  }

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(
    SnackBar(
      content: Text(message),
      duration:
          const Duration(seconds: 2),
    ),
  );
}

Future<String?>
    _createSystemCalendarEvent({
  required BuildContext context,
  required String title,
  required String description,
  required DateTime? date,
  required TimeOfDay? time,
  RepeatConfig? repeatConfig,
}) async {
  if (date == null) {
    _showCalendarSnackBar(
      context,
      '请先选择日期，再添加到系统日程',
    );

    return null;
  }

  _ensureCalendarTimeZones();

  final dcPlugin =
      dc.DeviceCalendarPlugin();

  var permission =
      await dcPlugin.hasPermissions();

  if (!permission.isSuccess ||
      !(permission.data ?? false)) {
    permission =
        await dcPlugin.requestPermissions();
  }

  if (!permission.isSuccess ||
      !(permission.data ?? false)) {
    _showCalendarSnackBar(
      context,
      '需要允许日历权限才能添加日程',
    );

    return null;
  }

  final calendarsResult =
      await dcPlugin.retrieveCalendars();

  if (!calendarsResult.isSuccess) {
    _showCalendarSnackBar(
      context,
      '获取系统日历失败',
    );

    return null;
  }

  final calendars =
      calendarsResult.data?.toList() ??
          [];

  final writableCalendars =
      calendars
          .where(
            (c) =>
                c.id != null &&
                !(c.isReadOnly ?? false),
          )
          .toList();

  dc.Calendar? targetCalendar;

  for (final c
      in writableCalendars) {
    if (c.isDefault == true) {
      targetCalendar = c;
      break;
    }
  }

  targetCalendar ??=
      writableCalendars.isNotEmpty
          ? writableCalendars.first
          : null;

  String? calendarId =
      targetCalendar?.id;

  if (calendarId == null) {
    final createCalendarResult =
        await dcPlugin.createCalendar(
      'Monenta',
    );

    if (createCalendarResult.isSuccess &&
        createCalendarResult.data !=
            null) {
      calendarId =
          createCalendarResult.data;
    } else {
      _showCalendarSnackBar(
        context,
        '没有可写日历',
      );

      return null;
    }
  }

  final chinaLocation =
      tz.getLocation(
    'Asia/Shanghai',
  );

  final start = tz.TZDateTime(
    chinaLocation,
    date.year,
    date.month,
    date.day,
    time?.hour ?? 0,
    time?.minute ?? 0,
  );

  final end = time == null
      ? start.add(
          const Duration(days: 1),
        )
      : start.add(
          const Duration(minutes: 5),
        );

  final event = dc.Event(
    calendarId,
    title: title.trim().isEmpty
        ? '新事件'
        : title.trim(),
    description:
        description.trim(),
    start: start,
    end: end,
    allDay: time == null,
  );

  if (repeatConfig != null) {
    dc.RecurrenceFrequency freq =
        dc.RecurrenceFrequency.Daily;

    if (repeatConfig.unit == 'week') {
      freq =
          dc.RecurrenceFrequency.Weekly;
    }

    if (repeatConfig.unit == 'month') {
      freq =
          dc.RecurrenceFrequency.Monthly;
    }

    if (repeatConfig.unit == 'year') {
      freq =
          dc.RecurrenceFrequency.Yearly;
    }

    event.recurrenceRule =
        dc.RecurrenceRule(
      freq,
      interval:
          repeatConfig.interval,
      endDate:
          repeatConfig.endDate,
    );
  }

  final saveResult =
      await dcPlugin.createOrUpdateEvent(
    event,
  );

  if (saveResult == null ||
      !saveResult.isSuccess ||
      saveResult.data == null) {
    _showCalendarSnackBar(
      context,
      '系统日程创建失败：${_calendarErrors(saveResult)}',
    );

    return null;
  }

  return saveResult.data;
}

void showTaskBottomSheet(
  BuildContext context, {
  Task? existingTask,
  DateTime? defaultDate,
  String? defaultList,
  List<String>? defaultTags,
}) {
  final TextEditingController
      titleController =
      TextEditingController(
    text: existingTask?.title ?? '',
  );

  final TextEditingController
      descController =
      TextEditingController(
    text:
        existingTask?.description ??
            '',
  );

  DateTime? taskDate =
      existingTask != null
          ? existingTask.date
          : defaultDate;

  TimeOfDay? selectedTime =
      existingTask?.time;

  bool addToCalendar =
      existingTask?.addToCalendar ??
          false;

  bool isEvent =
      existingTask?.isEvent ??
          false;

  String? selectedList =
      existingTask?.listName ??
          defaultList;

  List<String> selectedTags =
      existingTask?.tags.toList() ??
          defaultTags ??
          [];

  RepeatConfig? currentRepeat;

  bool isToday(
    DateTime? d,
  ) {
    if (d == null) {
      return false;
    }

    final now = DateTime.now();

    return d.year == now.year &&
        d.month == now.month &&
        d.day == now.day;
  }

  bool isTomorrow(
    DateTime? d,
  ) {
    if (d == null) {
      return false;
    }

    final tomorrow =
        DateTime.now().add(
      const Duration(days: 1),
    );

    return d.year == tomorrow.year &&
        d.month == tomorrow.month &&
        d.day == tomorrow.day;
  }

  bool isCustom(
    DateTime? d,
  ) {
    return d != null &&
        !isToday(d) &&
        !isTomorrow(d);
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (context) {
      return StatefulBuilder(
        builder: (
          context,
          setModalState,
        ) {
          void _showNewListDialog() {
            final ctrl =
                TextEditingController();

            Color selectedColor =
                Colors.blue;

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

            bool showCustomColor =
                false;

            final rCtrl =
                TextEditingController(
              text: selectedColor.red
                  .toString(),
            );

            final gCtrl =
                TextEditingController(
              text: selectedColor.green
                  .toString(),
            );

            final bCtrl =
                TextEditingController(
              text: selectedColor.blue
                  .toString(),
            );

            Widget _buildRgbInput(
              String label,
              TextEditingController
                  textCtrl,
              StateSetter setState,
            ) {
              return Padding(
                padding:
                    const EdgeInsets
                        .symmetric(
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
                    const SizedBox(
                      width: 4,
                    ),
                    SizedBox(
                      width: 42,
                      height: 32,
                      child: TextField(
                        controller:
                            textCtrl,
                        keyboardType:
                            TextInputType
                                .number,
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
                                BorderRadius
                                    .circular(
                              6,
                            ),
                          ),
                        ),
                        onChanged: (val) {
                          final r =
                              int.tryParse(
                                    rCtrl.text,
                                  ) ??
                                  selectedColor
                                      .red;

                          final g =
                              int.tryParse(
                                    gCtrl.text,
                                  ) ??
                                  selectedColor
                                      .green;

                          final b =
                              int.tryParse(
                                    bCtrl.text,
                                  ) ??
                                  selectedColor
                                      .blue;

                          setState(() {
                            selectedColor =
                                Color.fromARGB(
                              255,
                              r.clamp(
                                0,
                                255,
                              ),
                              g.clamp(
                                0,
                                255,
                              ),
                              b.clamp(
                                0,
                                255,
                              ),
                            );
                          });
                        },
                      ),
                    ),
                  ],
                ),
              );
            }

            void _updateFromWheel(
              double hue,
              double saturation,
              StateSetter setState,
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
                    selectedColor.red
                        .toString();

                gCtrl.text =
                    selectedColor.green
                        .toString();

                bCtrl.text =
                    selectedColor.blue
                        .toString();
              });
            }

            showDialog(
              context: context,
              builder: (ctx) {
                return StatefulBuilder(
                  builder: (
                    ctx,
                    setState,
                  ) {
                    return AlertDialog(
                      title: const Text(
                        '新建清单',
                        style:
                            TextStyle(
                          color:
                              Colors.lightBlue,
                        ),
                      ),
                      content: Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          TextField(
                            controller:
                                ctrl,
                            autofocus: true,
                            decoration:
                                const InputDecoration(
                              hintText:
                                  '清单名称',
                            ),
                          ),
                          const SizedBox(
                            height: 16,
                          ),
                          if (!showCustomColor)
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                ...colors.map(
                                  (c) =>
                                      GestureDetector(
                                    onTap: () =>
                                        setState(() {
                                      selectedColor =
                                          c;

                                      rCtrl.text =
                                          c.red
                                              .toString();

                                      gCtrl.text =
                                          c.green
                                              .toString();

                                      bCtrl.text =
                                          c.blue
                                              .toString();
                                    }),
                                    child:
                                        CircleAvatar(
                                      backgroundColor:
                                          c,
                                      radius:
                                          16,
                                      child: selectedColor ==
                                              c
                                          ? const Icon(
                                              Icons.check,
                                              color:
                                                  Colors.white,
                                              size:
                                                  16,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      setState(
                                    () =>
                                        showCustomColor =
                                            true,
                                  ),
                                  child:
                                      const CircleAvatar(
                                    backgroundColor:
                                        Colors.grey,
                                    radius:
                                        16,
                                    child:
                                        Icon(
                                      Icons.palette,
                                      color:
                                          Colors.white,
                                      size:
                                          16,
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
                                            details.localPosition.dx -
                                                radius;

                                        final dy =
                                            details.localPosition.dy -
                                                radius;

                                        double angle =
                                            atan2(
                                          dy,
                                          dx,
                                        );

                                        if (angle <
                                            0) {
                                          angle +=
                                              2 *
                                                  pi;
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

                                        _updateFromWheel(
                                          hue,
                                          saturation,
                                          setState,
                                        );
                                      },
                                      onTapDown:
                                          (details) {
                                        const radius =
                                            75.0;

                                        final dx =
                                            details.localPosition.dx -
                                                radius;

                                        final dy =
                                            details.localPosition.dy -
                                                radius;

                                        double angle =
                                            atan2(
                                          dy,
                                          dx,
                                        );

                                        if (angle <
                                            0) {
                                          angle +=
                                              2 *
                                                  pi;
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

                                        _updateFromWheel(
                                          hue,
                                          saturation,
                                          setState,
                                        );
                                      },
                                      child:
                                          Container(
                                        width:
                                            150,
                                        height:
                                            150,
                                        decoration:
                                            const BoxDecoration(
                                          shape:
                                              BoxShape.circle,
                                          gradient:
                                              SweepGradient(
                                            colors: [
                                              Color.fromARGB(
                                                255,
                                                255,
                                                0,
                                                0,
                                              ),
                                              Color.fromARGB(
                                                255,
                                                255,
                                                255,
                                                0,
                                              ),
                                              Color.fromARGB(
                                                255,
                                                0,
                                                255,
                                                0,
                                              ),
                                              Color.fromARGB(
                                                255,
                                                0,
                                                255,
                                                255,
                                              ),
                                              Color.fromARGB(
                                                255,
                                                0,
                                                0,
                                                255,
                                              ),
                                              Color.fromARGB(
                                                255,
                                                255,
                                                0,
                                                255,
                                              ),
                                              Color.fromARGB(
                                                255,
                                                255,
                                                0,
                                                0,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Builder(
                                      builder:
                                          (context) {
                                        final hsv =
                                            HSVColor.fromColor(
                                          selectedColor,
                                        );

                                        final angle =
                                            hsv.hue *
                                                pi /
                                                180;

                                        final distance =
                                            hsv.saturation *
                                                75;

                                        return Transform.translate(
                                          offset:
                                              Offset(
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
                                            width:
                                                20,
                                            height:
                                                20,
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
                                                width:
                                                    2,
                                              ),
                                              boxShadow:
                                                  const [
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
                                      MainAxisAlignment.center,
                                  children: [
                                    _buildRgbInput(
                                      'R',
                                      rCtrl,
                                      setState,
                                    ),
                                    _buildRgbInput(
                                      'G',
                                      gCtrl,
                                      setState,
                                    ),
                                    _buildRgbInput(
                                      'B',
                                      bCtrl,
                                      setState,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(
                            ctx,
                          ),
                          child:
                              const Text(
                            '取消',
                            style:
                                TextStyle(
                              color:
                                  Colors.grey,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            if (ctrl.text
                                .trim()
                                .isNotEmpty) {
                              taskData.addList(
                                ctrl.text.trim(),
                                selectedColor,
                              );

                              setModalState(
                                () {
                                  selectedList =
                                      ctrl.text.trim();
                                },
                              );

                              Navigator.pop(
                                ctx,
                              );
                            }
                          },
                          child:
                              const Text(
                            '保存',
                            style:
                                TextStyle(
                              color:
                                  Colors.lightBlue,
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

          void _showNewTagDialog() {
            final ctrl =
                TextEditingController();

            showDialog(
              context: context,
              builder: (ctx) {
                return AlertDialog(
                  title: const Text(
                    '新建标签',
                    style:
                        TextStyle(
                      color:
                          Colors.lightBlue,
                    ),
                  ),
                  content: TextField(
                    controller:
                        ctrl,
                    autofocus: true,
                    decoration:
                        const InputDecoration(
                      hintText:
                          '标签名称',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(
                        ctx,
                      ),
                      child:
                          const Text(
                        '取消',
                        style:
                            TextStyle(
                          color:
                              Colors.grey,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        if (ctrl.text
                            .trim()
                            .isNotEmpty) {
                          taskData.addTag(
                            ctrl.text
                                .trim(),
                          );

                          setModalState(
                            () {
                              selectedTags
                                  .add(
                                ctrl.text
                                    .trim(),
                              );
                            },
                          );

                          Navigator.pop(
                            ctx,
                          );
                        }
                      },
                      child:
                          const Text(
                        '保存',
                        style:
                            TextStyle(
                          color:
                              Colors.lightBlue,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          }

          void _showTimeAndCalendarDialog()
              async {
            TimeOfDay? pickedTime =
                selectedTime ??
                    TimeOfDay.now();

            bool tempAdd =
                addToCalendar;

            await showDialog(
              context: context,
              builder: (ctx) {
                return StatefulBuilder(
                  builder: (
                    ctx,
                    setDialogState,
                  ) {
                    return AlertDialog(
                      title: const Text(
                        '设置时间与日程',
                        style:
                            TextStyle(
                          color:
                              Colors.lightBlue,
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      content: Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          ListTile(
                            contentPadding:
                                EdgeInsets.zero,
                            title: Text(
                              pickedTime!.format(
                                context,
                              ),
                              style:
                                  const TextStyle(
                                fontSize:
                                    32,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            trailing:
                                const Icon(
                              Icons
                                  .edit_calendar,
                              color: Colors
                                  .lightBlue,
                            ),
                            onTap: () async {
                              final t =
                                  await showTimePicker(
                                context:
                                    ctx,
                                initialTime:
                                    pickedTime!,
                              );

                              if (t != null) {
                                setDialogState(
                                  () =>
                                      pickedTime =
                                          t,
                                );
                              }
                            },
                          ),
                          const Divider(),
                          SwitchListTile(
                            contentPadding:
                                EdgeInsets.zero,
                            title: const Text(
                              '添加到系统日程',
                              style:
                                  TextStyle(
                                fontSize:
                                    15,
                              ),
                            ),
                            subtitle:
                                const Text(
                              '后台静默同步到系统日历',
                              style:
                                  TextStyle(
                                fontSize:
                                    12,
                                color:
                                    Colors.grey,
                              ),
                            ),
                            value: tempAdd,
                            activeColor:
                                Colors
                                    .lightBlue,
                            onChanged:
                                (val) async {
                              if (val) {
                                if (taskDate ==
                                    null) {
                                  _showCalendarSnackBar(
                                    context,
                                    '请先选择日期，再添加到系统日程',
                                  );

                                  setDialogState(
                                    () =>
                                        tempAdd =
                                            false,
                                  );

                                  return;
                                }

                                final plugin =
                                    dc.DeviceCalendarPlugin();

                                var status =
                                    await plugin.hasPermissions();

                                if (!status.isSuccess ||
                                    !(status.data ??
                                        false)) {
                                  status =
                                      await plugin.requestPermissions();
                                }

                                if (status.isSuccess &&
                                    (status.data ??
                                        false)) {
                                  setDialogState(
                                    () =>
                                        tempAdd =
                                            true,
                                  );
                                } else {
                                  _showCalendarSnackBar(
                                    context,
                                    '需要允许日历权限才能添加日程',
                                  );

                                  setDialogState(
                                    () =>
                                        tempAdd =
                                            false,
                                  );
                                }
                              } else {
                                setDialogState(
                                  () =>
                                      tempAdd =
                                          false,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            setModalState(
                              () {
                                selectedTime =
                                    null;
                                addToCalendar =
                                    false;
                              },
                            );

                            Navigator.pop(
                              ctx,
                            );
                          },
                          child:
                              const Text(
                            '清除时间',
                            style:
                                TextStyle(
                              color:
                                  Colors.red,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(
                            ctx,
                          ),
                          child:
                              const Text(
                            '取消',
                            style:
                                TextStyle(
                              color:
                                  Colors.grey,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(
                              () {
                                selectedTime =
                                    pickedTime;

                                addToCalendar =
                                    tempAdd;
                              },
                            );

                            Navigator.pop(
                              ctx,
                            );
                          },
                          child:
                              const Text(
                            '确定',
                            style:
                                TextStyle(
                              color:
                                  Colors.lightBlue,
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

          void _showRepeatDialog() {
            int tempInterval =
                currentRepeat?.interval ??
                    1;

            int tempUnitIdx =
                [
                  'day',
                  'week',
                  'month',
                  'year',
                ].indexOf(
              currentRepeat?.unit ??
                  'day',
            );

            DateTime? tempEndDate =
                currentRepeat?.endDate;

            final units = [
              '日',
              '周',
              '月',
              '年',
            ];

            final unitKeys = [
              'day',
              'week',
              'month',
              'year',
            ];

            showDialog(
              context: context,
              builder: (ctx) {
                return StatefulBuilder(
                  builder: (
                    ctx,
                    setDialogState,
                  ) {
                    return AlertDialog(
                      title: const Text(
                        '设置重复',
                        style:
                            TextStyle(
                          color:
                              Colors.lightBlue,
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      content: Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 150,
                            child: Row(
                              children: [
                                const Text(
                                  '每',
                                  style:
                                      TextStyle(
                                    fontSize:
                                        18,
                                  ),
                                ),
                                const SizedBox(
                                  width: 10,
                                ),
                                Expanded(
                                  child:
                                      CupertinoPicker(
                                    itemExtent:
                                        40,
                                    scrollController:
                                        FixedExtentScrollController(
                                      initialItem:
                                          tempInterval -
                                              1,
                                    ),
                                    onSelectedItemChanged:
                                        (i) {
                                      tempInterval =
                                          i +
                                              1;
                                    },
                                    children:
                                        List.generate(
                                      99,
                                      (i) =>
                                          Center(
                                        child:
                                            Text(
                                          '${i + 1}',
                                          style:
                                              const TextStyle(
                                            fontSize:
                                                20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child:
                                      CupertinoPicker(
                                    itemExtent:
                                        40,
                                    scrollController:
                                        FixedExtentScrollController(
                                      initialItem:
                                          tempUnitIdx,
                                    ),
                                    onSelectedItemChanged:
                                        (i) {
                                      tempUnitIdx =
                                          i;
                                    },
                                    children:
                                        units
                                            .map(
                                              (u) =>
                                                  Center(
                                                child:
                                                    Text(
                                                  u,
                                                  style:
                                                      const TextStyle(
                                                    fontSize:
                                                        20,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(),
                          ListTile(
                            contentPadding:
                                EdgeInsets.zero,
                            title: const Text(
                              '结束时间',
                              style:
                                  TextStyle(
                                fontSize:
                                    15,
                              ),
                            ),
                            trailing:
                                TextButton(
                              onPressed:
                                  () async {
                                final picked =
                                    await showDatePicker(
                                  context:
                                      ctx,
                                  initialDate:
                                      tempEndDate ??
                                          DateTime
                                              .now(),
                                  firstDate:
                                      DateTime(
                                    2020,
                                  ),
                                  lastDate:
                                      DateTime(
                                    2050,
                                  ),
                                  locale:
                                      const Locale(
                                    'zh',
                                    'CN',
                                  ),
                                );

                                if (picked !=
                                    null) {
                                  setDialogState(
                                    () =>
                                        tempEndDate =
                                            picked,
                                  );
                                }
                              },
                              child: Text(
                                tempEndDate !=
                                        null
                                    ? '${tempEndDate!.year}-${tempEndDate!.month}-${tempEndDate!.day}'
                                    : '永远重复',
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.lightBlue,
                                  fontSize:
                                      16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            setModalState(
                              () =>
                                  currentRepeat =
                                      null,
                            );

                            Navigator.pop(
                              ctx,
                            );
                          },
                          child:
                              const Text(
                            '清除重复',
                            style:
                                TextStyle(
                              color:
                                  Colors.red,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(
                            ctx,
                          ),
                          child:
                              const Text(
                            '取消',
                            style:
                                TextStyle(
                              color:
                                  Colors.grey,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(
                              () {
                                currentRepeat =
                                    RepeatConfig(
                                  groupId:
                                      DateTime
                                          .now()
                                          .millisecondsSinceEpoch
                                          .toString(),
                                  interval:
                                      tempInterval,
                                  unit:
                                      unitKeys[
                                          tempUnitIdx],
                                  endDate:
                                      tempEndDate,
                                );
                              },
                            );

                            Navigator.pop(
                              ctx,
                            );
                          },
                          child:
                              const Text(
                            '确定',
                            style:
                                TextStyle(
                              color:
                                  Colors.lightBlue,
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

          Future<int?>
              _askUpdateFuture() async {
            if (existingTask ==
                    null ||
                existingTask!
                        .repeatGroupId ==
                    null) {
              return 0;
            }

            return showDialog<int>(
              context: context,
              builder: (c) =>
                  AlertDialog(
                title: const Text(
                  '保存修改',
                  style:
                      TextStyle(
                    color:
                        Colors.lightBlue,
                  ),
                ),
                content: const Text(
                  '这是一个重复事件，您希望将修改应用到哪些事件？',
                ),
                actions: [
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(
                      c,
                      0,
                    ),
                    child:
                        const Text(
                      '仅修改当前事件',
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
                      1,
                    ),
                    child:
                        const Text(
                      '修改所有后续事件',
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

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(
                context,
              ).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                /*
                 * 代办 / 事件切换
                 * 放在清单栏上方。
                 */
                Align(
                  alignment:
                      Alignment.centerLeft,
                  child:
                      CupertinoSlidingSegmentedControl<
                          bool>(
                    groupValue:
                        isEvent,
                    children: const {
                      false: Padding(
                        padding:
                            EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 7,
                        ),
                        child: Text(
                          '代办',
                          style:
                              TextStyle(
                            fontSize:
                                12,
                          ),
                        ),
                      ),
                      true: Padding(
                        padding:
                            EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 7,
                        ),
                        child: Text(
                          '事件',
                          style:
                              TextStyle(
                            fontSize:
                                12,
                          ),
                        ),
                      ),
                    },
                    thumbColor:
                        Colors.lightBlue
                            .shade50,
                    backgroundColor:
                        Colors.grey
                            .shade100,
                    onValueChanged:
                        (value) {
                      if (value ==
                          null) {
                        return;
                      }

                      setModalState(
                        () {
                          isEvent = value;

                          /*
                           * 事件不允许存在完成状态。
                           */
                          if (isEvent) {
                            if (existingTask ==
                                null) {
                              // 新建事件默认未完成。
                            }
                          } else {
                            // 切回代办时不改变
                            // 已经选择的其他字段。
                          }
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                /*
                 * 切换按钮和清单栏之间的分隔线。
                 */
                const Divider(
                  height: 1,
                ),

                const SizedBox(
                  height: 8,
                ),

                /*
                 * 清单栏
                 *
                 * 原来的最左侧 Icons.list
                 * 已经移除。
                 */
                SingleChildScrollView(
                  scrollDirection:
                      Axis.horizontal,
                  child: Row(
                    children: [
                      ...taskData.myLists.map(
                        (list) =>
                            Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                            right: 8,
                          ),
                          child:
                              ChoiceChip(
                            label: Text(
                              list.name,
                              style:
                                  TextStyle(
                                color: selectedList ==
                                        list.name
                                    ? list.color
                                    : Colors
                                        .black87,
                              ),
                            ),
                            selected:
                                selectedList ==
                                    list.name,
                            selectedColor:
                                list.color
                                    .withOpacity(
                              0.1,
                            ),
                            backgroundColor:
                                Colors
                                    .grey
                                    .shade100,
                            side: BorderSide
                                .none,
                            onSelected:
                                (val) {
                              setModalState(
                                () {
                                  selectedList =
                                      val
                                          ? list.name
                                          : null;
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      ActionChip(
                        label:
                            const Text(
                          '+ 清单',
                          style:
                              TextStyle(
                            color: Colors
                                .lightBlue,
                            fontSize:
                                12,
                          ),
                        ),
                        backgroundColor:
                            Colors.white,
                        side:
                            BorderSide(
                          color: Colors
                              .lightBlue
                              .shade200,
                        ),
                        onPressed:
                            _showNewListDialog,
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                /*
                 * 事件：
                 * “会发生什么事？”
                 *
                 * 代办：
                 * “准备做什么？”
                 */
                TextField(
                  controller:
                      titleController,
                  decoration:
                      InputDecoration(
                    hintText: isEvent
                        ? '会发生什么事？'
                        : '准备做什么？',
                    border:
                        InputBorder.none,
                    hintStyle:
                        const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                TextField(
                  controller:
                      descController,
                  decoration:
                      const InputDecoration(
                    hintText:
                        '添加描述...',
                    border:
                        InputBorder.none,
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label:
                          const Text(
                        '今天',
                      ),
                      selected:
                          isToday(
                        taskDate,
                      ),
                      selectedColor:
                          Colors
                              .lightBlue
                              .shade100,
                      backgroundColor:
                          Colors
                              .grey
                              .shade100,
                      side: BorderSide.none,
                      onSelected:
                          (val) {
                        setModalState(
                          () {
                            taskDate =
                                DateTime.now();
                          },
                        );
                      },
                    ),
                    ChoiceChip(
                      label:
                          const Text(
                        '明天',
                      ),
                      selected:
                          isTomorrow(
                        taskDate,
                      ),
                      selectedColor:
                          Colors
                              .lightBlue
                              .shade100,
                      backgroundColor:
                          Colors
                              .grey
                              .shade100,
                      side: BorderSide.none,
                      onSelected:
                          (val) {
                        setModalState(
                          () {
                            taskDate =
                                DateTime.now()
                                    .add(
                              const Duration(
                                days: 1,
                              ),
                            );
                          },
                        );
                      },
                    ),
                    ChoiceChip(
                      label:
                          const Text(
                        '无日期',
                      ),
                      selected:
                          taskDate == null,
                      selectedColor:
                          Colors
                              .lightBlue
                              .shade100,
                      backgroundColor:
                          Colors
                              .grey
                              .shade100,
                      side: BorderSide.none,
                      onSelected:
                          (val) {
                        setModalState(
                          () {
                            taskDate =
                                null;

                            addToCalendar =
                                false;
                          },
                        );
                      },
                    ),
                    ActionChip(
                      label: Text(
                        isCustom(taskDate)
                            ? '${taskDate!.month}月${taskDate!.day}日'
                            : '自定日期',
                      ),
                      backgroundColor:
                          isCustom(
                        taskDate,
                      )
                              ? Colors
                                  .lightBlue
                                  .shade100
                              : Colors
                                  .grey
                                  .shade100,
                      side:
                          BorderSide.none,
                      avatar:
                          const Icon(
                        Icons
                            .calendar_month,
                        size: 16,
                        color: Colors
                            .lightBlue,
                      ),
                      onPressed:
                          () async {
                        final picked =
                            await showDatePicker(
                          context:
                              context,
                          initialDate:
                              taskDate ??
                                  DateTime
                                      .now(),
                          firstDate:
                              DateTime(
                            2020,
                          ),
                          lastDate:
                              DateTime(
                            2030,
                          ),
                          locale:
                              const Locale(
                            'zh',
                            'CN',
                          ),
                        );

                        if (picked !=
                            null) {
                          setModalState(
                            () =>
                                taskDate =
                                    picked,
                          );
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(
                  height: 10,
                ),

                SingleChildScrollView(
                  scrollDirection:
                      Axis.horizontal,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.tag,
                        color: Colors
                            .lightBlue,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      ...taskData.myTags
                          .map(
                        (tag) =>
                            Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                            right: 8,
                          ),
                          child:
                              FilterChip(
                            label:
                                Text(
                              tag,
                              style:
                                  TextStyle(
                                color: selectedTags.contains(
                                      tag,
                                    )
                                    ? Colors
                                        .lightBlue
                                    : Colors
                                        .black87,
                                fontSize:
                                    12,
                              ),
                            ),
                            selected:
                                selectedTags.contains(
                              tag,
                            ),
                            selectedColor:
                                Colors
                                    .lightBlue
                                    .shade50,
                            backgroundColor:
                                Colors.white,
                            side:
                                BorderSide(
                              color: selectedTags.contains(
                                      tag,
                                    )
                                  ? Colors
                                      .lightBlue
                                  : Colors
                                      .grey
                                      .shade300,
                            ),
                            onSelected:
                                (selected) {
                              setModalState(
                                () {
                                  if (selected) {
                                    selectedTags
                                        .add(
                                      tag,
                                    );
                                  } else {
                                    selectedTags
                                        .remove(
                                      tag,
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      ActionChip(
                        label:
                            const Text(
                          '+ 标签',
                          style:
                              TextStyle(
                            color: Colors
                                .lightBlue,
                            fontSize:
                                12,
                          ),
                        ),
                        backgroundColor:
                            Colors.white,
                        side:
                            BorderSide(
                          color: Colors
                              .lightBlue
                              .shade200,
                        ),
                        onPressed:
                            _showNewTagDialog,
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                Row(
                  children: [
                    ActionChip(
                      avatar:
                          const Icon(
                        Icons
                            .access_time,
                        size: 16,
                        color: Colors
                            .lightBlue,
                      ),
                      label: Text(
                        selectedTime !=
                                null
                            ? selectedTime!
                                .format(
                                context,
                              )
                            : '设具体时间',
                        style:
                            const TextStyle(
                          color: Colors
                              .lightBlue,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor:
                          Colors
                              .lightBlue
                              .shade50,
                      side:
                          BorderSide.none,
                      onPressed:
                          _showTimeAndCalendarDialog,
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    /*
                     * 事件仍然可以重复。
                     */
                    ActionChip(
                      avatar:
                          const Icon(
                        Icons.repeat,
                        size: 16,
                        color: Colors
                            .lightBlue,
                      ),
                      label: Text(
                        currentRepeat !=
                                null
                            ? '每 ${currentRepeat!.interval} '
                              '${{
                                'day': '天',
                                'week': '周',
                                'month': '月',
                                'year': '年',
                              }[currentRepeat!.unit]}'
                            : (existingTask
                                        ?.repeatRuleText ??
                                    '重复'),
                        style:
                            const TextStyle(
                          color: Colors
                              .lightBlue,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor:
                          Colors
                              .lightBlue
                              .shade50,
                      side:
                          BorderSide.none,
                      onPressed:
                          existingTask !=
                                  null
                              ? () =>
                                  _showCalendarSnackBar(
                                context,
                                '重复规则创建后不可修改，请删除重建',
                              )
                              : _showRepeatDialog,
                    ),

                    if (addToCalendar) ...[
                      const SizedBox(
                        width: 8,
                      ),
                      const Icon(
                        Icons
                            .event_available,
                        size: 16,
                        color:
                            Colors.green,
                      ),
                      const Text(
                        ' 已加日程',
                        style:
                            TextStyle(
                          fontSize: 12,
                          color: Colors
                              .green,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(
                  height: 10,
                ),

                Align(
                  alignment:
                      Alignment.centerRight,
                  child:
                      ElevatedButton(
                    style:
                        ElevatedButton
                            .styleFrom(
                      backgroundColor:
                          Colors
                              .lightBlue,
                      elevation: 0,
                    ),
                    onPressed:
                        () async {
                      if (titleController
                          .text
                          .trim()
                          .isEmpty) {
                        return;
                      }

                      bool calendarSaved =
                          false;

                      if (addToCalendar) {
                        final eventId =
                            await _createSystemCalendarEvent(
                          context:
                              context,
                          title:
                              titleController
                                  .text,
                          description:
                              descController
                                  .text,
                          date:
                              taskDate,
                          time:
                              selectedTime,
                          repeatConfig:
                              currentRepeat,
                        );

                        calendarSaved =
                            eventId !=
                                null;

                        if (!calendarSaved) {
                          return;
                        }
                      }

                      if (existingTask !=
                          null) {
                        int? choice =
                            await _askUpdateFuture();

                        if (choice == null) {
                          return;
                        }

                        taskData
                            .editTaskFull(
                          existingTask.id,
                          titleController
                              .text,
                          descController
                              .text,
                          taskDate,
                          selectedTime,
                          calendarSaved,
                          selectedList,
                          selectedTags,
                          updateFuture:
                              choice == 1,
                          newIsEvent:
                              isEvent,
                        );
                      } else {
                        taskData.addTask(
                          Task(
                            id: DateTime
                                .now()
                                .millisecondsSinceEpoch
                                .toString(),
                            title:
                                titleController
                                    .text,
                            description:
                                descController
                                    .text,
                            date:
                                taskDate,
                            time:
                                selectedTime,
                            addToCalendar:
                                calendarSaved,
                            listName:
                                selectedList,
                            tags:
                                selectedTags,
                            isEvent:
                                isEvent,
                          ),
                          repeat:
                              currentRepeat,
                        );
                      }

                      Navigator.pop(
                        context,
                      );
                    },
                    child:
                        const Text(
                      '保存',
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),
              ],
            ),
          );
        },
      );
    },
  );
}