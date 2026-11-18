import 'dart:async';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../../artworks/data/artwork_models.dart';
import '../../artworks/state/artwork_review_controller.dart';
import '../data/exam_critique_models.dart';
import '../data/study_center_repository.dart';
import 'study_detail_providers.dart';
import 'study_report_controller.dart';

// ───────────────────────────── 教职端 ─────────────────────────────

/// 班级学情里那一科讲评的状态（未开始 / 草稿 / 已发布）。从工作台回来时刷新。
final staffCritiqueSummaryProvider = FutureProvider.autoDispose
    .family<ExamCritiqueBoard, StudySubjectKey>((ref, key) async {
      final response = await ref
          .watch(studyCenterRepositoryProvider)
          .staffCritique(key.examId, key.subjectId);
      if (!response.isSuccess) {
        throw StudyLoadException(studyResponseMessage(response, '讲评加载失败'));
      }
      return ExamCritiqueBoard.fromJson(response.data);
    });

/// 打开讲评工作台的参数。[personalArchiveId] 不为空时直接给那位学生录个人讲评。
@immutable
class CritiqueWorkspaceArgs {
  const CritiqueWorkspaceArgs({
    required this.examId,
    required this.subjectId,
    this.personalArchiveId = '',
  });

  final String examId;
  final String subjectId;
  final String personalArchiveId;

  @override
  bool operator ==(Object other) =>
      other is CritiqueWorkspaceArgs &&
      other.examId == examId &&
      other.subjectId == subjectId &&
      other.personalArchiveId == personalArchiveId;

  @override
  int get hashCode => Object.hash(examId, subjectId, personalArchiveId);
}

@immutable
class ExamCritiqueState {
  const ExamCritiqueState({
    this.loading = true,
    this.loadFailed = false,
    this.errorMessage = '',
    this.board,
    this.selectedKey = '',
    this.draft,
    this.selectedMarkId,
    this.saving = false,
  });

  final bool loading;
  final bool loadFailed;
  final String errorMessage;
  final ExamCritiqueBoard? board;

  /// 选中的卷子（[critiquePaperKey]）。还没加进讲评的卷子也可以选中，先看一眼。
  final String selectedKey;

  /// 选中的、已加进讲评的那张卷子的工作副本；没保存的改动都在这里。
  final CritiquePaper? draft;
  final String? selectedMarkId;

  /// 保存、加入、移出、发布共用：同一时间只提交一件。
  final bool saving;

  ExamCritique get critique => board?.critique ?? const ExamCritique();

  bool get canEdit => board?.canEdit ?? false;

  CritiquePaper? get savedPaper => board?.paper(selectedKey);

  /// 选中的卷子已经在讲评里。
  bool get selectedAdded => savedPaper != null;

  String get selectedArchiveId {
    final index = selectedKey.indexOf(':');
    return index < 0 ? '' : selectedKey.substring(index + 1);
  }

  bool get selectedShared => !selectedKey.startsWith('personal:');

  CritiqueCandidate? get selectedCandidate =>
      board?.candidate(selectedArchiveId);

  bool get dirty {
    final current = draft;
    final saved = savedPaper;
    return current != null && saved != null && !current.sameContent(saved);
  }

  ArtworkMark? get selectedMark {
    final id = selectedMarkId;
    if (id == null) return null;
    for (final mark in draft?.marks ?? const <ArtworkMark>[]) {
      if (mark.id == id) return mark;
    }
    return null;
  }

  ExamCritiqueState copyWith({
    bool? loading,
    bool? loadFailed,
    String? errorMessage,
    ExamCritiqueBoard? board,
    String? selectedKey,
    CritiquePaper? draft,
    bool clearDraft = false,
    String? selectedMarkId,
    bool clearMark = false,
    bool? saving,
  }) {
    return ExamCritiqueState(
      loading: loading ?? this.loading,
      loadFailed: loadFailed ?? this.loadFailed,
      errorMessage: errorMessage ?? this.errorMessage,
      board: board ?? this.board,
      selectedKey: selectedKey ?? this.selectedKey,
      draft: clearDraft ? null : (draft ?? this.draft),
      selectedMarkId: clearMark ? null : (selectedMarkId ?? this.selectedMarkId),
      saving: saving ?? this.saving,
    );
  }
}

final examCritiqueControllerProvider = StateNotifierProvider.autoDispose
    .family<ExamCritiqueController, ExamCritiqueState, CritiqueWorkspaceArgs>((
      ref,
      args,
    ) {
      return ExamCritiqueController(
        repository: ref.watch(studyCenterRepositoryProvider),
        voiceUploader: ref.watch(artworkVoiceUploaderProvider),
        args: args,
      );
    });

/// 讲评工作台：选卷、加入 / 移出、在卷面上标几处、写总结、录语音、保存、发布。
class ExamCritiqueController extends StateNotifier<ExamCritiqueState> {
  ExamCritiqueController({
    required StudyCenterRepository repository,
    required this.args,
    ArtworkVoiceUploader? voiceUploader,
  }) : _repository = repository,
       _voiceUploader = voiceUploader,
       super(const ExamCritiqueState()) {
    unawaited(load());
  }

  final StudyCenterRepository _repository;
  final ArtworkVoiceUploader? _voiceUploader;
  final CritiqueWorkspaceArgs args;
  int _markSeq = 0;
  bool _personalHandled = false;

  String get _examId => args.examId;
  String get _subjectId => args.subjectId;

  Future<void> load() async {
    state = state.copyWith(loading: true, loadFailed: false, errorMessage: '');
    final response = await _repository.staffCritique(_examId, _subjectId);
    if (!mounted) return;
    if (!response.isSuccess) {
      state = state.copyWith(
        loading: false,
        loadFailed: state.board == null,
        errorMessage: studyResponseMessage(response, '讲评加载失败'),
      );
      return;
    }
    final board = ExamCritiqueBoard.fromJson(response.data);
    final keep = state.selectedKey.isNotEmpty ? state.selectedKey : '';
    final key = keep.isNotEmpty ? keep : _initialKey(board);
    state = ExamCritiqueState(
      loading: false,
      board: board,
      selectedKey: key,
      draft: board.paper(key),
    );
    await _openPersonal(board);
  }

  /// 从「阅卷明细」进来：还没有这位学生的个人讲评时先加上，直接开始录。
  Future<void> _openPersonal(ExamCritiqueBoard board) async {
    final archiveId = args.personalArchiveId;
    if (_personalHandled || archiveId.isEmpty) return;
    _personalHandled = true;
    final key = critiquePaperKey(archiveId, shared: false);
    if (board.paper(key) != null || !board.canEdit) {
      return;
    }
    await addPaper(archiveId: archiveId, shared: false);
  }

  String _initialKey(ExamCritiqueBoard board) {
    final personal = args.personalArchiveId;
    if (personal.isNotEmpty && board.candidate(personal) != null) {
      return critiquePaperKey(personal, shared: false);
    }
    final papers = board.critique.papers;
    if (papers.isNotEmpty) return papers.first.key;
    for (final band in board.bands) {
      for (final candidate in board.candidatesIn(band.grade)) {
        if (candidate.suggested) {
          return critiquePaperKey(candidate.archiveId, shared: true);
        }
      }
    }
    final first = board.candidates.firstOrNull;
    return first == null ? '' : critiquePaperKey(first.archiveId, shared: true);
  }

  /// 换一张卷子。手上这张有没保存的改动时先保存，保存失败就留在这张，返回 false。
  Future<bool> select(String key) async {
    if (key == state.selectedKey) return true;
    if (state.dirty && !await save()) return false;
    if (!mounted) return false;
    state = state.copyWith(
      selectedKey: key,
      draft: state.board?.paper(key),
      clearDraft: state.board?.paper(key) == null,
      clearMark: true,
    );
    return true;
  }

  /// 把一张卷子加进讲评（代表卷或个人点评），加上后选中它。
  Future<bool> addPaper({
    required String archiveId,
    required bool shared,
  }) async {
    final board = state.board;
    if (board == null || state.saving) return false;
    if (shared &&
        board.paper(critiquePaperKey(archiveId, shared: true)) == null &&
        board.critique.sharedCount >= ExamCritiqueRules.sharedPapers) {
      state = state.copyWith(
        errorMessage: '每科最多选 ${ExamCritiqueRules.sharedPapers} 张代表卷',
      );
      return false;
    }
    if (state.dirty && !await save()) return false;
    final key = critiquePaperKey(archiveId, shared: shared);
    final ok = await _submit(
      () => _repository.saveCritiquePaper(_examId, _subjectId, {
        'archiveId': archiveId,
        'shared': shared,
      }),
      '没能加入讲评，请稍后重试',
      selectKey: key,
    );
    return ok;
  }

  /// 把选中的卷子移出讲评（学生那边随之看不到）。
  Future<bool> removeSelected() async {
    final paper = state.savedPaper;
    if (paper == null) return false;
    final ok = await _submit(
      () => _repository.deleteCritiquePaper(
        _examId,
        _subjectId,
        archiveId: paper.archiveId,
        shared: paper.shared,
      ),
      '没能移出，请稍后重试',
      selectKey: paper.key,
    );
    return ok;
  }

  /// 保存选中的卷子；没有改动时直接返回 true。
  Future<bool> save() async {
    final draft = state.draft;
    if (draft == null || !state.dirty) return true;
    return _submit(
      () => _repository.saveCritiquePaper(
        _examId,
        _subjectId,
        draft.toSaveJson(),
      ),
      '讲评保存失败，请稍后重试',
      selectKey: draft.key,
    );
  }

  /// 发布或撤回。发布前先保存手上的改动。
  Future<bool> setPublished(bool published, {bool showNames = false}) async {
    if (published && state.dirty && !await save()) return false;
    return _submit(
      () => _repository.publishCritique(
        _examId,
        _subjectId,
        published: published,
        showNames: showNames,
      ),
      published ? '发布失败，请稍后重试' : '撤回失败，请稍后重试',
      selectKey: state.selectedKey,
    );
  }

  /// 提交一件写操作，成功后换上接口返回的整份讲评并选中 [selectKey]。
  Future<bool> _submit(
    Future<ApiResponse> Function() request,
    String fallback, {
    required String selectKey,
  }) async {
    if (state.saving) return false;
    state = state.copyWith(saving: true, errorMessage: '');
    final response = await request();
    if (!mounted) return false;
    if (!response.isSuccess) {
      state = state.copyWith(
        saving: false,
        errorMessage: studyResponseMessage(response, fallback),
      );
      return false;
    }
    final board = ExamCritiqueBoard.fromJson(response.data);
    final saved = board.paper(selectKey);
    final markId = state.selectedMarkId;
    final keepMark =
        saved != null &&
        saved.key == state.draft?.key &&
        saved.marks.any((m) => m.id == markId);
    state = state.copyWith(
      saving: false,
      board: board,
      selectedKey: selectKey,
      draft: saved,
      clearDraft: saved == null,
      clearMark: !keepMark,
    );
    return true;
  }

  /// 放弃没保存的改动。
  void discardChanges() {
    state = state.copyWith(
      draft: state.savedPaper,
      clearDraft: state.savedPaper == null,
      clearMark: true,
    );
  }

  // ── 卷面上的标记 ─────────────────────────────────────────────────────

  /// 在 [at]（按卷面归一化）加一处，返回它的 id；已满 20 处时返回 null。
  String? addMark(Offset at) {
    final draft = state.draft;
    if (draft == null || !state.canEdit) return null;
    final marks = _withoutEmpty(draft.marks, keep: null);
    if (marks.length >= ExamCritiqueRules.marksPerPaper) {
      state = state.copyWith(
        errorMessage: '每张卷子最多标 ${ExamCritiqueRules.marksPerPaper} 处',
      );
      return null;
    }
    final taken = marks.map((m) => m.id).toSet();
    String id;
    do {
      id = 'mk-${DateTime.now().millisecondsSinceEpoch}-${_markSeq++}';
    } while (taken.contains(id));
    state = state.copyWith(
      draft: draft.copyWith(
        marks: List<ArtworkMark>.unmodifiable([
          ...marks,
          ArtworkMark(
            id: id,
            x: at.dx.clamp(0.0, 1.0),
            y: at.dy.clamp(0.0, 1.0),
          ),
        ]),
      ),
      selectedMarkId: id,
    );
    return id;
  }

  /// 选中一处（null 为不选）。离开的那一处既没写字也没录音时去掉。
  void selectMark(String? id) {
    final draft = state.draft;
    if (draft == null) return;
    state = state.copyWith(
      draft: draft.copyWith(marks: _withoutEmpty(draft.marks, keep: id)),
      selectedMarkId: id,
      clearMark: id == null,
    );
  }

  void moveMark(String id, Offset to) =>
      _updateMark(id, (mark) => mark.copyWith(position: to));

  void setMarkText(String id, String text) => _updateMark(
    id,
    (mark) => mark.copyWith(
      text: String.fromCharCodes(
        text.runes.take(ExamCritiqueRules.markTextLimit),
      ),
    ),
  );

  void setMarkVoice(String id, String voiceUrl, int seconds) => _updateMark(
    id,
    (mark) => mark.copyWith(voiceUrl: voiceUrl, voiceSeconds: seconds),
  );

  void removeMark(String id) {
    final draft = state.draft;
    if (draft == null) return;
    state = state.copyWith(
      draft: draft.copyWith(
        marks: List<ArtworkMark>.unmodifiable([
          for (final mark in draft.marks)
            if (mark.id != id) mark,
        ]),
      ),
      clearMark: state.selectedMarkId == id,
    );
  }

  void setSummary(String text) {
    final draft = state.draft;
    if (draft == null) return;
    state = state.copyWith(
      draft: draft.copyWith(
        summary: String.fromCharCodes(
          text.runes.take(ExamCritiqueRules.summaryLimit),
        ),
      ),
    );
  }

  void setSummaryVoice(String voiceUrl, int seconds) {
    final draft = state.draft;
    if (draft == null) return;
    state = state.copyWith(
      draft: draft.copyWith(voiceUrl: voiceUrl, voiceSeconds: seconds),
    );
  }

  /// 上传一段语音，返回可保存的路径；失败返回 null。
  Future<String?> uploadVoice(Uint8List bytes, String filename) async {
    final uploader = _voiceUploader;
    if (uploader == null) return null;
    try {
      return await uploader(bytes, filename);
    } catch (_) {
      return null;
    }
  }

  void _updateMark(String id, ArtworkMark Function(ArtworkMark) change) {
    final draft = state.draft;
    if (draft == null) return;
    final index = draft.marks.indexWhere((mark) => mark.id == id);
    if (index < 0) return;
    final updated = change(draft.marks[index]);
    if (updated == draft.marks[index]) return;
    state = state.copyWith(
      draft: draft.copyWith(
        marks: List<ArtworkMark>.unmodifiable(
          [...draft.marks]..[index] = updated,
        ),
      ),
    );
  }

  static List<ArtworkMark> _withoutEmpty(
    List<ArtworkMark> marks, {
    required String? keep,
  }) => List<ArtworkMark>.unmodifiable([
    for (final mark in marks)
      if (!mark.isEmpty || mark.id == keep) mark,
  ]);

  void clearError() {
    state = state.copyWith(errorMessage: '');
  }
}

// ───────────────────────────── 学生端 ─────────────────────────────

@immutable
class StudentCritiqueState {
  const StudentCritiqueState({
    this.loading = true,
    this.failed = false,
    this.errorMessage = '',
    this.critique,
    this.selectedPaperId = '',
    this.selectedMarkKey,
  });

  final bool loading;
  final bool failed;
  final String errorMessage;
  final StudentExamCritique? critique;
  final String selectedPaperId;

  /// 选中的一处（[NumberedArtworkMark.key]）。
  final String? selectedMarkKey;

  List<CritiqueSection> get sections =>
      critique?.sections ?? const <CritiqueSection>[];

  CritiqueSection? get selectedSection {
    for (final section in sections) {
      if (section.paper.id == selectedPaperId) return section;
    }
    return sections.firstOrNull;
  }

  StudentCritiqueState copyWith({
    bool? loading,
    bool? failed,
    String? errorMessage,
    StudentExamCritique? critique,
    String? selectedPaperId,
    String? selectedMarkKey,
    bool clearMark = false,
  }) {
    return StudentCritiqueState(
      loading: loading ?? this.loading,
      failed: failed ?? this.failed,
      errorMessage: errorMessage ?? this.errorMessage,
      critique: critique ?? this.critique,
      selectedPaperId: selectedPaperId ?? this.selectedPaperId,
      selectedMarkKey: clearMark
          ? null
          : (selectedMarkKey ?? this.selectedMarkKey),
    );
  }
}

/// 学生看某一科的讲评。标为已读后，成绩报告上那一科的「新」随之去掉。
final studentCritiqueProvider = StateNotifierProvider.autoDispose
    .family<StudentCritiqueController, StudentCritiqueState, StudySubjectKey>((
      ref,
      key,
    ) {
      final report = studyReportControllerProvider(
        StudyReportKey(examId: key.examId),
      );
      return StudentCritiqueController(
        repository: ref.watch(studyCenterRepositoryProvider),
        subjectKey: key,
        onRead: () {
          if (ref.exists(report)) {
            ref.read(report.notifier).markCritiqueRead(key.subjectId);
          }
        },
      );
    });

class StudentCritiqueController extends StateNotifier<StudentCritiqueState> {
  StudentCritiqueController({
    required StudyCenterRepository repository,
    required this.subjectKey,
    this.onRead,
  }) : _repository = repository,
       super(const StudentCritiqueState()) {
    unawaited(load());
  }

  final StudyCenterRepository _repository;
  final StudySubjectKey subjectKey;
  final VoidCallback? onRead;
  bool _reading = false;

  Future<void> load() async {
    state = state.copyWith(loading: true, failed: false, errorMessage: '');
    final response = await _repository.studentCritique(
      subjectKey.examId,
      subjectKey.subjectId,
    );
    if (!mounted) return;
    if (!response.isSuccess) {
      state = state.copyWith(
        loading: false,
        failed: state.critique == null,
        errorMessage: studyResponseMessage(response, '讲评加载失败'),
      );
      return;
    }
    final critique = StudentExamCritique.fromJson(response.data);
    final keep = critique.papers.any((p) => p.id == state.selectedPaperId);
    state = StudentCritiqueState(
      loading: false,
      critique: critique,
      selectedPaperId: keep
          ? state.selectedPaperId
          : (critique.sections.firstOrNull?.paper.id ?? ''),
    );
  }

  void selectPaper(String id) {
    if (id == state.selectedPaperId) return;
    state = state.copyWith(selectedPaperId: id, clearMark: true);
  }

  /// 选中一处：换到它所在的那张卷子。null 为不选。
  void selectMark(String? key) {
    if (key == null) {
      state = state.copyWith(clearMark: true);
      return;
    }
    final paperId = key.split('/').first;
    state = state.copyWith(selectedPaperId: paperId, selectedMarkKey: key);
  }

  /// 打开讲评即算听过。只发一次。
  Future<void> markRead() async {
    final critique = state.critique;
    if (critique == null || critique.read || !critique.published || _reading) {
      return;
    }
    _reading = true;
    final response = await _repository.markCritiqueRead(
      subjectKey.examId,
      subjectKey.subjectId,
    );
    _reading = false;
    if (!mounted || !response.isSuccess) return;
    state = state.copyWith(critique: state.critique?.markedRead());
    onRead?.call();
  }

  void clearError() {
    state = state.copyWith(errorMessage: '');
  }
}
