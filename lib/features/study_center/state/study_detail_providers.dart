import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/study_center_repository.dart';
import '../data/study_models.dart';

/// 详情类接口失败时抛出，携带可直接展示的文案。
class StudyLoadException implements Exception {
  const StudyLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}

String studyErrorText(Object? error, String fallback) =>
    error is StudyLoadException && error.message.isNotEmpty
    ? error.message
    : fallback;

class StudySubjectKey {
  const StudySubjectKey({required this.examId, required this.subjectId});

  final String examId;
  final String subjectId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudySubjectKey &&
          examId == other.examId &&
          subjectId == other.subjectId;

  @override
  int get hashCode => Object.hash(examId, subjectId);
}

class StudyMarkingKey {
  const StudyMarkingKey({
    required this.archiveId,
    required this.examId,
    required this.subjectId,
  });

  final String archiveId;
  final String examId;
  final String subjectId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudyMarkingKey &&
          archiveId == other.archiveId &&
          examId == other.examId &&
          subjectId == other.subjectId;

  @override
  int get hashCode => Object.hash(archiveId, examId, subjectId);
}

/// 学生本人某科原卷（带水印文案与临时地址）。
final studyPaperProvider = FutureProvider.autoDispose
    .family<StudyPaper, StudySubjectKey>((ref, key) async {
      final response = await ref
          .watch(studyCenterRepositoryProvider)
          .paper(key.examId, key.subjectId);
      if (!response.isSuccess) {
        throw StudyLoadException(studyResponseMessage(response, '原卷加载失败'));
      }
      return StudyPaper.fromJson(response.data, subjectId: key.subjectId);
    });

/// 学生端某科评分标准（档位、样图、计分方式）。
final studyGradeStandardProvider = FutureProvider.autoDispose
    .family<GradeStandard, StudySubjectKey>((ref, key) async {
      final response = await ref
          .watch(studyCenterRepositoryProvider)
          .gradeStandard(key.examId, key.subjectId);
      if (!response.isSuccess) {
        throw StudyLoadException(studyResponseMessage(response, '评分标准加载失败'));
      }
      return GradeStandard.fromJson(response.data, subjectId: key.subjectId);
    });

/// 教职端某学生某科阅卷明细。
final staffMarkingReviewProvider = FutureProvider.autoDispose
    .family<MarkingReview, StudyMarkingKey>((ref, key) async {
      final response = await ref
          .watch(studyCenterRepositoryProvider)
          .studentMarking(
            archiveId: key.archiveId,
            examId: key.examId,
            subjectId: key.subjectId,
          );
      if (!response.isSuccess) {
        throw StudyLoadException(studyResponseMessage(response, '阅卷明细加载失败'));
      }
      return MarkingReview.fromJson(response.data);
    });
