import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/task_data.dart';
import 'version_history_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // ----------------- 分栏管理 -----------------
  void _showAddBucketDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增分栏', style: TextStyle(color: Colors.lightBlue)),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: '如：清晨、夜间等')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                taskData.addTimeBucket(ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('添加', style: TextStyle(color: Colors.lightBlue)),
          ),
        ],
      ),
    );
  }

  void _showEditBucketDialog(String oldName) {
    final ctrl = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑分栏名称', style: TextStyle(color: Colors.lightBlue)),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: '输入新分栏名称')),
        actions: [
          TextButton(
            onPressed: () {
              taskData.deleteTimeBucket(oldName);
              Navigator.pop(ctx);
            },
            child: const Text('删除分栏', style: TextStyle(color: Colors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                taskData.editTimeBucket(oldName, ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('保存', style: TextStyle(color: Colors.lightBlue)),
          ),
        ],
      ),
    );
  }

  void _showManageBucketsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => ListenableBuilder(
          listenable: taskData,
          builder: (context, _) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('自定义每日分栏', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                      TextButton.icon(icon: const Icon(Icons.add, size: 18), label: const Text('添加分栏'), onPressed: _showAddBucketDialog),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: taskData.timeBuckets.isEmpty
                      ? const Center(child: Text('暂无分栏，点击右上角添加', style: TextStyle(color: Colors.grey)))
                      : ReorderableListView.builder(
                          scrollController: scrollController,
                          itemCount: taskData.timeBuckets.length,
                          onReorder: (oldIndex, newIndex) => taskData.reorderTimeBuckets(oldIndex, newIndex),
                          itemBuilder: (context, index) {
                            final bName = taskData.timeBuckets[index];
                            return ListTile(
                              key: ValueKey('bucket_$bName'),
                              leading: const Icon(Icons.drag_indicator, color: Colors.grey),
                              title: Text(bName, style: const TextStyle(fontWeight: FontWeight.w500)),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.lightBlue),
                                onPressed: () => _showEditBucketDialog(bName),
                              ),
                              onTap: () => _showEditBucketDialog(bName),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ----------------- 链管理 -----------------
  void _showEditChainDialog(TaskChain chain) {
    final ctrl = TextEditingController(text: chain.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改链名称', style: TextStyle(color: Colors.lightBlue)),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: '输入新链名称')),
        actions: [
          TextButton(
            onPressed: () {
              taskData.deleteChain(chain.id);
              Navigator.pop(ctx);
            },
            child: const Text('删除链', style: TextStyle(color: Colors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                taskData.editChain(chain.id, ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('保存', style: TextStyle(color: Colors.lightBlue)),
          ),
        ],
      ),
    );
  }

  void _showManageChainsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => ListenableBuilder(
          listenable: taskData,
          builder: (context, _) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('链管理', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: taskData.myChains.isEmpty
                      ? const Center(child: Text('暂无链，可在新建待办时创建', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: taskData.myChains.length,
                          itemBuilder: (context, index) {
                            final chain = taskData.myChains[index];
                            return ListTile(
                              leading: const Icon(Icons.link, color: Colors.lightBlue),
                              title: Text(chain.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text('当前连续: #${chain.count}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.lightBlue),
                                    onPressed: () => _showEditChainDialog(chain),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                    onPressed: () => taskData.deleteChain(chain.id),
                                  ),
                                ],
                              ),
                              onTap: () => _showEditChainDialog(chain),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ----------------- 🔴 清单管理（支持长按自由排序，无排序图标） -----------------
  void _showAddListDialog() {
    final ctrl = TextEditingController();
    Color selectedColor = Colors.blue;
    final colors = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red,
      Colors.teal, Colors.pink, Colors.amber, Colors.indigo, Colors.cyan,
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('新建清单', style: TextStyle(color: Colors.lightBlue, fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: '清单名称')),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: colors.map((c) => GestureDetector(
                  onTap: () => setDialogState(() => selectedColor = c),
                  child: CircleAvatar(
                    backgroundColor: c,
                    radius: 14,
                    child: selectedColor == c ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                  ),
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Colors.grey))),
            TextButton(
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  taskData.addList(ctrl.text.trim(), selectedColor);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('保存', style: TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditListDialog(TaskList list) {
    final ctrl = TextEditingController(text: list.name);
    Color selectedColor = list.color;
    final colors = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red,
      Colors.teal, Colors.pink, Colors.amber, Colors.indigo, Colors.cyan,
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('编辑清单', style: TextStyle(color: Colors.lightBlue, fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: '清单名称')),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: colors.map((c) => GestureDetector(
                  onTap: () => setDialogState(() => selectedColor = c),
                  child: CircleAvatar(
                    backgroundColor: c,
                    radius: 14,
                    child: selectedColor == c ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                  ),
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                taskData.deleteList(list.name);
                Navigator.pop(ctx);
              },
              child: const Text('删除清单', style: TextStyle(color: Colors.red)),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Colors.grey))),
            TextButton(
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  taskData.editList(list.name, ctrl.text.trim(), selectedColor);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('保存', style: TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showManageListsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => ListenableBuilder(
          listenable: taskData,
          builder: (context, _) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('清单管理', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('添加清单'),
                        onPressed: _showAddListDialog,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: taskData.myLists.isEmpty
                      ? const Center(child: Text('暂无清单', style: TextStyle(color: Colors.grey)))
                      : ReorderableListView.builder(
                          scrollController: scrollController,
                          buildDefaultDragHandles: false, // 🔴 不出现排序提示图标
                          itemCount: taskData.myLists.length,
                          onReorder: (oldIndex, newIndex) => taskData.reorderLists(oldIndex, newIndex),
                          itemBuilder: (context, index) {
                            final item = taskData.myLists[index];
                            return ReorderableDelayedDragStartListener( // 🔴 长按自由排序
                              key: ValueKey('manage_list_${item.name}_$index'),
                              index: index,
                              child: ListTile(
                                leading: CircleAvatar(backgroundColor: item.color, radius: 8),
                                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.lightBlue),
                                      onPressed: () => _showEditListDialog(item),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                      onPressed: () => taskData.deleteList(item.name),
                                    ),
                                  ],
                                ),
                                onTap: () => _showEditListDialog(item),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ----------------- 🔴 标签管理（支持长按自由排序，无排序图标） -----------------
  void _showAddTagDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建标签', style: TextStyle(color: Colors.lightBlue, fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: '标签名称')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                taskData.addTag(ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('保存', style: TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditTagDialog(String oldName) {
    final ctrl = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改标签名称', style: TextStyle(color: Colors.lightBlue, fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: '输入新标签名称')),
        actions: [
          TextButton(
            onPressed: () {
              taskData.deleteTag(oldName);
              Navigator.pop(ctx);
            },
            child: const Text('删除标签', style: TextStyle(color: Colors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                taskData.editTag(oldName, ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('保存', style: TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showManageTagsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => ListenableBuilder(
          listenable: taskData,
          builder: (context, _) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('标签管理', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('添加标签'),
                        onPressed: _showAddTagDialog,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: taskData.myTags.isEmpty
                      ? const Center(child: Text('暂无标签', style: TextStyle(color: Colors.grey)))
                      : ReorderableListView.builder(
                          scrollController: scrollController,
                          buildDefaultDragHandles: false, // 🔴 不出现排序提示图标
                          itemCount: taskData.myTags.length,
                          onReorder: (oldIndex, newIndex) => taskData.reorderTags(oldIndex, newIndex),
                          itemBuilder: (context, index) {
                            final tag = taskData.myTags[index];
                            return ReorderableDelayedDragStartListener( // 🔴 长按自由排序
                              key: ValueKey('manage_tag_${tag}_$index'),
                              index: index,
                              child: ListTile(
                                leading: const Icon(Icons.tag, color: Colors.lightBlue, size: 20),
                                title: Text(tag, style: const TextStyle(fontWeight: FontWeight.w500)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.lightBlue),
                                      onPressed: () => _showEditTagDialog(tag),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                      onPressed: () => taskData.deleteTag(tag),
                                    ),
                                  ],
                                ),
                                onTap: () => _showEditTagDialog(tag),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showSetDefaultMinutesDialog(String title, int currentVal, Function(int) onVal) {
    final ctrl = TextEditingController(text: '$currentVal');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.lightBlue, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(suffixText: '分钟'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text.trim());
              if (v != null && v >= 0) {
                onVal(v);
                Navigator.pop(ctx);
              }
            },
            child: const Text('保存', style: TextStyle(color: Colors.lightBlue)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('设置', style: TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
      ),
      body: ListenableBuilder(
        listenable: taskData,
        builder: (context, child) {
          return ListView(
            children: [
              const SizedBox(height: 10),

              // 每日分栏开关
              SwitchListTile(
                secondary: const Icon(Icons.view_agenda_outlined, color: Colors.lightBlue),
                title: const Text('每日分栏', style: TextStyle(fontSize: 15)),
                subtitle: const Text('按时段分块规划每日待办', style: TextStyle(fontSize: 12, color: Colors.grey)),
                value: taskData.enableTimeBuckets,
                activeColor: Colors.lightBlue,
                onChanged: (val) => taskData.toggleTimeBuckets(val),
              ),

              if (taskData.enableTimeBuckets)
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 72, right: 16),
                  title: const Text('分栏管理与排序', style: TextStyle(fontSize: 14, color: Colors.black87)),
                  subtitle: Text(
                    taskData.timeBuckets.isEmpty ? '未配置分栏' : taskData.timeBuckets.join(' · '),
                    style: const TextStyle(fontSize: 12, color: Colors.lightBlue),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                  onTap: _showManageBucketsModal,
                ),

              const Divider(height: 1, indent: 56),

              // 链管理
              ListTile(
                leading: const Icon(Icons.link, color: Colors.lightBlue),
                title: const Text('链管理', style: TextStyle(fontSize: 15)),
                trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                onTap: _showManageChainsModal,
              ),

              const Divider(height: 1, indent: 56),

              // 🔴 新增：清单管理
              ListTile(
                leading: const Icon(Icons.format_list_bulleted, color: Colors.lightBlue),
                title: const Text('清单管理', style: TextStyle(fontSize: 15)),
                trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                onTap: _showManageListsModal,
              ),

              const Divider(height: 1, indent: 56),

              // 🔴 新增：标签管理
              ListTile(
                leading: const Icon(Icons.tag, color: Colors.lightBlue),
                title: const Text('标签管理', style: TextStyle(fontSize: 15)),
                trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                onTap: _showManageTagsModal,
              ),

              const Divider(height: 1, indent: 56),

              // 专注偏好设置
              const Padding(
                padding: EdgeInsets.only(left: 16, top: 16, bottom: 6),
                child: Text('专注默认偏好', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),

              ListTile(
                leading: const Icon(Icons.timer_outlined, color: Colors.lightBlue),
                title: const Text('新建待办默认计时模式', style: TextStyle(fontSize: 14)),
                trailing: CupertinoSlidingSegmentedControl<String>(
                  groupValue: taskData.defaultTimerMode,
                  children: const {
                    'countdown': Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Text('倒计时', style: TextStyle(fontSize: 12))),
                    'countup': Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Text('正计时', style: TextStyle(fontSize: 12))),
                  },
                  thumbColor: Colors.lightBlue.shade50,
                  backgroundColor: Colors.grey.shade100,
                  onValueChanged: (v) {
                    if (v != null) taskData.updateDefaultFocusSettings(mode: v);
                  },
                ),
              ),

              ListTile(
                contentPadding: const EdgeInsets.only(left: 72, right: 16),
                title: const Text('倒计时默认时长', style: TextStyle(fontSize: 14)),
                trailing: Text('${taskData.defaultCountdownMinutes} 分钟', style: const TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
                onTap: () => _showSetDefaultMinutesDialog(
                  '修改倒计时默认时长',
                  taskData.defaultCountdownMinutes,
                  (v) => taskData.updateDefaultFocusSettings(countdownMins: v),
                ),
              ),

              // 预约默认时长
              ListTile(
                contentPadding: const EdgeInsets.only(left: 72, right: 16),
                title: const Text('预约默认时长', style: TextStyle(fontSize: 14)),
                trailing: Text(
                  taskData.defaultPrepMinutes > 0 ? '${taskData.defaultPrepMinutes} 分钟' : '无预约',
                  style: const TextStyle(
                    color: Colors.lightBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () => _showSetDefaultMinutesDialog(
                  '修改预约默认时长',
                  taskData.defaultPrepMinutes,
                  (v) => taskData.updateDefaultFocusSettings(prepMins: v),
                ),
              ),

              SwitchListTile(
                contentPadding: const EdgeInsets.only(left: 72, right: 16),
                title: const Text('默认允许暂停', style: TextStyle(fontSize: 14)),
                value: taskData.defaultAllowPause,
                activeColor: Colors.lightBlue,
                onChanged: (v) => taskData.updateDefaultFocusSettings(allowPause: v),
              ),

              if (taskData.defaultAllowPause)
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 72, right: 16),
                  title: const Text('默认暂停限时', style: TextStyle(fontSize: 14)),
                  trailing: Text('${taskData.defaultPauseLimitMinutes} 分钟', style: const TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
                  onTap: () => _showSetDefaultMinutesDialog(
                    '修改默认暂停限时',
                    taskData.defaultPauseLimitMinutes,
                    (v) => taskData.updateDefaultFocusSettings(pauseLimitMins: v),
                  ),
                ),

              const Divider(height: 1, indent: 56),

              // 法定节假日
              SwitchListTile(
                secondary: const Icon(Icons.celebration, color: Colors.lightBlue),
                title: const Text('法定节假日', style: TextStyle(fontSize: 15)),
                value: taskData.enableHolidays,
                activeColor: Colors.lightBlue,
                onChanged: (val) => taskData.toggleHolidays(val),
              ),

              const Divider(height: 1, indent: 56),

              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.lightBlue),
                title: const Text('版本记录', style: TextStyle(fontSize: 15)),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const VersionHistoryPage()));
                },
              ),
            ],
          );
        },
      ),
    );
  }
}