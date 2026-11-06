import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/art/art_subject.dart';
import '../../../../core/art/art_tokens.dart';
import '../../../../core/demo/demo_accounts.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_font.dart';
import '../../../../core/widgets/art_widgets.dart';
import '../../../shell/state/shell_controller.dart';
import '../../../shell/state/shell_state.dart';
import '../../../study_center/data/study_center_repository.dart';
import '../../../study_center/data/study_models.dart';

class HomeStudySnapshot {
  const HomeStudySnapshot({
    required this.staff,
    required this.examName,
    required this.examDate,
    this.totalScore,
    this.maxScore,
    this.ranking,
    this.topScore,
    this.participants,
    this.scoreChange,
    this.rankingChange,
    this.subjects = const <({String name, double? score, String grade})>[],
  });

  final bool staff;
  final String examName;
  final String examDate;

  /// 学生：本人总分；老师：全体平均分。
  final double? totalScore;
  final double? maxScore;

  /// 学生：总排名。
  final int? ranking;

  /// 老师：本场最高分。
  final double? topScore;
  final int? participants;
  final double? scoreChange;
  final int? rankingChange;

  /// 学生：各科分数与档位；老师：各科平均分。
  final List<({String name, double? score, String grade})> subjects;
}

/// 首页「学情速览」：学生看最近一次已出分考试，教职工看最近一次考试的班级概况。
final homeStudySnapshotProvider =
    FutureProvider.autoDispose<HomeStudySnapshot?>((ref) async {
      final role = ref.watch(shellControllerProvider.select((s) => s.user.role));
      final effectiveRole = role.isNotEmpty
          ? role
          : DemoAccounts.fromToken(ref.read(appStorageProvider).token).roleKey;
      final repository = ref.watch(studyCenterRepositoryProvider);

      if (isStaffRole(effectiveRole)) {
        final examsResponse = await repository.teacherExams();
        if (!examsResponse.isSuccess) return null;
        final exams = StudyPage<TeacherExam>.fromJson(
          examsResponse.data,
          TeacherExam.fromJson,
        ).records.where((e) => e.isPublished).toList();
        if (exams.isEmpty) return null;
        final exam = exams.first;
        final rowsResponse = await repository.scoreQuery(examId: exam.examId);
        if (!rowsResponse.isSuccess) return null;
        final rows = StudyPage<ScoreQueryRow>.fromJson(
          rowsResponse.data,
          ScoreQueryRow.fromJson,
        ).records;
        final totals = [
          for (final row in rows)
            if (row.totalScore != null) row.totalScore!,
        ];
        if (totals.isEmpty) return null;
        double? averageOf(Iterable<double> values) {
          final list = values.toList();
          if (list.isEmpty) return null;
          return list.reduce((a, b) => a + b) / list.length;
        }

        return HomeStudySnapshot(
          staff: true,
          examName: exam.examName,
          examDate: exam.examDate,
          totalScore: averageOf(totals),
          maxScore: exam.fullScore,
          topScore: totals.reduce((a, b) => a > b ? a : b),
          participants: totals.length,
          subjects: [
            for (final subject in ArtSubject.values)
              (
                name: subject.label,
                score: averageOf([
                  for (final row in rows)
                    for (final s in row.subjectScores)
                      if (s.subjectName == subject.label && s.score != null)
                        s.score!,
                ]),
                grade: '',
              ),
          ],
        );
      }

      final response = await repository.overview();
      if (!response.isSuccess) return null;
      final overview = StudyOverview.fromJson(response.data);
      final stage = overview.recentStage;
      if (stage == null) return null;
      final exam = stage.exam;
      return HomeStudySnapshot(
        staff: false,
        examName: exam.examName,
        examDate: exam.examTime.length >= 10
            ? exam.examTime.substring(0, 10)
            : exam.examTime,
        totalScore: exam.totalScore,
        maxScore: exam.maxScore,
        ranking: exam.totalRanking,
        participants: exam.participantCount,
        scoreChange: stage.scoreChange,
        rankingChange: stage.rankingChange,
        subjects: [
          for (final subject in exam.subjects)
            (name: subject.subjectName, score: subject.score, grade: subject.grade),
        ],
      );
    });

class HomeStudySnapshotCard extends ConsumerWidget {
  const HomeStudySnapshotCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(homeStudySnapshotProvider);
    return snapshot.when(
      loading: () => const SizedBox(height: 112),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) => data == null
          ? const SizedBox.shrink()
          : _SnapshotCard(
              data: data,
              onOpen: () =>
                  Navigator.pushNamed(context, RoutePaths.studyCenter),
            ),
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({required this.data, required this.onOpen});

  final HomeStudySnapshot data;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final summary = _Summary(data: data);
            final subjects = _SubjectStrip(data: data);
            if (!wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  summary,
                  const SizedBox(height: 12),
                  subjects,
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 5, child: summary),
                const SizedBox(width: 16),
                Expanded(flex: 6, child: subjects),
                const SizedBox(width: 12),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: ArtColors.ink4,
                  size: 22,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.data});

  final HomeStudySnapshot data;

  @override
  Widget build(BuildContext context) {
    final change = data.scoreChange;
    return Row(
      children: [
        Container(
          width: 96,
          height: 84,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [ArtColors.brandSoft, ArtColors.brandDeep],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatScore(data.totalScore),
                  maxLines: 1,
                  style: ArtText.number(size: 24, color: Colors.white),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.staff
                    ? '平均分'
                    : '总分 / ${formatScore(data.maxScore)}',
                maxLines: 1,
                style: ArtText.caption(size: 11, color: const Color(0xE6FFFFFF)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data.staff ? '班级学情速览' : '学情速览',
                style: ArtText.caption(color: ArtColors.brandDeep),
              ),
              const SizedBox(height: 4),
              Text(
                data.examName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ArtText.title(size: 16),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(data.examDate, style: ArtText.caption()),
                  if (data.staff) ...[
                    Text('参考 ${data.participants ?? '—'} 人', style: ArtText.caption()),
                    Text('最高 ${formatScore(data.topScore)} 分', style: ArtText.caption()),
                  ] else
                    Text(
                      '总排名 ${data.ranking ?? '—'} / ${data.participants ?? '—'}',
                      style: ArtText.caption(),
                    ),
                  if (!data.staff && change != null && change != 0)
                    Text(
                      '较上次 ${change > 0 ? '+' : ''}${formatScore(change)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: change > 0 ? ArtColors.up : ArtColors.down,
                        fontWeight: AppFont.w500,
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubjectStrip extends StatelessWidget {
  const _SubjectStrip({required this.data});

  final HomeStudySnapshot data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < data.subjects.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _SubjectTile(item: data.subjects[i], staff: data.staff)),
        ],
      ],
    );
  }
}

class _SubjectTile extends StatelessWidget {
  const _SubjectTile({required this.item, required this.staff});

  final ({String name, double? score, String grade}) item;
  final bool staff;

  @override
  Widget build(BuildContext context) {
    final accent = artSubjectColor(item.name);
    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: artSubjectSoftColor(item.name),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  staff ? '${item.name}均分' : item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: accent,
                    fontWeight: AppFont.w600,
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ),
              if (!staff && item.grade.isNotEmpty)
                ArtGradeBadge(grade: item.grade, size: 20),
            ],
          ),
          Text(
            formatScore(item.score),
            style: ArtText.number(size: 22, color: ArtColors.ink),
          ),
        ],
      ),
    );
  }
}
