import 'package:flutter/material.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/theme/app_font.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/art_widgets.dart';
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: StudySectionHeader(
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: ArtEmptyState(
                      message: keyword.trim().isEmpty ? '暂无成绩' : '没有找到匹配的学生',
                      icon: Icons.person_search_outlined,
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
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
            ],
          ),
        );
      },
    );
  }
}

const _rowPadding = EdgeInsets.symmetric(horizontal: 32);
const _rankWidth = 44.0;
const _avatarSpace = 48.0;
const _scoreWidth = 96.0;
const _gradeWidth = 48.0;
const _chevronWidth = 22.0;

class _ListHead extends StatelessWidget {
  const _ListHead({required this.wide, required this.showGrade});

  final bool wide;
  final bool showGrade;

  @override
  Widget build(BuildContext context) {
    final style = ArtText.caption(size: 12);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: ArtColors.subtle,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _rankWidth,
            child: Text('排名', style: style),
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
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Divider(height: 1, thickness: 1, color: ArtColors.line),
          ),
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: _rowPadding.add(
                const EdgeInsets.symmetric(vertical: 10),
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
                  ArtAvatar(
                    name: row.studentName,
                    url: row.avatarUrl,
                    size: 36,
                  ),
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
                          style: ArtText.body(size: 14, weight: AppFont.w500),
                        ),
                        Text(
                          wide || row.organizationName.isEmpty
                              ? '准考证号 ${row.admissionNo}'
                              : row.organizationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ArtText.caption(size: 11),
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
                            style: ArtText.body(
                              size: 13,
                              color: ArtColors.ink2,
                            ),
                          ),
                          if (subjectName.isEmpty && organizationRank != null)
                            Text(
                              '校区第 $organizationRank 名',
                              style: ArtText.caption(size: 11),
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
                        size: 17,
                        color: ArtColors.brandDeep,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: _gradeWidth,
                    child: Center(
                      child: grade.isEmpty
                          ? const SizedBox.shrink()
                          : ArtGradeBadge(grade: grade, size: 22),
                    ),
                  ),
                  const SizedBox(
                    width: _chevronWidth,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: ArtColors.ink4,
                      size: 22,
                    ),
                  ),
                ],
              ),
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

  static const _medals = <List<Color>>[
    [Color(0xFFFFD36B), Color(0xFFF2A516)],
    [Color(0xFFE3E7EE), Color(0xFFAEB6C5)],
    [Color(0xFFF6C9A4), Color(0xFFD68B5B)],
  ];

  @override
  Widget build(BuildContext context) {
    final value = rank;
    if (value == null) {
      return Text('—', style: ArtText.number(size: 14, color: ArtColors.ink3));
    }
    if (value >= 1 && value <= _medals.length) {
      return Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _medals[value - 1],
          ),
        ),
        child: Text(
          '$value',
          style: ArtText.number(size: 13, color: Colors.white),
        ),
      );
    }
    return Text(
      '$value',
      style: ArtText.number(size: 15, color: ArtColors.ink2),
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _update(String value) {
    widget.onChanged(value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: AppTextField(
        controller: _controller,
        onChanged: _update,
        textInputAction: TextInputAction.search,
        style: ArtText.body(size: 14),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: ArtColors.subtle,
          hintText: '搜索姓名 / 准考证号',
          hintStyle: ArtText.body(size: 13, color: ArtColors.ink4),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 18,
            color: ArtColors.ink3,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 36,
          ),
          suffixIcon: _controller.text.isEmpty
              ? null
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _controller.clear();
                    _update('');
                  },
                  child: const Icon(
                    Icons.cancel_rounded,
                    size: 16,
                    color: ArtColors.ink4,
                  ),
                ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 9,
            horizontal: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
