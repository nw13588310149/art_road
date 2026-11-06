import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ChecklistGroup {
  documents('证件'),
  sketch('素描'),
  color('色彩'),
  speed('速写'),
  other('其他');

  const ChecklistGroup(this.label);

  final String label;

  static ChecklistGroup? tryParse(Object? name) {
    for (final group in values) {
      if (group.name == name) {
        return group;
      }
    }
    return null;
  }
}

/// 页面底部的提示。
const kChecklistNotice = '以当年考试说明和准考证要求为准，部分考点统一提供画纸或限制携带物品';

/// 自定义物品名称的长度上限。
const kChecklistLabelMaxLength = 20;

@immutable
class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.group,
    required this.label,
    this.custom = false,
  });

  final String id;
  final ChecklistGroup group;
  final String label;

  /// 用户添加的物品，可以删除。
  final bool custom;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'group': group.name,
    'label': label,
  };

  static ChecklistItem? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final id = json['id']?.toString() ?? '';
    final label = json['label']?.toString().trim() ?? '';
    final group = ChecklistGroup.tryParse(json['group']);
    if (id.isEmpty || label.isEmpty || group == null) {
      return null;
    }
    return ChecklistItem(id: id, group: group, label: label, custom: true);
  }
}

/// 默认清单（id 固定，勾选状态按 id 保存）。
const kDefaultChecklistItems = <ChecklistItem>[
  ChecklistItem(id: 'doc-admission', group: ChecklistGroup.documents, label: '准考证'),
  ChecklistItem(id: 'doc-id', group: ChecklistGroup.documents, label: '身份证'),
  ChecklistItem(id: 'doc-pouch', group: ChecklistGroup.documents, label: '透明文件袋'),
  ChecklistItem(id: 'sketch-pencil', group: ChecklistGroup.sketch, label: '2B–8B 铅笔（每种备几支）'),
  ChecklistItem(id: 'sketch-charcoal', group: ChecklistGroup.sketch, label: '炭笔'),
  ChecklistItem(id: 'sketch-kneaded', group: ChecklistGroup.sketch, label: '可塑橡皮'),
  ChecklistItem(id: 'sketch-eraser', group: ChecklistGroup.sketch, label: '硬橡皮'),
  ChecklistItem(id: 'sketch-knife', group: ChecklistGroup.sketch, label: '美工刀（削笔用）'),
  ChecklistItem(id: 'sketch-stump', group: ChecklistGroup.sketch, label: '纸擦笔'),
  ChecklistItem(id: 'color-paint', group: ChecklistGroup.color, label: '水粉颜料（检查常用色余量）'),
  ChecklistItem(id: 'color-brush', group: ChecklistGroup.color, label: '水粉笔（大中小号）'),
  ChecklistItem(id: 'color-palette', group: ChecklistGroup.color, label: '调色盒'),
  ChecklistItem(id: 'color-bucket', group: ChecklistGroup.color, label: '水桶'),
  ChecklistItem(id: 'color-sponge', group: ChecklistGroup.color, label: '吸水海绵'),
  ChecklistItem(id: 'color-cloth', group: ChecklistGroup.color, label: '抹布或纸巾'),
  ChecklistItem(id: 'speed-pen', group: ChecklistGroup.speed, label: '速写用笔（炭笔、钢笔或针管笔）'),
  ChecklistItem(id: 'speed-spare', group: ChecklistGroup.speed, label: '备用笔'),
  ChecklistItem(id: 'other-tape', group: ChecklistGroup.other, label: '纸胶带 / 夹子'),
  ChecklistItem(id: 'other-watch', group: ChecklistGroup.other, label: '手表（非智能手表）'),
  ChecklistItem(id: 'other-water', group: ChecklistGroup.other, label: '饮用水'),
];

/// 考场物品清单：默认物品 + 自定义物品，以及已勾选的 id。
@immutable
class ExamChecklist {
  const ExamChecklist({
    this.custom = const <ChecklistItem>[],
    this.checked = const <String>{},
  });

  final List<ChecklistItem> custom;
  final Set<String> checked;

  List<ChecklistItem> get items => [...kDefaultChecklistItems, ...custom];

  List<ChecklistItem> itemsOf(ChecklistGroup group) => [
    for (final item in items)
      if (item.group == group) item,
  ];

  int get total => items.length;

  int get checkedCount => items.where((item) => checked.contains(item.id)).length;

  bool isChecked(String id) => checked.contains(id);

  ExamChecklist toggle(String id) {
    final next = {...checked};
    if (!next.remove(id)) {
      next.add(id);
    }
    return ExamChecklist(custom: custom, checked: next);
  }

  /// 名称会去掉首尾空格并截断；为空或同组已有同名物品时返回原清单。
  ExamChecklist add(ChecklistGroup group, String label, {String? id}) {
    var name = label.trim();
    if (name.length > kChecklistLabelMaxLength) {
      name = name.substring(0, kChecklistLabelMaxLength);
    }
    if (name.isEmpty || itemsOf(group).any((item) => item.label == name)) {
      return this;
    }
    final item = ChecklistItem(
      id: id ?? 'custom-${DateTime.now().microsecondsSinceEpoch}',
      group: group,
      label: name,
      custom: true,
    );
    return ExamChecklist(custom: [...custom, item], checked: checked);
  }

  /// 只能删除自定义物品。
  ExamChecklist remove(String id) {
    if (!custom.any((item) => item.id == id)) {
      return this;
    }
    return ExamChecklist(
      custom: [
        for (final item in custom)
          if (item.id != id) item,
      ],
      checked: {...checked}..remove(id),
    );
  }

  /// 清空勾选；[keepCustom] 为 false 时同时删除自定义物品。
  ExamChecklist reset({bool keepCustom = false}) =>
      ExamChecklist(custom: keepCustom ? custom : const <ChecklistItem>[]);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'custom': [for (final item in custom) item.toJson()],
    'checked': [
      for (final item in items)
        if (checked.contains(item.id)) item.id,
    ],
  };

  static ExamChecklist fromJson(Object? json) {
    if (json is! Map) {
      return const ExamChecklist();
    }
    final rawCustom = json['custom'];
    final custom = <ChecklistItem>[
      if (rawCustom is List)
        for (final item in rawCustom) ?ChecklistItem.fromJson(item),
    ];
    final rawChecked = json['checked'];
    return ExamChecklist(
      custom: custom,
      checked: {
        if (rawChecked is List)
          for (final id in rawChecked) id.toString(),
      },
    );
  }
}

/// 考场物品清单本地存储（SharedPreferences JSON）。
class ExamChecklistRepository {
  static const storageKey = 'art_toolbox_exam_checklist_v1';

  Future<ExamChecklist> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) {
      return const ExamChecklist();
    }
    try {
      return ExamChecklist.fromJson(jsonDecode(raw));
    } catch (_) {
      return const ExamChecklist();
    }
  }

  Future<void> save(ExamChecklist checklist) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(checklist.toJson()));
  }
}
