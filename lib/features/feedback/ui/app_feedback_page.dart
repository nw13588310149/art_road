import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../smart_campus/data/principal_mailbox_repository.dart';

const _kMaxLength = 500;

/// 全局「意见反馈」页：与校长信箱分离，走 `/app/user/feedback*` 接口。
class AppFeedbackPage extends ConsumerStatefulWidget {
  const AppFeedbackPage({super.key});

  @override
  ConsumerState<AppFeedbackPage> createState() => _AppFeedbackPageState();
}

class _AppFeedbackPageState extends ConsumerState<AppFeedbackPage> {
  final _bodyCtrl = TextEditingController();
  bool _submitting = false;
  bool _loading = true;
  String? _loadError;
  String? _formError;
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

  Future<void> _loadFeedback() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final resp = await _repo.feedbackList(current: 1, size: 50);
      if (!mounted) return;
      if (!resp.isSuccess) {
        setState(() {
          _loading = false;
          _loadError = resp.displayMsg;
        });
        return;
      }
      setState(() {
        _records = parseFeedbackRecords(resp.data);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '网络异常，请检查网络后重试';
      });
    }
  }

  Future<void> _onSubmit() async {
    if (_submitting) return;
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty) {
      setState(() => _formError = '请先填写反馈内容');
      return;
    }
    setState(() => _submitting = true);
    try {
      final resp = await _repo.feedbackSave(content: body);
      if (!mounted) return;
      setState(() => _submitting = false);
      if (!resp.isSuccess) {
        AppToast.showError(context, resp.displayMsg);
        return;
      }
      _bodyCtrl.clear();
      AppToast.showSuccess(context, '反馈已提交，回复会显示在「我的反馈」中');
      unawaited(_loadFeedback());
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppToast.showError(context, '网络异常，请稍后重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    final form = _FeedbackForm(
      controller: _bodyCtrl,
      errorText: _formError,
      submitting: _submitting,
      onChanged: () {
        if (_formError != null) {
          setState(() => _formError = null);
        }
      },
      onSubmit: _onSubmit,
    );
    final history = _FeedbackHistory(
      loading: _loading,
      error: _records.isEmpty ? _loadError : null,
      records: _records,
      onRetry: _loadFeedback,
    );
    return AppCard(
      padding: EdgeInsets.zero,
      bordered: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPageHeader(
            title: '意见反馈',
            subtitle: '想要的范画资料、功能建议都可以告诉我们',
            onBack: navigator.canPop() ? navigator.pop : null,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxHeight < 460) {
                    return ListView(
                      children: [
                        SizedBox(height: 240, child: history),
                        const SizedBox(height: AppSpace.s12),
                        form,
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: history),
                      const SizedBox(height: AppSpace.s12),
                      form,
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackForm extends StatelessWidget {
  const _FeedbackForm({
    required this.controller,
    required this.errorText,
    required this.submitting,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String? errorText;
  final bool submitting;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: '写新反馈',
      padding: EdgeInsets.zero,
      bordered: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppInputField(
            controller: controller,
            hint: '请描述你的意见或建议，如想要的范画资源、作品点评或画室工具的使用体验',
            multiline: true,
            minLines: 4,
            maxLines: 4,
            maxLength: _kMaxLength,
            errorText: errorText,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: AppSpace.s8),
          Text('反馈会发送给美术之路产品团队，回复会显示在「我的反馈」中。', style: AppText.caption12),
          const SizedBox(height: AppSpace.s16),
          Center(
            child: SizedBox(
              width: 240,
              child: AppButton(
                label: '提交反馈',
                loading: submitting,
                expand: true,
                onTap: onSubmit,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackHistory extends StatelessWidget {
  const _FeedbackHistory({
    required this.loading,
    required this.error,
    required this.records,
    required this.onRetry,
  });

  final bool loading;
  final String? error;
  final List<FeedbackRecord> records;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (loading && records.isEmpty) {
      content = ListView(
        padding: const EdgeInsets.all(AppSpace.s16),
        children: const [
          AppSkeletonText(lines: 3),
          SizedBox(height: AppSpace.s24),
          AppSkeletonText(lines: 3),
        ],
      );
    } else if (error != null) {
      content = AppErrorState(
        title: '反馈记录加载失败',
        description: error,
        onRetry: onRetry,
      );
    } else if (records.isEmpty) {
      content = const AppEmptyState(
        icon: Icons.forum_outlined,
        title: '还没有提交过反馈',
        description: '写下你的意见或建议，提交后可以在这里查看回复',
      );
    } else {
      content = ListView.builder(
        padding: const EdgeInsets.only(bottom: AppSpace.s8),
        itemCount: records.length,
        itemBuilder: (_, i) =>
            _FeedbackTile(record: records[i], divider: i < records.length - 1),
      );
    }
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s16,
              AppSpace.s16,
              AppSpace.s16,
              AppSpace.s4,
            ),
            child: Row(
              children: [
                Text('我的反馈', style: AppText.title16),
                const Spacer(),
                if (records.isNotEmpty)
                  Text.rich(
                    TextSpan(
                      style: AppText.caption12,
                      children: [
                        const TextSpan(text: '共 '),
                        TextSpan(
                          text: '${records.length}',
                          style: AppText.number(
                            size: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const TextSpan(text: ' 条'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}

class _FeedbackTile extends StatelessWidget {
  const _FeedbackTile({required this.record, required this.divider});

  final FeedbackRecord record;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final hasReply = record.replyContent.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(AppSpace.s16),
      decoration: BoxDecoration(
        border: divider
            ? const Border(bottom: BorderSide(color: AppColors.lineSoft))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppTag(
                label: hasReply ? '已回复' : '待回复',
                tone: hasReply ? AppTone.success : AppTone.warning,
              ),
              const Spacer(),
              if (record.createTime.isNotEmpty)
                Text(
                  formatFeedbackTime(record.createTime),
                  style: AppText.caption12,
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          Text(record.content, style: AppText.body14),
          if (hasReply) ...[
            const SizedBox(height: AppSpace.s12),
            Container(
              padding: const EdgeInsets.all(AppSpace.s12),
              decoration: const BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: AppRadius.br8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.support_agent_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpace.s4),
                      Text('官方回复', style: AppText.caption12Strong),
                      const Spacer(),
                      if (record.replyTime.isNotEmpty)
                        Text(
                          formatFeedbackTime(record.replyTime),
                          style: AppText.caption12,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Text(record.replyContent, style: AppText.body13),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 列表时间统一为「MM-DD HH:mm」，不显示秒；无法解析时原样返回。
String formatFeedbackTime(String raw) {
  final parsed = DateTime.tryParse(raw.trim());
  if (parsed == null) {
    return raw;
  }
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(parsed.month)}-${two(parsed.day)} '
      '${two(parsed.hour)}:${two(parsed.minute)}';
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
