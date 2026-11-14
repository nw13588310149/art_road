import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/art/art_subject.dart';
import '../../../core/ui/ui.dart';
import '../data/teaching_overview_repository.dart';
import '../state/teaching_overview_controller.dart';

const followStatuses = {
  'pending': '待跟进',
  'following': '跟进中',
  'resolved': '已记录处理',
};

class TeachingStudentList extends StatefulWidget {
  const TeachingStudentList({
    required this.rows,
    required this.request,
    required this.onSelect,
    this.selected = '',
    this.allowFollowUp = true,
    super.key,
  });
  final List<TeachingRow> rows;
  final TeachingRequest request;
  final ValueChanged<TeachingRow> onSelect;
  final String selected;
  final bool allowFollowUp;
  @override
  State<TeachingStudentList> createState() => _TeachingStudentListState();
}

class _TeachingStudentListState extends State<TeachingStudentList> {
  final _search = TextEditingController();
  String _keyword = '',
      _class = '',
      _subject = '',
      _status = '',
      _sort = 'risk';
  bool _all = false;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int risk(TeachingRow row) =>
      (row['reasons'] as List? ?? []).length * 100 +
      ((row['unresolvedCount'] as num?)?.toInt() ?? 0);
  @override
  Widget build(BuildContext context) {
    final rows = widget.rows
        .where(
          (r) =>
              (_all || widget.selected.isEmpty || r['id'] == widget.selected) &&
              '${r['name']} ${r['className']} ${r['teacher'] ?? ''}'.contains(
                _keyword.trim(),
              ) &&
              (_class.isEmpty || r['className'] == _class) &&
              (_subject.isEmpty ||
                  teachingRows(r['subjectInsights']).any(
                    (s) =>
                        s['subject'] == _subject &&
                        (s['sampleCount'] as num? ?? 0) > 0,
                  )) &&
              (_status.isEmpty ||
                  (teachingRow(r['followUp'])['status'] ?? 'pending') ==
                      _status),
        )
        .toList();
    rows.sort(
      (a, b) => _sort == 'recent'
          ? teachingText(
              b['latestWork'],
            ).compareTo(teachingText(a['latestWork']))
          : risk(b).compareTo(risk(a)),
    );
    final classes = widget.rows
        .map((r) => teachingText(r['className']))
        .where((s) => s.isNotEmpty)
        .toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 220,
              child: AppSearchField(
                controller: _search,
                hint: '搜索学生或班级',
                onChanged: (v) => setState(() => _keyword = v),
              ),
            ),
            SizedBox(
              width: 170,
              child: AppSelect<String>(
                value: _class,
                options: [
                  const AppSelectOption(value: '', label: '全部班级'),
                  for (final c in classes) AppSelectOption(value: c, label: c),
                ],
                onChanged: (v) => setState(() => _class = v),
              ),
            ),
            SizedBox(
              width: 140,
              child: AppSelect<String>(
                value: _subject,
                options: [
                  const AppSelectOption(value: '', label: '全部科目'),
                  for (final name in ['素描', '色彩', '速写'])
                    AppSelectOption(
                      value: name,
                      label: ArtSubject.tryParse(name)?.label ?? name,
                    ),
                ],
                onChanged: (v) => setState(() => _subject = v),
              ),
            ),
            SizedBox(
              width: 145,
              child: AppSelect<String>(
                value: _sort,
                options: const [
                  AppSelectOption(value: 'risk', label: '关注事项优先'),
                  AppSelectOption(value: 'recent', label: '最近提交优先'),
                ],
                onChanged: (v) => setState(() => _sort = v),
              ),
            ),
          ],
        ),
        if (widget.allowFollowUp)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppChip(
                label: '全部状态',
                selected: _status.isEmpty,
                onTap: () => setState(() => _status = ''),
              ),
              for (final e in followStatuses.entries)
                AppChip(
                  label: e.value,
                  selected: _status == e.key,
                  onTap: () => setState(() => _status = e.key),
                ),
            ],
          ),
        Text(
          '当前 ${rows.length} 人 · 分项依据近期已点评作品；关注信号不等同于最终评价。',
          style: AppText.caption12,
        ),
        if (widget.selected.isNotEmpty && !_all)
          AppButton(
            label: '查看完整名单',
            variant: AppButtonVariant.secondary,
            onTap: () => setState(() => _all = true),
          ),
        if (rows.isEmpty)
          AppEmptyState(
            title: '没有匹配的学生',
            description: '可调整班级、科目或跟进状态。',
            action: AppButton(
              label: '清空筛选',
              variant: AppButtonVariant.secondary,
              onTap: () => setState(() {
                _search.clear();
                _keyword = '';
                _class = '';
                _subject = '';
                _status = '';
                _all = true;
              }),
            ),
          ),
        for (final row in rows) _row(row),
      ],
    );
  }

  Widget _row(TeachingRow row) {
    final follow = teachingRow(row['followUp']);
    final reasons = (row['reasons'] as List? ?? []).map((v) => '$v').toList();
    final issues = [
      for (final s in teachingRows(row['subjectInsights']))
        if (_subject.isEmpty || s['subject'] == _subject)
          ...teachingRows(s['issues'])
              .where((i) => i['latestResolved'] != true)
              .map((i) => '${s['subject']} · ${i['name']}'),
    ];
    final status = followStatuses[follow['status']] ?? '待跟进';
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (_, size) {
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Row(
                children: [
                  Text(teachingText(row['name']), style: AppText.title16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${row['className']} · ${row['campus'] ?? ''}',
                      style: AppText.body13,
                    ),
                  ),
                ],
              ),
              if (teachingText(row['teacher']).isNotEmpty)
                Text('负责老师 ${row['teacher']}', style: AppText.caption12),
              Text(
                reasons.isNotEmpty
                    ? reasons.join('；')
                    : issues.isEmpty
                    ? '暂无重复出现的短板记录，继续观察后续作品。'
                    : issues.take(3).join('；'),
                style: AppText.body14,
              ),
              Text(
                '最近提交 ${row['latestWork'] ?? '暂无'} · 已提交 ${row['workCount'] ?? 0} 份作品',
                style: AppText.caption12,
              ),
              if (follow.isNotEmpty)
                Text(
                  '${follow['owner']} · ${follow['updatedAt']}\n${follow['note']}',
                  style: AppText.body13,
                ),
            ],
          );
          final actions = Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 8,
            children: [
              if (widget.allowFollowUp)
                AppTag(
                  label: status,
                  tone: follow['status'] == 'following'
                      ? AppTone.brand
                      : AppTone.neutral,
                ),
              AppButton(
                label: '查看学情与作品',
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                onTap: () => widget.onSelect(row),
              ),
              if (widget.allowFollowUp)
                AppButton(
                  label: '记录跟进',
                  variant: AppButtonVariant.quiet,
                  size: AppButtonSize.sm,
                  onTap: () => showAppDrawer(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) =>
                        _FollowUpDrawer(row: row, request: widget.request),
                  ),
                ),
            ],
          );
          if (size.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [info, actions],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(name: teachingText(row['name']), size: 40),
              const SizedBox(width: 16),
              Expanded(child: info),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _FollowUpDrawer extends ConsumerStatefulWidget {
  const _FollowUpDrawer({required this.row, required this.request});
  final TeachingRow row;
  final TeachingRequest request;
  @override
  ConsumerState<_FollowUpDrawer> createState() => _FollowUpDrawerState();
}

class _FollowUpDrawerState extends ConsumerState<_FollowUpDrawer> {
  final _note = TextEditingController();
  String _status = 'following', _error = '';
  bool _busy = false;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    final error = await ref
        .read(teachingOverviewProvider(widget.request).notifier)
        .followUp(teachingText(widget.row['id']), _status, _note.text.trim());
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = teachingRows(
      teachingRow(widget.row['followUp'])['history'],
    );
    return PopScope(
      canPop: !_busy,
      child: AppDrawer(
        title: '${widget.row['name']} · 教学跟进',
        width: 560,
        onClose: _busy ? () {} : () => Navigator.pop(context),
        actions: [
          AppButton(
            label: '保存跟进记录',
            loading: _busy,
            onTap: _busy ? null : _save,
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            Text(
              '记录已采取的沟通、练习安排与下次复查要点。处理状态用于协作，不会修改学生分数或自动清除关注信号。',
              style: AppText.body14,
            ),
            AppSelect<String>(
              value: _status,
              options: [
                for (final e in followStatuses.entries)
                  AppSelectOption(value: e.key, label: e.value),
              ],
              onChanged: (v) => setState(() => _status = v),
            ),
            AppInputField(
              controller: _note,
              label: '本次跟进内容',
              hint: '沟通结果、练习安排与下次复查要点',
              multiline: true,
              maxLength: 500,
            ),
            if (_error.isNotEmpty)
              AppNotice(message: _error, tone: AppTone.danger),
            Text('历史记录', style: AppText.title16),
            if (history.isEmpty) Text('尚未记录跟进', style: AppText.body13),
            for (final h in history)
              AppListRow(
                title: '${h['owner']} · ${followStatuses[h['status']] ?? ''}',
                subtitle: '${h['updatedAt']}\n${h['note']}',
              ),
          ],
        ),
      ),
    );
  }
}
