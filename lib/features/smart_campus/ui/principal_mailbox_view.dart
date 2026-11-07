// =============================================================================
// 智慧校园「校长信箱」页（学生 / 教师 / 班主任共用）
//
// 入口：`controller.openPrincipalMailbox()` → mainView == principalMailbox。
// 返回：左上角返回 → onBack → controller.backToDashboard()。
//
// 通过右上角分段切换 compose / submitted，外白卡 970×731 占满父容器。
// 「意见反馈」已独立为全局侧栏底部入口（AppFeedbackPage）。
//
// 1) compose（校长信箱 · 写信）—— 严格对齐 Figma 绝对坐标（卡内为基准）：
//    · header 0-82：white→#F9EDFF 渐变，左 32 返回 / 中标题 / 右分段
//    · 消息类型：96-168（label 28 + gap 12 + 32 chips）
//    · 匿名：    180-244（label 28 + gap 12 + 24 自定义 44×24 开关）
//    · 正文：    272-452（label 28 + gap 12 + 140 灰底 textarea，宽 938）
//    · 上传文件：468-532 右侧（242×64 描边 #CECED1）
//    · 提交按钮：618-670 居中（240×52 紫渐变 + 阴影 + 发送图标）
//    · 卡底 731；提交按钮距底 61
//
// chips 强制 Row（mainAxisSize.min）保持单行；开关使用本文件自定义
// _AnonymousSwitch（44×24，紫底 #715EFE）以匹配 Figma 视觉。
//
// 文件上传：复用 courseware 的 `pickCoursewareFiles` + `cloudDriveControllerProvider`
// 提供的 `uploadFilePathRaw`（native 路径）/`uploadFileRaw`（web 字节）双通道
// 上传，进度回调直接驱动 _UploadTile 内 LinearProgressIndicator；成功后保存
// 后端返回的可保存 path（_AttachmentSlot.uploadedPath），提交时一并带出。
// =============================================================================

import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:the_road_of_art_flutter/core/widgets/app_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../courseware/state/cloud_drive_controller.dart';
import '../../courseware/ui/courseware_file_picker.dart';
import '../data/campus_format.dart';
import 'widgets/smart_campus_page_banner.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/principal_mailbox_repository.dart';
import 'mailbox_attachment_widgets.dart';
import 'package:the_road_of_art_flutter/core/theme/app_font.dart';

const Color _kCardBg = AppColors.surface;
const Color _kInnerGray = AppColors.surfaceSubtle;
const Color _kBorderSoft = AppColors.lineSoft;
const Color _kBorderDash = AppColors.textTertiary;
const Color _kTextDark = AppColors.ink;
const Color _kTextHint = AppColors.textPlaceholder;
const Color _kPlaceholder = AppColors.textTertiary;
const Color _kPurple = AppColors.brand;

enum _MailboxMode { compose, submitted }

enum _MsgKind { report, suggestion, other }

/// 「我提交的校长信箱」状态：
/// - sent     已发送（待校长查看 / 处理）
/// - replied  已回复
/// - closed   已关闭
enum _MailboxStatus { sent, replied, closed }

extension _MailboxStatusX on _MailboxStatus {
  /// 与后端 `status` 字段一致：0 / 1 / 2。
  int get apiCode {
    switch (this) {
      case _MailboxStatus.sent:
        return 0;
      case _MailboxStatus.replied:
        return 1;
      case _MailboxStatus.closed:
        return 2;
    }
  }

  String get label {
    switch (this) {
      case _MailboxStatus.sent:
        return '已发送';
      case _MailboxStatus.replied:
        return '已回复';
      case _MailboxStatus.closed:
        return '已关闭';
    }
  }
}

extension _MsgKindX on _MsgKind {
  /// 后端 `msgType` 字段：举报 / 建议 / 其他。
  String get apiLabel {
    switch (this) {
      case _MsgKind.report:
        return '举报';
      case _MsgKind.suggestion:
        return '建议';
      case _MsgKind.other:
        return '其他';
    }
  }
}

/// 「我提交的校长信箱」单条记录（前端模型，对齐
/// `/principalMailboxList` 返回结构里我们关心的字段）。
class _MailboxRecord {
  const _MailboxRecord({
    required this.id,
    required this.msgType,
    required this.content,
    required this.status,
    required this.createTime,
    required this.isAnonymous,
    required this.attachments,
    required this.replyContent,
    required this.replyTime,
  });

  final String id;
  final String msgType;
  final String content;
  final _MailboxStatus status;
  final String createTime;
  final bool isAnonymous;

  /// 多个附件 URL，已按英文逗号拆分。
  final List<String> attachments;

  /// 校长回复正文；状态非「已回复」时通常为空。
  final String replyContent;
  final String replyTime;
}

class PrincipalMailboxView extends ConsumerStatefulWidget {
  const PrincipalMailboxView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<PrincipalMailboxView> createState() =>
      _PrincipalMailboxViewState();
}

class _PrincipalMailboxViewState extends ConsumerState<PrincipalMailboxView> {
  _MailboxMode _mode = _MailboxMode.compose;

  // compose
  _MsgKind _kind = _MsgKind.suggestion;
  bool _anonymous = false;
  final _bodyCtrl = TextEditingController();
  _AttachmentSlot? _attachment;
  bool _submitting = false;

  // submitted（我提交的）
  _MailboxStatus _listStatus = _MailboxStatus.sent;
  bool _loadingList = false;
  List<_MailboxRecord> _records = const <_MailboxRecord>[];

  late final PrincipalMailboxRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(principalMailboxRepositoryProvider);
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    AppToast.show(context, msg);
  }

  /// 切换顶部分段：`submitted` 时按当前 `_listStatus` 拉一次校长信箱列表。
  void _switchMode(_MailboxMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    if (mode == _MailboxMode.submitted) {
      unawaited(_loadList());
    }
  }

  /// 切换「我提交的」状态过滤（已发送 / 已回复 / 已关闭），并重新拉一次。
  void _switchListStatus(_MailboxStatus status) {
    if (_listStatus == status && !_loadingList) return;
    setState(() {
      _listStatus = status;
      _records = const <_MailboxRecord>[];
    });
    unawaited(_loadList());
  }

  Future<void> _loadList() async {
    setState(() => _loadingList = true);
    try {
      final resp = await _repo.principalMailboxList(
        current: 1,
        size: 50,
        status: _listStatus.apiCode,
      );
      if (!mounted) return;
      if (!resp.isSuccess) {
        _toast(resp.displayMsg);
        setState(() => _loadingList = false);
        return;
      }
      final parsed = _parseRecords(resp.data);
      setState(() {
        _records = parsed;
        _loadingList = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingList = false);
      _toast('网络异常，请稍后再试');
    }
  }

  Future<void> _onSubmit() async {
    if (_submitting) return;
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty) {
      _toast('请先填写正文');
      return;
    }
    final att = _attachment;
    if (att != null && att.isUploading) {
      _toast('附件上传中，请稍候');
      return;
    }
    if (att != null && att.hasError) {
      _toast('附件上传失败，请重试或移除');
      return;
    }

    final sid = ref.read(appStorageProvider).cachedSchoolId.trim();
    if (sid.isEmpty || sid == '0') {
      _toast('未绑定学校');
      return;
    }

    setState(() => _submitting = true);
    try {
      final attachments = att?.uploadedPath ?? '';
      final resp = await _repo.principalMailboxSubmit(
        content: body,
        msgType: _kind.apiLabel,
        isAnonymous: _anonymous ? 1 : 0,
        attachments: attachments,
      );
      if (!mounted) return;
      if (!resp.isSuccess) {
        _toast(resp.displayMsg);
        setState(() => _submitting = false);
        return;
      }
      // 清空草稿并切到「已提交」分段，让用户看到自己的新条目。
      _bodyCtrl.clear();
      setState(() {
        _attachment = null;
        _kind = _MsgKind.suggestion;
        _submitting = false;
        _mode = _MailboxMode.submitted;
        _listStatus = _MailboxStatus.sent;
      });
      _toast('已提交，校长会尽快查看');
      unawaited(_loadList());
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast('网络异常，请稍后再试');
    }
  }

  /// 点击上传卡片：
  /// - 若当前已有附件且处于失败态 → 重试；
  /// - 否则唤起系统选择器（单文件，覆盖之前的附件）。
  ///   iOS / iPad 走 [CoursewarePickType.image] 直接进相册，避免 UIDocumentPicker。
  Future<void> _onUploadTap() async {
    final cur = _attachment;
    if (cur != null && cur.isUploading) return;
    if (cur != null && cur.hasError) {
      _retryAttachment(cur);
      return;
    }
    final pickType = !kIsWeb && Platform.isIOS
        ? CoursewarePickType.image
        : CoursewarePickType.any;
    final files = await pickCoursewareFiles(
      allowMultiple: false,
      type: pickType,
    );
    if (files.isEmpty || !mounted) return;
    final f = files.first;
    final slot = _AttachmentSlot(
      name: f.name,
      bytes: f.bytes,
      path: f.path,
      size: f.size,
    );
    if (!slot.canUpload) {
      _toast('无法读取所选文件');
      return;
    }
    setState(() => _attachment = slot);
    unawaited(_startUploadAttachment(slot));
  }

  Future<void> _startUploadAttachment(_AttachmentSlot slot) async {
    void progress(double p) {
      if (!mounted || !identical(slot, _attachment)) return;
      setState(() => slot.progress = p.clamp(0.0, 0.99));
    }

    final controller = ref.read(cloudDriveControllerProvider.notifier);
    final path = slot.path?.trim();
    final saved = path != null && path.isNotEmpty
        ? await controller.uploadFilePathRaw(
            filePath: path,
            filename: slot.name,
            onProgress: progress,
          )
        : await controller.uploadFileRaw(
            bytes: slot.bytes ?? Uint8List(0),
            filename: slot.name,
            onProgress: progress,
          );

    if (!mounted || !identical(slot, _attachment)) return;
    setState(() {
      if (saved != null && saved.isNotEmpty) {
        slot.uploadedPath = saved;
        slot.progress = 1.0;
        slot.error = null;
      } else {
        slot.error = '上传失败，点击重试';
        slot.progress = 0.0;
      }
    });
  }

  void _removeAttachment() {
    setState(() => _attachment = null);
  }

  void _retryAttachment(_AttachmentSlot slot) {
    setState(() {
      slot.error = null;
      slot.progress = 0.0;
      slot.uploadedPath = null;
    });
    unawaited(_startUploadAttachment(slot));
  }

  Widget _buildBody() {
    switch (_mode) {
      case _MailboxMode.compose:
        return _ComposeForm(
          kind: _kind,
          onKindChanged: (k) => setState(() {
            _kind = k;
            if (k == _MsgKind.report) _anonymous = true;
          }),
          anonymous: _anonymous,
          onAnonymousChanged: (v) => setState(() => _anonymous = v),
          bodyCtrl: _bodyCtrl,
          attachment: _attachment,
          onUploadTap: _onUploadTap,
          onRemoveAttachment: _removeAttachment,
          onSubmit: _onSubmit,
          submitting: _submitting,
        );
      case _MailboxMode.submitted:
        return _SubmittedList(
          status: _listStatus,
          onStatusChanged: _switchListStatus,
          loading: _loadingList,
          records: _records,
          onWriteNew: () => _switchMode(_MailboxMode.compose),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SmartCampusSecondaryPageShell(
      bodyScrollable: false,
      header: AppPageHeader(
        centerTitle: true,
        title: '校长信箱',
        subtitle: '写给画室负责人（校长）的建议、举报或其他诉求，只有校长能看到',
        onBack: widget.onBack,
        bottom: AppTabs<_MailboxMode>(
          tabs: const [
            AppTab(value: _MailboxMode.compose, label: '写信'),
            AppTab(value: _MailboxMode.submitted, label: '已提交'),
          ],
          value: _mode,
          onChanged: _switchMode,
        ),
      ),
      body: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: _kCardBg,
          borderRadius: AppRadius.br12,
        ),
        child: _buildBody(),
      ),
    );
  }
}

class _ComposeForm extends StatelessWidget {
  const _ComposeForm({
    required this.kind,
    required this.onKindChanged,
    required this.anonymous,
    required this.onAnonymousChanged,
    required this.bodyCtrl,
    required this.attachment,
    required this.onUploadTap,
    required this.onRemoveAttachment,
    required this.onSubmit,
    required this.submitting,
  });

  final _MsgKind kind;
  final ValueChanged<_MsgKind> onKindChanged;
  final bool anonymous;
  final ValueChanged<bool> onAnonymousChanged;
  final TextEditingController bodyCtrl;
  final _AttachmentSlot? attachment;
  final VoidCallback onUploadTap;
  final VoidCallback onRemoveAttachment;
  final VoidCallback onSubmit;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(16), ui(14), ui(16), ui(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('留言类型'),
          SizedBox(height: ui(8)),
          AppSegmented<_MsgKind>(
            segments: const [
              AppSegment(value: _MsgKind.suggestion, label: '建议'),
              AppSegment(value: _MsgKind.report, label: '举报'),
              AppSegment(value: _MsgKind.other, label: '其他'),
            ],
            value: kind,
            onChanged: onKindChanged,
          ),
          SizedBox(height: ui(16)),
          Row(
            children: [
              const _SectionTitle('匿名'),
              SizedBox(width: ui(12)),
              AppSwitch(
                value: anonymous,
                onChanged: onAnonymousChanged,
                semanticLabel: '匿名提交',
              ),
              SizedBox(width: ui(8)),
              Expanded(
                child: Text(
                  anonymous
                      ? '校长看到的发信人显示为「匿名」，回复在「已提交」里查看'
                      : '校长能看到你的姓名，方便当面跟进',
                  style: AppText.caption12.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          if (kind == _MsgKind.report) ...[
            SizedBox(height: ui(8)),
            Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: ui(4)),
                Text(
                  '举报内容只有校长能看到，默认匿名提交',
                  style: AppText.caption12.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: ui(16)),
          const _SectionTitle('正文'),
          SizedBox(height: ui(8)),
          _BodyField(controller: bodyCtrl, hint: '请写下你想反映的问题或建议'),
          SizedBox(height: ui(12)),
          _UploadTile(
            slot: attachment,
            onTap: onUploadTap,
            onRemove: onRemoveAttachment,
          ),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: '提交',
              icon: Icons.send_rounded,
              loading: submitting,
              onTap: submitting ? null : onSubmit,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      style: TextStyle(
        fontSize: ui(16),
        color: _kTextDark,
        fontWeight: AppFont.w500,
        height: 28 / 16,
      ),
    );
  }
}

class _BodyField extends StatelessWidget {
  const _BodyField({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _bodyInput(ui),
        SizedBox(height: ui(4)),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => Text(
            '${value.text.characters.length} / $_kMailboxMaxChars',
            style: AppText.caption12.copyWith(color: AppColors.textTertiary),
          ),
        ),
      ],
    );
  }

  Widget _bodyInput(double Function(double) ui) {
    return Container(
      height: ui(140),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: AppTextField(
        controller: controller,
        maxLines: null,
        expands: true,
        maxLength: _kMailboxMaxChars,
        textAlignVertical: TextAlignVertical.top,
        cursorColor: _kPurple,
        cursorWidth: 1.5,
        cursorHeight: ui(14),
        style: TextStyle(
          fontSize: ui(12),
          color: _kTextDark,
          fontWeight: AppFont.w400,
          height: 20 / 12,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: ui(12),
            color: _kPlaceholder,
            fontWeight: AppFont.w400,
            height: 20 / 12,
          ),
          border: InputBorder.none,
          counterText: '',
          contentPadding: EdgeInsets.all(ui(16)),
        ),
      ),
    );
  }
}

const int _kMailboxMaxChars = 500;

/// 单文件附件状态：与 courseware 上传对话框中的 `_UploadSlot` 等价的最小子集。
/// `bytes`（web）/ `path`（native）二选一，由 `pickCoursewareFiles` 决定。
class _AttachmentSlot {
  _AttachmentSlot({required this.name, this.bytes, this.path, this.size});

  final String name;
  final Uint8List? bytes;
  final String? path;
  final int? size;

  /// 0.0–1.0；上传完成后被设为 1.0。
  double progress = 0.0;

  /// 上传成功后服务器返回的可保存路径（提交校长信箱时一并带出）。
  String? uploadedPath;

  /// 失败文案；null 表示无错误。
  String? error;

  bool get isDone => uploadedPath != null;
  bool get hasError => error != null;
  bool get isUploading => !isDone && !hasError;
  bool get canUpload =>
      (bytes != null && bytes!.isNotEmpty) ||
      (path != null && path!.trim().isNotEmpty);
}

/// 上传卡片。空状态显示「上传文件」；有附件后切换为「文件名 + 状态行」并在
/// 右上角露出 × 移除按钮。点击行为：
/// - 空：iOS 打开相册，其它平台打开文件选择器
/// - 失败：触发重试
/// - 上传中：忽略
/// - 已完成：再次选择则覆盖原附件
class _UploadTile extends StatelessWidget {
  const _UploadTile({
    required this.slot,
    required this.onTap,
    required this.onRemove,
  });

  final _AttachmentSlot? slot;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final s = slot;
    return SizedBox(
      width: ui(242),
      height: ui(64),
      child: Stack(
        children: [
          Positioned.fill(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(ui(12)),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ui(16),
                  vertical: ui(10),
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ui(12)),
                  border: Border.all(color: _kBorderDash),
                ),
                child: s == null ? _buildEmpty(ui) : _buildFilled(ui, s),
              ),
            ),
          ),
          if (s != null)
            Positioned(
              right: ui(4),
              top: ui(4),
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: EdgeInsets.all(ui(4)),
                  child: Icon(
                    Icons.close_rounded,
                    size: ui(14),
                    color: _kTextHint,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty(double Function(num) ui) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.upload_file_rounded, size: ui(18), color: AppColors.ink),
        SizedBox(width: ui(4)),
        Text(
          '上传文件',
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextDark,
            fontWeight: AppFont.w500,
            height: 20 / 14,
          ),
        ),
      ],
    );
  }

  Widget _buildFilled(double Function(num) ui, _AttachmentSlot s) {
    final Widget statusIcon;
    if (s.isUploading) {
      statusIcon = const AppLoadingIndicator();
    } else if (s.isDone) {
      statusIcon = Icon(
        Icons.check_circle_rounded,
        size: ui(16),
        color: _kPurple,
      );
    } else {
      statusIcon = Icon(
        Icons.error_outline_rounded,
        size: ui(16),
        color: AppColors.danger,
      );
    }

    final String statusLabel;
    final Color statusColor;
    if (s.isUploading) {
      statusLabel = '上传中 ${(s.progress * 100).toStringAsFixed(0)}%';
      statusColor = _kTextHint;
    } else if (s.isDone) {
      statusLabel = '已上传，可点击重新选择';
      statusColor = _kTextHint;
    } else {
      statusLabel = s.error ?? '上传失败，点击重试';
      statusColor = AppColors.danger;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            statusIcon,
            SizedBox(width: ui(6)),
            Expanded(
              child: Text(
                s.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(13),
                  color: _kTextDark,
                  fontWeight: AppFont.w500,
                  height: 1.2,
                ),
              ),
            ),
            SizedBox(width: ui(14)), // 给右上 × 让位
          ],
        ),
        SizedBox(height: ui(4)),
        if (s.isUploading)
          ClipRRect(
            borderRadius: BorderRadius.circular(ui(2)),
            child: LinearProgressIndicator(
              value: s.progress,
              minHeight: ui(3),
              backgroundColor: _kInnerGray,
              valueColor: const AlwaysStoppedAnimation(_kPurple),
            ),
          )
        else
          Text(
            statusLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(12),
              color: statusColor,
              fontWeight: AppFont.w400,
              height: 1.2,
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// 「我提交的」列表
// ============================================================================

class _SubmittedList extends StatelessWidget {
  const _SubmittedList({
    required this.status,
    required this.onStatusChanged,
    required this.loading,
    required this.records,
    required this.onWriteNew,
  });

  final _MailboxStatus status;
  final ValueChanged<_MailboxStatus> onStatusChanged;
  final bool loading;
  final List<_MailboxRecord> records;
  final VoidCallback onWriteNew;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(16), ui(14), ui(16), ui(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusFilterRow(current: status, onChanged: onStatusChanged),
          SizedBox(height: ui(12)),
          Expanded(
            child: loading
                ? const Center(child: AppLoadingIndicator())
                : (records.isEmpty
                      ? _EmptyHint(status: status, onWriteNew: onWriteNew)
                      : ListView.separated(
                          padding: EdgeInsets.only(bottom: ui(8)),
                          itemBuilder: (_, i) =>
                              _MailboxRecordTile(record: records[i]),
                          separatorBuilder: (_, _) => SizedBox(height: ui(12)),
                          itemCount: records.length,
                        )),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterRow extends StatelessWidget {
  const _StatusFilterRow({required this.current, required this.onChanged});

  final _MailboxStatus current;
  final ValueChanged<_MailboxStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: AppSegmented<_MailboxStatus>(
        size: AppControlSize.sm,
        segments: [
          for (final s in _MailboxStatus.values)
            AppSegment(value: s, label: s.label),
        ],
        value: current,
        onChanged: onChanged,
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.status, required this.onWriteNew});

  final _MailboxStatus status;
  final VoidCallback onWriteNew;

  @override
  Widget build(BuildContext context) {
    final String hint;
    switch (status) {
      case _MailboxStatus.sent:
        hint = '暂无已发送的信件';
        break;
      case _MailboxStatus.replied:
        hint = '暂无已回复的信件';
        break;
      case _MailboxStatus.closed:
        hint = '暂无已关闭的信件';
        break;
    }
    return Center(
      child: AppEmptyState(
        icon: Icons.mark_email_read_outlined,
        title: hint,
        actionLabel: '写一封新信',
        onAction: onWriteNew,
      ),
    );
  }
}

/// 单条「我提交的校长信」卡片：状态徽章 + 类型 + 时间 + 正文 + 附件 / 回复折叠区。
class _MailboxRecordTile extends StatelessWidget {
  const _MailboxRecordTile({required this.record});

  final _MailboxRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hasReply = record.replyContent.trim().isNotEmpty;
    return Container(
      padding: EdgeInsets.all(ui(14)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusBadge(status: record.status),
              SizedBox(width: ui(8)),
              if (record.msgType.isNotEmpty) _KindBadge(label: record.msgType),
              if (record.isAnonymous) ...[
                SizedBox(width: ui(8)),
                const _KindBadge(label: '匿名'),
              ],
              const Spacer(),
              if (record.createTime.isNotEmpty)
                Text(
                  campusListTimeOf(
                    record.createTime,
                    fallback: record.createTime,
                  ),
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextHint,
                    fontWeight: AppFont.w400,
                    height: 1.2,
                  ),
                ),
            ],
          ),
          SizedBox(height: ui(10)),
          Text(
            record.content,
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextDark,
              fontWeight: AppFont.w400,
              height: 22 / 14,
            ),
          ),
          if (record.attachments.isNotEmpty) ...[
            SizedBox(height: ui(10)),
            Wrap(
              spacing: ui(8),
              runSpacing: ui(8),
              children: [
                for (var i = 0; i < record.attachments.length; i++)
                  MailboxAttachmentChip(
                    url: record.attachments[i],
                    onTap: () => previewMailboxAttachment(
                      context,
                      attachments: record.attachments,
                      index: i,
                      heroTagPrefix: 'mailbox_${record.id}',
                    ),
                  ),
              ],
            ),
          ],
          if (hasReply) ...[
            SizedBox(height: ui(12)),
            Container(
              padding: EdgeInsets.all(ui(12)),
              decoration: BoxDecoration(
                color: _kInnerGray,
                borderRadius: BorderRadius.circular(ui(8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.campaign_outlined,
                        size: ui(14),
                        color: _kPurple,
                      ),
                      SizedBox(width: ui(4)),
                      Text(
                        '校长回复',
                        style: TextStyle(
                          fontSize: ui(12),
                          color: _kPurple,
                          fontWeight: AppFont.w500,
                          height: 1.2,
                        ),
                      ),
                      const Spacer(),
                      if (record.replyTime.isNotEmpty)
                        Text(
                          campusListTimeOf(
                            record.replyTime,
                            fallback: record.replyTime,
                          ),
                          style: TextStyle(
                            fontSize: ui(12),
                            color: _kTextHint,
                            fontWeight: AppFont.w400,
                            height: 1.2,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: ui(6)),
                  Text(
                    record.replyContent,
                    style: TextStyle(
                      fontSize: ui(13),
                      color: _kTextDark,
                      fontWeight: AppFont.w400,
                      height: 20 / 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final _MailboxStatus status;

  @override
  Widget build(BuildContext context) {
    return AppStatusTag(
      label: status.label,
      tone: switch (status) {
        _MailboxStatus.sent => AppTone.brand,
        _MailboxStatus.replied => AppTone.success,
        _MailboxStatus.closed => AppTone.neutral,
      },
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => AppTag(label: label);
}

// ============================================================================
// 列表数据解析
// ============================================================================

/// 把后端 `principalMailboxList` 的 `data` 字段（可能是分页对象 / 数组 /
/// 嵌套 `records` 字段）安全解析为前端 [_MailboxRecord] 列表。
List<_MailboxRecord> _parseRecords(dynamic data) {
  final list = _asList(data);
  return list
      .map((e) {
        if (e is! Map) return null;
        final m = Map<String, dynamic>.from(e);
        final statusInt = _asInt(m['status']);
        final _MailboxStatus status;
        switch (statusInt) {
          case 1:
            status = _MailboxStatus.replied;
            break;
          case 2:
            status = _MailboxStatus.closed;
            break;
          default:
            status = _MailboxStatus.sent;
        }
        final attachmentsRaw = _pickString(m, const [
          'attachments',
          'attachment',
        ]);
        final attachments = attachmentsRaw
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        return _MailboxRecord(
          id: _pickString(m, const ['id', 'msgId', 'mailboxId']),
          msgType: _pickString(m, const ['msgType', 'type']),
          content: _pickString(m, const ['content', 'body']),
          status: status,
          createTime: _pickString(m, const [
            'createTime',
            'submitTime',
            'createdAt',
          ]),
          isAnonymous: _asInt(m['isAnonymous']) == 1,
          attachments: attachments,
          replyContent: _pickString(m, const [
            'replyContent',
            'reply',
            'replyMsg',
          ]),
          replyTime: _pickString(m, const ['replyTime', 'replyAt']),
        );
      })
      .whereType<_MailboxRecord>()
      .toList();
}

/// 兼容三种常见容器形态：直接数组 / `{records: [...]}` / `{list: [...]}` /
/// `{data: [...]}`。其它形态返回空数组。
List<dynamic> _asList(dynamic data) {
  if (data is List) return data;
  if (data is Map) {
    for (final key in const ['records', 'list', 'rows', 'data', 'items']) {
      final v = data[key];
      if (v is List) return v;
    }
  }
  return const <dynamic>[];
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  if (v is bool) return v ? 1 : 0;
  return 0;
}

String _pickString(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return '';
}
