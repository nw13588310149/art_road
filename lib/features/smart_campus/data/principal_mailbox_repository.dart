import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/snowflake_id.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/storage/app_storage.dart';

/// 智慧校园「校长信箱 + 意见反馈」相关接口的 Repository。学生 / 任课老师 /
/// 班主任 / 管理员四端共用同一个页面（[PrincipalMailboxView]），因此把
/// 「校长信箱」与「意见反馈」两组接口聚合在同一仓库中。
///
/// **校长信箱**（`POST /app/school/v2/user/*`）：
///   - `principalMailboxList`    我提交的校长信箱列表（按 status 过滤）
///   - `principalMailboxSubmit`  提交校长信箱
///
/// **校长端收件箱**（`POST /app/school/v2/headmaster/*`）：
///   - `headmasterPrincipalMailboxList`   校长查看来信列表
///   - `headmasterPrincipalMailboxReply`  校长回复来信
///
/// **意见反馈**（`POST /app/user/*`，与学校上下文无关）：
///   - `feedbackList`            我提交的意见反馈列表（分页）
///   - `feedbackSave`            提交意见反馈
///
/// 请求头 `app-token` / `schoolId` 由 [ApiClient] 统一注入；校长信箱列表
/// 接口无须单独传 `schoolId`，提交接口 body 的 `schoolId` 与请求头同源：
/// SharedPreferences 字符串缓存（Web 为 `flutter.schoolId`）。
/// 意见反馈接口与学校无关，仅需 token 即可。
final principalMailboxRepositoryProvider = Provider<PrincipalMailboxRepository>(
  (ref) {
    final client = ref.watch(apiClientProvider);
    final storage = ref.watch(appStorageProvider);
    return PrincipalMailboxRepository(client: client, storage: storage);
  },
);

class PrincipalMailboxRepository {
  PrincipalMailboxRepository({required this.client, required this.storage});

  final ApiClient client;
  final AppStorage storage;

  static const _base = '/app/school/v2/user';
  static const _headmasterBase = '/app/school/v2/headmaster';
  static const _userBase = '/app/user';

  /// 「我提交的校长信箱」列表。
  ///
  /// `status` 状态：
  /// - 0 已发送
  /// - 1 已回复
  /// - 2 已关闭
  Future<ApiResponse> principalMailboxList({
    int current = 1,
    int size = 10,
    int status = 0,
  }) {
    return client.post(
      '$_base/principalMailboxList',
      data: <String, dynamic>{
        'current': current,
        'size': size,
        'status': status,
      },
    );
  }

  /// 提交一封新的校长信。
  ///
  /// - [content]      正文内容（必填）
  /// - [msgType]      消息类型，例：举报 / 建议 / 其他
  /// - [isAnonymous]  是否匿名：0 否 / 1 是
  /// - [attachments]  附件 URL，多个用英文逗号分隔；无附件传空串
  ///
  /// `schoolId` 固定读 SharedPreferences 缓存（Web 本地键为 `flutter.schoolId`），
  /// 手写 JSON 字符串提交，避免 Map 序列化时雪花 id 被转成 null / 精度丢失。
  Future<ApiResponse> principalMailboxSubmit({
    required String content,
    required String msgType,
    int isAnonymous = 0,
    String attachments = '',
  }) {
    final sid = storage.schoolId.trim();
    if (sid.isEmpty || sid == '0') {
      return Future.value(ApiResponse.failure('未绑定学校'));
    }
    final encoded = encodeSnowflakeSafeRequestBody(<String, dynamic>{
      'attachments': attachments,
      'content': content,
      'isAnonymous': isAnonymous,
      'msgType': msgType,
      'schoolId': sid,
    });
    return client.post('$_base/principalMailboxSubmit', data: encoded);
  }

  /// 校长端：查看来信列表。
  ///
  /// `status`：0 已发送 / 1 已回复 / 2 已关闭
  Future<ApiResponse> headmasterPrincipalMailboxList({
    int current = 1,
    int size = 10,
    int status = 0,
  }) {
    return client.post(
      '$_headmasterBase/principalMailboxList',
      data: <String, dynamic>{
        'current': current,
        'size': size,
        'status': status,
      },
    );
  }

  /// 校长端：回复来信。
  Future<ApiResponse> headmasterPrincipalMailboxReply({
    required String id,
    required String replyContent,
  }) {
    final encoded = encodeNumericIdRequestBody(
      <String, dynamic>{'id': id, 'replyContent': replyContent},
      numericIdKeys: const {'id'},
    );
    if (encoded == null) {
      return Future.value(ApiResponse.failure('信件 id 无效'));
    }
    return client.post('$_headmasterBase/principalMailboxReply', data: encoded);
  }

  // ============== 意见反馈 ==============

  /// 「我提交的意见反馈」列表（分页）。返回数据通常为 `{records, total, ...}`
  /// 结构，由调用方按 `_asList` 规则容错解析。
  Future<ApiResponse> feedbackList({int current = 1, int size = 10}) {
    return client.post(
      '$_userBase/feedbackList',
      data: <String, dynamic>{'current': current, 'size': size},
    );
  }

  /// 提交一条意见反馈。仅 `content` 必填。
  Future<ApiResponse> feedbackSave({required String content}) {
    return client.post(
      '$_userBase/feedbackSave',
      data: <String, dynamic>{'content': content},
    );
  }
}
