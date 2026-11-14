import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../data/artwork_repository.dart';

Future<void> showReviewSettings(BuildContext context) => showAppDialog<void>(
  context: context,
  builder: (_) => const _ReviewSettingsDialog(),
);

final _reviewSettings = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  final response = await ref
      .watch(artworkRepositoryProvider)
      .getReviewSettings();
  if (!response.isSuccess || response.data is! Map) {
    throw StateError(response.displayMsg);
  }
  return Map<String, dynamic>.from(response.data as Map);
});

class _ReviewSettingsDialog extends ConsumerStatefulWidget {
  const _ReviewSettingsDialog();

  @override
  ConsumerState<_ReviewSettingsDialog> createState() =>
      _ReviewSettingsDialogState();
}

class _ReviewSettingsDialogState extends ConsumerState<_ReviewSettingsDialog> {
  final _percent = TextEditingController();
  final _review = TextEditingController();
  final _lead = TextEditingController();
  bool _ready = false;
  bool _saving = false;

  @override
  void dispose() {
    _percent.dispose();
    _review.dispose();
    _lead.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final percent = int.tryParse(_percent.text.trim());
    final review = int.tryParse(_review.text.trim());
    final lead = int.tryParse(_lead.text.trim());
    if (percent == null ||
        percent < 10 ||
        percent > 50 ||
        review == null ||
        lead == null ||
        review < 1 ||
        lead < 1) {
      AppToast.showError(context, '抽查比例填写 10 至 50，点评和复核时限填写正整数');
      return;
    }
    setState(() => _saving = true);
    final response = await ref
        .read(artworkRepositoryProvider)
        .saveReviewSettings(
          percent: percent,
          reviewHours: review,
          leadHours: lead,
        );
    if (!mounted) return;
    if (response.isSuccess) {
      ref.invalidate(_reviewSettings);
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
      AppToast.showError(context, response.errorOr('点评设置保存失败'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_reviewSettings);
    final data = state.asData?.value;
    if (data != null && !_ready) {
      _percent.text = '${data['spotCheckPercent']}';
      _review.text = '${data['reviewHours']}';
      _lead.text = '${data['leadHours']}';
      _ready = true;
    }
    return AppDialog(
      title: '点评设置',
      actions: [
        AppButton(
          label: '取消',
          variant: AppButtonVariant.secondary,
          onTap: _saving ? null : () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: '保存设置',
          onTap: data == null || _saving ? null : _save,
          loading: _saving,
        ),
      ],
      child: state.when(
        loading: () => const SizedBox(
          height: 150,
          child: Center(child: AppLoadingIndicator()),
        ),
        error: (error, _) => AppErrorState(
          title: '点评设置加载失败',
          description: '$error',
          onRetry: () => ref.invalidate(_reviewSettings),
        ),
        data: (settings) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpace.s12,
          children: [
            AppInputField(
              controller: _percent,
              label: '抽查比例（%）',
              keyboardType: TextInputType.number,
              enabled: !_saving,
            ),
            AppInputField(
              controller: _review,
              label: '点评时限（小时）',
              keyboardType: TextInputType.number,
              enabled: !_saving,
            ),
            AppInputField(
              controller: _lead,
              label: '复核时限（小时）',
              keyboardType: TextInputType.number,
              enabled: !_saving,
            ),
            Text('教学组长', style: AppText.body14Strong),
            for (final row
                in (settings['leaders'] as List? ?? []).whereType<Map>())
              Text('${row['subject']} · ${row['name']}', style: AppText.body13),
          ],
        ),
      ),
    );
  }
}
