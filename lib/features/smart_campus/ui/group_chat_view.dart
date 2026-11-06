// =============================================================================
// 智慧校园「群聊」独立页面（学生 / 教师 / 班主任 共用）
//
// 入口：所有角色 dashboard 快捷区「群聊」按钮 → controller.openGroupChat()
//      → mainView == groupChat → SmartCampusPage 路由到本视图。
//      返回：左侧会话栏顶部「返回」按钮（原「会话」标题位）→ onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. 顶部辅助 row（位于聊天主区上方）：抽屉按钮 + 「任课老师」下拉 +
//      「管理群聊」下拉（仅视觉，未挂业务逻辑）。
//   2. 双栏聊天主区（高 ~648）：
//      左 280 会话栏（白底圆左角）：
//          · 顶部返回按钮（原「会话」标题位）
//          · 264×40 灰底搜索框（占位"传统音乐"，仅视觉）
//          · 多条会话 cell（36 头像 + 群名 + 摘要 + 时间 + 红色未读徽章 +
//            免打扰图标），当前会话灰色高亮 #F5F6FA。
//      右 ~690 聊天主区（白底圆右角）：
//          · 顶部 68 高 header（与课表页同款 [AppAssets.authBgTop]）：群名 +
//            右侧 抽屉/详情图标；底色为 270deg `#C0D2F1→#E8C8F9`，
//            并叠加 `#F9EEFF→#F9EEFF` 与左侧白色淡出，整体看起来像
//            浅紫白渐变。
//          · 内嵌灰底圆角内容板（#F5F6FA padding 16）承载消息流：
//            ① 顶部紫色公告条（铃铛 + 公告内容 + 「编辑公告」 + 更新时间）
//            ② 中部消息 LIST（ListView）：
//               - 系统提示：「入群通知 李老师邀请了 教务处-王教务、赵宇 加入群聊」
//                          「群公告 李老师发布了最新群公告」
//               - 日期分隔："4月13日"
//               - 文本气泡（白底）：陈老师 — 招生简章已挂网
//               - 文件气泡：上海音乐学院2026本科招生简章.pdf 3.32M（蓝渐变 + 红 PDF 角标）
//               - 语音气泡：紫播放按钮 + 灰色波形 + 28s
//               - 当前正在播放的语音：紫色波形（已播放部分）+ 灰色（未播）
//            ③ 输入栏（白底 52 高）：左 attach + textfield + 表情 + 录音 +
//               紫色「发送」按钮（输入为空时变浅）。
//
// 颜色：白卡 / #F5F6FA 灰底板 / #EFF3FC 页面底 / #8741FF 主紫
//      / #325BFF 蓝（@提及/链接）/ #FF323C 红（未读）/ #F04545 红（角标）
// 字体：PingFang SC（中文） + Manrope（数字徽章）
//
// 消息模型：参考 1.0 `the-road-of-music/pages/SmartCampus/chat.vue`
//   - type=0 系统通知（item.text）/ type=1 文本（item.content）/
//   - type=2 图片（item.content url）/ type=3 富内容（item.param1 决定子类）
//      · param1=='kj'    课件分享
//      · param1=='video' 视频分享
//      · param1=='news'  资讯分享
//      · param1=='book'  课程分享
//      · param1=='voice' 录音分享（点击切换播放，同 1.0 `playVoice`）
//   - 这里 Flutter 端把消息收敛为 `_ChatMessage` 密封类树，对应 `_TextBubble`
//     `_FileBubble` `_VoiceBubble` `_ImageBubble`，方便后续接入 socket
//     消息时直接 mapping。
// =============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/network/chat_socket_service.dart';
import '../../../core/network/chat_sync_payload.dart';
import '../../../core/network/media_url.dart';
import '../../../core/network/snowflake_id.dart';
import '../../../core/widgets/app_asset_graphic.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/image_gallery_viewer.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../../core/widgets/wechat_emoji.dart';
import '../../recording_system/audio/recording_bytes_loader.dart';
import '../../recording_system/audio/recording_capture.dart';
import '../../recording_system/audio/recording_playback.dart';
import '../../shell/ui/shell_layout.dart';
import '../../courseware/ui/courseware_file_picker.dart';
import '../navigation/group_chat_return.dart';
import '../data/chat_repository.dart';
import '../data/teacher_repository.dart';
import '../services/group_chat_media_saver.dart';
import 'widgets/group_chat_media_action_sheet.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

const Color _kPageBg = Color(0xFFEFF3FC);
const Color _kCardBg = Colors.white;
const Color _kBoardBg = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextDivider = Color(0xFFCECED1);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleLight = Color(0xFFB48BFF);
const Color _kRecordRed = Color(0xFFFF323C);
const Color _kRecordRedLight = Color(0xFFFF7A7A);
const Color _kAnnouncementBg = Color(0xBDEFE5FF); // rgba(239,229,255,0.74)
const Color _kBlueLink = Color(0xFF325BFF);
const Color _kPdfBlueGradStart = Color(0xFFD7E2FF);
const Color _kPdfBlueGradEnd = Color(0xFFF9FBFF);
const Color _kPdfBorder = Color(0xFFE5EFFF);
const Color _kPdfRed = Color(0xFFFF5040);

// =============================================================================
// 顶级视图
// =============================================================================

class GroupChatView extends ConsumerStatefulWidget {
  const GroupChatView({
    super.key,
    required this.onBack,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserAvatarUrl,
  });

  final VoidCallback onBack;

  /// 当前登录用户的 id（来自 `myInfo.user.id`，雪花长整型字符串）。
  /// 用于 `fromUserId == currentUserId` 判断当前消息是否是自己发的。
  final String currentUserId;

  /// 当前登录用户名（出现在自己消息气泡的右侧 nickname）。
  final String currentUserName;

  /// 当前登录用户头像 URL；如果不可用，UI 会回退到首字母彩色头像。
  final String currentUserAvatarUrl;

  @override
  ConsumerState<GroupChatView> createState() => _GroupChatViewState();
}

/// `msgList` / `syncMsg` 每页拉的条数。后端默认 20，前端保持一致。
const int _kChatPageSize = 20;

/// 触发"加载更多旧消息"的滚动距离阈值。reverse:true 下用户滚到列表
/// 视觉顶端时 `position.maxScrollExtent - pixels` 会接近 0，留 120px 余
/// 量提前发起请求避免硬卡顿。
const double _kLoadOlderTriggerPx = 120;

Widget _wrapGroupChatDismissTap({
  required bool enabled,
  required VoidCallback onDismiss,
  required Widget child,
}) {
  if (!enabled) return child;
  return GestureDetector(
    behavior: HitTestBehavior.translucent,
    onTap: onDismiss,
    child: child,
  );
}

class _GroupChatViewState extends ConsumerState<GroupChatView>
    with WidgetsBindingObserver {
  // —— 会话 ——————————————————————————————————————————————————————
  /// `null` = 加载中；空 List = 已加载但接口返回空。
  List<_Conversation>? _conversations;
  String? _selectedConvId;

  // —— 消息列表（针对当前会话） —————————————————————————————————
  List<_ChatMessage> _messages = const [];
  bool _loadingMessages = false;
  int _msgLoadSeq = 0;

  // —— 消息分页 ————————————————————————————————————————————
  /// 当前会话还能不能继续往上翻：上次拉到不足一页时置 false。
  bool _hasMoreOlder = false;

  /// 正在拉旧消息时短暂为 true，避免滚动事件多次触发。
  bool _loadingOlder = false;

  /// 当前会话已加载的「最旧消息」的 id（即 `_messages.first.id`），
  /// 下次拉旧消息时作为 `offsetMsgId` 传给 `msgList`。
  String? _oldestMsgId;

  /// `msgList` 用的 ScrollController（reverse:true 模式下 offset=0 = 列表底
  /// = 最新一条消息）。切换会话时不重建，保留 attached 状态。
  final ScrollController _messagesController = ScrollController();

  /// `syncMsg` 跨会话维护的最大 offsetMsgId —— 每次 sync 完用响应里
  /// 最大的 msgId 更新它，下次只拉「之后」的消息。'0' 表示首次同步。
  String _syncOffsetMsgId = '0';

  /// 防止 sync 与初次 classList / app resume 并发触发自身。
  bool _syncing = false;

  /// sync 进行中又收到 WS 推送时，结束后补跑一轮。
  bool _syncPending = false;

  /// iOS / Android：WS 易被系统挂起，群聊页可见时轻量 syncMsg 兜底（Web 已验证 WS 足够）。
  Timer? _nativeSyncPollTimer;

  /// 全局长连接订阅：收到 `chatNewMessage` / `chatMessageDeleted`
  /// / `chatAnnouncementUpdated` 时触发刷新或局部更新。
  StreamSubscription<ChatSocketEvent>? _wsSubscription;

  // —— 群详情（公告 / 成员数 / 免打扰 / 是否班主任） ——————————————————
  String _announcement = '';
  String _announcementUpdatedAt = '';
  bool _canEditAnnouncement = false;
  int? _detailMemberCount;
  int _detailLoadSeq = 0;

  // 班级详情抽屉（教师 / 学生列表 / 班主任 / 班级名）
  _MemberInfo? _detailHeadTeacher;
  List<_MemberInfo> _detailTeachers = const [];
  List<_MemberInfo> _detailStudents = const [];
  String _detailClassName = '';
  String _detailLogo = '';

  // —— 发送 / 撤回 / 公告 / 免打扰 提交锁 ——————————————————————————
  bool _sending = false;
  final Set<String> _recalling = <String>{};
  bool _muteSaving = false;
  bool _pinSaving = false;
  bool _announcementSaving = false;
  bool _groupProfileSaving = false;

  String? _playingVoiceId;
  double _playingFraction = 0.32;
  bool _muted = false;
  bool _pinned = false;

  final TextEditingController _inputController = TextEditingController();

  // —— 语音录制状态 ———————————————————————————————————————————————
  // _voiceMode：mic icon 切换到语音输入模式后，输入栏被替换为大按钮。
  // _recording：长按"按住说话"时为 true，松手即结束。
  // _willCancel：录音过程中手指上滑超过阈值，进入"松开取消"状态。
  // _recordSeconds：当前录音时长秒数（每秒 +1）。
  // _liveWaveform：录音时滚动更新的波形采样（来自真实麦克风振幅）。
  bool _voiceMode = false;
  bool _showEmoji = false;
  bool _recording = false;
  bool _willCancel = false;
  int _recordSeconds = 0;
  late List<double> _liveWaveform;
  Timer? _recordTimer; // 用于计秒（1s 间隔）
  static const int _kLiveWaveLen = 56;

  /// 上滑取消的阈值（dy 小于该值即视为进入"松开取消"区域）。
  static const double _kCancelThresholdY = -56;

  // —— 真实录音 / 播放服务 —————————————————————————————————————
  RecordingCapture? _capture;
  StreamSubscription<double>? _captureSub; // 麦克风振幅流

  RecordingPlayback? _audioPlayer; // just_audio 播放实例
  StreamSubscription<RecordingPlaybackStatus>? _playerStatusSub;
  StreamSubscription<int>? _playerPositionSub;
  int? _playerDurationMs;

  @override
  void initState() {
    super.initState();
    _liveWaveform = List<double>.filled(_kLiveWaveLen, 0.18);
    // 监听滚动：列表滚到视觉顶端附近时自动拉一页更早的消息。
    _messagesController.addListener(_onMessagesScroll);
    // App 切回前台 / 重连 → didChangeAppLifecycleState 调 _syncMessages。
    WidgetsBinding.instance.addObserver(this);
    // 订阅全局 WS：服务端推群聊新消息 / 撤回 / 公告变更时实时刷新。
    final socket = ref.read(chatSocketServiceProvider);
    _wsSubscription = socket.events.listen(_handleSocketEvent);
    // 先进群聊再 reconnect，避免 App 冷启动时 connected/推送在订阅前被漏掉。
    socket.reconnect();
    if (!kIsWeb) {
      _nativeSyncPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted) unawaited(_syncMessages());
      });
    }
    // 进入页面后立即拉群聊列表；接着会触发一次 syncMsg 把离线消息补齐。
    Future.microtask(() async {
      await _loadConversations();
      if (!mounted) return;
      unawaited(_syncMessages());
    });
  }

  @override
  void dispose() {
    _nativeSyncPollTimer?.cancel();
    _nativeSyncPollTimer = null;
    unawaited(_wsSubscription?.cancel());
    _wsSubscription = null;
    _inputController.dispose();
    _recordTimer?.cancel();
    _captureSub?.cancel();
    _capture?.dispose();
    _playerStatusSub?.cancel();
    _playerPositionSub?.cancel();
    _audioPlayer?.dispose();
    _messagesController.removeListener(_onMessagesScroll);
    _messagesController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 处理全局 WS 下行事件。
  ///
  /// 兜底策略：服务端事件 payload 可能完整、也可能只携带 `classId` 信号位。
  /// 我们统一调用 [_syncMessages]，由后端 `syncMsg` 接口按 offsetMsgId
  /// 增量补齐 —— 既能覆盖"服务端只推信号"的情况，又能跟离线消息补齐路径
  /// 共享同一份合并逻辑（dedupe + 时间排序 + 未读/活跃区分），不会重复实现。
  ///
  /// 性能：syncMsg 接口本身是轻量的 offset 查询，瞬时几十 ms；高频群聊
  /// 时 _syncing 锁会自然合并并发请求，不会把后端打挂。
  void _handleSocketEvent(ChatSocketEvent event) {
    if (!mounted) return;
    switch (event.type) {
      case ChatSocketEventType.chatNewMessage:
        _applyRealtimeChatPayload(event.payload);
        unawaited(_syncMessages());
        break;
      case ChatSocketEventType.chatMessageDeleted:
        unawaited(_syncMessages());
        break;
      case ChatSocketEventType.connected:
        unawaited(_syncMessages());
        break;
      case ChatSocketEventType.message:
        // 兜底：若 WS 帧未被上层分类为 chatNewMessage，但语义上是群聊推送，
        // 仍触发一次就地合并 + syncMsg。
        final normalized = ChatSyncPayload.normalizePush(event.payload);
        if (ChatSyncPayload.hasChatIdentity(normalized)) {
          _applyRealtimeChatPayload(normalized);
          unawaited(_syncMessages());
        }
        break;
      case ChatSocketEventType.chatAnnouncementUpdated:
        // 公告变更：若刚好是当前会话，重新拉一次群详情；其它会话等用户
        // 切换进去再拉，不主动打扰。
        final classId = (event.payload['classId'] ?? event.payload['cId'] ?? '')
            .toString();
        if (classId.isEmpty) break;
        final convs = _conversations;
        if (convs == null) break;
        if (classId == _selectedConvId) {
          final hit = convs.where((c) => c.id == classId);
          if (hit.isNotEmpty) {
            unawaited(_loadGroupDetail(hit.first));
          }
        }
        break;
      default:
        break;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 切回前台时按 swagger 描述："登录 / 重连 / 切回前台时调用一次同步"，
    // 不做轮询。
    if (state == AppLifecycleState.resumed) {
      ref.read(chatSocketServiceProvider).reconnect();
      unawaited(_syncMessages());
    }
  }

  // ===========================================================================
  // 接口加载
  // ===========================================================================

  ChatRepository get _repo => ref.read(chatRepositoryProvider);
  TeacherRepository get _teacherRepo => ref.read(teacherRepositoryProvider);

  Future<void> _loadConversations() async {
    final res = await _repo.classList();
    if (!mounted) return;
    if (res.code != 0) {
      setState(() => _conversations = const []);
      AppToast.show(context, res.displayMsg);
      return;
    }
    final list = _sortConversations(_parseConversations(res.data));
    setState(() {
      _conversations = list;
      if (list.isNotEmpty) {
        _selectedConvId = list.first.id;
      }
    });
    if (list.isNotEmpty) {
      unawaited(_loadGroupDetail(list.first));
      unawaited(_loadMessages(list.first.id));
    }
  }

  Future<void> _loadGroupDetail(_Conversation conv) async {
    final seq = ++_detailLoadSeq;
    final res = await _repo.classDetail(classId: conv.id);
    if (!mounted || seq != _detailLoadSeq) return;
    if (res.code != 0) {
      setState(() {
        _announcement = '';
        _announcementUpdatedAt = '';
        _canEditAnnouncement = false;
        _detailMemberCount = null;
        _muted = conv.muted;
        _pinned = conv.pinned;
        _detailLogo = conv.avatarUrl ?? '';
      });
      return;
    }
    final detail = _parseGroupDetail(
      res.data,
      conv,
      currentUserId: widget.currentUserId,
    );
    setState(() {
      _announcement = detail.announcement;
      _announcementUpdatedAt = detail.announcementUpdatedAt;
      _canEditAnnouncement = detail.canEditAnnouncement;
      _detailMemberCount = detail.memberCount;
      _muted = detail.doNotDisturb;
      _pinned = detail.pinned;
      _detailHeadTeacher = detail.headTeacher;
      _detailTeachers = detail.teachers;
      _detailStudents = detail.students;
      _detailClassName = detail.className.isNotEmpty
          ? detail.className
          : conv.name;
      _detailLogo = detail.logo.isNotEmpty
          ? detail.logo
          : (conv.avatarUrl ?? '');
      _conversations = _conversations
          ?.map(
            (c) => c.id == conv.id
                ? c.copyWith(
                    name: _detailClassName,
                    avatarUrl: _detailLogo.isEmpty ? c.avatarUrl : _detailLogo,
                  )
                : c,
          )
          .toList();
    });
  }

  Future<void> _loadMessages(String classId) async {
    final seq = ++_msgLoadSeq;
    setState(() {
      _loadingMessages = true;
      _messages = const [];
      _hasMoreOlder = false;
      _loadingOlder = false;
      _oldestMsgId = null;
    });
    final res = await _repo.msgList(
      classId: classId,
      offsetMsgId: '0',
      size: _kChatPageSize,
    );
    if (!mounted || seq != _msgLoadSeq) return;
    if (res.code != 0) {
      setState(() => _loadingMessages = false);
      AppToast.show(context, res.displayMsg);
      return;
    }
    final parsed = _parseMessages(res.data);
    final pageCount = _countRawMessages(res.data);
    setState(() {
      _messages = parsed;
      _loadingMessages = false;
      _oldestMsgId = parsed.isNotEmpty ? parsed.first.id : null;
      // 后端按降序返回一页（默认 20）。返回数 < 页面大小说明已无更早消息。
      _hasMoreOlder = pageCount >= _kChatPageSize;
    });
    _bumpSyncOffsetFromMessages(parsed);
    _scheduleScrollToBottom();
  }

  /// 用户在消息区滚到视觉顶端时（reverse:true → maxScrollExtent 附近），
  /// 用 `_oldestMsgId` 作为 offsetMsgId 再拉一页。
  Future<void> _loadOlderMessages() async {
    final classId = _selectedConvId;
    if (classId == null) return;
    if (_loadingOlder || !_hasMoreOlder) return;
    final offset = _oldestMsgId;
    if (offset == null) return;
    setState(() => _loadingOlder = true);
    final seq = _msgLoadSeq; // 切换会话期间废弃当前请求
    final res = await _repo.msgList(
      classId: classId,
      offsetMsgId: offset,
      size: _kChatPageSize,
    );
    if (!mounted || seq != _msgLoadSeq) return;
    if (res.code != 0) {
      setState(() => _loadingOlder = false);
      AppToast.show(context, res.displayMsg);
      return;
    }
    final older = _parseMessages(res.data);
    final pageCount = _countRawMessages(res.data);
    if (older.isEmpty) {
      setState(() {
        _hasMoreOlder = false;
        _loadingOlder = false;
      });
      return;
    }
    // 去重：同一 msgId 不再插入。older 是按时间升序的（_parseMessages 已排序）。
    final existing = {for (final m in _messages) m.id};
    final dedup = older.where((m) => !existing.contains(m.id)).toList();
    setState(() {
      _messages = [...dedup, ..._messages];
      _oldestMsgId = _messages.isNotEmpty ? _messages.first.id : _oldestMsgId;
      _hasMoreOlder = pageCount >= _kChatPageSize;
      _loadingOlder = false;
    });
  }

  /// 滚动到「最新一条消息」位置：
  /// - 有更早历史（reverse 列表）：offset 0
  /// - 新群无历史（正序列表）：滚到 maxScrollExtent
  void _scrollToBottom({bool animated = false}) {
    if (!_messagesController.hasClients) return;
    final position = _messagesController.position;
    final target = _hasMoreOlder ? 0.0 : position.maxScrollExtent;
    if (animated) {
      _messagesController.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      _messagesController.jumpTo(target);
    }
  }

  void _scheduleScrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToBottom(animated: animated);
    });
  }

  void _onMessagesScroll() {
    if (!_messagesController.hasClients) return;
    if (_loadingOlder || !_hasMoreOlder) return;
    final pos = _messagesController.position;
    // reverse:true → 越靠近 maxScrollExtent 越接近列表「视觉顶端 / 最早消息」。
    final remaining = pos.maxScrollExtent - pos.pixels;
    if (remaining <= _kLoadOlderTriggerPx) {
      unawaited(_loadOlderMessages());
    }
  }

  /// `syncMsg`：登录 / 重连 / 切回前台时把离线消息批量补齐。`offsetMsgId`
  /// 起始用 `'0'`，之后用响应里看到的最大 msgId 增量同步。
  ///
  /// 解析后按 `classId` 分桶：
  ///   - 命中当前激活会话 → 直接 append 到 `_messages`（去重，按时间升序）
  ///     并自动滚到底部；
  ///   - 其它会话 → 更新会话列表的 `lastMessage` / `lastTime` / `unread`。
  Future<void> _syncMessages() async {
    if (_syncing) {
      _syncPending = true;
      return;
    }
    _syncing = true;
    try {
      final res = await _repo.syncMsg(offsetMsgId: _syncOffsetMsgId, size: 100);
      if (!mounted || res.code != 0) return;
      final raw = res.data;
      final list = ChatSyncPayload.extractMessageList(raw);
      if (list.isEmpty) return;
      // 按 classId 分桶：每条 sync 出来的消息都带 classId。
      final bucket = <String, List<Map<String, dynamic>>>{};
      String maxMsgId = _syncOffsetMsgId;
      for (final item in list) {
        if (item is! Map) continue;
        final m = item.map((k, v) => MapEntry(k.toString(), v));
        final classId = _readClassIdFromRaw(m);
        if (classId.isEmpty) continue;
        bucket.putIfAbsent(classId, () => []).add(m);
        final id = _readMsgIdFromRaw(m);
        if (id.isNotEmpty && _compareSnowflakeIds(id, maxMsgId) > 0) {
          maxMsgId = id;
        }
      }
      _syncOffsetMsgId = maxMsgId;

      // 当前激活会话：把解析后的消息合并到 `_messages` 末尾，去重 + 按时间升序。
      final activeId = _selectedConvId;
      var didMergeIntoActive = false;
      if (activeId != null && bucket.containsKey(activeId)) {
        final envelope = raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
        envelope['msgList'] = bucket[activeId];
        final newOnes = _parseMessages(envelope);
        if (newOnes.isNotEmpty) {
          final existing = {for (final m in _messages) m.id};
          final dedup = newOnes.where((m) => !existing.contains(m.id)).toList();
          if (dedup.isNotEmpty) {
            final merged = [..._messages, ...dedup]
              ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
            setState(() {
              _messages = merged;
            });
            didMergeIntoActive = true;
          }
        }
        // 激活会话不算未读，徽章清零。
        _bumpConversation(activeId, bucket[activeId]!, addUnread: false);
      }

      // 其它会话：bump 未读 + 更新 lastMessage / lastTime。
      for (final entry in bucket.entries) {
        if (entry.key == activeId) continue;
        _bumpConversation(entry.key, entry.value, addUnread: true);
      }

      if (didMergeIntoActive) {
        _scheduleScrollToBottom(animated: true);
      }
    } finally {
      _syncing = false;
      if (_syncPending) {
        _syncPending = false;
        unawaited(_syncMessages());
      }
    }
  }

  /// WS 推送携带完整消息体时，先就地合并到当前会话 / 会话列表，避免等
  /// syncMsg 往返才看到新消息。
  void _applyRealtimeChatPayload(Map<String, dynamic> payload) {
    final normalized = ChatSyncPayload.normalizePush(payload);
    final classId = _readClassIdFromRaw(normalized);
    if (classId.isEmpty) return;

    final msgId = _readMsgIdFromRaw(normalized);
    if (msgId.isNotEmpty && _compareSnowflakeIds(msgId, _syncOffsetMsgId) > 0) {
      _syncOffsetMsgId = msgId;
    }

    final raw = normalized.map((k, v) => MapEntry(k.toString(), v));
    final parser = GroupChatMessageParser(userMap: _memberUserMap());
    final parsed = parser.parseRaw(raw);
    if (parsed is! _ChatMessage) return;

    final activeId = _selectedConvId;
    if (classId == activeId) {
      if (_messages.any((m) => m.id == parsed.id)) return;
      setState(() {
        _messages = [..._messages, parsed]
          ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
      });
      _bumpConversation(classId, [raw], addUnread: false);
      _scheduleScrollToBottom(animated: true);
    } else {
      _bumpConversation(classId, [raw], addUnread: true);
    }
  }

  Map<String, _MemberInfo> _memberUserMap() {
    final map = <String, _MemberInfo>{};
    void add(_MemberInfo? m) {
      if (m == null || m.id.isEmpty) return;
      map[m.id] = m;
    }

    add(_detailHeadTeacher);
    for (final m in _detailTeachers) {
      add(m);
    }
    for (final m in _detailStudents) {
      add(m);
    }
    return map;
  }

  /// 19 位雪花 id 用字符串语义比较：长度优先，相同长度按字典序。
  /// 避免直接 int.parse 在 Web 端损失精度。
  int _compareSnowflakeIds(String a, String b) {
    if (a.length != b.length) return a.length.compareTo(b.length);
    return a.compareTo(b);
  }

  void _bumpSyncOffsetFromMessages(Iterable<_ChatMessage> messages) {
    for (final message in messages) {
      if (_compareSnowflakeIds(message.id, _syncOffsetMsgId) > 0) {
        _syncOffsetMsgId = message.id;
      }
    }
  }

  String _readClassIdFromRaw(Map<String, dynamic> raw) {
    return readSnowflakeId(raw['classId']) ?? readSnowflakeId(raw['cId']) ?? '';
  }

  String _readMsgIdFromRaw(Map<String, dynamic> raw) {
    return readSnowflakeId(raw['id']) ??
        readSnowflakeId(raw['msgId']) ??
        readSnowflakeId(raw['messageId']) ??
        '';
  }

  /// 把 sync 拉到的一组 raw 消息 reflect 到会话列表 cell（最近一条摘要 +
  /// 时间 + 未读计数）。raw 列表里取时间最新的一条作为 last。
  void _bumpConversation(
    String classId,
    List<Map<String, dynamic>> rawMessages, {
    required bool addUnread,
  }) {
    final convs = _conversations;
    if (convs == null) return;
    final idx = convs.indexWhere((c) => c.id == classId);
    if (idx < 0) return;
    Map<String, dynamic>? latest;
    DateTime? latestAt;
    for (final m in rawMessages) {
      final at = _parseDateTime(
        m['createTime'] ?? m['sentAt'] ?? m['time'] ?? m['msgTime'],
      );
      if (at == null) continue;
      if (latestAt == null || at.isAfter(latestAt)) {
        latestAt = at;
        latest = m;
      }
    }
    if (latest == null) return;
    final summary = _summaryFor(latest);
    final addedUnread = addUnread ? rawMessages.length : 0;
    final next = [...convs];
    next[idx] = next[idx].copyWith(
      lastMessage: summary,
      lastTime: _formatLastTime(latestAt),
      unread: convs[idx].unread + addedUnread,
    );
    setState(() => _conversations = next);
  }

  /// 把一条 raw 消息压成会话 cell 上的一行简介（图片/语音/文件给中文占位）。
  String _summaryFor(Map<String, dynamic> m) => _previewTextForRawMessage(m);

  /// 数页 raw count，与 `_parseMessages` 保持一致的 key 顺序。
  int _countRawMessages(Object? raw) {
    final l = raw is List
        ? raw
        : (raw is Map
              ? _asList(raw['msgList'] ?? raw['records'] ?? raw['list'])
              : const []);
    return l.length;
  }

  // ===========================================================================
  // 交互
  // ===========================================================================

  void _selectConversation(String id) {
    if (_selectedConvId == id) return;
    final conv = _conversations?.firstWhere(
      (c) => c.id == id,
      orElse: () => _Conversation(
        id: id,
        name: '',
        lastMessage: '',
        lastTime: '',
        unread: 0,
        muted: false,
        pinned: false,
        memberCount: 0,
      ),
    );
    setState(() {
      _selectedConvId = id;
      _playingVoiceId = null;
      _showEmoji = false;
      _abortRecording();
      // 进入会话即清零未读计数，与 IM 通用交互一致。
      final list = _conversations;
      if (list != null) {
        final idx = list.indexWhere((c) => c.id == id);
        if (idx >= 0 && list[idx].unread > 0) {
          final next = [...list];
          next[idx] = next[idx].copyWith(unread: 0);
          _conversations = next;
        }
      }
    });
    if (conv != null && conv.name.isNotEmpty) {
      unawaited(_loadGroupDetail(conv));
      unawaited(_loadMessages(id));
    }
  }

  void _toggleVoicePlay(String voiceMsgId) {
    // 找到对应气泡
    _VoiceBubble? bubble;
    for (final m in _messages) {
      if (m.id == voiceMsgId &&
          m is _UserChatMessage &&
          m.bubble is _VoiceBubble) {
        bubble = m.bubble as _VoiceBubble;
        break;
      }
    }

    // 如果点的是正在播放的，暂停
    if (_playingVoiceId == voiceMsgId) {
      _audioPlayer?.pause();
      setState(() {
        _playingVoiceId = null;
        _playingFraction = 0;
      });
      return;
    }

    // 停止之前的播放
    _audioPlayer?.stop();
    _playerStatusSub?.cancel();
    _playerPositionSub?.cancel();
    _playerPositionSub = null;
    _playerStatusSub = null;

    setState(() {
      _playingVoiceId = voiceMsgId;
      _playingFraction = 0;
    });

    final rawUrl = bubble?.url;
    if (rawUrl == null || rawUrl.isEmpty) return; // 无 URL（尚未上传），仅切换 UI 状态
    final url = _resolveMediaUrl(rawUrl);

    // 启动真实播放
    unawaited(_startVoicePlayback(voiceMsgId, url, bubble?.durationSec ?? 0));
  }

  Future<void> _startVoicePlayback(
    String msgId,
    String url,
    int totalSec,
  ) async {
    try {
      final player = _audioPlayer ?? (_audioPlayer = createRecordingPlayback());
      final isUrl = url.startsWith('http') || url.startsWith('blob:');
      final durationMs = await player.setSource(url, isUrl: isUrl);
      if (!mounted) return;

      _playerDurationMs = durationMs;

      _playerPositionSub?.cancel();
      _playerPositionSub = player.positionMs.listen((ms) {
        if (!mounted || _playingVoiceId != msgId) return;
        final total = _playerDurationMs ?? (totalSec * 1000);
        if (total <= 0) return;
        setState(() => _playingFraction = (ms / total).clamp(0.0, 1.0));
      });

      _playerStatusSub?.cancel();
      _playerStatusSub = player.status.listen((s) {
        if (!mounted) return;
        if (s.completed && _playingVoiceId == msgId) {
          setState(() {
            _playingVoiceId = null;
            _playingFraction = 0;
          });
        }
      });

      await player.play();
    } catch (_) {
      if (mounted) {
        setState(() {
          _playingVoiceId = null;
          _playingFraction = 0;
        });
      }
    }
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;
    final classId = _selectedConvId;
    if (classId == null) return;
    final tempId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = _UserChatMessage(
      id: tempId,
      fromUserId: widget.currentUserId,
      fromName: widget.currentUserName,
      avatarUrl: widget.currentUserAvatarUrl,
      avatarColor: const Color(0xFF8741FF),
      sentAt: DateTime.now(),
      bubble: _TextBubble(text: text),
    );
    setState(() {
      _sending = true;
      _messages = [..._messages, optimistic];
      _inputController.clear();
    });
    _scheduleScrollToBottom(animated: true);
    final res = await _repo.sendMsg(classId: classId, type: 1, content: text);
    if (!mounted) return;
    if (res.code == 0) {
      final newId = _extractMsgId(res.data);
      setState(() {
        _sending = false;
        if (newId != null) {
          if (_compareSnowflakeIds(newId, _syncOffsetMsgId) > 0) {
            _syncOffsetMsgId = newId;
          }
          _messages = _messages
              .map(
                (m) => m.id == tempId
                    ? _replaceUserMessageId(m as _UserChatMessage, newId)
                    : m,
              )
              .toList();
        }
      });
    } else {
      setState(() {
        _sending = false;
        _messages = _messages.where((m) => m.id != tempId).toList();
        _inputController.text = text;
      });
      AppToast.show(context, res.displayMsg);
    }
  }

  /// 撤回（删除）消息：仅自己发的或群管理可发起。后端会再做权限校验。
  Future<void> _recallMessage(_UserChatMessage message) async {
    if (message.fromUserId != widget.currentUserId) return;
    final msgId = message.id;
    if (msgId.startsWith('local-')) {
      AppToast.show(context, '消息未同步，请稍后再试');
      return;
    }
    if (_recalling.contains(msgId)) return;
    final ok = await showConfirmDialog(
      context: context,
      title: '撤回消息',
      content: '确定撤回这条消息吗？',
      confirmLabel: '撤回',
    );
    if (!ok) return;
    setState(() => _recalling.add(msgId));
    final res = await _repo.deleteMsg(msgId: msgId);
    if (!mounted) return;
    if (res.code == 0) {
      setState(() {
        _messages = _messages.where((m) => m.id != msgId).toList();
        _recalling.remove(msgId);
      });
      AppToast.show(context, '已撤回');
    } else {
      setState(() => _recalling.remove(msgId));
      AppToast.show(context, res.displayMsg);
    }
  }

  Future<void> _onMessageLongPress(_UserChatMessage message) async {
    final downloads = _downloadItemsForBubble(message.bubble);
    final extras = <GroupChatMessageAction>[];
    if (message.fromUserId == widget.currentUserId &&
        !message.id.startsWith('local-')) {
      extras.add(
        GroupChatMessageAction(
          label: '撤回',
          destructive: true,
          onSelected: () => _recallMessage(message),
        ),
      );
    }
    if (downloads.isEmpty && extras.isEmpty) return;
    await showGroupChatMessageActionSheet(
      context,
      downloadItems: downloads,
      extraActions: extras,
    );
  }

  Future<void> _toggleMute() async {
    if (_muteSaving) return;
    final classId = _selectedConvId;
    if (classId == null) return;
    final next = !_muted;
    setState(() {
      _muteSaving = true;
      _muted = next;
    });
    final res = await _repo.updateDoNotDisturb(
      classId: classId,
      doNotDisturb: next,
    );
    if (!mounted) return;
    if (res.code == 0) {
      setState(() => _muteSaving = false);
      AppToast.show(context, next ? '已开启免打扰' : '已取消免打扰');
    } else {
      setState(() {
        _muteSaving = false;
        _muted = !next;
      });
      AppToast.show(context, res.displayMsg);
    }
  }

  Future<void> _togglePin() async {
    if (_pinSaving) return;
    final classId = _selectedConvId;
    if (classId == null) return;
    final next = !_pinned;
    setState(() {
      _pinSaving = true;
      _pinned = next;
    });
    final res = await _repo.pinnedClass(
      classId: classId,
      isPinned: next ? 1 : 0,
    );
    if (!mounted) return;
    if (res.code == 0) {
      setState(() {
        _pinSaving = false;
        _conversations = _sortConversations(
          _conversations
                  ?.map((c) => c.id == classId ? c.copyWith(pinned: next) : c)
                  .toList() ??
              const [],
        );
      });
      AppToast.show(context, next ? '已置顶' : '已取消置顶');
    } else {
      setState(() {
        _pinSaving = false;
        _pinned = !next;
      });
      AppToast.show(context, res.displayMsg);
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_sending) return;
    final classId = _selectedConvId;
    if (classId == null) return;
    final picked = await pickCoursewareFiles(
      allowMultiple: false,
      type: CoursewarePickType.image,
    );
    if (!mounted || picked.isEmpty) return;
    final file = picked.first;
    if (!file.canUpload) {
      AppToast.show(context, '无法读取图片');
      return;
    }

    final tempId = 'local-${DateTime.now().microsecondsSinceEpoch}';

    Uint8List? bytes = file.bytes;
    if ((bytes == null || bytes.isEmpty) && file.path != null) {
      bytes = await loadRecordedBytes(file.path!);
    }
    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) {
      AppToast.show(context, '无法读取图片');
      return;
    }

    final optimistic = _UserChatMessage(
      id: tempId,
      fromUserId: widget.currentUserId,
      fromName: widget.currentUserName,
      avatarUrl: widget.currentUserAvatarUrl,
      avatarColor: const Color(0xFF8741FF),
      sentAt: DateTime.now(),
      bubble: _ImageBubble(url: '', localBytes: bytes, uploading: true),
    );
    setState(() {
      _sending = true;
      _messages = [..._messages, optimistic];
    });
    _scheduleScrollToBottom(animated: true);

    try {
      final filename = file.name.isNotEmpty
          ? file.name
          : 'chat_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final uploadRes = await _repo.uploadImage(
        bytes: bytes,
        filename: filename,
      );
      if (!mounted) return;
      if (!uploadRes.isSuccess) {
        _removeAndWarn(tempId, uploadRes.displayMsg);
        setState(() => _sending = false);
        return;
      }
      final url = _extractUploadUrl(uploadRes.data);
      if (url == null || url.isEmpty) {
        _removeAndWarn(tempId, '图片上传失败');
        setState(() => _sending = false);
        return;
      }
      final sendRes = await _repo.sendMsg(
        classId: classId,
        type: 2,
        content: url,
      );
      if (!mounted) return;
      if (sendRes.isSuccess) {
        final newId = _extractMsgId(sendRes.data) ?? tempId;
        setState(() {
          _sending = false;
          _messages = _messages.map((m) {
            if (m.id != tempId || m is! _UserChatMessage) return m;
            return _UserChatMessage(
              id: newId,
              sentAt: m.sentAt,
              fromUserId: m.fromUserId,
              fromName: m.fromName,
              avatarUrl: m.avatarUrl,
              avatarColor: m.avatarColor,
              bubble: _ImageBubble(url: url),
            );
          }).toList();
        });
      } else {
        _removeAndWarn(tempId, sendRes.displayMsg);
        setState(() => _sending = false);
      }
    } catch (_) {
      if (mounted) {
        _removeAndWarn(tempId, '图片发送失败');
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _editAnnouncement() async {
    if (!_canEditAnnouncement || _announcementSaving) return;
    final classId = _selectedConvId;
    if (classId == null) return;
    final text = await _showAnnouncementEditor(_announcement);
    if (text == null) return;
    final draft = text.trim();
    setState(() => _announcementSaving = true);
    final res = await _repo.updateAnnouncement(
      classId: classId,
      announcement: draft,
    );
    if (!mounted) return;
    setState(() => _announcementSaving = false);
    if (res.code == 0) {
      setState(() {
        _announcement = draft;
        _announcementUpdatedAt =
            '更新于 ${_formatLastTime(DateTime.now(), withDateForOldDays: false)}';
      });
      AppToast.show(context, '群公告已更新');
    } else {
      AppToast.show(context, res.displayMsg);
    }
  }

  Future<String?> _showAnnouncementEditor(String initial) {
    final ctrl = TextEditingController(text: initial);
    return showScaledDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return GradientHeaderDialog(
          width: 480,
          title: '编辑群公告',
          actionBar: AppDialogActionBar(
            cancelLabel: '取消',
            confirmLabel: '保存',
            onCancel: () => Navigator.of(dialogContext).pop(),
            onConfirm: () => Navigator.of(dialogContext).pop(ctrl.text),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: AppTextField(
              controller: ctrl,
              maxLines: 8,
              minLines: 6,
              maxLength: 500,
              cursorColor: const Color(0xFF8741FF),
              cursorWidth: 1.5,
              cursorHeight: 16,
              style: const TextStyle(
                fontSize: 14,
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                height: 1.55,
              ),
              decoration: InputDecoration(
                hintText: '请输入群公告内容',
                hintStyle: const TextStyle(
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                ),
                filled: true,
                fillColor: _kBoardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kPurple, width: 1),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _editGroupProfile(_Conversation conv) async {
    if (!_canEditAnnouncement || _groupProfileSaving) return;
    final initialName = _detailClassName.isNotEmpty
        ? _detailClassName
        : conv.name;
    final initialLogo = _detailLogo.isNotEmpty
        ? _detailLogo
        : (conv.avatarUrl ?? '');
    final result = await _showGroupProfileEditor(
      initialName: initialName,
      initialLogo: initialLogo,
    );
    if (!mounted || result == null) return;
    final groupName = result.groupName.trim();
    if (groupName.isEmpty) {
      AppToast.show(context, '请输入群聊名称');
      return;
    }
    setState(() => _groupProfileSaving = true);
    final res = await _teacherRepo.classUpdate(<String, dynamic>{
      'id': conv.id,
      'groupName': groupName,
      'logo': result.logo,
    });
    if (!mounted) return;
    setState(() => _groupProfileSaving = false);
    if (!res.isSuccess) {
      AppToast.show(context, res.displayMsg);
      return;
    }
    setState(() {
      _detailClassName = groupName;
      _detailLogo = result.logo;
      _conversations = _conversations
          ?.map(
            (c) => c.id == conv.id
                ? c.copyWith(name: groupName, avatarUrl: result.logo)
                : c,
          )
          .toList();
    });
    AppToast.show(context, '群资料已保存');
    final updated = _conversations?.firstWhere(
      (c) => c.id == conv.id,
      orElse: () => conv.copyWith(name: groupName, avatarUrl: result.logo),
    );
    if (updated != null) {
      unawaited(_loadGroupDetail(updated));
    }
  }

  Future<({String groupName, String logo})?> _showGroupProfileEditor({
    required String initialName,
    required String initialLogo,
  }) {
    final nameCtrl = TextEditingController(text: initialName);
    var logo = initialLogo;
    var uploading = false;

    return showScaledDialog<({String groupName, String logo})>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickAndUploadLogo() async {
              if (uploading) return;
              final files = await pickCoursewareFiles(
                allowMultiple: false,
                type: CoursewarePickType.image,
              );
              if (!context.mounted || files.isEmpty) return;
              final file = files.first;
              if (!file.canUpload) {
                AppToast.show(context, '无法读取所选图片');
                return;
              }
              setDialogState(() => uploading = true);
              final uploadRes = file.hasPath
                  ? await _repo.uploadImagePath(
                      filePath: file.path!,
                      filename: file.name,
                    )
                  : await _repo.uploadImage(
                      bytes: file.bytes!,
                      filename: file.name,
                    );
              if (!context.mounted) return;
              setDialogState(() => uploading = false);
              if (!uploadRes.isSuccess) {
                AppToast.show(context, uploadRes.displayMsg);
                return;
              }
              final uploaded = _extractUploadUrl(uploadRes.data);
              if (uploaded == null || uploaded.isEmpty) {
                AppToast.show(context, '头像上传结果异常');
                return;
              }
              setDialogState(() => logo = uploaded);
            }

            return GradientHeaderDialog(
              width: 460,
              title: '编辑群资料',
              actionBar: AppDialogActionBar(
                cancelLabel: '取消',
                confirmLabel: _groupProfileSaving ? '保存中' : '保存',
                confirmEnabled: !uploading && !_groupProfileSaving,
                onCancel: () => Navigator.of(dialogContext).pop(),
                onConfirm: () {
                  Navigator.of(
                    dialogContext,
                  ).pop((groupName: nameCtrl.text, logo: logo));
                },
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: pickAndUploadLogo,
                        // 头像显示 100，但占位高度仍为 72，顶部对齐，避免变大后整体下移。
                        child: SizedBox(
                          width: 100,
                          height: 72,
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            maxWidth: 100,
                            maxHeight: 100,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                _AvatarCircle(
                                  avatarUrl: logo.isEmpty
                                      ? null
                                      : _resolveMediaUrl(logo),
                                  fallback: nameCtrl.text.trim().isEmpty
                                      ? '群聊'
                                      : nameCtrl.text.trim(),
                                  size: 100,
                                  radius: 16,
                                  color: _kPurple,
                                ),
                                Positioned(
                                  right: -4,
                                  bottom: -4,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: _kPurple,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: uploading
                                        ? const AppLoadingIndicator(
                                            size: 16,
                                            color: Colors.white,
                                          )
                                        : const Icon(
                                            Icons.camera_alt_rounded,
                                            size: 13,
                                            color: Colors.white,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 头像向下溢出 (100-72)，补足与输入框间距。
                    const SizedBox(height: 46),
                    AppTextField(
                      controller: nameCtrl,
                      maxLength: 30,
                      cursorColor: _kPurple,
                      cursorWidth: 1.5,
                      cursorHeight: 16,
                      style: const TextStyle(
                        fontSize: 14,
                        color: _kTextDark,
                        fontFamily: 'PingFang SC',
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        hintText: '请输入群聊名称',
                        counterText: '',
                        filled: true,
                        fillColor: _kBoardBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: _kPurple,
                            width: 1,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(nameCtrl.dispose);
  }

  // —— 班级详情抽屉 ——————————————————————————————————————————————————

  /// 右上角「列表」icon → 从右侧弹出班级详情抽屉。
  void _openGroupDetailDrawer() {
    if (_selectedConvId == null && _conversations?.isEmpty != false) return;
    final conv = _conversations?.firstWhere(
      (c) => c.id == _selectedConvId,
      orElse: () => _conversations!.first,
    );
    if (conv == null) return;
    // 在对话框打开前先捕获 DashboardScaleData，后续的 pageBuilder
    // context 是新路由的 context，不继承 InheritedWidget 树。
    final scaleData = DashboardScaleScope.maybeOf(context);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim, secAnim) {
        Widget drawer = _GroupDetailDrawer(
          className: _detailClassName.isNotEmpty ? _detailClassName : conv.name,
          logoUrl: _detailLogo.isNotEmpty ? _detailLogo : conv.avatarUrl,
          announcement: _announcement,
          headTeacher: _detailHeadTeacher,
          teachers: _detailTeachers,
          students: _detailStudents,
          memberCount:
              _detailMemberCount ??
              (_detailTeachers.length + _detailStudents.length),
          muted: _muted,
          onToggleMute: () {
            Navigator.of(ctx).pop();
            _toggleMute();
          },
          canEditAnnouncement: _canEditAnnouncement,
          onEditAnnouncement: _canEditAnnouncement
              ? () {
                  Navigator.of(ctx).pop();
                  // 等抽屉动画结束后再开编辑弹框
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _editAnnouncement(),
                  );
                }
              : null,
          canEditProfile: _canEditAnnouncement,
          onEditProfile: _canEditAnnouncement
              ? () {
                  Navigator.of(ctx).pop();
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _editGroupProfile(conv),
                  );
                }
              : null,
        );
        // 把捕获的 scale data 重新注入到对话框子树。
        if (scaleData != null) {
          drawer = DashboardScaleScope(data: scaleData, child: drawer);
        }
        return Align(
          alignment: Alignment.centerRight,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                ),
            child: drawer,
          ),
        );
      },
    );
  }

  // —— 语音模式切换 / 录制 ———————————————————————————————————————

  /// 输入栏 mic icon 点击 → 切到语音输入模式（大"按住说话"按钮）；
  /// 已在语音模式时 mic icon / keyboard icon 复用此函数切回文本输入。
  void _setShowEmoji(bool value) {
    if (_showEmoji == value) return;
    setState(() => _showEmoji = value);
  }

  void _toggleShowEmoji() => _setShowEmoji(!_showEmoji);

  bool get _shouldDismissInputOnBlankTap =>
      _showEmoji || (_voiceMode && !_recording);

  /// 点击输入栏 / 表情面板以外的区域：收起表情 / 退出语音输入，回到正常文本输入。
  void _dismissSpecialInputModes() {
    if (_showEmoji) _setShowEmoji(false);
    if (_voiceMode && !_recording) {
      setState(() {
        _voiceMode = false;
        _abortRecording();
      });
    }
  }

  void _toggleVoiceMode() {
    setState(() {
      _voiceMode = !_voiceMode;
      if (_voiceMode) _showEmoji = false;
      // 切换出语音模式时，若有未发送的录音直接丢弃。
      if (!_voiceMode) _abortRecording();
    });
  }

  /// 长按按下时触发：向用户请求麦克风权限后开始真实录音，
  /// 同时订阅振幅流实时更新波形，并启动 1s 计秒定时器。
  Future<void> _onRecordPressStart() async {
    if (_recording) return;
    // 获取 / 复用 RecordingCapture 实例
    final capture = _capture ?? (_capture = createRecordingCapture());
    final hasPerm = await capture.hasPermission();
    if (!mounted) return;
    if (!hasPerm) {
      AppToast.show(context, '请授权麦克风权限后重试');
      return;
    }
    // 取消上一次订阅（防止重入）
    await _captureSub?.cancel();
    _captureSub = null;
    _recordTimer?.cancel();

    final path = buildTemporaryRecordingPath();
    try {
      await capture.start(path: path);
    } catch (_) {
      if (!mounted) return;
      AppToast.show(context, '无法启动录音，请检查麦克风权限');
      return;
    }
    if (!mounted) return;
    setState(() {
      _recording = true;
      _willCancel = false;
      _recordSeconds = 0;
      _liveWaveform = List<double>.filled(_kLiveWaveLen, 0.18);
    });
    // 订阅麦克风振幅，滚动更新波形
    _captureSub = capture.amplitudes.listen((amp) {
      if (!mounted || !_recording) return;
      // IO: dBFS (负数, 约 -50~0)；Web: 0.0~1.0。统一归一化到 0.1~1.0。
      final bar = _normalizeAmplitude(amp);
      setState(() {
        _liveWaveform = [..._liveWaveform.skip(1), bar];
      });
    });
    // 1 秒一次计秒（上限 60s）
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_recording) return;
      setState(() {
        if (_recordSeconds < 60) _recordSeconds++;
      });
    });
  }

  /// 将麦克风振幅归一化为 [0.1, 1.0] 的波形高度。
  /// IO: record 插件返回 dBFS（通常 -50~0）；Web: 0.0~1.0。
  double _normalizeAmplitude(double amp) {
    if (amp >= 0.0 && amp <= 1.0) return amp.clamp(0.1, 1.0);
    return ((amp + 50.0) / 50.0).clamp(0.1, 1.0);
  }

  /// 长按拖动时调用：根据 LongPress 起点的纵向偏移更新"是否取消"。
  void _onRecordPressMove(double offsetDy) {
    if (!_recording) return;
    final cancel = offsetDy < _kCancelThresholdY;
    if (cancel != _willCancel) {
      setState(() => _willCancel = cancel);
    }
  }

  /// 松手：停止录音，上传语音文件，发送消息。
  Future<void> _onRecordPressEnd() async {
    if (!_recording) return;
    if (_willCancel) {
      _abortRecording();
      return;
    }
    if (_recordSeconds < 1) {
      _abortRecording();
      if (mounted) AppToast.show(context, '录音时间太短');
      return;
    }
    final waveSnapshot = List<double>.from(_liveWaveform);
    final duration = _recordSeconds;
    final downsampled = _downsampleWaveform(waveSnapshot, 44);

    // 停止振幅订阅和计秒定时器
    await _captureSub?.cancel();
    _captureSub = null;
    _recordTimer?.cancel();
    _recordTimer = null;

    // 停止录音，获取文件路径 / blob URL
    String? path;
    try {
      path = await _capture?.stop();
    } catch (_) {
      path = null;
    }

    if (!mounted) return;
    setState(() {
      _recording = false;
      _willCancel = false;
    });

    final classId = _selectedConvId;
    if (classId == null) return;

    // 添加乐观消息（发送中）
    final tempId = 'local-voice-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = _UserChatMessage(
      id: tempId,
      fromUserId: widget.currentUserId,
      fromName: widget.currentUserName,
      avatarUrl: widget.currentUserAvatarUrl,
      avatarColor: const Color(0xFF8741FF),
      sentAt: DateTime.now(),
      bubble: _VoiceBubble(durationSec: duration, waveform: downsampled),
    );
    setState(() => _messages = [..._messages, optimistic]);
    _scheduleScrollToBottom(animated: true);

    if (path != null && path.isNotEmpty) {
      unawaited(
        _uploadAndSendVoice(
          path: path,
          duration: duration,
          waveform: downsampled,
          classId: classId,
          tempId: tempId,
        ),
      );
    }
  }

  /// 中止录音：取消 / 短按 / 切换会话 / 切走 voice mode 时统一调用。
  void _abortRecording() {
    _captureSub?.cancel();
    _captureSub = null;
    _recordTimer?.cancel();
    _recordTimer = null;
    _capture?.cancel();
    if (!_recording && !_willCancel) return;
    setState(() {
      _recording = false;
      _willCancel = false;
      _recordSeconds = 0;
    });
  }

  // ── 语音上传 & 发送 ────────────────────────────────────────────

  /// 读取录音文件字节 → 上传 → sendMsg(type=3, param1='voice')。
  /// 成功后用带 URL 的 _VoiceBubble 替换乐观消息；失败则移除乐观消息并提示。
  Future<void> _uploadAndSendVoice({
    required String path,
    required int duration,
    required List<double> waveform,
    required String classId,
    required String tempId,
  }) async {
    try {
      // 平台通用：IO 读取文件字节，Web 读取 blob URL 字节
      final Uint8List bytes = await loadRecordedBytes(path);

      final isWebm = path.contains('.webm') || path.startsWith('blob:');
      final ext = isWebm ? 'webm' : 'm4a';
      final filename =
          'voice_chat_${DateTime.now().millisecondsSinceEpoch}.$ext';

      final uploadRes = await _repo.uploadVoice(
        bytes: bytes,
        filename: filename,
      );
      if (!mounted) return;
      if (!uploadRes.isSuccess) {
        _removeAndWarn(tempId, uploadRes.displayMsg);
        return;
      }

      final url = _extractUploadUrl(uploadRes.data);
      if (url == null || url.isEmpty) {
        _removeAndWarn(tempId, '语音上传失败');
        return;
      }

      final content = jsonEncode({'url': url, 'duration': duration});
      final sendRes = await _repo.sendMsg(
        classId: classId,
        type: 3,
        content: content,
        param1: 'voice',
      );
      if (!mounted) return;
      if (sendRes.isSuccess) {
        final newId = _extractMsgId(sendRes.data) ?? tempId;
        setState(() {
          _messages = _messages.map((m) {
            if (m.id != tempId || m is! _UserChatMessage) return m;
            return _UserChatMessage(
              id: newId,
              sentAt: m.sentAt,
              fromUserId: m.fromUserId,
              fromName: m.fromName,
              avatarUrl: m.avatarUrl,
              avatarColor: m.avatarColor,
              bubble: _VoiceBubble(
                durationSec: duration,
                waveform: waveform,
                url: url,
              ),
            );
          }).toList();
        });
      } else {
        _removeAndWarn(tempId, sendRes.displayMsg);
      }
    } catch (_) {
      if (mounted) _removeAndWarn(tempId, '语音发送失败');
    }
  }

  void _removeAndWarn(String tempId, String msg) {
    setState(() => _messages = _messages.where((m) => m.id != tempId).toList());
    AppToast.show(context, msg);
  }

  String? _extractUploadUrl(Object? data) {
    String? raw;
    if (data is String && data.isNotEmpty) {
      raw = data;
    } else if (data is Map) {
      raw = (data['url'] ?? data['path'] ?? data['fileUrl'])?.toString();
    }
    if (raw == null || raw.isEmpty) return null;
    final resolved = _resolveMediaUrl(raw);
    return resolved.isEmpty ? null : resolved;
  }

  String? _extractMsgId(Object? data) {
    if (data == null) return null;
    if (data is String && data.isNotEmpty) return data;
    if (data is int) return data.toString();
    if (data is Map) {
      return (data['msgId'] ?? data['id'])?.toString();
    }
    return null;
  }

  /// 把任意长度的波形重采样为 [target] 个柱：取桶平均。
  List<double> _downsampleWaveform(List<double> src, int target) {
    if (src.isEmpty) return List<double>.filled(target, 0.3);
    if (src.length <= target) {
      return List<double>.from(src);
    }
    final out = <double>[];
    final bucket = src.length / target;
    for (var i = 0; i < target; i++) {
      final start = (i * bucket).floor();
      final end = ((i + 1) * bucket).floor().clamp(start + 1, src.length);
      var sum = 0.0;
      for (var j = start; j < end; j++) {
        sum += src[j];
      }
      out.add(sum / (end - start));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final convs = _conversations ?? const <_Conversation>[];
    // 空列表时不再「整页占位」，仍按双栏布局渲染：左栏给 _ConversationListPane
    // 内置的「暂无班级」占位，右栏给一个无群可聊的友好状态（无 header /
    // 输入栏禁用），方便用户看清楚整体页面结构。
    final selectedId = convs.isEmpty ? '' : (_selectedConvId ?? convs.first.id);
    final currentConv = convs.isEmpty
        ? const _Conversation(
            id: '',
            name: '群聊',
            lastMessage: '',
            lastTime: '',
            unread: 0,
            muted: false,
            pinned: false,
            memberCount: 0,
          )
        : convs.firstWhere(
            (c) => c.id == selectedId,
            orElse: () => convs.first,
          );
    final memberCount = _detailMemberCount ?? currentConv.memberCount;
    return Container(
      color: _kPageBg,
      // 直接占满父容器，不再保留任何顶部辅助 row（任课老师 / 管理群聊
      // 等下拉按钮已下线，群信息走 header bar 上的 menu icon 入口）。
      child: _ChatLayout(
          conversations: convs,
          selectedConvId: selectedId,
          hasSelection: convs.isNotEmpty,
          onSelectConv: _selectConversation,
          messages: _messages,
          loadingMessages: _loadingMessages,
          loadingOlder: _loadingOlder,
          hasMoreOlder: _hasMoreOlder,
          messagesController: _messagesController,
          currentUserId: widget.currentUserId,
          playingVoiceId: _playingVoiceId,
          playingFraction: _playingFraction,
          onToggleVoice: _toggleVoicePlay,
          inputController: _inputController,
          onSend: _send,
          onBack: widget.onBack,
          currentConv: currentConv,
          memberCount: memberCount,
          announcement: _announcement,
          announcementUpdatedAt: _announcementUpdatedAt,
          canEditAnnouncement: _canEditAnnouncement,
          onEditAnnouncement: _editAnnouncement,
          onMessageLongPress: _onMessageLongPress,
          muted: _muted,
          pinned: _pinned,
          onToggleMute: _toggleMute,
          onTogglePin: _togglePin,
          onUploadImage: _pickAndSendImage,
          voiceMode: _voiceMode,
          recording: _recording,
          willCancel: _willCancel,
          liveWaveform: _liveWaveform,
          onToggleVoiceMode: _toggleVoiceMode,
          onRecordPressStart: _onRecordPressStart,
          onRecordPressMove: _onRecordPressMove,
          onRecordPressEnd: _onRecordPressEnd,
          onShowDetail: _openGroupDetailDrawer,
          showEmoji: _showEmoji,
          onToggleShowEmoji: _toggleShowEmoji,
          onSetShowEmoji: _setShowEmoji,
          shouldDismissInputOnBlankTap: _shouldDismissInputOnBlankTap,
          onDismissInputModes: _dismissSpecialInputModes,
        ),
    );
  }
}

/// 右侧聊天主区在「无选中会话 / 群聊列表为空」时的占位（替换原本
/// 「暂无消息，发送一条吧～」，避免提示用户去发消息）。
class _NoSelectionHint extends StatelessWidget {
  const _NoSelectionHint();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: ui(40), color: _kTextHint),
          SizedBox(height: ui(10)),
          Text(
            '暂无可聊的群聊',
            style: TextStyle(
              color: _kTextSecondary,
              fontSize: ui(13),
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 空会话占位：接口返回 0 群时嵌在「会话栏」搜索框下方代替群列表，
/// 整体页面骨架（双栏 + header bar + 输入栏）继续保留，避免给用户
/// 「整页空白」的错觉。
class _EmptyConversationsHint extends StatelessWidget {
  const _EmptyConversationsHint();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Text(
        '暂无班级',
        style: TextStyle(
          color: _kTextSecondary,
          fontSize: ui(13),
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w500,
        ),
      ),
    );
  }
}

// （已移除：_TopActionRow / _SquareIconChip / _DropdownChip 顶部辅助 row。
// 群聊业务直接占满容器，群详情等管理入口收敛到 header bar 上的 menu icon。）

// =============================================================================
// 双栏布局
// =============================================================================

class _ChatLayout extends StatelessWidget {
  const _ChatLayout({
    required this.conversations,
    required this.selectedConvId,
    required this.hasSelection,
    required this.onSelectConv,
    required this.messages,
    required this.loadingMessages,
    required this.loadingOlder,
    required this.hasMoreOlder,
    required this.messagesController,
    required this.currentUserId,
    required this.playingVoiceId,
    required this.playingFraction,
    required this.onToggleVoice,
    required this.inputController,
    required this.onSend,
    required this.onBack,
    required this.currentConv,
    required this.memberCount,
    required this.announcement,
    required this.announcementUpdatedAt,
    required this.canEditAnnouncement,
    required this.onEditAnnouncement,
    required this.onMessageLongPress,
    required this.muted,
    required this.pinned,
    required this.onToggleMute,
    required this.onTogglePin,
    required this.onUploadImage,
    required this.voiceMode,
    required this.recording,
    required this.willCancel,
    required this.liveWaveform,
    required this.onToggleVoiceMode,
    required this.onRecordPressStart,
    required this.onRecordPressMove,
    required this.onRecordPressEnd,
    required this.onShowDetail,
    required this.showEmoji,
    required this.onToggleShowEmoji,
    required this.onSetShowEmoji,
    required this.shouldDismissInputOnBlankTap,
    required this.onDismissInputModes,
  });

  final List<_Conversation> conversations;
  final String selectedConvId;

  /// 是否已经有「当前会话」可聊：会话列表为空 / 还没选中时为 false，
  /// 此时右侧聊天区会显示无选中占位（不显示「发送一条吧～」），
  /// 输入栏的发送按钮也由调用层在 `_send` 中拒绝处理。
  final bool hasSelection;
  final ValueChanged<String> onSelectConv;
  final List<_ChatMessage> messages;
  final bool loadingMessages;

  /// 是否正在拉「更早一页」消息：用作消息区顶端的 loader 显示。
  final bool loadingOlder;

  /// 是否还有更早消息可拉：上次返回不足一页时置 false，loader 不再显示。
  final bool hasMoreOlder;

  /// 消息 ListView 的 ScrollController（reverse:true，offset 0 = 最新一条）。
  final ScrollController messagesController;

  final String currentUserId;
  final String? playingVoiceId;
  final double playingFraction;
  final ValueChanged<String> onToggleVoice;
  final TextEditingController inputController;
  final VoidCallback onSend;
  final VoidCallback onBack;
  final _Conversation currentConv;
  final int memberCount;
  final String announcement;
  final String announcementUpdatedAt;
  final bool canEditAnnouncement;
  final VoidCallback onEditAnnouncement;
  final ValueChanged<_UserChatMessage> onMessageLongPress;
  final bool muted;
  final bool pinned;
  final VoidCallback onToggleMute;
  final VoidCallback onTogglePin;
  final VoidCallback onUploadImage;

  // —— 录音相关传入 ————————————————————————————————————————
  final bool voiceMode;
  final bool recording;
  final bool willCancel;
  final List<double> liveWaveform;
  final VoidCallback onToggleVoiceMode;
  final VoidCallback onRecordPressStart;
  final ValueChanged<double> onRecordPressMove;
  final VoidCallback onRecordPressEnd;
  final VoidCallback onShowDetail;
  final bool showEmoji;
  final VoidCallback onToggleShowEmoji;
  final ValueChanged<bool> onSetShowEmoji;
  final bool shouldDismissInputOnBlankTap;
  final VoidCallback onDismissInputModes;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < ui(720);
        if (compact) {
          // 紧凑布局：会话列表收起为顶部 horizontal scroll；下方是 chat。
          return Column(
            children: [
              _CompactConversationStrip(
                conversations: conversations,
                selectedConvId: selectedConvId,
                onSelect: onSelectConv,
                onBack: onBack,
                dismissTapEnabled: shouldDismissInputOnBlankTap,
                onDismissTap: onDismissInputModes,
              ),
              SizedBox(height: ui(8)),
              Expanded(
                child: _ChatRightPane(
                    conv: currentConv,
                    hasSelection: hasSelection,
                    memberCount: memberCount,
                    announcement: announcement,
                    announcementUpdatedAt: announcementUpdatedAt,
                    canEditAnnouncement: canEditAnnouncement,
                    onEditAnnouncement: onEditAnnouncement,
                    onMessageLongPress: onMessageLongPress,
                    messages: messages,
                    loadingMessages: loadingMessages,
                    loadingOlder: loadingOlder,
                    hasMoreOlder: hasMoreOlder,
                    messagesController: messagesController,
                    currentUserId: currentUserId,
                    playingVoiceId: playingVoiceId,
                    playingFraction: playingFraction,
                    onToggleVoice: onToggleVoice,
                    inputController: inputController,
                    onSend: onSend,
                    muted: muted,
                    pinned: pinned,
                    onToggleMute: onToggleMute,
                    onTogglePin: onTogglePin,
                    onUploadImage: onUploadImage,
                    outerCornerLeft: true,
                    voiceMode: voiceMode,
                    recording: recording,
                    willCancel: willCancel,
                    liveWaveform: liveWaveform,
                    onToggleVoiceMode: onToggleVoiceMode,
                    onRecordPressStart: onRecordPressStart,
                    onRecordPressMove: onRecordPressMove,
                    onRecordPressEnd: onRecordPressEnd,
                    onShowDetail: onShowDetail,
                    showEmoji: showEmoji,
                    onToggleShowEmoji: onToggleShowEmoji,
                    onSetShowEmoji: onSetShowEmoji,
                    dismissTapEnabled: shouldDismissInputOnBlankTap,
                    onDismissTap: onDismissInputModes,
                  ),
                ),
              ],
            );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: ui(230),
              child: _ConversationListPane(
                conversations: conversations,
                selectedConvId: selectedConvId,
                onSelect: onSelectConv,
                onBack: onBack,
                dismissTapEnabled: shouldDismissInputOnBlankTap,
                onDismissTap: onDismissInputModes,
              ),
            ),
            Expanded(
              child: _ChatRightPane(
                  conv: currentConv,
                  hasSelection: hasSelection,
                  memberCount: memberCount,
                  announcement: announcement,
                  announcementUpdatedAt: announcementUpdatedAt,
                  canEditAnnouncement: canEditAnnouncement,
                  onEditAnnouncement: onEditAnnouncement,
                  onMessageLongPress: onMessageLongPress,
                  messages: messages,
                  loadingMessages: loadingMessages,
                  loadingOlder: loadingOlder,
                  hasMoreOlder: hasMoreOlder,
                  messagesController: messagesController,
                  currentUserId: currentUserId,
                  playingVoiceId: playingVoiceId,
                  playingFraction: playingFraction,
                  onToggleVoice: onToggleVoice,
                  inputController: inputController,
                  onSend: onSend,
                  muted: muted,
                  pinned: pinned,
                  onToggleMute: onToggleMute,
                  onTogglePin: onTogglePin,
                  onUploadImage: onUploadImage,
                  voiceMode: voiceMode,
                  recording: recording,
                  willCancel: willCancel,
                  liveWaveform: liveWaveform,
                  onToggleVoiceMode: onToggleVoiceMode,
                  onRecordPressStart: onRecordPressStart,
                  onRecordPressMove: onRecordPressMove,
                  onRecordPressEnd: onRecordPressEnd,
                  onShowDetail: onShowDetail,
                  showEmoji: showEmoji,
                  onToggleShowEmoji: onToggleShowEmoji,
                  onSetShowEmoji: onSetShowEmoji,
                  dismissTapEnabled: shouldDismissInputOnBlankTap,
                  onDismissTap: onDismissInputModes,
                ),
              ),
            ],
          );
      },
    );
  }
}

// =============================================================================
// 班级详情抽屉（从右侧滑入）
// =============================================================================

class _GroupDetailDrawer extends StatelessWidget {
  const _GroupDetailDrawer({
    required this.className,
    required this.logoUrl,
    required this.announcement,
    required this.headTeacher,
    required this.teachers,
    required this.students,
    required this.memberCount,
    required this.muted,
    required this.onToggleMute,
    this.canEditAnnouncement = false,
    this.onEditAnnouncement,
    this.canEditProfile = false,
    this.onEditProfile,
  });

  final String className;
  final String? logoUrl;
  final String announcement;
  final _MemberInfo? headTeacher;
  final List<_MemberInfo> teachers;
  final List<_MemberInfo> students;
  final int memberCount;
  final bool muted;
  final VoidCallback onToggleMute;
  final bool canEditAnnouncement;
  final VoidCallback? onEditAnnouncement;
  final bool canEditProfile;
  final VoidCallback? onEditProfile;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 学生头像区域：班主任不重复展示在「任课老师」列表里。
    final teacherListExHead = headTeacher == null
        ? teachers
        : teachers.where((t) => t.id != headTeacher!.id).toList();
    final effectiveMemberCount = memberCount > 0
        ? memberCount
        : teachers.length + students.length;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: ui(520),
        height: double.infinity,
        color: _kCardBg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DetailDrawerHeader(
              memberCount: effectiveMemberCount,
              onClose: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Container(
                color: _kBoardBg,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(ui(16), ui(16), ui(16), ui(20)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 班级概要卡
                      _DetailSummaryCard(
                        className: className,
                        logoUrl: logoUrl,
                        memberCount: effectiveMemberCount,
                        teacherCount: teachers.length,
                        studentCount: students.length,
                        muted: muted,
                        onToggleMute: onToggleMute,
                        canEditProfile: canEditProfile,
                        onEditProfile: onEditProfile,
                      ),

                      // 班主任始终显示公告卡片（有内容展示内容，无内容展示空状态提示）
                      if (canEditAnnouncement ||
                          announcement.trim().isNotEmpty) ...[
                        SizedBox(height: ui(12)),
                        _DetailAnnouncementCard(
                          text: announcement,
                          canEdit: canEditAnnouncement,
                          onEdit: onEditAnnouncement,
                        ),
                      ],

                      if (headTeacher != null) ...[
                        SizedBox(height: ui(12)),
                        _DetailSectionCard(
                          title: '班主任',
                          children: [
                            _MemberTile(member: headTeacher!, badge: '班主任'),
                          ],
                        ),
                      ],

                      if (teacherListExHead.isNotEmpty) ...[
                        SizedBox(height: ui(12)),
                        _DetailSectionCard(
                          title: '任课老师',
                          count: teacherListExHead.length,
                          children: [_MemberGrid(members: teacherListExHead)],
                        ),
                      ],

                      if (students.isNotEmpty) ...[
                        SizedBox(height: ui(12)),
                        _DetailSectionCard(
                          title: '学生',
                          count: students.length,
                          children: [_MemberGrid(members: students)],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 抽屉顶栏：左侧紫色窄竖条 + 标题 + 成员数小徽章 + 右侧关闭，与
/// `_CheckInHistoryDrawer` / `_MakeupAuditDrawer` 一致。
class _DetailDrawerHeader extends StatelessWidget {
  const _DetailDrawerHeader({required this.memberCount, required this.onClose});

  final int memberCount;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(62),
      padding: EdgeInsets.symmetric(horizontal: ui(12)),
      decoration: const BoxDecoration(
        color: _kCardBg,
        border: Border(bottom: BorderSide(color: _kBorderSoft)),
      ),
      child: Row(
        children: [
          Container(
            width: ui(3.25),
            height: ui(15),
            decoration: BoxDecoration(
              color: _kPurple,
              borderRadius: BorderRadius.circular(ui(6)),
            ),
          ),
          SizedBox(width: ui(8)),
          Text(
            '班级详情',
            style: TextStyle(
              fontSize: ui(16),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w600,
              height: 1.2,
            ),
          ),
          if (memberCount > 0) ...[
            SizedBox(width: ui(8)),
            Container(
              padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(2)),
              decoration: BoxDecoration(
                color: _kPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(ui(8)),
              ),
              child: Text(
                '$memberCount 人',
                style: TextStyle(
                  fontSize: ui(11),
                  color: _kPurple,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1,
                ),
              ),
            ),
          ],
          const Spacer(),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(ui(8)),
            child: Padding(
              padding: EdgeInsets.all(ui(8)),
              child: Icon(
                Icons.close_rounded,
                size: ui(18),
                color: _kTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 班级概要卡：班级头像 + 名称 + 统计 + 免打扰开关。
class _DetailSummaryCard extends StatelessWidget {
  const _DetailSummaryCard({
    required this.className,
    required this.logoUrl,
    required this.memberCount,
    required this.teacherCount,
    required this.studentCount,
    required this.muted,
    required this.onToggleMute,
    this.canEditProfile = false,
    this.onEditProfile,
  });

  final String className;
  final String? logoUrl;
  final int memberCount;
  final int teacherCount;
  final int studentCount;
  final bool muted;
  final VoidCallback onToggleMute;
  final bool canEditProfile;
  final VoidCallback? onEditProfile;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(14)),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: canEditProfile ? onEditProfile : null,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _AvatarCircle(
                      avatarUrl: (logoUrl ?? '').isEmpty
                          ? null
                          : _resolveMediaUrl(logoUrl),
                      fallback: className,
                      size: ui(44),
                      radius: ui(10),
                      color: _kPurple,
                    ),
                    if (canEditProfile)
                      Positioned(
                        right: ui(-3),
                        bottom: ui(-3),
                        child: Container(
                          width: ui(16),
                          height: ui(16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _kPurple,
                            borderRadius: BorderRadius.circular(ui(5)),
                            border: Border.all(
                              color: Colors.white,
                              width: ui(1.5),
                            ),
                          ),
                          child: Icon(
                            Icons.edit_rounded,
                            size: ui(10),
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: ui(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  className,
                                  style: TextStyle(
                                    fontSize: ui(15),
                                    color: _kTextDark,
                                    fontFamily: 'PingFang SC',
                                    fontWeight: AppFont.w600,
                                    height: 1.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (canEditProfile) ...[
                                SizedBox(width: ui(6)),
                                GestureDetector(
                                  onTap: onEditProfile,
                                  child: AppAssetGraphic(
                                    AppAssets.groupChatSet,
                                    width: ui(14),
                                    height: ui(14),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ui(4)),
                    Row(
                      children: [
                        _SummaryChip(
                          icon: Icons.people_alt_rounded,
                          label: '$memberCount 人',
                          color: _kPurple,
                        ),
                        SizedBox(width: ui(6)),
                        _SummaryChip(
                          icon: Icons.school_outlined,
                          label: '老师 $teacherCount',
                          color: const Color(0xFF325BFF),
                        ),
                        SizedBox(width: ui(6)),
                        _SummaryChip(
                          icon: Icons.school_rounded,
                          label: '学生 $studentCount',
                          color: const Color(0xFF12CE51),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: ui(12)),
          Container(height: 0.5, color: _kBorderSoft),
          SizedBox(height: ui(10)),
          Row(
            children: [
              _DetailCardLeadingIcon(
                asset: muted
                    ? AppAssets.groupChatMessageMuted
                    : AppAssets.groupChatMessage,
              ),
              SizedBox(width: ui(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '消息免打扰',
                      style: TextStyle(
                        fontSize: ui(13),
                        color: _kTextDark,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w500,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: ui(2)),
                    Text(
                      muted ? '该群消息不再提醒' : '开启后，新消息将静默接收',
                      style: TextStyle(
                        fontSize: ui(11),
                        color: _kTextHint,
                        fontFamily: 'PingFang SC',
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              _MuteSwitch(value: muted, onTap: onToggleMute),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(3)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ui(10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: ui(11), color: color),
          SizedBox(width: ui(3)),
          Text(
            label,
            style: TextStyle(
              fontSize: ui(11),
              color: color,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MuteSwitch extends StatelessWidget {
  const _MuteSwitch({required this.value, required this.onTap});

  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: ui(40),
        height: ui(22),
        padding: EdgeInsets.all(ui(2)),
        decoration: BoxDecoration(
          color: value ? _kPurple : const Color(0xFFCECED1),
          borderRadius: BorderRadius.circular(ui(11)),
        ),
        child: Align(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: ui(18),
            height: ui(18),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 班级详情抽屉内行首图标（与群公告卡喇叭 icon 同尺寸）。
class _DetailCardLeadingIcon extends StatelessWidget {
  const _DetailCardLeadingIcon({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(32),
      height: ui(32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ui(8)),
        child: AppAssetGraphic(
          asset,
          width: ui(32),
          height: ui(32),
          fit: BoxFit.fill,
        ),
      ),
    );
  }
}

/// 公告卡：浅紫底铃铛 icon + 公告内容。
class _DetailAnnouncementCard extends StatelessWidget {
  const _DetailAnnouncementCard({
    required this.text,
    this.canEdit = false,
    this.onEdit,
  });

  final String text;
  final bool canEdit;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isEmpty = text.trim().isEmpty;
    Widget card = Container(
      padding: EdgeInsets.all(ui(14)),
      decoration: BoxDecoration(
        color: _kAnnouncementBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailCardLeadingIcon(asset: AppAssets.groupChatInfo),
          SizedBox(width: ui(10)),
          // 标题 + 正文（或空状态提示）
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '群公告',
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kPurple,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: ui(6)),
                if (!isEmpty)
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: ui(13),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.6,
                    ),
                  )
                else
                  Text(
                    '暂无群公告，点击右侧按钮发布',
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextHint,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
          // 班主任专属编辑按钮
          if (canEdit) ...[
            SizedBox(width: ui(8)),
            GestureDetector(
              onTap: onEdit,
              child: AppAssetGraphic(
                AppAssets.groupChatSet,
                width: ui(14),
                height: ui(14),
                fit: BoxFit.contain,
              ),
            ),
          ],
        ],
      ),
    );

    // 整张卡片可点击触发编辑（班主任）
    if (canEdit) {
      card = GestureDetector(onTap: onEdit, child: card);
    }
    return card;
  }
}

/// 通用「分组卡」：白底圆角 + 顶部段落标题 + 子内容。
class _DetailSectionCard extends StatelessWidget {
  const _DetailSectionCard({
    required this.title,
    required this.children,
    this.count,
  });

  final String title;
  final int? count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.fromLTRB(ui(14), ui(14), ui(14), ui(14)),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: ui(13),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w600,
                  height: 1.2,
                ),
              ),
              if (count != null) ...[
                SizedBox(width: ui(6)),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ui(6),
                    vertical: ui(1),
                  ),
                  decoration: BoxDecoration(
                    color: _kBoardBg,
                    borderRadius: BorderRadius.circular(ui(8)),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: ui(11),
                      color: _kTextSecondary,
                      fontFamily: 'Manrope',
                      fontWeight: AppFont.w500,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: ui(12)),
          ...children,
        ],
      ),
    );
  }
}

/// 5 列头像网格，每格：圆形头像 + 姓名（最多 4 字截断）。
class _MemberGrid extends StatelessWidget {
  const _MemberGrid({required this.members});

  final List<_MemberInfo> members;

  static const int _cols = 5;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final rowCount = (members.length / _cols).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var row = 0; row < rowCount; row++) ...[
          if (row > 0) SizedBox(height: ui(16)),
          Row(
            children: [
              for (var col = 0; col < _cols; col++) ...[
                if (col > 0) SizedBox(width: ui(8)),
                Expanded(
                  child: () {
                    final idx = row * _cols + col;
                    if (idx >= members.length) return const SizedBox();
                    final m = members[idx];
                    final headUrl = m.headUrl ?? '';
                    final resolvedUrl = _resolveMediaUrl(headUrl);
                    final hasAvatar = resolvedUrl.isNotEmpty;
                    final initial = m.displayName.isNotEmpty
                        ? m.displayName.substring(0, 1)
                        : '?';
                    final color = _avatarColorFor(m.id);
                    final label = m.displayName.length > 4
                        ? '${m.displayName.substring(0, 4)}…'
                        : m.displayName.isNotEmpty
                        ? m.displayName
                        : '未命名';
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(ui(22)),
                          child: hasAvatar
                              ? Image.network(
                                  resolvedUrl,
                                  width: ui(44),
                                  height: ui(44),
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, st) =>
                                      _InitialAvatar(
                                        initial: initial,
                                        color: color,
                                        size: ui(44),
                                      ),
                                )
                              : _InitialAvatar(
                                  initial: initial,
                                  color: color,
                                  size: ui(44),
                                ),
                        ),
                        SizedBox(height: ui(4)),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: ui(11),
                            color: _kTextDark,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w400,
                            height: 1.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    );
                  }(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, this.badge});

  final _MemberInfo member;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final headUrl = member.headUrl ?? '';
    final resolvedUrl = _resolveMediaUrl(headUrl);
    final avatarColor = _avatarColorFor(member.id);
    final initials = member.displayName.isNotEmpty
        ? member.displayName.substring(0, 1)
        : '?';
    final hasAvatar = resolvedUrl.isNotEmpty;
    final hasNick =
        member.nickname.trim().isNotEmpty &&
        member.nickname.trim() != member.displayName;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(ui(20)),
          child: hasAvatar
              ? Image.network(
                  resolvedUrl,
                  width: ui(40),
                  height: ui(40),
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, st) => _InitialAvatar(
                    initial: initials,
                    color: avatarColor,
                    size: ui(40),
                  ),
                )
              : _InitialAvatar(
                  initial: initials,
                  color: avatarColor,
                  size: ui(40),
                ),
        ),
        SizedBox(width: ui(10)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      member.displayName.isNotEmpty
                          ? member.displayName
                          : '未命名',
                      style: TextStyle(
                        fontSize: ui(13),
                        color: _kTextDark,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w500,
                        height: 1.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasNick) ...[
                    SizedBox(width: ui(4)),
                    Flexible(
                      child: Text(
                        '（${member.nickname}）',
                        style: TextStyle(
                          fontSize: ui(11),
                          color: _kTextHint,
                          fontFamily: 'PingFang SC',
                          height: 1.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  if (badge != null) ...[
                    SizedBox(width: ui(6)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ui(5),
                        vertical: ui(1),
                      ),
                      decoration: BoxDecoration(
                        color: _kPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(ui(4)),
                      ),
                      child: Text(
                        badge!,
                        style: TextStyle(
                          fontSize: ui(10),
                          color: _kPurple,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w500,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (member.mobile != null && member.mobile!.isNotEmpty) ...[
                SizedBox(height: ui(2)),
                Text(
                  member.mobile!,
                  style: TextStyle(
                    fontSize: ui(11),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({
    required this.initial,
    required this.color,
    required this.size,
  });

  final String initial;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: color,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.44,
          color: Colors.white,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w600,
        ),
      ),
    );
  }
}

// =============================================================================
// 左 280：会话列表
// =============================================================================

class _GroupChatBackButton extends StatelessWidget {
  const _GroupChatBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: ui(32),
        height: ui(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderSoft),
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: ui(16),
          color: const Color(0xFF1C274C),
        ),
      ),
    );
  }
}

class _ConversationListPane extends StatefulWidget {
  const _ConversationListPane({
    required this.conversations,
    required this.selectedConvId,
    required this.onSelect,
    required this.onBack,
    this.dismissTapEnabled = false,
    this.onDismissTap,
  });

  final List<_Conversation> conversations;
  final String selectedConvId;
  final ValueChanged<String> onSelect;
  final VoidCallback onBack;
  final bool dismissTapEnabled;
  final VoidCallback? onDismissTap;

  @override
  State<_ConversationListPane> createState() => _ConversationListPaneState();
}

class _ConversationListPaneState extends State<_ConversationListPane> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_Conversation> get _filteredConversations {
    final keyword = _searchCtrl.text.trim();
    if (keyword.isEmpty) return widget.conversations;
    return widget.conversations.where((c) => c.name.contains(keyword)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final filtered = _filteredConversations;
    return _wrapGroupChatDismissTap(
      enabled: widget.dismissTapEnabled,
      onDismiss: widget.onDismissTap ?? () {},
      child: Container(
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(ui(16)),
            bottomLeft: Radius.circular(ui(16)),
          ),
          border: Border(right: BorderSide(color: _kBorderSoft)),
        ),
        padding: EdgeInsets.fromLTRB(ui(8), 0, ui(8), ui(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: ui(68),
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(ui(4), ui(12), 0, 0),
                  child: _GroupChatBackButton(onTap: widget.onBack),
                ),
              ),
            ),
            _ConvSearchField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: ui(12)),
            Expanded(
              child: widget.conversations.isEmpty
                  ? const _EmptyConversationsHint()
                  : filtered.isEmpty
                  ? const _ConversationSearchEmptyHint()
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) {
                        final selectedIndex = filtered.indexWhere(
                          (c) => c.id == widget.selectedConvId,
                        );
                        final hideDivider =
                            selectedIndex != -1 &&
                            (index == selectedIndex - 1 ||
                                index == selectedIndex);
                        return Divider(
                          height: 1,
                          thickness: 0.5,
                          color: hideDivider ? Colors.transparent : _kBorderSoft,
                        );
                      },
                      itemBuilder: (context, i) {
                        final c = filtered[i];
                        return _ConversationCell(
                          conv: c,
                          active: c.id == widget.selectedConvId,
                          onTap: () => widget.onSelect(c.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConvSearchField extends StatelessWidget {
  const _ConvSearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(40),
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      decoration: BoxDecoration(
        color: _kBoardBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Row(
        children: [
          AppAssetGraphic(
            AppAssets.shellV2Search,
            width: ui(16),
            height: ui(16),
            fit: BoxFit.contain,
          ),
          SizedBox(width: ui(8)),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(
                fontSize: ui(14),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.2,
              ),
              cursorColor: _kPurple,
              cursorWidth: 1.5,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '搜索群聊',
                hintStyle: TextStyle(
                  fontSize: ui(14),
                  color: const Color(0xFFD1D1D1),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.2,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              child: Icon(
                Icons.cancel_rounded,
                size: ui(16),
                color: const Color(0xFFD1D1D1),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConversationSearchEmptyHint extends StatelessWidget {
  const _ConversationSearchEmptyHint();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Text(
        '未找到相关群聊',
        style: TextStyle(
          color: _kTextSecondary,
          fontSize: ui(13),
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
        ),
      ),
    );
  }
}

class _ConversationCell extends StatelessWidget {
  const _ConversationCell({
    required this.conv,
    required this.active,
    required this.onTap,
  });

  final _Conversation conv;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(60),
        padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(8)),
        decoration: BoxDecoration(
          color: active ? _kBoardBg : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: ui(40),
              height: ui(40),
              child: _AvatarCircle(
                avatarUrl: conv.avatarUrl,
                fallback: conv.name,
                size: ui(40),
                radius: ui(8),
                color: conv.avatarColor,
              ),
            ),
            SizedBox(width: ui(10)),
            Expanded(
              child: SizedBox(
                height: ui(36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      conv.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(14),
                        color: _kTextDark,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w500,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      conv.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(11),
                        color: _kTextHint,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: ui(6)),
            SizedBox(
              height: ui(36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppAssetGraphic(
                    conv.pinned
                        ? AppAssets.groupChatPin
                        : AppAssets.groupChatPinOff,
                    width: ui(12),
                    height: ui(12),
                    fit: BoxFit.contain,
                  ),
                  Text(
                    conv.lastTime,
                    style: TextStyle(
                      fontSize: ui(11),
                      color: _kTextDivider,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 紧凑布局下的横向会话条带。
class _CompactConversationStrip extends StatelessWidget {
  const _CompactConversationStrip({
    required this.conversations,
    required this.selectedConvId,
    required this.onSelect,
    required this.onBack,
    this.dismissTapEnabled = false,
    this.onDismissTap,
  });

  final List<_Conversation> conversations;
  final String selectedConvId;
  final ValueChanged<String> onSelect;
  final VoidCallback onBack;
  final bool dismissTapEnabled;
  final VoidCallback? onDismissTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return _wrapGroupChatDismissTap(
      enabled: dismissTapEnabled,
      onDismiss: onDismissTap ?? () {},
      child: Padding(
        padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(8), 0),
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GroupChatBackButton(onTap: onBack),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: ui(8)),
              itemCount: conversations.length,
              separatorBuilder: (a, b) => SizedBox(width: ui(8)),
              itemBuilder: (context, i) {
                final c = conversations[i];
                final active = c.id == selectedConvId;
                return GestureDetector(
                  onTap: () => onSelect(c.id),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ui(8),
                      vertical: ui(6),
                    ),
                    decoration: BoxDecoration(
                      color: active ? _kBoardBg : Colors.white,
                      borderRadius: BorderRadius.circular(ui(12)),
                    ),
                    child: Row(
                      children: [
                        _AvatarCircle(
                          avatarUrl: c.avatarUrl,
                          fallback: c.name,
                          size: ui(36),
                          radius: ui(8),
                          color: c.avatarColor,
                        ),
                        SizedBox(width: ui(6)),
                        Text(
                          c.name,
                          style: TextStyle(
                            fontSize: ui(12),
                            color: _kTextDark,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w500,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }
}

// =============================================================================
// 右侧：聊天主区
// =============================================================================

class _ChatRightPane extends StatefulWidget {
  const _ChatRightPane({
    required this.conv,
    required this.hasSelection,
    required this.memberCount,
    required this.announcement,
    required this.announcementUpdatedAt,
    required this.canEditAnnouncement,
    required this.onEditAnnouncement,
    required this.onMessageLongPress,
    required this.messages,
    required this.loadingMessages,
    required this.loadingOlder,
    required this.hasMoreOlder,
    required this.messagesController,
    required this.currentUserId,
    required this.playingVoiceId,
    required this.playingFraction,
    required this.onToggleVoice,
    required this.inputController,
    required this.onSend,
    required this.muted,
    required this.pinned,
    required this.onToggleMute,
    required this.onTogglePin,
    required this.onUploadImage,
    required this.voiceMode,
    required this.recording,
    required this.willCancel,
    required this.liveWaveform,
    required this.onToggleVoiceMode,
    required this.onRecordPressStart,
    required this.onRecordPressMove,
    required this.onRecordPressEnd,
    required this.onShowDetail,
    required this.showEmoji,
    required this.onToggleShowEmoji,
    required this.onSetShowEmoji,
    this.dismissTapEnabled = false,
    this.onDismissTap,
    this.outerCornerLeft = false,
  });

  final _Conversation conv;
  final bool hasSelection;
  final int memberCount;
  final String announcement;
  final String announcementUpdatedAt;
  final bool canEditAnnouncement;
  final VoidCallback onEditAnnouncement;
  final ValueChanged<_UserChatMessage> onMessageLongPress;
  final List<_ChatMessage> messages;
  final bool loadingMessages;

  /// 顶部「加载更多旧消息」loader 是否在转圈。
  final bool loadingOlder;

  /// 是否还有更早的消息可以继续向上翻。false 时不再显示 loader。
  final bool hasMoreOlder;

  /// 消息 ListView 的滚动控制器（reverse:true）。
  final ScrollController messagesController;

  final String currentUserId;
  final String? playingVoiceId;
  final double playingFraction;
  final ValueChanged<String> onToggleVoice;
  final TextEditingController inputController;
  final VoidCallback onSend;
  final bool muted;
  final bool pinned;
  final VoidCallback onToggleMute;
  final VoidCallback onTogglePin;
  final VoidCallback onUploadImage;
  final bool outerCornerLeft;

  // —— 录音相关 ———————————————————————————————————————
  final bool voiceMode;
  final bool recording;
  final bool willCancel;
  final List<double> liveWaveform;
  final VoidCallback onToggleVoiceMode;
  final VoidCallback onRecordPressStart;
  final ValueChanged<double> onRecordPressMove;
  final VoidCallback onRecordPressEnd;
  final VoidCallback onShowDetail;
  final bool showEmoji;
  final VoidCallback onToggleShowEmoji;
  final ValueChanged<bool> onSetShowEmoji;
  final bool dismissTapEnabled;
  final VoidCallback? onDismissTap;

  @override
  State<_ChatRightPane> createState() => _ChatRightPaneState();
}

class _ChatRightPaneState extends State<_ChatRightPane> {
  /// 在输入框光标处插入 emoji；如有选中区，则替换并把光标移到 emoji 之后。
  void _insertEmoji(String emoji) {
    final controller = widget.inputController;
    final value = controller.value;
    final text = value.text;
    final sel = value.selection;
    final start = sel.isValid ? sel.start.clamp(0, text.length) : text.length;
    final end = sel.isValid ? sel.end.clamp(0, text.length) : text.length;
    final newText = text.replaceRange(start, end, emoji);
    final newOffset = start + emoji.length;
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
      composing: TextRange.empty,
    );
  }

  /// 退格：以「字符簇」为单位删除，正确处理 ZWJ / 肤色 / region 等
  /// 多 code-point 组合 emoji（例如 👨‍👩‍👧‍👦 / 👍🏽 / 🇨🇳）。
  void _backspace() {
    final controller = widget.inputController;
    controller.value = WechatEmoji.deleteBeforeCursor(controller.value);
  }

  void _onSend() {
    if (widget.showEmoji) widget.onSetShowEmoji(false);
    widget.onSend();
  }

  void _onTapMic() {
    if (widget.showEmoji) widget.onSetShowEmoji(false);
    widget.onToggleVoiceMode();
  }

  void _onInputFocus() {
    if (widget.showEmoji) widget.onSetShowEmoji(false);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final onDismiss = widget.onDismissTap ?? () {};
    final chatBody = _wrapGroupChatDismissTap(
      enabled: widget.dismissTapEnabled,
      onDismiss: onDismiss,
      child: _ChatBodyBoard(
        messages: widget.messages,
        loading: widget.loadingMessages,
        loadingOlder: widget.loadingOlder,
        hasMoreOlder: widget.hasMoreOlder,
        scrollController: widget.messagesController,
        hasSelection: widget.hasSelection,
        announcement: widget.announcement,
        announcementUpdatedAt: widget.announcementUpdatedAt,
        canEditAnnouncement: widget.canEditAnnouncement,
        onEditAnnouncement: widget.onEditAnnouncement,
        onMessageLongPress: widget.onMessageLongPress,
        currentUserId: widget.currentUserId,
        playingVoiceId: widget.playingVoiceId,
        playingFraction: widget.playingFraction,
        onToggleVoice: widget.onToggleVoice,
        groupChatClassId: widget.conv.id,
      ),
    );
    final bottomBar = widget.voiceMode
        ? _VoiceHoldBar(
            recording: widget.recording,
            willCancel: widget.willCancel,
            onToggleBackToText: widget.onToggleVoiceMode,
            onPressStart: widget.onRecordPressStart,
            onPressMove: widget.onRecordPressMove,
            onPressEnd: widget.onRecordPressEnd,
          )
        : _ChatInputBar(
            controller: widget.inputController,
            onSend: _onSend,
            onTapMic: _onTapMic,
            onUpload: widget.onUploadImage,
            emojiActive: widget.showEmoji,
            onToggleEmoji: widget.onToggleShowEmoji,
            onInputFocus: _onInputFocus,
          );
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(widget.outerCornerLeft ? ui(16) : 0),
          bottomLeft: Radius.circular(widget.outerCornerLeft ? ui(16) : 0),
          topRight: Radius.circular(ui(16)),
          bottomRight: Radius.circular(ui(16)),
        ),
      ),
      child: Column(
        children: [
          _wrapGroupChatDismissTap(
            enabled: widget.dismissTapEnabled,
            onDismiss: onDismiss,
            child: _ChatHeaderBar(
              title: widget.conv.name,
              memberCount: widget.memberCount,
              muted: widget.muted,
              pinned: widget.pinned,
              onToggleMute: widget.onToggleMute,
              onTogglePin: widget.onTogglePin,
              onShowDetail: widget.onShowDetail,
            ),
          ),
          Expanded(
            // 用 Stack 让录音浮窗 / 表情面板悬浮在消息区底部，不挤压消息布局。
            child: Stack(
              children: [
                Positioned.fill(child: chatBody),
                if (widget.recording)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: ui(8),
                    child: Center(
                      child: _RecordingHintCard(
                        waveform: widget.liveWaveform,
                        willCancel: widget.willCancel,
                      ),
                    ),
                  ),
                if (widget.showEmoji)
                  Positioned(
                    left: ui(16),
                    right: ui(16),
                    bottom: ui(8),
                    child: WechatEmojiPanel(
                      onPick: _insertEmoji,
                      onBackspace: _backspace,
                    ),
                  ),
              ],
            ),
          ),
          bottomBar,
        ],
      ),
    );
  }
}

// =============================================================================
// 顶部 header bar（68 高，课表页同款 bgtop 背景）
// =============================================================================

class _ChatHeaderBar extends StatelessWidget {
  const _ChatHeaderBar({
    required this.title,
    required this.memberCount,
    required this.muted,
    required this.pinned,
    required this.onToggleMute,
    required this.onTogglePin,
    required this.onShowDetail,
  });

  final String title;
  final int memberCount;
  final bool muted;
  final bool pinned;
  final VoidCallback onToggleMute;
  final VoidCallback onTogglePin;
  final VoidCallback onShowDetail;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: ui(68),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(ui(16)),
                topRight: Radius.circular(ui(16)),
              ),
              child: Image.asset(
                AppAssets.authBgTop,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.fill,
                alignment: Alignment.centerRight,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(height: 0.5, color: _kBorderSoft),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(ui(20), 0, ui(16), 0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: ui(15),
                              color: _kTextDark,
                              fontFamily: 'PingFang SC',
                              fontWeight: AppFont.w600,
                              height: 1.1,
                            ),
                          ),
                          SizedBox(width: ui(8)),
                          InkWell(
                            onTap: onShowDetail,
                            borderRadius: BorderRadius.circular(ui(4)),
                            child: AppAssetGraphic(
                              AppAssets.groupChatSet,
                              width: ui(13),
                              height: ui(13),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: ui(4)),
                      Text(
                        '$memberCount人',
                        style: TextStyle(
                          fontSize: ui(11),
                          color: _kTextDivider,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w400,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _HeaderIconButton(
                    asset: pinned
                        ? AppAssets.groupChatPinActionOn
                        : AppAssets.groupChatPinAction,
                    onTap: onTogglePin,
                  ),
                  SizedBox(width: ui(8)),
                  _HeaderIconButton(
                    asset: muted
                        ? AppAssets.groupChatMessageMuted
                        : AppAssets.groupChatMessage,
                    onTap: onToggleMute,
                  ),
                  SizedBox(width: ui(8)),
                  _HeaderIconButton(
                    icon: Icons.menu_rounded,
                    onTap: onShowDetail,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    this.asset,
    this.icon,
    required this.onTap,
  });

  final String? asset;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (asset != null) {
      return _GroupChatFullAssetButton(
        asset: asset!,
        onTap: onTap,
        size: 32,
        borderRadius: 8,
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        width: ui(32),
        height: ui(32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Icon(icon, size: ui(18), color: const Color(0xFF1C274C)),
      ),
    );
  }
}

/// 设计稿图标自带背景色，需铺满整个按钮区域，不再叠加额外底色。
class _GroupChatFullAssetButton extends StatelessWidget {
  const _GroupChatFullAssetButton({
    required this.asset,
    required this.onTap,
    this.size = 36,
    this.borderRadius = 8,
  });

  final String asset;
  final VoidCallback onTap;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final radius = ui(borderRadius);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: AppAssetGraphic(
          asset,
          width: ui(size),
          height: ui(size),
          fit: BoxFit.fill,
        ),
      ),
    );
  }
}

// =============================================================================
// 中间消息板（灰底圆角）
// =============================================================================

class _ChatBodyBoard extends StatelessWidget {
  const _ChatBodyBoard({
    required this.messages,
    required this.loading,
    required this.loadingOlder,
    required this.hasMoreOlder,
    required this.scrollController,
    required this.hasSelection,
    required this.announcement,
    required this.announcementUpdatedAt,
    required this.canEditAnnouncement,
    required this.onEditAnnouncement,
    required this.onMessageLongPress,
    required this.currentUserId,
    required this.playingVoiceId,
    required this.playingFraction,
    required this.onToggleVoice,
    required this.groupChatClassId,
  });

  final List<_ChatMessage> messages;
  final bool loading;

  /// 是否正在拉「更早一页」消息：顶端 loader 显示转圈状态。
  final bool loadingOlder;

  /// 是否还有更早消息：决定顶端 loader 是否渲染。
  final bool hasMoreOlder;

  /// 列表 ScrollController（reverse:true，offset 0 = 最新消息位置）。
  final ScrollController scrollController;

  final bool hasSelection;
  final String announcement;
  final String announcementUpdatedAt;
  final bool canEditAnnouncement;
  final VoidCallback onEditAnnouncement;
  final ValueChanged<_UserChatMessage> onMessageLongPress;
  final String currentUserId;
  final String? playingVoiceId;
  final double playingFraction;
  final ValueChanged<String> onToggleVoice;
  final String groupChatClassId;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hasAnnouncement = announcement.trim().isNotEmpty;
    final showAnnouncement =
        hasSelection && (hasAnnouncement || canEditAnnouncement);
    // 无更早历史的新群：消息从上往下排；有历史则 reverse 锚底并支持上滑加载。
    final anchorToBottom = hasMoreOlder;
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(16), ui(8), ui(16), ui(8)),
      child: Container(
        decoration: BoxDecoration(
          color: _kBoardBg,
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        padding: EdgeInsets.all(ui(16)),
        child: Column(
          children: [
            if (showAnnouncement) ...[
              _AnnouncementBar(
                text: hasAnnouncement
                    ? (announcement.startsWith('[群公告]')
                          ? announcement
                          : '[群公告] $announcement')
                    : '暂未发布群公告',
                updatedAt: announcementUpdatedAt.isNotEmpty
                    ? announcementUpdatedAt
                    : '',
                editable: canEditAnnouncement,
                onEdit: onEditAnnouncement,
              ),
              SizedBox(height: ui(12)),
            ],
            Expanded(
              child: !hasSelection
                  ? const _NoSelectionHint()
                  : loading && messages.isEmpty
                  ? const SizedBox.shrink()
                  : messages.isEmpty
                  ? Center(
                      child: Text(
                        '暂无消息，发送一条吧～',
                        style: TextStyle(
                          color: _kTextSecondary,
                          fontSize: 13,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w400,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      reverse: anchorToBottom,
                      padding: EdgeInsets.zero,
                      itemCount: messages.length + (hasMoreOlder ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (anchorToBottom && i == messages.length) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: ui(8)),
                            child: Center(
                              child: loadingOlder
                                  ? const AppLoadingIndicator()
                                  : Text(
                                      '上滑加载更多',
                                      style: TextStyle(
                                        fontSize: ui(11),
                                        color: _kTextHint,
                                        fontFamily: 'PingFang SC',
                                        fontWeight: AppFont.w400,
                                      ),
                                    ),
                            ),
                          );
                        }
                        final realIdx = anchorToBottom
                            ? messages.length - 1 - i
                            : i;
                        final m = messages[realIdx];
                        final showDate = _shouldShowDateBar(messages, realIdx);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showDate)
                              _DateDivider(label: _formatDateDivider(m.sentAt)),
                            _MessageRowDispatcher(
                              message: m,
                              isMine:
                                  m is _UserChatMessage &&
                                  m.fromUserId == currentUserId,
                              playingVoiceId: playingVoiceId,
                              playingFraction: playingFraction,
                              onToggleVoice: onToggleVoice,
                              onMessageLongPress: onMessageLongPress,
                              groupChatClassId: groupChatClassId,
                            ),
                            SizedBox(height: ui(28)),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _shouldShowDateBar(List<_ChatMessage> list, int i) {
    if (i == 0) return true;
    final prev = list[i - 1].sentAt;
    final cur = list[i].sentAt;
    return prev.year != cur.year ||
        prev.month != cur.month ||
        prev.day != cur.day;
  }

  static String _formatDateDivider(DateTime t) {
    final today = DateTime.now();
    if (t.year == today.year && t.month == today.month && t.day == today.day) {
      return '今天';
    }
    final yesterday = today.subtract(const Duration(days: 1));
    if (t.year == yesterday.year &&
        t.month == yesterday.month &&
        t.day == yesterday.day) {
      return '昨天';
    }
    if (t.year == today.year) {
      return '${t.month}月${t.day}日';
    }
    return '${t.year}年${t.month}月${t.day}日';
  }
}

class _AnnouncementBar extends StatelessWidget {
  const _AnnouncementBar({
    required this.text,
    required this.updatedAt,
    required this.editable,
    this.onEdit,
  });

  final String text;
  final String updatedAt;
  final bool editable;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(10)),
      decoration: BoxDecoration(
        color: _kAnnouncementBg,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: ui(20),
                height: ui(20),
                child: AppAssetGraphic(
                  AppAssets.groupChatInfo,
                  width: ui(20),
                  height: ui(20),
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(width: ui(12)),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 20 / 13,
                  ),
                ),
              ),
              if (editable)
                Padding(
                  padding: EdgeInsets.only(left: ui(8), top: ui(1)),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onEdit,
                    child: Text(
                      '编辑公告',
                      style: TextStyle(
                        fontSize: ui(13),
                        color: _kTextDark,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w500,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (updatedAt.isNotEmpty) ...[
            SizedBox(height: ui(4)),
            Padding(
              padding: EdgeInsets.only(left: ui(24)),
              child: Text(
                updatedAt,
                style: TextStyle(
                  fontSize: ui(11),
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: ui(8)),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 消息行（系统提示 / 普通消息）
// =============================================================================

/// 撤回消息行：居中显示 "xxx 撤回了一条消息"，与 [_DateDivider] 视觉风格一致。
class _RecallMessageRow extends StatelessWidget {
  const _RecallMessageRow({required this.message});

  final _RecallChatMessage message;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: ui(4)),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: ui(10), vertical: ui(3)),
          decoration: BoxDecoration(
            color: const Color(0x14000000),
            borderRadius: BorderRadius.circular(ui(10)),
          ),
          child: Text(
            '${message.recallerName} 撤回了一条消息',
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageRowDispatcher extends StatelessWidget {
  const _MessageRowDispatcher({
    required this.message,
    required this.isMine,
    required this.playingVoiceId,
    required this.playingFraction,
    required this.onToggleVoice,
    required this.onMessageLongPress,
    required this.groupChatClassId,
  });

  final _ChatMessage message;
  final bool isMine;
  final String? playingVoiceId;
  final double playingFraction;
  final ValueChanged<String> onToggleVoice;
  final ValueChanged<_UserChatMessage> onMessageLongPress;
  final String groupChatClassId;

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (m is _RecallChatMessage) {
      return _RecallMessageRow(message: m);
    }
    if (m is _SystemChatMessage) {
      return _SystemMessageRow(message: m);
    }
    if (m is _UserChatMessage) {
      return _UserMessageRow(
        message: m,
        isMine: isMine,
        playingVoiceId: playingVoiceId,
        playingFraction: playingFraction,
        onToggleVoice: onToggleVoice,
        onMessageLongPress: onMessageLongPress,
        groupChatClassId: groupChatClassId,
      );
    }
    return const SizedBox.shrink();
  }
}

class _SystemMessageRow extends StatelessWidget {
  const _SystemMessageRow({required this.message});

  final _SystemChatMessage message;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: ui(2)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: ui(20),
            padding: EdgeInsets.symmetric(horizontal: ui(6)),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ui(4)),
            ),
            child: Text(
              message.tagLabel,
              style: TextStyle(
                fontSize: ui(11),
                color: _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1,
              ),
            ),
          ),
          SizedBox(width: ui(12)),
          Flexible(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextSecondary,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.2,
                ),
                children: [
                  for (final seg in message.segments)
                    TextSpan(
                      text: seg.text,
                      style: TextStyle(
                        color: seg.highlight ? _kBlueLink : _kTextSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserMessageRow extends StatelessWidget {
  const _UserMessageRow({
    required this.message,
    required this.isMine,
    required this.playingVoiceId,
    required this.playingFraction,
    required this.onToggleVoice,
    required this.onMessageLongPress,
    required this.groupChatClassId,
  });

  final _UserChatMessage message;
  final bool isMine;
  final String? playingVoiceId;
  final double playingFraction;
  final ValueChanged<String> onToggleVoice;
  final ValueChanged<_UserChatMessage> onMessageLongPress;
  final String groupChatClassId;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final avatar = _AvatarCircle(
      avatarUrl: message.avatarUrl,
      fallback: message.fromName,
      size: ui(36),
      radius: ui(8),
      color: message.avatarColor,
    );
    Widget bubble = _BubbleDispatcher(
      message: message,
      playingVoiceId: playingVoiceId,
      playingFraction: playingFraction,
      onToggleVoice: onToggleVoice,
      groupChatClassId: groupChatClassId,
    );
    final downloads = _downloadItemsForBubble(message.bubble);
    final canRecall =
        isMine &&
        !message.id.startsWith('local-') &&
        message.fromUserId.isNotEmpty;
    if (downloads.isNotEmpty || canRecall) {
      bubble = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () => onMessageLongPress(message),
        child: bubble,
      );
    }
    final nameMeta = Padding(
      padding: EdgeInsets.only(bottom: ui(4)),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          message.fromName,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
      ),
    );
    final timeLabel = Text(
      _formatTime(message.sentAt),
      style: TextStyle(
        fontSize: ui(12),
        color: _kTextDivider,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w400,
        height: 1,
      ),
    );
    final bubbleWithTime = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: isMine
          ? [
              timeLabel,
              SizedBox(width: ui(6)),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: ui(420)),
                child: bubble,
              ),
            ]
          : [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: ui(420)),
                child: bubble,
              ),
              SizedBox(width: ui(6)),
              timeLabel,
            ],
    );

    final textColumn = Column(
      crossAxisAlignment: isMine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [nameMeta, bubbleWithTime],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: isMine
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: isMine
          ? [Flexible(child: textColumn), SizedBox(width: ui(10)), avatar]
          : [avatar, SizedBox(width: ui(10)), Flexible(child: textColumn)],
    );
  }

  static String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// =============================================================================
// 消息气泡分发
// =============================================================================

class _BubbleDispatcher extends StatelessWidget {
  const _BubbleDispatcher({
    required this.message,
    required this.playingVoiceId,
    required this.playingFraction,
    required this.onToggleVoice,
    required this.groupChatClassId,
  });

  final _UserChatMessage message;
  final String? playingVoiceId;
  final double playingFraction;
  final ValueChanged<String> onToggleVoice;
  final String groupChatClassId;

  @override
  Widget build(BuildContext context) {
    final b = message.bubble;
    if (b is _TextBubble) {
      return _TextBubbleView(text: b.text);
    }
    if (b is _FileBubble) {
      return _FileBubbleView(bubble: b);
    }
    if (b is _VoiceBubble) {
      final isPlaying = playingVoiceId == message.id;
      return _VoiceBubbleView(
        bubble: b,
        isPlaying: isPlaying,
        playedFraction: isPlaying ? playingFraction : 0,
        onTap: () => onToggleVoice(message.id),
      );
    }
    if (b is _ImageBubble) {
      return _ImageBubbleView(bubble: b);
    }
    if (b is _SharedCardBubble) {
      return GestureDetector(
        onTap: () => _navigateSharedContent(
          context,
          b,
          groupChatClassId: groupChatClassId,
        ),
        child: _SharedCardBubbleView(bubble: b),
      );
    }
    return const SizedBox.shrink();
  }
}

// 文本气泡
List<InlineSpan> _chatTextSpans(
  String text,
  TextStyle baseStyle,
  double Function(double) ui,
) {
  return buildWechatEmojiTextSpans(
    text: text,
    baseStyle: baseStyle,
    emojiSize: ui(20),
  );
}

class _TextBubbleView extends StatelessWidget {
  const _TextBubbleView({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final baseStyle = TextStyle(
      fontSize: ui(14),
      color: _kTextDark,
      fontFamily: 'PingFang SC',
      fontWeight: AppFont.w400,
      height: 1.7,
    );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Text.rich(
        TextSpan(
          children: _chatTextSpans(text, baseStyle, ui),
        ),
        style: baseStyle,
      ),
    );
  }
}

// 文件气泡（PDF 等）
class _FileBubbleView extends StatelessWidget {
  const _FileBubbleView({required this.bubble});

  final _FileBubble bubble;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FileIconBlock(extension: bubble.fileType),
          SizedBox(width: ui(10)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bubble.fileName,
                style: TextStyle(
                  fontSize: ui(13),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1.6,
                ),
              ),
              SizedBox(height: ui(2)),
              Text(
                bubble.fileSize,
                style: TextStyle(
                  fontSize: ui(11),
                  color: _kTextSecondary,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FileIconBlock extends StatelessWidget {
  const _FileIconBlock({required this.extension});

  final String extension;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      width: ui(34),
      height: ui(40),
      child: Stack(
        children: [
          // 蓝渐变页面
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_kPdfBlueGradStart, _kPdfBlueGradEnd],
                ),
                borderRadius: BorderRadius.circular(ui(6)),
                border: Border.all(color: _kPdfBorder, width: 0.5),
              ),
            ),
          ),
          // 内部条状装饰
          Positioned(
            left: ui(4),
            top: ui(8),
            right: ui(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: ui(8),
                  height: 2,
                  color: const Color(0xFFDAE4FF),
                ),
                SizedBox(height: ui(3)),
                Container(
                  width: ui(13),
                  height: 2,
                  color: const Color(0xFFDAE4FF),
                ),
                SizedBox(height: ui(3)),
                Container(
                  width: ui(17),
                  height: 2,
                  color: const Color(0xFFDAE4FF),
                ),
              ],
            ),
          ),
          // 红色 PDF 角标
          Positioned(
            right: -ui(2),
            bottom: ui(4),
            child: Container(
              width: ui(28),
              height: ui(11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _kPdfRed,
                borderRadius: BorderRadius.circular(ui(2)),
              ),
              child: Text(
                extension.toUpperCase(),
                style: TextStyle(
                  fontSize: ui(8),
                  color: Colors.white,
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 语音气泡
class _VoiceBubbleView extends StatelessWidget {
  const _VoiceBubbleView({
    required this.bubble,
    required this.isPlaying,
    required this.playedFraction,
    required this.onTap,
  });

  final _VoiceBubble bubble;
  final bool isPlaying;
  final double playedFraction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 语音条按时长做线性插值：短语音接近最小宽，长语音接近最大宽。
    const minSec = 1;
    const maxSec = 60;
    const minBars = 8;
    const maxBars = 42;
    final sec = bubble.durationSec.clamp(minSec, maxSec);
    final ratio = (sec - minSec) / (maxSec - minSec);
    final barCount = (minBars + (maxBars - minBars) * ratio).round();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 播放/暂停按钮图片（24x24）
            AppAssetGraphic(
              isPlaying ? AppAssets.groupChatStop : AppAssets.groupChatPlay,
              width: ui(24),
              height: ui(24),
              fit: BoxFit.contain,
            ),
            SizedBox(width: ui(8)),
            // 语音播放进度条的容器
            Container(
              constraints: BoxConstraints(minWidth: ui(44), maxWidth: ui(192)),
              padding: EdgeInsets.symmetric(
                horizontal: ui(12),
                vertical: ui(8),
              ),
              decoration: BoxDecoration(
                color: _kBoardBg,
                borderRadius: BorderRadius.circular(ui(12)),
              ),
              child: _Waveform(
                heights: bubble.waveform,
                barCount: barCount,
                playedFraction: isPlaying ? playedFraction.clamp(0, 1) : 0,
                playedColor: _kPurple,
                idleColor: const Color(0xFFD2D5DA),
              ),
            ),
            SizedBox(width: ui(8)),
            Text(
              '${bubble.durationSec}s',
              style: TextStyle(
                fontSize: ui(13),
                color: const Color(0xFF6D6B75),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({
    required this.heights,
    this.barCount,
    required this.playedFraction,
    required this.playedColor,
    required this.idleColor,
  });

  /// 长度任意的归一化高度（0~1），UI 会按 16px 最大高映射。
  final List<double> heights;
  final int? barCount;
  final double playedFraction;
  final Color playedColor;
  final Color idleColor;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final bars = _sampleBars(heights, barCount ?? heights.length);
    final total = bars.length;
    final playedCount = (playedFraction * total).round();
    return SizedBox(
      height: ui(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++) ...[
            Container(
              width: ui(2),
              height: ui(3 + bars[i] * 13),
              decoration: BoxDecoration(
                color: i < playedCount ? playedColor : idleColor,
                borderRadius: BorderRadius.circular(ui(1)),
              ),
            ),
            if (i < total - 1) SizedBox(width: ui(2)),
          ],
        ],
      ),
    );
  }

  List<double> _sampleBars(List<double> src, int target) {
    if (target <= 0) return const <double>[];
    if (src.isEmpty) return List<double>.filled(target, 0.28);
    if (src.length == target) {
      return src.map((v) => v.clamp(0.08, 1).toDouble()).toList();
    }
    return List<double>.generate(target, (i) {
      final sourceIndex = (i * (src.length - 1) / (target - 1)).round();
      return src[sourceIndex].clamp(0.08, 1).toDouble();
    });
  }
}

// 图片气泡：单击 / 双击均打开全屏查看器（photo_view + Hero 动画）
class _ImageBubbleView extends StatelessWidget {
  const _ImageBubbleView({required this.bubble});

  final _ImageBubble bubble;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final size = ui(180);
    final url = _resolveMediaUrl(bubble.url);
    final radius = BorderRadius.circular(ui(8));

    Widget imagePlaceholder({Widget? child}) {
      return SizedBox(
        width: size,
        height: size,
        child: Container(
          decoration: BoxDecoration(color: _kBoardBg, borderRadius: radius),
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          child: child ?? const AppLoadingIndicator(),
        ),
      );
    }

    if (bubble.uploading || url.isEmpty) {
      final preview = bubble.localBytes != null
          ? Image.memory(
              bubble.localBytes!,
              width: size,
              height: size,
              fit: BoxFit.cover,
            )
          : null;
      if (preview == null) return imagePlaceholder();
      return SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              preview,
              ColoredBox(color: Colors.black.withValues(alpha: 0.18)),
              const Center(child: AppLoadingIndicator()),
            ],
          ),
        ),
      );
    }

    // hero tag 需与 showImageGallery 内部 tag 格式一致
    // showImageGallery 使用 '${heroTagPrefix}_${image}_$index'
    const prefix = 'chat_img';
    final heroTag = '${prefix}_${url}_0';
    return GestureDetector(
      onTap: () =>
          showImageGallery(context, images: [url], heroTagPrefix: prefix),
      child: Hero(
        tag: heroTag,
        child: ClipRRect(
          borderRadius: radius,
          child: Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, st) => Container(
              width: size,
              height: size,
              decoration: BoxDecoration(color: _kBoardBg, borderRadius: radius),
              child: Icon(
                Icons.broken_image_outlined,
                color: _kTextSecondary,
                size: ui(32),
              ),
            ),
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return imagePlaceholder();
            },
          ),
        ),
      ),
    );
  }
}

/// 补全相对路径媒体 URL（头像、图片、封面等）。
String _resolveMediaUrl(String? raw) {
  if (raw == null) return '';
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.startsWith('blob:')) return trimmed;
  return MediaUrl.resolve(trimmed);
}

List<GroupChatMediaDownloadItem> _downloadItemsForBubble(_ChatBubble bubble) {
  if (bubble is _ImageBubble) {
    return _downloadItemsForImageBubble(bubble);
  }
  if (bubble is _VoiceBubble) {
    return _downloadItemsForVoiceBubble(bubble);
  }
  if (bubble is _FileBubble) {
    return _downloadItemsForFileBubble(bubble);
  }
  if (bubble is _SharedCardBubble) {
    return _downloadItemsForSharedCardBubble(bubble);
  }
  return const [];
}

List<GroupChatMediaDownloadItem> _downloadItemsForImageBubble(_ImageBubble bubble) {
  if (bubble.uploading) return const [];
  if (bubble.localBytes != null) {
    return [
      GroupChatMediaDownloadItem(
        label: '保存图片',
        suggestedFileName: sanitizeChatDownloadFileName(
          fileNameFromUrl(bubble.url, fallback: 'chat_image.jpg'),
        ),
        kind: GroupChatMediaKind.image,
        bytes: bubble.localBytes,
      ),
    ];
  }
  final url = bubble.url.trim();
  if (url.isEmpty) return const [];
  return [
    GroupChatMediaDownloadItem(
      label: '保存图片',
      suggestedFileName: fileNameFromUrl(url, fallback: 'chat_image.jpg'),
      kind: GroupChatMediaKind.image,
      url: url,
    ),
  ];
}

List<GroupChatMediaDownloadItem> _downloadItemsForVoiceBubble(_VoiceBubble bubble) {
  final url = bubble.url?.trim() ?? '';
  if (url.isEmpty) return const [];
  return [
    GroupChatMediaDownloadItem(
      label: '保存语音',
      suggestedFileName: fileNameFromUrl(url, fallback: 'chat_voice.m4a'),
      kind: GroupChatMediaKind.audio,
      url: url,
    ),
  ];
}

List<GroupChatMediaDownloadItem> _downloadItemsForFileBubble(_FileBubble bubble) {
  final url = bubble.url?.trim() ?? '';
  if (url.isEmpty) return const [];
  final fallback = bubble.fileName.trim().isNotEmpty
      ? bubble.fileName.trim()
      : 'chat_file.${bubble.fileType.isNotEmpty ? bubble.fileType : 'bin'}';
  return [
    GroupChatMediaDownloadItem(
      label: '下载文件',
      suggestedFileName: sanitizeChatDownloadFileName(fallback),
      kind: GroupChatMediaKind.file,
      url: url,
    ),
  ];
}

List<GroupChatMediaDownloadItem> _downloadItemsForSharedCardBubble(
  _SharedCardBubble bubble,
) {
  final items = <GroupChatMediaDownloadItem>[];

  void addImage(String url, String label) {
    final resolved = url.trim();
    if (resolved.isEmpty) return;
    items.add(
      GroupChatMediaDownloadItem(
        label: label,
        suggestedFileName: fileNameFromUrl(resolved, fallback: 'chat_image.jpg'),
        kind: GroupChatMediaKind.image,
        url: resolved,
      ),
    );
  }

  void addVideo(String url) {
    final resolved = url.trim();
    if (resolved.isEmpty) return;
    items.add(
      GroupChatMediaDownloadItem(
        label: '保存视频',
        suggestedFileName: fileNameFromUrl(resolved, fallback: 'chat_video.mp4'),
        kind: GroupChatMediaKind.video,
        url: resolved,
      ),
    );
  }

  void addAudio(String url) {
    final resolved = url.trim();
    if (resolved.isEmpty) return;
    items.add(
      GroupChatMediaDownloadItem(
        label: '保存音频',
        suggestedFileName: fileNameFromUrl(resolved, fallback: 'chat_audio.m4a'),
        kind: GroupChatMediaKind.audio,
        url: resolved,
      ),
    );
  }

  switch (bubble.subtype) {
    case 'video':
      addVideo(bubble.mediaUrl ?? '');
      if (items.isEmpty) {
        addImage(bubble.coverUrl ?? '', '保存封面');
      }
    case 'kj':
      if (bubble.kjTypeValue == '1' && bubble.kjAudioUrl != null) {
        addAudio(bubble.kjAudioUrl!);
      }
      for (final imageUrl in bubble.kjImageUrls) {
        addImage(imageUrl, '保存图片');
      }
      if (items.isEmpty) {
        addImage(bubble.coverUrl ?? '', '保存图片');
      }
    default:
      addImage(bubble.coverUrl ?? '', '保存图片');
  }

  return items;
}

/// 根据分享内容的子类型跳转到对应详情页。
void _navigateSharedContent(
  BuildContext context,
  _SharedCardBubble b, {
  required String groupChatClassId,
}) {
  final id = b.contentId;
  switch (b.subtype) {
    case 'news':
      Navigator.pushNamed(
        context,
        RoutePaths.consultationDetail,
        arguments: GroupChatReturnNavigator.wrapMap(
          <String, dynamic>{'id': id == null ? 0 : (int.tryParse(id) ?? 0)},
          classId: groupChatClassId,
        ),
      );
    case 'video':
      if (b.schoolMode) {
        final routeArgs = <String, dynamic>{};
        if (id != null && id.isNotEmpty) {
          routeArgs['openVideoId'] = id;
        }
        final schoolId = b.schoolId;
        if (schoolId != null && schoolId > 0) {
          routeArgs['school'] = schoolId;
        }
        Navigator.pushNamed(
          context,
          RoutePaths.schoolVideo,
          arguments: GroupChatReturnNavigator.wrapMap(
            routeArgs,
            classId: groupChatClassId,
          ),
        );
      } else {
        final routeArgs = (id != null && id.isNotEmpty)
            ? <String, dynamic>{'openVideoId': id}
            : <String, dynamic>{};
        Navigator.pushNamed(
          context,
          RoutePaths.videoTutorial,
          arguments: GroupChatReturnNavigator.wrapMap(
            routeArgs,
            classId: groupChatClassId,
          ),
        );
      }
    case 'kj':
      // 直接打开云盘课件预览页，并通过 route arguments 传入 previewItem
      // MyCloudDrivePage.didChangeDependencies 会读取并调用 openPreview(item)
      Navigator.pushNamed(
        context,
        RoutePaths.courseware,
        arguments: GroupChatReturnNavigator.wrapMap(
          <String, dynamic>{
            'previewItem': <String, dynamic>{
              'id': int.tryParse(id ?? '') ?? 0,
              'title': b.title,
              'typeValue': b.kjTypeValue ?? '3',
              'audioUrl': b.kjAudioUrl ?? '',
              'imageUrls': b.kjImageUrls,
            },
          },
          classId: groupChatClassId,
        ),
      );
    case 'book':
      if (id == null || id.isEmpty) return;
      final bookType = b.bookType;
      if (bookType == 2) {
        Navigator.pushNamed(
          context,
          RoutePaths.theory,
          arguments: GroupChatReturnNavigator.wrapMap(
            <String, dynamic>{'id': id},
            classId: groupChatClassId,
          ),
        );
      } else if (bookType == 1) {
        Navigator.pushNamed(
          context,
          RoutePaths.musicPlay,
          arguments: GroupChatReturnNavigator.wrapMap(
            <String, dynamic>{'id': id, 'type': 3},
            classId: groupChatClassId,
          ),
        );
      } else if (bookType == 4 || bookType == 5) {
        Navigator.pushNamed(
          context,
          RoutePaths.musicPlay,
          arguments: GroupChatReturnNavigator.wrapMap(
            <String, dynamic>{'id': id, 'type': 2},
            classId: groupChatClassId,
          ),
        );
      } else if (bookType == 10) {
        Navigator.pushNamed(
          context,
          RoutePaths.answerEnd2,
          arguments: GroupChatReturnNavigator.wrapMap(
            <String, dynamic>{'id': id, 'closedByDefault': true},
            classId: groupChatClassId,
          ),
        );
      } else {
        Navigator.pushNamed(
          context,
          RoutePaths.musicPlay,
          arguments: GroupChatReturnNavigator.wrapMap(
            <String, dynamic>{'id': id},
            classId: groupChatClassId,
          ),
        );
      }
    default:
      break;
  }
}

// 富内容分享气泡（课件 / 视频 / 资讯 / 课程）
class _SharedCardBubbleView extends StatelessWidget {
  const _SharedCardBubbleView({required this.bubble});

  final _SharedCardBubble bubble;

  bool get _usesKjIcon => bubble.subtype == 'kj' || bubble.subtype == 'book';

  Widget _kjIcon(double Function(double) ui, {required double size}) {
    return Image.asset(
      AppAssets.groupChatKj,
      width: ui(size),
      height: ui(size),
      fit: BoxFit.contain,
    );
  }

  Widget _defaultIcon(double Function(double) ui, {required double size}) {
    return Container(
      width: ui(size),
      height: ui(size),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bubble.iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ui(6)),
      ),
      child: Icon(bubble.icon, color: bubble.iconColor, size: ui(size * 0.5)),
    );
  }

  Widget _leadingIcon(double Function(double) ui) {
    if (_usesKjIcon) {
      return _kjIcon(ui, size: 36);
    }
    return _defaultIcon(ui, size: 36);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(220),
      padding: EdgeInsets.all(ui(10)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (bubble.coverUrl != null && bubble.coverUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(ui(4)),
              child: Image.network(
                _resolveMediaUrl(bubble.coverUrl),
                width: ui(44),
                height: ui(44),
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, st) {
                  if (_usesKjIcon) {
                    return _kjIcon(ui, size: 44);
                  }
                  return Container(
                    width: ui(44),
                    height: ui(44),
                    color: const Color(0xFFF3F2F3),
                    alignment: Alignment.center,
                    child: Icon(
                      bubble.icon,
                      color: bubble.iconColor,
                      size: ui(20),
                    ),
                  );
                },
              ),
            ),
            SizedBox(width: ui(8)),
          ] else ...[
            _leadingIcon(ui),
            SizedBox(width: ui(8)),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bubble.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: ui(2)),
                Text(
                  bubble.subtitle,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 输入栏
// =============================================================================

class _ChatInputBar extends StatefulWidget {
  const _ChatInputBar({
    required this.controller,
    required this.onSend,
    required this.onTapMic,
    required this.onUpload,
    required this.emojiActive,
    required this.onToggleEmoji,
    required this.onInputFocus,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onTapMic;
  final VoidCallback onUpload;
  final bool emojiActive;
  final VoidCallback onToggleEmoji;
  final VoidCallback onInputFocus;

  @override
  State<_ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<_ChatInputBar> {
  bool _hasText = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    _hasText = widget.controller.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) {
      setState(() => _hasText = has);
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) widget.onInputFocus();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(16), 0, ui(16), ui(12)),
      child: Container(
        height: ui(52),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: _kBorderSoft),
        ),
        padding: EdgeInsets.symmetric(horizontal: ui(8)),
        child: Row(
          children: [
            _GroupChatBarIconButton(
              asset: AppAssets.groupChatVoice,
              onTap: widget.onTapMic,
            ),
            SizedBox(width: ui(12)),
            Expanded(
              child: _ChatComposerField(
                controller: widget.controller,
                focusNode: _focusNode,
                onSubmitted: widget.onSend,
              ),
            ),
            SizedBox(width: ui(8)),
            _GroupChatBarIconButton(
              asset: AppAssets.groupChatMsg,
              onTap: widget.onToggleEmoji,
            ),
            SizedBox(width: ui(8)),
            _GroupChatBarIconButton(
              asset: AppAssets.groupChatUpload,
              onTap: widget.onUpload,
            ),
            SizedBox(width: ui(8)),
            _SendButton(enabled: _hasText, onTap: widget.onSend),
          ],
        ),
      ),
    );
  }
}

/// 输入框：文字 14px，emoji 20px —— 与 [_TextBubbleView] 保持一致。
class _ChatComposerField extends StatelessWidget {
  const _ChatComposerField({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final baseStyle = TextStyle(
      fontSize: ui(14),
      color: _kTextDark,
      fontFamily: 'PingFang SC',
      fontWeight: AppFont.w400,
      height: 1.7,
    );
    final strutStyle = StrutStyle(
      fontSize: ui(14),
      height: 1.7,
      forceStrutHeight: true,
    );
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.isNotEmpty;
        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            if (hasText)
              IgnorePointer(
                child: Text.rich(
                  TextSpan(
                    children: _chatTextSpans(value.text, baseStyle, ui),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  strutStyle: strutStyle,
                ),
              ),
            AppTextField(
              controller: controller,
              focusNode: focusNode,
              maxLines: 1,
              cursorColor: const Color(0xFF8741FF),
              cursorWidth: 1.5,
              cursorHeight: ui(14 * 1.7),
              style: baseStyle.copyWith(
                color: hasText ? Colors.transparent : _kTextDark,
              ),
              strutStyle: strutStyle,
              decoration: InputDecoration(
                hintText: '请输入文字',
                hintStyle: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDivider,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.7,
                ),
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(vertical: ui(8)),
              ),
              onSubmitted: (_) => onSubmitted(),
            ),
          ],
        );
      },
    );
  }
}

class _GroupChatBarIconButton extends StatelessWidget {
  const _GroupChatBarIconButton({required this.asset, required this.onTap});

  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _GroupChatFullAssetButton(asset: asset, onTap: onTap);
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          width: ui(74),
          height: ui(36),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? _kPurple : null,
            gradient: enabled
                ? null
                : const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xFFE8DEFF), Color(0xFFD4C2FF)],
                  ),
            borderRadius: BorderRadius.circular(ui(8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '发送',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: ui(13),
                  color: Colors.white,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 24 / 13,
                ),
              ),
              SizedBox(width: ui(4)),
              AppAssetGraphic(
                AppAssets.groupChatSend,
                width: ui(12),
                height: ui(12),
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 语音输入栏（按住说话）
// =============================================================================

class _VoiceHoldBar extends StatelessWidget {
  const _VoiceHoldBar({
    required this.recording,
    required this.willCancel,
    required this.onToggleBackToText,
    required this.onPressStart,
    required this.onPressMove,
    required this.onPressEnd,
  });

  final bool recording;
  final bool willCancel;
  final VoidCallback onToggleBackToText;
  final VoidCallback onPressStart;
  final ValueChanged<double> onPressMove;
  final VoidCallback onPressEnd;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final useRed = recording && willCancel;
    final gradColors = useRed
        ? const [_kRecordRed, _kRecordRedLight]
        : const [_kPurple, _kPurpleLight];
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(16), 0, ui(16), ui(12)),
      child: Container(
        height: ui(52),
        padding: EdgeInsets.symmetric(horizontal: ui(8)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: _kBorderSoft),
        ),
        child: Row(
          children: [
            _GroupChatBarIconButton(
              asset: AppAssets.groupChatVoiceMode,
              onTap: onToggleBackToText,
            ),
            SizedBox(width: ui(8)),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPressStart: (_) => onPressStart(),
                onLongPressMoveUpdate: (d) =>
                    onPressMove(d.localOffsetFromOrigin.dy),
                onLongPressEnd: (_) => onPressEnd(),
                onLongPressCancel: onPressEnd,
                child: Container(
                  height: ui(36),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: gradColors,
                    ),
                    borderRadius: BorderRadius.circular(ui(8)),
                    boxShadow: [
                      BoxShadow(
                        color: (useRed ? _kRecordRed : _kPurple).withValues(
                          alpha: 0.18,
                        ),
                        blurRadius: ui(8),
                        offset: Offset(0, ui(2)),
                      ),
                    ],
                  ),
                  child: Text(
                    '按住说话',
                    style: TextStyle(
                      fontSize: ui(14),
                      color: Colors.white,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                      height: 1,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 录音浮窗：实时波形 + 提示文案（"松开发送 上滑取消" / "松开取消"）
// =============================================================================

class _RecordingHintCard extends StatelessWidget {
  const _RecordingHintCard({required this.waveform, required this.willCancel});

  final List<double> waveform;
  final bool willCancel;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final color = willCancel ? _kRecordRed : _kPurple;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: ui(334),
          height: ui(74),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(12)),
          ),
          child: _LiveBigWaveform(heights: waveform, color: color),
        ),
        SizedBox(height: ui(18)),
        Text(
          willCancel ? '松开取消' : '松开发送 上滑取消',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: ui(13),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 24 / 13,
          ),
        ),
      ],
    );
  }
}

/// 录音浮窗专用波形：固定采样到稳定宽度，保持截图中的居中捕捉区域。
class _LiveBigWaveform extends StatelessWidget {
  const _LiveBigWaveform({required this.heights, required this.color});

  final List<double> heights;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final bars = _sampleBars(heights, 34);
    final maxHeight = ui(36);
    final base = ui(3);
    final barW = ui(2);
    final gap = ui(2);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < bars.length; i++) ...[
          Container(
            width: barW,
            height: base + bars[i] * (maxHeight - base),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(barW),
            ),
          ),
          if (i < bars.length - 1) SizedBox(width: gap),
        ],
      ],
    );
  }

  List<double> _sampleBars(List<double> source, int targetCount) {
    if (source.isEmpty) {
      return List<double>.filled(targetCount, 0.2);
    }
    if (source.length == targetCount) {
      return source.map((v) => v.clamp(0.08, 1).toDouble()).toList();
    }
    return List<double>.generate(targetCount, (i) {
      final sourceIndex = (i * (source.length - 1) / (targetCount - 1)).round();
      return source[sourceIndex].clamp(0.08, 1).toDouble();
    });
  }
}

// =============================================================================
// 通用组件
// =============================================================================

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.avatarUrl,
    required this.fallback,
    required this.size,
    required this.radius,
    required this.color,
  });

  final String? avatarUrl;
  final String fallback;
  final double size;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final hasUrl = (avatarUrl ?? '').isNotEmpty;
    final ch = fallback.isNotEmpty ? fallback.characters.first : '?';
    final initial = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        ch,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w600,
          height: 1,
        ),
      ),
    );
    if (!hasUrl) return initial;
    final resolvedUrl = _resolveMediaUrl(avatarUrl);
    if (resolvedUrl.isEmpty) return initial;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        resolvedUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, st) => initial,
      ),
    );
  }
}

// =============================================================================
// 数据模型 + Demo
// =============================================================================

class _Conversation {
  const _Conversation({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.lastTime,
    required this.unread,
    required this.muted,
    required this.pinned,
    required this.memberCount,
    this.avatarColor = const Color(0xFF8741FF),
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String lastMessage;
  final String lastTime;
  final int unread;
  final bool muted;
  final bool pinned;
  final int memberCount;
  final Color avatarColor;
  final String? avatarUrl;

  /// `syncMsg` 把离线消息回放到非激活会话时，更新摘要 + 时间 + 未读计数。
  _Conversation copyWith({
    String? name,
    String? lastMessage,
    String? lastTime,
    int? unread,
    bool? muted,
    bool? pinned,
    int? memberCount,
    String? avatarUrl,
  }) {
    return _Conversation(
      id: id,
      name: name ?? this.name,
      lastMessage: lastMessage ?? this.lastMessage,
      lastTime: lastTime ?? this.lastTime,
      unread: unread ?? this.unread,
      muted: muted ?? this.muted,
      pinned: pinned ?? this.pinned,
      memberCount: memberCount ?? this.memberCount,
      avatarColor: avatarColor,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

abstract class _ChatMessage {
  const _ChatMessage({required this.id, required this.sentAt});

  final String id;
  final DateTime sentAt;
}

/// 系统通知（对应 1.0 chat.vue 的 type === 0）
class _SystemChatMessage extends _ChatMessage {
  _SystemChatMessage({
    required super.id,
    required super.sentAt,
    required this.tagLabel,
    required this.segments,
  });

  final String tagLabel; // 入群通知 / 群公告 ...
  final List<_RichSpan> segments;
}

/// 撤回消息（type=100）：居中显示 "xxx 撤回了一条消息"
class _RecallChatMessage extends _ChatMessage {
  _RecallChatMessage({
    required super.id,
    required super.sentAt,
    required this.recallerName,
  });

  final String recallerName;
}

class _RichSpan {
  // ignore: unused_element_parameter
  const _RichSpan(this.text, {this.highlight = false});

  final String text;
  final bool highlight;
}

/// 用户消息（type 1/2/3）
class _UserChatMessage extends _ChatMessage {
  _UserChatMessage({
    required super.id,
    required super.sentAt,
    required this.fromUserId,
    required this.fromName,
    required this.bubble,
    this.avatarUrl,
    this.avatarColor = const Color(0xFF8741FF),
  });

  final String fromUserId;
  final String fromName;
  final String? avatarUrl;
  final Color avatarColor;
  final _ChatBubble bubble;
}

abstract class _ChatBubble {
  const _ChatBubble();
}

class _TextBubble extends _ChatBubble {
  const _TextBubble({required this.text});

  final String text;
}

class _ImageBubble extends _ChatBubble {
  const _ImageBubble({
    required this.url,
    this.localBytes,
    this.uploading = false,
  });

  final String url;
  final Uint8List? localBytes;
  final bool uploading;
}

class _VoiceBubble extends _ChatBubble {
  const _VoiceBubble({
    required this.durationSec,
    required this.waveform,
    this.url,
  });

  final int durationSec;
  final List<double> waveform;

  /// 远端 URL 或本地文件路径（发送后填充）；null 表示尚未上传。
  final String? url;
}

class _FileBubble extends _ChatBubble {
  const _FileBubble({
    required this.fileName,
    required this.fileSize,
    required this.fileType,
    this.url,
  });

  final String fileName;
  final String fileSize;
  final String fileType;
  final String? url;
}

/// 课件 / 视频 / 资讯 / 课程等富内容分享气泡（type=3，param1=kj/video/news/book）。
class _SharedCardBubble extends _ChatBubble {
  const _SharedCardBubble({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.subtype, // 'kj' / 'video' / 'news' / 'book'
    this.coverUrl,
    this.contentId,
    this.mediaUrl,
    // 云盘课件（kj）专用预览数据
    this.kjAudioUrl,
    this.kjImageUrls = const [],
    this.kjTypeValue, // '1'=音频 '2'=谱例 '3'=课件
    this.bookType,
    this.schoolMode = false,
    this.schoolId,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String subtype;
  final String? coverUrl;
  final String? contentId;
  final String? mediaUrl;

  final String? kjAudioUrl;
  final List<String> kjImageUrls;
  final String? kjTypeValue;

  /// 课程教材 type（1 视唱 / 2 乐理 / 3 听写 / 4 声乐 / 5 器乐）。
  final int? bookType;

  /// 校园课件视频（走 schoolVideoTutorialDetail），否则为公开视频中心。
  final bool schoolMode;
  final int? schoolId;
}

// =============================================================================
// 解析 1.0 后端返回的原始 message JSON 为 _ChatMessage 树
// =============================================================================
//
// 1.0 chat.vue 的消息字段约定（节选 chat.vue 第 13~248 行）：
//   - id / msgId / messageId：消息唯一 id
//   - createTime / sendTime / msgTime：发送时间
//   - fromUserId、userName、userHead
//   - type==0：系统通知，content 是字符串/text
//   - type==1：text，content 字符串（可能含表情 img）
//   - type==2：image，content 是 url
//   - type==3：富内容，param1 决定 sub-kind，content 是 JSON 字符串
//
// 这里写一个 best-effort 的 parse，前端 demo 阶段其实用不到，但保留以后接
// socket / REST 时可以直接接入。这里把内部气泡树包成 dynamic 暴露，避免
// 把私有类型直接写进 public API（library_private_types_in_public_api）。
class GroupChatMessageParser {
  const GroupChatMessageParser({this.userMap = const {}});

  // ignore: library_private_types_in_public_api
  final Map<String, _MemberInfo> userMap;

  /// 返回内部 `_ChatMessage` 实例（动态类型暴露），调用方只需要把它放进
  /// `messages` 列表即可。
  dynamic parseRaw(Map<String, dynamic> raw) {
    return _parseInternal(raw);
  }

  _ChatMessage? _parseInternal(Map<String, dynamic> raw) {
    final id =
        (raw['id'] ?? raw['msgId'] ?? raw['messageId'])?.toString() ??
        DateTime.now().microsecondsSinceEpoch.toString();
    final time = _parseDate(
      raw['createTime'] ?? raw['sendTime'] ?? raw['msgTime'],
    );
    final typeRaw = raw['type'];
    final type = typeRaw is int
        ? typeRaw
        : int.tryParse(typeRaw?.toString() ?? '');

    // ── type=0 系统消息 / type=100 撤回消息 ──────────────────────
    if (type == 0) {
      final content = (raw['text'] ?? raw['content'] ?? '').toString();
      final parts = _parseSystemMessageParts(content);
      return _SystemChatMessage(
        id: id,
        sentAt: time,
        tagLabel: parts.$1,
        segments: parts.$2,
      );
    }
    if (type == 100) {
      // type=100 撤回消息：fromUserId='0'（系统），param2=执行撤回的用户 ID
      // 从 userMap 查找撤回人信息；同时兼容消息体内直接有 userName 的旧格式
      final recallerId = raw['param2']?.toString() ?? '';
      final recallerInfo = userMap[recallerId];
      final recallerName =
          recallerInfo?.displayName.trim() ??
          (raw['userName'] ?? raw['nickname'])?.toString().trim() ??
          '';
      return _RecallChatMessage(
        id: id,
        sentAt: time,
        recallerName: recallerName.isEmpty ? '对方' : recallerName,
      );
    }

    final fromId = raw['fromUserId']?.toString() ?? '';
    // 优先从 userMap 查找（API userList），不到则回退到消息内嵌字段
    final userInfo = userMap[fromId];
    final fromName = userInfo?.displayName.trim().isNotEmpty == true
        ? userInfo!.displayName.trim()
        : (raw['userName']?.toString().trim() ??
                  raw['nickname']?.toString().trim() ??
                  raw['realname']?.toString().trim() ??
                  (fromId.isNotEmpty ? '用户$fromId' : ''))
              .trim();
    final avatar = userInfo?.headUrl?.isNotEmpty == true
        ? userInfo!.headUrl
        : _resolveMediaUrl(
            raw['userHead']?.toString() ?? raw['headUrl']?.toString(),
          );
    final color = _avatarColorFor(fromId);
    _ChatBubble? bubble;

    if (type == 1) {
      // 去除富文本 HTML 标签（如 "<div><br></div>"）
      final raw1 = raw['content']?.toString() ?? '';
      bubble = _TextBubble(text: _stripHtml(raw1));
    } else if (type == 2) {
      bubble = _ImageBubble(url: _resolveMediaUrl(raw['content']?.toString()));
    } else if (type == 3) {
      final p1 = raw['param1']?.toString() ?? '';
      // content 通常是 JSON 字符串，先尝试解析
      Map<String, dynamic>? obj;
      final contentRaw = raw['content'];
      if (contentRaw is Map<String, dynamic>) {
        obj = contentRaw;
      } else if (contentRaw is String && contentRaw.startsWith('{')) {
        try {
          final decoded = _jsonDecodeQuiet(contentRaw);
          if (decoded is Map<String, dynamic>) obj = decoded;
        } catch (_) {}
      }
      switch (p1) {
        case 'voice':
          final dur = (obj?['duration'] ?? 0).toString();
          bubble = _VoiceBubble(
            durationSec: int.tryParse(dur) ?? 0,
            waveform: _kDemoWaveformIdle,
            url: _resolveMediaUrl(obj?['url']?.toString()),
          );
          break;
        case 'file':
          bubble = _FileBubble(
            fileName: (obj?['name'] ?? '未命名文件').toString(),
            fileSize: (obj?['size'] ?? '').toString(),
            fileType: ((obj?['ext'] ?? 'pdf').toString()).toLowerCase(),
            url: _resolveMediaUrl(
              (obj?['url'] ?? obj?['path'] ?? obj?['fileUrl'])?.toString(),
            ),
          );
          break;
        case 'kj':
          // content JSON: {id, title, param1=typeValue, param2=audioUrl, param3=imageUrls(JSON)}
          final kjAudio = (obj?['param2'] ?? '').toString();
          List<String> kjImgs = const [];
          final p3raw = obj?['param3'];
          if (p3raw is String && p3raw.isNotEmpty) {
            try {
              final imgs = _jsonDecodeQuiet(p3raw);
              if (imgs is List) {
                kjImgs = imgs
                    .map((item) => _resolveMediaUrl(item?.toString()))
                    .where((url) => url.isNotEmpty)
                    .toList(growable: false);
              }
            } catch (_) {}
          }
          bubble = _SharedCardBubble(
            icon: Icons.menu_book_rounded,
            iconColor: const Color(0xFF8741FF),
            title: (obj?['title'] ?? '课件分享').toString(),
            subtitle: '云盘课件',
            subtype: 'kj',
            coverUrl: kjImgs.isNotEmpty ? kjImgs.first : null,
            contentId: obj?['id']?.toString(),
            kjAudioUrl: kjAudio.isEmpty ? null : _resolveMediaUrl(kjAudio),
            kjImageUrls: kjImgs,
            kjTypeValue: obj?['param1']?.toString(),
          );
          break;
        case 'video':
          bubble = _SharedCardBubble(
            icon: Icons.play_circle_outline_rounded,
            iconColor: const Color(0xFFF59E0B),
            title: (obj?['name'] ?? obj?['title'] ?? '视频分享').toString(),
            subtitle: '视频 · ${obj?['duration'] ?? ''}',
            subtype: 'video',
            coverUrl: _resolveMediaUrl(obj?['coverImg']?.toString()),
            contentId: obj?['id']?.toString(),
            mediaUrl: _resolveMediaUrl(
              (obj?['url'] ??
                      obj?['videoUrl'] ??
                      obj?['fileUrl'] ??
                      obj?['path'])
                  ?.toString(),
            ),
            schoolMode:
                _isTruthy(obj?['schoolMode']) || _isTruthy(obj?['school']),
            schoolId: _asInt(obj?['schoolId'] ?? obj?['school']),
          );
          break;
        case 'news':
          bubble = _SharedCardBubble(
            icon: Icons.article_outlined,
            iconColor: const Color(0xFF3B6FFF),
            title: (obj?['title'] ?? '资讯').toString(),
            subtitle: '资讯',
            subtype: 'news',
            coverUrl: _resolveMediaUrl(
              obj?['coverImg']?.toString() ?? obj?['imgUrl']?.toString(),
            ),
            contentId: obj?['id']?.toString(),
          );
          break;
        case 'book':
          final subtitle = (obj?['subtitle'] ?? obj?['shortText3'] ?? '')
              .toString()
              .trim();
          bubble = _SharedCardBubble(
            icon: Icons.menu_book_rounded,
            iconColor: const Color(0xFF325BFF),
            title: (obj?['title'] ?? '课程分享').toString(),
            subtitle: subtitle.isEmpty ? '课程分享' : subtitle,
            subtype: 'book',
            coverUrl: _resolveMediaUrl(
              obj?['coverImg']?.toString() ?? obj?['imgUrl']?.toString(),
            ),
            contentId: obj?['id']?.toString(),
            bookType: _asInt(obj?['type']),
          );
          break;
        default:
          bubble = _TextBubble(
            text:
                '[${p1.isEmpty ? '消息' : p1}] ${(obj?['title'] ?? obj?['name'] ?? '').toString()}',
          );
      }
    }

    if (bubble == null) return null;
    return _UserChatMessage(
      id: id,
      sentAt: time,
      fromUserId: fromId,
      fromName: fromName,
      avatarUrl: avatar,
      avatarColor: color,
      bubble: bubble,
    );
  }

  /// 去除 HTML 标签（含 &lt; &gt; 等常见实体）。
  static String _stripHtml(String s) {
    // 替换 <br> / <div><br></div> 类换行为空格
    var out = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ');
    // 去掉所有标签
    out = out.replaceAll(RegExp(r'<[^>]*>'), '');
    // 解码常见 HTML 实体
    out = out
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"');
    return out.trim();
  }

  static Object? _jsonDecodeQuiet(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  DateTime _parseDate(Object? raw) {
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is String) {
      return DateTime.tryParse(raw) ?? DateTime.now();
    }
    return DateTime.now();
  }

  Color _avatarColorFor(String uid) {
    final palette = <Color>[
      Color(0xFF325BFF),
      Color(0xFFF97316),
      Color(0xFFB98FFF),
      Color(0xFF12CE51),
      Color(0xFF8741FF),
    ];
    if (uid.isEmpty) return palette.first;
    final h = uid.hashCode.abs();
    return palette[h % palette.length];
  }
}

// =============================================================================
// API 响应 → UI model 解析（_parseConversations / _parseMessages /
// _parseGroupDetail），以及发送消息后从响应抽 msgId 的 helper。
// =============================================================================

/// 成员（老师 / 学生）信息，用于班级详情抽屉展示。
class _MemberInfo {
  const _MemberInfo({
    required this.id,
    required this.realname,
    required this.nickname,
    required this.role,
    this.headUrl,
    this.mobile,
    this.gender,
  });

  final String id;
  final String realname;
  final String nickname;
  final String role; // 'teacher' / 'student'
  final String? headUrl;
  final String? mobile;
  final String? gender;

  String get displayName =>
      realname.trim().isNotEmpty ? realname.trim() : nickname.trim();
}

class _GroupDetail {
  const _GroupDetail({
    required this.announcement,
    required this.announcementUpdatedAt,
    required this.canEditAnnouncement,
    required this.memberCount,
    required this.doNotDisturb,
    required this.pinned,
    this.className = '',
    this.logo = '',
    this.headTeacher,
    this.teachers = const [],
    this.students = const [],
  });

  final String announcement;
  final String announcementUpdatedAt;
  final bool canEditAnnouncement;
  final int? memberCount;
  final bool doNotDisturb;
  final bool pinned;
  final String className;
  final String logo;
  final _MemberInfo? headTeacher;
  final List<_MemberInfo> teachers;
  final List<_MemberInfo> students;
}

List<_Conversation> _sortConversations(List<_Conversation> list) {
  if (list.length <= 1) return list;
  final pinned = list.where((c) => c.pinned).toList();
  final normal = list.where((c) => !c.pinned).toList();
  return [...pinned, ...normal];
}

bool _truthyTop(Object? value) {
  if (value == true) return true;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.trim().toLowerCase();
    return v == '1' || v == 'true' || v == 'yes';
  }
  return false;
}

bool _isConversationPinned(Map<String, dynamic> m) {
  if (_truthyTop(m['top']) ||
      _truthyTop(m['isTop']) ||
      _truthyTop(m['pinned']) ||
      _truthyTop(m['isPinned'])) {
    return true;
  }
  final pinnedTime = m['pinnedTime'];
  if (pinnedTime is num) return pinnedTime != 0;
  if (pinnedTime is String) {
    final v = pinnedTime.trim();
    return v.isNotEmpty && v != '0';
  }
  return false;
}

/// classList / syncMsg 里 latestMsg 等 raw 消息 → 会话列表摘要文案。
String _previewTextForRawMessage(Map<String, dynamic> m) {
  final type = _asInt(m['type']) ?? 1;
  switch (type) {
    case 0:
      return GroupChatMessageParser._stripHtml(
        (m['text'] ?? m['content'] ?? '系统通知').toString(),
      );
    case 1:
      return GroupChatMessageParser._stripHtml((m['content'] ?? '').toString());
    case 2:
      return '[图片]';
    case 3:
      final p = (m['param1'] ?? '').toString();
      if (p == 'book') {
        final contentRaw = m['content'];
        if (contentRaw is String && contentRaw.startsWith('{')) {
          try {
            final decoded = jsonDecode(contentRaw);
            if (decoded is Map) {
              final title = (decoded['title'] ?? '').toString().trim();
              if (title.isNotEmpty) return '[课程] $title';
            }
          } catch (_) {}
        }
        return '[课程分享]';
      }
      switch (p) {
        case 'voice':
          return '[语音]';
        case 'video':
          return '[视频]';
        case 'news':
          return '[资讯]';
        case 'book':
        case 'kj':
          return '[课程分享]';
        case 'file':
          return '[文件]';
        default:
          return '[消息]';
      }
    case 100:
      return '撤回了一条消息';
    default:
      return GroupChatMessageParser._stripHtml((m['content'] ?? '').toString());
  }
}

(String, List<_RichSpan>) _parseSystemMessageParts(String content) {
  final text = content.trim();
  if (text.isEmpty) {
    return ('系统消息', const [_RichSpan('系统消息')]);
  }
  const tags = ['入群通知', '群公告', '系统消息'];
  for (final tag in tags) {
    if (text.startsWith(tag)) {
      final rest = text.substring(tag.length).trimLeft();
      return (tag, [_RichSpan(rest.isEmpty ? text : rest)]);
    }
  }
  final spaceIdx = text.indexOf(' ');
  if (spaceIdx > 0 && spaceIdx <= 6) {
    return (
      text.substring(0, spaceIdx),
      [_RichSpan(text.substring(spaceIdx + 1).trimLeft())],
    );
  }
  return ('系统消息', [_RichSpan(text)]);
}

List<_Conversation> _parseConversations(Object? raw) {
  final list = _asList(raw);
  if (list.isEmpty) return const [];
  final out = <_Conversation>[];
  for (final item in list) {
    if (item is! Map) continue;
    final m = item.map((k, v) => MapEntry(k.toString(), v));
    final id = (m['id'] ?? m['classId'])?.toString();
    if (id == null || id.isEmpty) continue;
    final name = (m['groupName'] ?? m['name'] ?? m['className'] ?? '')
        .toString();
    final latestMsgRaw =
        m['latestMsg'] ?? m['lastMsg'] ?? m['lastMessage'] ?? m['lastContent'];
    var lastMessage = '';
    DateTime? latestMsgTime;
    if (latestMsgRaw is Map) {
      final latestMap = latestMsgRaw.map((k, v) => MapEntry(k.toString(), v));
      lastMessage = _previewTextForRawMessage(latestMap);
      latestMsgTime = _parseDateTime(
        latestMap['createTime'] ??
            latestMap['sendTime'] ??
            latestMap['msgTime'],
      );
    } else if (latestMsgRaw != null) {
      final text = latestMsgRaw.toString().trim();
      if (text.isNotEmpty) lastMessage = text;
    }
    final lastTimeMs =
        m['lastTime'] ?? m['lastMsgTime'] ?? m['updateTime'] ?? latestMsgTime;
    final unreadRaw = m['unread'] ?? m['unreadCount'] ?? m['badge'] ?? 0;
    final muted =
        m['doNotDisturb'] == true ||
        m['muted'] == true ||
        m['isMute'] == true ||
        (m['doNotDisturb'] is num && (m['doNotDisturb'] as num) != 0) ||
        (m['mute'] is num && (m['mute'] as num) != 0);
    final pinned = _isConversationPinned(m);
    final memberRaw = m['memberCount'] ?? m['userCount'] ?? m['memberNum'] ?? 0;
    final logo = _resolveMediaUrl(
      (m['logo'] ?? m['groupLogo'] ?? m['avatarUrl'] ?? m['avatar'])
          ?.toString(),
    );
    out.add(
      _Conversation(
        id: id,
        name: name.isEmpty ? '群聊' : name,
        lastMessage: lastMessage,
        lastTime: _formatLastTime(_parseDateTime(lastTimeMs)),
        unread: _asInt(unreadRaw) ?? 0,
        muted: muted,
        pinned: pinned,
        memberCount: _asInt(memberRaw) ?? 0,
        avatarColor: _avatarColorFor(id),
        avatarUrl: logo.isEmpty ? null : logo,
      ),
    );
  }
  return out;
}

/// 从 msgList 接口响应构建 userId→MemberInfo 查找表。
///
/// 响应结构：`{offsetMsgId, msgList:[...], userList:[...], classList:[...]}`
/// userList 内的 headUrl 可能是相对路径，此处统一归一化。
Map<String, _MemberInfo> _buildUserMap(Object? raw) {
  if (raw is! Map) return const {};
  final userListRaw = raw['userList'];
  if (userListRaw is! List) return const {};
  final map = <String, _MemberInfo>{};
  for (final u in userListRaw) {
    if (u is! Map) continue;
    final uMap = u.map((k, v) => MapEntry(k.toString(), v));
    final id = uMap['id']?.toString() ?? '';
    if (id.isEmpty) continue;
    map[id] = _MemberInfo(
      id: id,
      realname: (uMap['realname'] ?? '').toString().trim(),
      nickname: (uMap['nickname'] ?? '').toString().trim(),
      role: (uMap['role'] ?? '').toString(),
      headUrl: _resolveMediaUrl(uMap['headUrl']?.toString()),
      mobile: uMap['mobile']?.toString(),
      gender: uMap['gender']?.toString(),
    );
  }
  return map;
}

List<_ChatMessage> _parseMessages(Object? raw) {
  // msgList 接口真实结构: {offsetMsgId, msgList:[...], userList:[...], classList:[...]}.
  // 兼容 records / list / 裸数组 多种后端结构。
  final list = _asList(
    raw is Map ? (raw['msgList'] ?? raw['records'] ?? raw['list']) : raw,
  );
  if (list.isEmpty) return const [];
  // 构建用户查找表供 parser 使用
  final userMap = _buildUserMap(raw);
  final parser = GroupChatMessageParser(userMap: userMap);
  final out = <_ChatMessage>[];
  for (final item in list) {
    if (item is! Map) continue;
    final m = item.map((k, v) => MapEntry(k.toString(), v));
    final parsed = parser.parseRaw(m);
    if (parsed is _ChatMessage) out.add(parsed);
  }
  // 后端按降序，UI 按升序。
  out.sort((a, b) => a.sentAt.compareTo(b.sentAt));
  return out;
}

_MemberInfo? _parseMemberInfo(Object? raw) {
  if (raw is! Map) return null;
  final m = raw.map((k, v) => MapEntry(k.toString(), v));
  final id = m['id']?.toString() ?? '';
  if (id.isEmpty) return null;
  return _MemberInfo(
    id: id,
    realname: (m['realname'] ?? '').toString(),
    nickname: (m['nickname'] ?? '').toString(),
    role: (m['role'] ?? '').toString(),
    headUrl: _resolveMediaUrl(m['headUrl']?.toString()),
    mobile: m['mobile']?.toString(),
    gender: m['gender']?.toString(),
  );
}

List<_MemberInfo> _parseMemberList(Object? raw) {
  final list = raw is List ? raw : [];
  final out = <_MemberInfo>[];
  for (final item in list) {
    final info = _parseMemberInfo(item);
    if (info != null) out.add(info);
  }
  return out;
}

_GroupDetail _parseGroupDetail(
  Object? raw,
  _Conversation fallback, {
  String currentUserId = '',
}) {
  final m = raw is Map
      ? raw.map((k, v) => MapEntry(k.toString(), v))
      : <String, dynamic>{};
  final schoolClass = m['schoolClass'];
  final classMap = schoolClass is Map
      ? schoolClass.map((k, v) => MapEntry(k.toString(), v))
      : const <String, dynamic>{};

  // 班级公告 / 名称 / 群头像
  final className =
      (classMap['groupName'] ??
              m['groupName'] ??
              classMap['name'] ??
              m['name'] ??
              fallback.name)
          .toString();
  final logoRaw =
      (classMap['logo'] ??
              m['logo'] ??
              classMap['groupLogo'] ??
              m['groupLogo'] ??
              fallback.avatarUrl ??
              '')
          .toString();
  final logo = logoRaw.isEmpty ? '' : _resolveMediaUrl(logoRaw);
  final announcement = (classMap['announcement'] ?? m['announcement'] ?? '')
      .toString();

  // 公告更新信息（该接口暂无 announcementTime，只展示存在性）
  final announcementBy =
      (m['announcementUserName'] ??
              m['announcementBy'] ??
              classMap['announcementUserName'] ??
              '')
          .toString();
  final announcementAt = _parseDateTime(
    m['announcementTime'] ??
        m['announcementUpdateTime'] ??
        classMap['announcementTime'],
  );
  String updatedAt = '';
  if (announcement.isNotEmpty && announcementAt != null) {
    final whenLabel = _formatLastTime(announcementAt, withDateForOldDays: true);
    updatedAt = announcementBy.isEmpty
        ? '更新于 $whenLabel'
        : '更新于 $announcementBy $whenLabel';
  } else if (announcement.isNotEmpty && announcementBy.isNotEmpty) {
    updatedAt = '更新于 $announcementBy';
  }

  // 教师 / 学生列表
  final teachers = _parseMemberList(m['teacherList']);
  final students = _parseMemberList(m['studentList']);
  final headTeacher =
      _parseMemberInfo(m['headTeacher']) ??
      (teachers.isNotEmpty ? teachers.first : null);

  // 成员总数 = 教师 + 学生（若后端没给则回退到列表长度之和）
  final memberCount =
      _asInt(m['memberCount'] ?? m['userCount'] ?? classMap['memberCount']) ??
      (teachers.length + students.length).let((n) => n > 0 ? n : null);

  // 判断当前登录用户是否有权编辑群公告：
  // 1. 后端直接返回权限标志位；
  // 2. 当前用户 ID 与班级的 headTeacherId 或 headTeacher.id 匹配；
  // 3. 当前用户 ID 与解析得到的 headTeacher 成员 ID 匹配。
  final headTeacherId = (classMap['headTeacherId'] ?? m['headTeacherId'] ?? '')
      .toString()
      .trim();
  final isHeadTeacher =
      (currentUserId.isNotEmpty &&
          (headTeacherId == currentUserId ||
              headTeacher?.id == currentUserId)) ||
      m['isHeadTeacher'] == true ||
      m['canEditAnnouncement'] == true ||
      m['isManager'] == true ||
      m['isAdmin'] == true ||
      (m['role']?.toString() == 'headTeacher') ||
      (m['role']?.toString() == 'admin');
  final canEdit = isHeadTeacher;

  final doNotDisturb =
      m['doNotDisturb'] == true ||
      m['muted'] == true ||
      m['mute'] == true ||
      (m['doNotDisturb'] is num && (m['doNotDisturb'] as num) != 0) ||
      (m['mute'] is num && (m['mute'] as num) != 0) ||
      (classMap['mute'] is num && (classMap['mute'] as num) != 0) ||
      fallback.muted;
  final pinned =
      _isConversationPinned(m) ||
      _isConversationPinned(classMap) ||
      fallback.pinned;

  return _GroupDetail(
    announcement: announcement,
    announcementUpdatedAt: updatedAt,
    canEditAnnouncement: canEdit,
    memberCount: memberCount,
    doNotDisturb: doNotDisturb,
    pinned: pinned,
    className: className,
    logo: logo,
    headTeacher: headTeacher,
    teachers: teachers,
    students: students,
  );
}

extension _LetExt<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

/// 复用既有 _UserChatMessage，把临时 `local-...` id 替换为后端真实 msgId。
_UserChatMessage _replaceUserMessageId(_UserChatMessage src, String newId) {
  return _UserChatMessage(
    id: newId,
    sentAt: src.sentAt,
    fromUserId: src.fromUserId,
    fromName: src.fromName,
    avatarUrl: src.avatarUrl,
    avatarColor: src.avatarColor,
    bubble: src.bubble,
  );
}

List<dynamic> _asList(Object? raw) {
  if (raw is List) return raw;
  if (raw is Map) {
    final inner =
        raw['msgList'] ?? raw['records'] ?? raw['list'] ?? raw['data'];
    if (inner is List) return inner;
  }
  return const [];
}

int? _asInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}

bool _isTruthy(Object? raw) {
  if (raw == null) return false;
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  final text = raw.toString().trim().toLowerCase();
  return text == 'true' || text == '1' || text == 'yes';
}

DateTime? _parseDateTime(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is num) {
    return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
  }
  if (raw is String) {
    if (raw.isEmpty) return null;
    final v = int.tryParse(raw);
    if (v != null && raw.length >= 10) {
      return DateTime.fromMillisecondsSinceEpoch(v);
    }
    return DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  }
  return null;
}

/// 给会话列表的 lastTime / 公告 updatedAt 用：今天 = HH:mm，昨天 =「昨天」，
/// 同年 = M月D日，不同年 = YYYY-MM-DD。
String _formatLastTime(DateTime? t, {bool withDateForOldDays = false}) {
  if (t == null) return '';
  final now = DateTime.now();
  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  String hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  if (sameDay(t, now)) return hm(t);
  final yesterday = now.subtract(const Duration(days: 1));
  if (sameDay(t, yesterday)) {
    return withDateForOldDays ? '昨天 ${hm(t)}' : '昨天';
  }
  if (t.year == now.year) {
    return withDateForOldDays
        ? '${t.month}月${t.day}日 ${hm(t)}'
        : '${t.month}月${t.day}日';
  }
  return withDateForOldDays
      ? '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} ${hm(t)}'
      : '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}

Color _avatarColorFor(String key) {
  const palette = <Color>[
    Color(0xFF8741FF),
    Color(0xFF325BFF),
    Color(0xFFF97316),
    Color(0xFFB98FFF),
    Color(0xFF12CE51),
    Color(0xFFFF6A00),
  ];
  if (key.isEmpty) return palette.first;
  return palette[key.hashCode.abs() % palette.length];
}

// =============================================================================
// 录音波形 demo 采样：消息解析器解析 voice 消息时，后端只回返时长，
// 没有真实波形，先用一组固定的样本充当占位。
// =============================================================================

const _kDemoWaveformIdle = <double>[
  0.5,
  1.0,
  0.4,
  0.6,
  1.0,
  0.1,
  0.25,
  0.5,
  0.6,
  0.5,
  0.25,
  0.1,
  1.0,
  0.6,
  1.0,
  0.6,
  1.0,
  0.6,
  1.0,
  1.0,
  0.6,
  1.0,
  0.6,
  1.0,
  0.4,
  0.4,
  1.0,
  0.4,
  0.4,
  0.4,
  0.4,
  0.4,
  0.4,
  0.4,
  0.25,
  0.6,
  0.6,
  0.25,
  0.6,
  1.0,
  0.25,
  0.6,
  0.25,
  0.6,
];
