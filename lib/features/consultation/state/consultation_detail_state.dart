import 'package:flutter/foundation.dart';

import '../data/consultation_cover.dart';

@immutable
class ConsultationDetailArgs {
  const ConsultationDetailArgs({required this.id, this.sourceName});

  final int id;

  /// 校园课件等入口透传的学校名称（schoolList.name）；有值时覆盖默认「音乐之路」。
  final String? sourceName;

  factory ConsultationDetailArgs.fromRaw(dynamic raw) {
    if (raw is ConsultationDetailArgs) return raw;
    if (raw is int) return ConsultationDetailArgs(id: raw);
    if (raw is Map) {
      final id = raw['id'];
      final sourceName =
          raw['sourceName']?.toString() ?? raw['schoolName']?.toString();
      if (id is int) {
        return ConsultationDetailArgs(id: id, sourceName: sourceName);
      }
      if (id is num) {
        return ConsultationDetailArgs(id: id.toInt(), sourceName: sourceName);
      }
      final parsed = int.tryParse(id?.toString() ?? '');
      if (parsed != null) {
        return ConsultationDetailArgs(id: parsed, sourceName: sourceName);
      }
    }
    final parsed = int.tryParse(raw?.toString() ?? '');
    return ConsultationDetailArgs(id: parsed ?? 0);
  }

  @override
  bool operator ==(Object other) =>
      other is ConsultationDetailArgs &&
      other.id == id &&
      other.sourceName == sourceName;

  @override
  int get hashCode => Object.hash(id, sourceName);
}

@immutable
class ConsultationDetail {
  const ConsultationDetail({
    required this.id,
    required this.title,
    required this.source,
    required this.updateTime,
    required this.viewCount,
    required this.htmlContent,
    required this.coverUrl,
  });

  final int id;
  final String title;

  /// 1.0 中固定显示"音乐之路"，但接口可能也提供来源字段，留作扩展。
  final String source;

  /// yyyy-MM-dd HH:mm:ss 字符串，直接展示。
  final String updateTime;

  final int viewCount;
  final String htmlContent;

  /// 详情/分享封面图（优先 img1 首图，回退 shortText3）。
  final String coverUrl;

  factory ConsultationDetail.fromJson(Map raw) {
    return ConsultationDetail(
      id: _toInt(raw['id']) ?? 0,
      title: raw['title']?.toString() ?? '',
      source: raw['shortText1']?.toString().trim().isNotEmpty == true
          ? raw['shortText1'].toString().trim()
          : '音乐之路',
      updateTime: raw['updateTime']?.toString() ?? '',
      viewCount: _toInt(raw['viewCount']) ?? 0,
      htmlContent: raw['longText1']?.toString() ?? '',
      coverUrl: parseConsultationCoverUrl(raw),
    );
  }

  ConsultationDetail copyWith({String? source}) {
    return ConsultationDetail(
      id: id,
      title: title,
      source: source ?? this.source,
      updateTime: updateTime,
      viewCount: viewCount,
      htmlContent: htmlContent,
      coverUrl: coverUrl,
    );
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

@immutable
class ConsultationClass {
  const ConsultationClass({
    required this.id,
    required this.name,
    this.avatarUrl = '',
    required this.checked,
  });

  /// 班级主键。后端使用 19 位 snowflake id（字符串），转成 int 在 Web 平台
  /// 的 JS Number（53 位精度）下会丢失末位精度，所以这里始终保持字符串。
  final String id;
  final String name;
  final String avatarUrl;
  final bool checked;

  ConsultationClass copyWith({bool? checked}) => ConsultationClass(
    id: id,
    name: name,
    avatarUrl: avatarUrl,
    checked: checked ?? this.checked,
  );

  factory ConsultationClass.fromJson(Map raw) {
    return ConsultationClass(
      id: raw['id']?.toString() ?? '',
      name: (raw['groupName'] ?? raw['name'] ?? raw['className'] ?? '')
          .toString()
          .trim(),
      avatarUrl: (raw['logo'] ?? raw['groupLogo'] ?? raw['avatarUrl'] ?? '')
          .toString()
          .trim(),
      checked: false,
    );
  }
}

@immutable
class ConsultationDetailState {
  const ConsultationDetailState({
    required this.args,
    required this.loading,
    required this.detail,
    required this.classList,
    required this.shareDialogVisible,
    required this.classLoading,
    required this.sending,
    required this.errorMessage,
  });

  final ConsultationDetailArgs args;
  final bool loading;
  final ConsultationDetail? detail;
  final List<ConsultationClass> classList;
  final bool shareDialogVisible;
  final bool classLoading;
  final bool sending;
  final String errorMessage;

  bool get hasCheckedClass => classList.any((c) => c.checked);

  ConsultationDetailState copyWith({
    bool? loading,
    ConsultationDetail? detail,
    List<ConsultationClass>? classList,
    bool? shareDialogVisible,
    bool? classLoading,
    bool? sending,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ConsultationDetailState(
      args: args,
      loading: loading ?? this.loading,
      detail: detail ?? this.detail,
      classList: classList ?? this.classList,
      shareDialogVisible: shareDialogVisible ?? this.shareDialogVisible,
      classLoading: classLoading ?? this.classLoading,
      sending: sending ?? this.sending,
      errorMessage: clearErrorMessage
          ? ''
          : (errorMessage ?? this.errorMessage),
    );
  }

  static ConsultationDetailState fromArgs(ConsultationDetailArgs args) =>
      ConsultationDetailState(
        args: args,
        loading: true,
        detail: null,
        classList: const <ConsultationClass>[],
        shareDialogVisible: false,
        classLoading: false,
        sending: false,
        errorMessage: '',
      );
}
