import 'package:flutter/material.dart';
import '../models/task_data.dart';
import 'version_history_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  void _showAddBucketDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增分栏', style: TextStyle(color: Colors.lightBlue)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '如：清晨、夜间、深度专注等'),
        ),
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
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入新分栏名称'),
        ),
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
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('添加分栏'),
                        onPressed: _showAddBucketDialog,
                      ),
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

              // 🔴 每日分栏开关
              SwitchListTile(
                secondary: const Icon(Icons.view_agenda_outlined, color: Colors.lightBlue),
                title: const Text('每日分栏', style: TextStyle(fontSize: 15)),
                subtitle: const Text('按时段（上午、下午等）分块规划每日待办', style: TextStyle(fontSize: 12, color: Colors.grey)),
                value: taskData.enableTimeBuckets,
                activeColor: Colors.lightBlue,
                onChanged: (val) => taskData.toggleTimeBuckets(val),
              ),

              // 开启时显示分栏字段管理入口
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

              // 法定节假日开关
              SwitchListTile(
                secondary: const Icon(Icons.celebration, color: Colors.orange),
                title: const Text('法定节假日', style: TextStyle(fontSize: 15)),
                subtitle: const Text('自动在对应日期添加放假与节日事件', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.help_outline, color: Colors.grey),
                title: const Text('关于 Monenta', style: TextStyle(fontSize: 15, color: Colors.grey)),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                onTap: () {},
              ),
            ],
          );
        },
      ),
    );
  }
}