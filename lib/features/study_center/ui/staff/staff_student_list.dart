import 'package:flutter/material.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/ui/ui.dart';
import '../../data/study_logic.dart';
import '../../data/study_models.dart';
import '../widgets/study_common.dart';

/// 成绩排名（Sliver）：搜索姓名 / 准考证号，点击进入学生成绩报告。
class StaffStudentListSliver extends StatelessWidget {
  const StaffStudentListSliver({
    required this.rows,
    required this.subjectName,
    required this.totalCount,
    required this.keyword,
    required this.onKeywordChanged,
    required this.onOpen,
    this.overflowCount = 0,
    super.key,
  });

  /// 已排序、已过滤的行。
  final List<ScoreQueryRow> rows;

  /// 空串表示总分。
  final String subjectName;
  final int totalCount;

  /// 超出统计上限、未加载的人数。
  final int overflowCount;
  final String keyword;
  final ValueChanged<String> onKeywordChanged;
  final ValueChanged<ScoreQueryRow> onOpen;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      keyword.trim().isEmpty
          ? '共 $totalCount 人'
          : '匹配 ${rows.length} / $totalCount 人',
      if (overflowCount > 0) '仅统计前 $totalCount 名',
    ].join(' · ');
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.crossAxisExtent >= 640;
        return DecoratedSliver(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.br12,
            border: Border.all(color: AppColors.lineSoft),
          ),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.card,
                    AppSpace.card,
                    AppSpace.card,
                    AppSpace.s12,
                  ),
                  child: AppSectionHeader(
                    title: subjectName.isEmpty ? '总分排名' : '$subjectName排名',
                    subtitle: subtitle,
                    trailing: SizedBox(
                      width: 240,
                      child: _SearchField(
                        initial: keyword,
                        onChanged: onKeywordChanged,
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _ListHead(wide: wide, showGrade: subjectName.isNotEmpty),
              ),
              if (rows.isEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 180,
                    child: keyword.trim().isEmpty
                        ? const AppEmptyState(
                            icon: Icons.person_search_outlined,
                            title: '暂无成绩',
                            description: '本场考试出分后会按名次列出学生',
                          )
                        : AppEmptyState(
                            icon: Icons.person_search_outlined,
                            title: '没有找到匹配的学生',
                            description: '换个姓名或准考证号试试',
                            actionLabel: '清除搜索',
                            onAction: () => onKeywordChanged(''),
                          ),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) => _StudentRow(
                    row: rows[index],
                    subjectName: subjectName,
                    wide: wide,
                    showDivider: index > 0,
                    onTap: () => onOpen(rows[index]),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpace.s12)),
            ],
          ),
        );
      },
    );
  }
}

const _rowPadding = EdgeInsets.symmetric(horizontal: 28);
const _rankWidth = 44.0;
const _avatarSpace = 48.0;
const _scoreWidth = 96.0;
const _gradeWidth = 56.0;
const _chevronWidth = 24.0;

class _ListHead extends StatelessWidget {
  const _ListHead({required this.wide, required this.showGrade});

  final bool wide;
  final bool showGrade;

  @override
  Widget build(BuildContext context) {
    final style = AppText.caption12;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.card),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s12,
        vertical: AppSpace.s8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: AppRadius.br8,
      ),
      child: Row(
        children: [
          SizedBox(
            width: _rankWidth,
            child: Text('名次', style: style),
          ),
          const SizedBox(width: _avatarSpace),
          Expanded(flex: 4, child: Text('学生', style: style)),
          if (wide) Expanded(flex: 3, child: Text('校区', style: style)),
          SizedBox(
            width: _scoreWidth,
            child: Text('成绩', textAlign: TextAlign.right, style: style),
          ),
          SizedBox(
            width: _gradeWidth,
            child: Text(
              showGrade ? '档位' : '',
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
          const SizedBox(width: _chevronWidth),
        ],
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.row,
    required this.subjectName,
    required this.wide,
    required this.showDivider,
    required this.onTap,
  });

  final ScoreQueryRow row;
  final String subjectName;
  final bool wide;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rank = rowRanking(row, subjectName);
    final score = rowScore(row, subjectName);
    final grade = subjectName.isEmpty
        ? ''
        : row.subjectNamed(subjectName)?.grade ?? '';
    final organizationRank = row.organizationRanking;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDivider)
          const Padding(
            padding: _rowPadding,
            child: Divider(height: 1, thickness: 1, color: AppColors.lineSoft),
          ),
        AppPressable(
          onTap: onTap,
          semanticLabel: '查看${row.studentName}的成绩报告',
          child: Padding(
            padding: _rowPadding.add(
              const EdgeInsets.symmetric(vertical: AppSpace.s8),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: _rankWidth,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _RankBadge(rank: rank),
                  ),
                ),
                AppAvatar(name: row.studentName, url: row.avatarUrl, size: 36),
                const SizedBox(width: _avatarSpace - 36),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body14Strong,
                      ),
                      Text(
                        wide || row.organizationName.isEmpty
                            ? '准考证号 ${row.admissionNo}'
                            : row.organizationName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption12,
                      ),
                    ],
                  ),
                ),
                if (wide)
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.organizationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body13,
                        ),
                        if (subjectName.isEmpty && organizationRank != null)
                          Text(
                            '校区第 $organizationRank 名',
                            style: AppText.caption12,
                          ),
                      ],
                    ),
                  ),
                SizedBox(
                  width: _scoreWidth,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: StudyNumberText(
                      formatScore(score),
                      unit: ' 分',
                      size: 16,
                    ),
                  ),
                ),
                SizedBox(
                  width: _gradeWidth,
                  child: Center(child: StudyGradeTag(grade: grade)),
                ),
                const SizedBox(
                  width: _chevronWidth,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textPlaceholder,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int? rank;

  @override
  Widget build(BuildContext context) {
    final value = rank;
    if (value == null) {
      return Text(
        '—',
        style: AppText.number(size: 14, color: AppColors.textTertiary),
      );
    }
    if (value <= 3) {
      return Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.brandWash,
          shape: BoxShape.circle,
        ),
        child: Text(
          '$value',
          style: AppText.number(size: 13, color: AppColors.brandDeep),
        ),
      );
    }
    return Text(
      '$value',
      style: AppText.number(size: 14, color: AppColors.textSecondary),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({required this.initial, required this.onChanged});

  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void didUpdateWidget(covariant _SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initial != oldWidget.initial &&
        widget.initial != _controller.text) {
      _controller.text = widget.initial;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppSearchField(
      controller: _controller,
      hint: '搜索姓名 / 准考证号',
      size: AppControlSize.sm,
      onChanged: widget.onChanged,
    );
  }
}
