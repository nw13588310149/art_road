import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/art/art_subject.dart';
import '../../../../core/art/art_tokens.dart';
import '../../../../core/demo/demo_accounts.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/ui/ui.dart';
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

  /// 名次变化：正数表示名次上升。
  final int? rankingChange;

  /// 学生：各科分数与档位；老师：各科平均分。
  final List<({String name, double? score, String grade})> subjects;

  /// 卡片标题。成绩查询接口不带班级字段，教职工看到的是全画室成绩，标题如实写「画室」。
  String get title => staff ? '画室学情速览' : '学情速览';

  String get subtitle {
    final parts = [
      if (examName.isNotEmpty) examName,
      if (examDate.isNotEmpty) examDate,
      if (staff && participants != null) '全画室 $participants 人',
    ];
    return parts.join(' · ');
  }
}

/// 首页「学情速览」：学生看最近一次已出分考试，教职工看最近一次已发布考试的全画室概况。
final homeStudySnapshotProvider =
    FutureProvider.autoDispose<HomeStudySnapshot?>((ref) async {
      final role = ref.watch(shellControllerProvider.select((s) => s.user.role));
      final effectiveRole = role.isNotEmpty
          ? role
          : DemoAccounts.fromToken(ref.read(appStorageProvider).token).roleKey;
      final repository = ref.watch(studyCenterRepositoryProvider);

      // 宿管不查看学生成绩。
      if (effectiveRole == 'dormManager') return null;

      if (isStaffRole(effectiveRole)) {
        final examsResponse = await repository.teacherExams();
        if (!examsResponse.isSuccess) {
          throw StateError(examsResponse.displayMsg);
        }
        final exams = StudyPage<TeacherExam>.fromJson(
          examsResponse.data,
          TeacherExam.fromJson,
        ).records.where((e) => e.isPublished).toList();
        if (exams.isEmpty) return null;
        final exam = exams.first;
        final rowsResponse = await repository.scoreQuery(examId: exam.examId);
        if (!rowsResponse.isSuccess) {
          throw StateError(rowsResponse.displayMsg);
        }
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
      if (!response.isSuccess) {
        throw StateError(response.displayMsg);
      }
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
            (
              name: subject.subjectName,
              score: subject.score,
              grade: subject.grade,
            ),
        ],
      );
    });

class HomeStudySnapshotCard extends ConsumerWidget {
  const HomeStudySnapshotCard({super.key});

  static const double _bodyHeight = 76;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(homeStudySnapshotProvider);
    return snapshot.when(
      loading: () => const AppCard(
        title: '学情速览',
        child: SizedBox(
          height: _bodyHeight,
          child: Row(
            children: [
              Expanded(child: AppSkeleton(height: _bodyHeight, radius: 12)),
              SizedBox(width: AppSpace.s8),
              Expanded(child: AppSkeleton(height: _bodyHeight, radius: 12)),
              SizedBox(width: AppSpace.s8),
              Expanded(child: AppSkeleton(height: _bodyHeight, radius: 12)),
            ],
          ),
        ),
      ),
      error: (_, _) => AppCard(
        title: '学情速览',
        child: SizedBox(
          height: 168,
          child: AppErrorState(
            title: '学情速览加载失败',
            description: '请检查网络后重试',
            onRetry: () => ref.invalidate(homeStudySnapshotProvider),
          ),
        ),
      ),
      data: (data) => data == null
          ? const AppCard(
              title: '学情速览',
              child: SizedBox(
                height: 168,
                child: AppEmptyState(
                  icon: Icons.insights_rounded,
                  title: '暂无已出分的考试',
                  description: '月考出分后，这里会显示总分、排名和各科档位',
                ),
              ),
            )
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
    final full = data.maxScore;
    final tiles = <(int, Widget)>[
      if (data.staff) ...[
        (
          5,
          AppStatTile(
            label: '平均分',
            value: formatScore(data.totalScore),
            unit: full == null ? null : '/ ${formatScore(full)}',
            boxed: true,
          ),
        ),
        (
          4,
          AppStatTile(
            label: '最高分',
            value: formatScore(data.topScore),
            boxed: true,
          ),
        ),
      ] else ...[
        (
          6,
          AppStatTile(
            label: '总分',
            value: formatScore(data.totalScore),
            unit: full == null ? null : '/ ${formatScore(full)}',
            delta: data.scoreChange,
            deltaSuffix: ' 分',
            valueColor: AppColors.brand,
            boxed: true,
          ),
        ),
        (
          5,
          AppStatTile(
            label: '总排名',
            value: data.ranking?.toString() ?? '—',
            unit: data.participants == null ? null : '/ ${data.participants}',
            delta: data.rankingChange,
            deltaSuffix: ' 名',
            boxed: true,
          ),
        ),
      ],
      for (final subject in data.subjects)
        (
          4,
          AppStatTile(
            label: data.staff ? '${subject.name}均分' : subject.name,
            value: formatScore(subject.score),
            unit: subject.grade.isEmpty ? null : '${subject.grade} 档',
            boxed: true,
          ),
        ),
    ];

    return AppCard(
      title: data.title,
      subtitle: data.subtitle,
      trailing: const Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: AppColors.textPlaceholder,
      ),
      onTap: onOpen,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpace.s8),
            Expanded(flex: tiles[i].$1, child: tiles[i].$2),
          ],
        ],
      ),
    );
  }
}
