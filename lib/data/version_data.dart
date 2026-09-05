class VersionRecord {
  final String version;
  final String date;
  final List<String> updates;

  const VersionRecord({
    required this.version,
    required this.date,
    required this.updates,
  });
}

// 🔴 所有的版本更新记录存在这里
const List<VersionRecord> versionHistory = [
      VersionRecord(
    version: 'v1.4.0',
    date: '2026-09-5',
    updates: [
      '新增：逾期功能',
      '新增：分类栏之前的分割线',
      '修复：最近代办无过去未完成',
      '修复：节假日无法显示的问题',
    ],
  ),
    VersionRecord(
    version: 'v1.3.0',
    date: '2026-09-4',
    updates: [
      '新增：法定节假日提示',
      '新增：当日代办提示',
      '修复：集子中对未完成任务的日期显示',
    ],
  ),
    VersionRecord(
    version: 'v1.2.0',
    date: '2026-08-30',
    updates: [
      '新增：事件记录功能',
      '修复：番茄钟与正计时',
    ],
  ),
  VersionRecord(
    version: 'v1.1.0',
    date: '2026-05-12',
    updates: [
      '新增：原生极简数据统计（折线图趋势、事件完成率双饼图）',
      '新增：番茄钟与正计时专注模式',
      '优化：全新无缝纯白UI，移除多余分割线',
      '优化：底层导航栏支持多模块快速切换',
    ],
  ),
  VersionRecord(
    version: 'v1.0.1',
    date: '2026-05-08',
    updates: [
      '新增：支持代办箱长按拖拽排序',
      '新增：支持标签管理与多颜色清单',
      '修复：修复了部分日期选中后无法取消的Bug',
    ],
  ),
  VersionRecord(
    version: 'v1.0.0',
    date: '2026-05-01',
    updates: [
      '发布：Monenta 初始版本正式上线',
      '基础：日历视图、每日代办、备忘录记录功能',
    ],
  ),
];