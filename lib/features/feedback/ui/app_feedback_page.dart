import 'dart:async';

import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../app/router/route_paths.dart';
import '../../shell/ui/shell_layout.dart';
import '../../smart_campus/data/principal_mailbox_repository.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

const Color _kInnerGray = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kPlaceholder = Color(0xFFCECED1);
const Color _kPurple = Color(0xFF8741FF);

/// 意见反馈页返回：统一回到个人中心（个人中心入口为 pushReplacement，不能依赖 pop）。
void _backFromFeedback(BuildContext context) {
  Navigator.of(context).pushReplacementNamed(RoutePaths.personalCenter);
}

/// 全局「意见反馈」页：与校长信箱分离，走 `/app/user/feedback*` 接口。
class AppFeedbackPage extends ConsumerStatefulWidget {
  const AppFeedbackPage({super.key});

  @override
  ConsumerState<AppFeedbackPage> createState() => _AppFeedbackPageState();
}

class _AppFeedbackPageState extends ConsumerState<AppFeedbackPage> {
  final _bodyCtrl = TextEditingController();
  bool _submitting = false;
  bool _loading = false;
  List<FeedbackRecord> _records = const <FeedbackRecord>[];

  late final PrincipalMailboxRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(principalMailboxRepositoryProvider);
    unawaited(_loadFeedback());
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    AppToast.show(context, msg);
  }

  Future<void> _loadFeedback() async {
    setState(() => _loading = true);
    try {
      final resp = await _repo.feedbackList(current: 1, size: 50);
      if (!mounted) return;
      if (!resp.isSuccess) {
        _toast(resp.displayMsg);
        setState(() => _loading = false);
        return;
      }
      setState(() {
        _records = parseFeedbackRecords(resp.data);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('网络异常，请稍后再试');
    }
  }

  Future<void> _onSubmit() async {
    if (_submitting) return;
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty) {
      _toast('请先填写反馈内容');
      return;
    }
    setState(() => _submitting = true);
    try {
      final resp = await _repo.feedbackSave(content: body);
      if (!mounted) return;
      if (!resp.isSuccess) {
        _toast(resp.displayMsg);
        setState(() => _submitting = false);
        return;
      }
      _bodyCtrl.clear();
      setState(() => _submitting = false);
      _toast('已提交反馈，感谢你的建议');
      unawaited(_loadFeedback());
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast('网络异常，请稍后再试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return ShellPageSurface(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ui(ShellLayoutSpec.panelRadius)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FeedbackHeader(
              ui: ui,
              onBack: () => _backFromFeedback(context),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(ui(16), ui(14), ui(16), ui(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const _SectionTitle('我的反馈'),
                        const Spacer(),
                        if (_records.isNotEmpty)
                          Text(
                            '共 ${_records.length} 条',
                            style: TextStyle(
                              fontSize: ui(12),
                              color: _kTextHint,
                              fontFamily: 'PingFang SC',
                              fontWeight: AppFont.w400,
                              height: 1.2,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: ui(12)),
                    Expanded(
                      child: _loading
                          ? const Center(
                              child: AppLoadingIndicator(),
                            )
                          : (_records.isEmpty
                                ? const _FeedbackEmptyHint()
                                : ListView.separated(
                                    padding: EdgeInsets.only(bottom: ui(8)),
                                    itemBuilder: (_, i) => _FeedbackTile(
                                      record: _records[i],
                                    ),
                                    separatorBuilder: (_, _) =>
                                        SizedBox(height: ui(10)),
                                    itemCount: _records.length,
                                  )),
                    ),
                    SizedBox(height: ui(12)),
                    Transform.translate(
                      offset: Offset(0, -ui(10)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _SectionTitle('写新反馈'),
                          SizedBox(height: ui(8)),
                          _BodyField(
                            controller: _bodyCtrl,
                            hint: '请描述你的意见或建议（如功能改进、体验优化等）',
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: ui(12)),
                    Align(
                      alignment: Alignment.center,
                      child: _SubmitButton(
                        label: _submitting ? '提交中…' : '提交给音乐之路',
                        onTap: _submitting ? null : _onSubmit,
                        busy: _submitting,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FeedbackRecord {
  const FeedbackRecord({
    required this.id,
    required this.content,
    required this.createTime,
    required this.replyContent,
    required this.replyTime,
  });

  final String id;
  final String content;
  final String createTime;
  final String replyContent;
  final String replyTime;
}

List<FeedbackRecord> parseFeedbackRecords(dynamic data) {
  final list = _asList(data);
  return list
      .map((e) {
        if (e is! Map) return null;
        final m = Map<String, dynamic>.from(e);
        return FeedbackRecord(
          id: _pickString(m, const ['id', 'feedbackId']),
          content: _pickString(m, const ['content', 'body', 'feedback']),
          createTime: _pickString(m, const [
            'createTime',
            'submitTime',
            'createdAt',
          ]),
          replyContent: _pickString(m, const [
            'replyContent',
            'reply',
            'replyMsg',
          ]),
          replyTime: _pickString(m, const ['replyTime', 'replyAt']),
        );
      })
      .whereType<FeedbackRecord>()
      .toList();
}

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

String _pickString(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return '';
}

class _FeedbackHeader extends StatelessWidget {
  const _FeedbackHeader({required this.ui, required this.onBack});

  final double Function(num) ui;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ui(82),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              AppAssets.infoTopBg,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          Positioned(
            left: ui(12),
            top: ui(15),
            child: _FeedbackBackButton(onTap: onBack),
          ),
          Positioned(
            top: ui(20),
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '意见反馈',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ui(16),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: ui(4)),
                Text(
                  '可将需要的资料或建议反馈，工作人员会尽快处理',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextHint,
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
    );
  }
}

class _FeedbackBackButton extends StatelessWidget {
  const _FeedbackBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: ui(32),
        height: ui(32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3), width: 1),
        ),
        child: Icon(
          Icons.chevron_left,
          size: ui(20),
          color: const Color(0xFF0B081A),
        ),
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
        fontFamily: 'PingFang SC',
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
        textAlignVertical: TextAlignVertical.top,
        cursorColor: _kPurple,
        cursorWidth: 1.5,
        cursorHeight: ui(14),
        style: TextStyle(
          fontSize: ui(12),
          color: _kTextDark,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 20 / 12,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: ui(12),
            color: _kPlaceholder,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 20 / 12,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(ui(16)),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final disabled = onTap == null || busy;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Opacity(
        opacity: disabled ? 0.7 : 1.0,
        child: Container(
          width: ui(240),
          height: ui(52),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
            ),
            borderRadius: BorderRadius.circular(ui(12)),
            boxShadow: [
              BoxShadow(
                color: const Color(0x59AD80FF),
                blurRadius: ui(20),
                offset: Offset(0, ui(16)),
              ),
            ],
          ),
          child: busy
              ? const AppLoadingIndicator(size: 16, color: Colors.white)
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: Colors.white,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1,
                  ),
                ),
        ),
      ),
    );
  }
}

class _FeedbackEmptyHint extends StatelessWidget {
  const _FeedbackEmptyHint();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: ui(48), color: _kPlaceholder),
          SizedBox(height: ui(12)),
          Text(
            '暂无历史反馈，欢迎在下方提一条',
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackTile extends StatelessWidget {
  const _FeedbackTile({required this.record});

  final FeedbackRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hasReply = record.replyContent.trim().isNotEmpty;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(10)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ui(8),
                  vertical: ui(2),
                ),
                decoration: BoxDecoration(
                  color: hasReply
                      ? const Color(0xFF35BD7C).withValues(alpha: 0.12)
                      : _kPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(ui(4)),
                ),
                child: Text(
                  hasReply ? '已回复' : '已提交',
                  style: TextStyle(
                    fontSize: ui(11),
                    color: hasReply ? const Color(0xFF35BD7C) : _kPurple,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.4,
                  ),
                ),
              ),
              const Spacer(),
              if (record.createTime.isNotEmpty)
                Text(
                  record.createTime,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.2,
                  ),
                ),
            ],
          ),
          SizedBox(height: ui(8)),
          Text(
            record.content,
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 20 / 13,
            ),
          ),
          if (hasReply) ...[
            SizedBox(height: ui(10)),
            Container(
              padding: EdgeInsets.all(ui(10)),
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
                        Icons.support_agent_rounded,
                        size: ui(14),
                        color: _kPurple,
                      ),
                      SizedBox(width: ui(4)),
                      Text(
                        '官方回复',
                        style: TextStyle(
                          fontSize: ui(12),
                          color: _kPurple,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w500,
                          height: 1.2,
                        ),
                      ),
                      const Spacer(),
                      if (record.replyTime.isNotEmpty)
                        Text(
                          record.replyTime,
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
                  SizedBox(height: ui(6)),
                  Text(
                    record.replyContent,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 20 / 12,
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
