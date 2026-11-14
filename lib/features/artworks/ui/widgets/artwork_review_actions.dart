import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../data/artwork_models.dart';
import '../../data/artwork_rules.dart';
import '../../state/artwork_review_controller.dart';

const artworkLeadReasonLabels = <String, String>{
  'REQUESTED': '老师请求',
  'SCORE_ANOMALY': '分数异常',
  'BRIEF': '点评过简',
  'SPOT_CHECK': '抽查',
};

class ArtworkLeadReviewForm extends ConsumerStatefulWidget {
  const ArtworkLeadReviewForm({required this.detail, super.key});

  final ArtworkDetail detail;

  @override
  ConsumerState<ArtworkLeadReviewForm> createState() =>
      _ArtworkLeadReviewFormState();
}

class _ArtworkLeadReviewFormState extends ConsumerState<ArtworkLeadReviewForm> {
  String _action = 'KEEP';
  int _stars = 0;
  late final _score = TextEditingController(
    text: widget.detail.review?.score == null
        ? ''
        : ArtworkRules.formatScore(widget.detail.review!.score),
  );
  final _reason = TextEditingController();
  final _content = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _score.dispose();
    _reason.dispose();
    _content.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = artworkReviewControllerProvider(widget.detail.work.id);
    final busy = ref.watch(provider.select((state) => state.saving));
    return AppCard(
      title: '提交复核',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.s12,
        children: [
          AppSegmented<String>(
            value: _action,
            onChanged: (value) => setState(() => _action = value),
            segments: const [
              AppSegment(value: 'KEEP', label: '维持'),
              AppSegment(value: 'ADJUST', label: '调分'),
              AppSegment(value: 'SUPPLEMENT', label: '补充评语'),
            ],
          ),
          if (_action == 'ADJUST') ...[
            AppInputField(
              controller: _score,
              label: '调整后分数',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            AppInputField(
              controller: _reason,
              label: '调分理由（至少 10 字）',
              multiline: true,
              minLines: 2,
              maxLines: 4,
            ),
          ],
          if (_action == 'SUPPLEMENT')
            AppInputField(
              controller: _content,
              label: '组长评语',
              multiline: true,
              minLines: 2,
              maxLines: 4,
            ),
          Text('点评质量（必选）', style: AppText.body14Strong),
          Wrap(
            spacing: AppSpace.s4,
            children: [
              for (var i = 1; i <= 5; i++)
                AppIconButton(
                  icon: i <= _stars ? Icons.star : Icons.star_border,
                  semanticLabel: '$i 星',
                  filled: false,
                  size: AppButtonSize.sm,
                  color: i <= _stars
                      ? AppColors.brand
                      : AppColors.textSecondary,
                  onTap: busy ? null : () => setState(() => _stars = i),
                ),
            ],
          ),
          AppInputField(controller: _note, label: '点评质量意见（可选）'),
          AppButton(
            label: '提交复核',
            expand: true,
            loading: busy,
            onTap: busy
                ? null
                : () async {
                    final error = await ref
                        .read(provider.notifier)
                        .submitLeadReview(
                          action: _action,
                          qualityStars: _stars,
                          score: _action == 'ADJUST'
                              ? double.tryParse(_score.text.trim())
                              : null,
                          reason: _action == 'ADJUST' ? _reason.text : '',
                          content: _action == 'SUPPLEMENT' ? _content.text : '',
                          qualityNote: _note.text,
                        );
                    if (!context.mounted) return;
                    if (error != null) AppToast.showError(context, error);
                  },
          ),
        ],
      ),
    );
  }
}

class ArtworkSupplementReviewForm extends ConsumerStatefulWidget {
  const ArtworkSupplementReviewForm({required this.artworkId, super.key});

  final String artworkId;

  @override
  ConsumerState<ArtworkSupplementReviewForm> createState() =>
      _ArtworkSupplementReviewFormState();
}

class _ArtworkSupplementReviewFormState
    extends ConsumerState<ArtworkSupplementReviewForm> {
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = artworkReviewControllerProvider(widget.artworkId);
    final busy = ref.watch(provider.select((state) => state.saving));
    return AppCard(
      title: '补充点评',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.s8,
        children: [
          AppInputField(
            controller: _comment,
            label: '补充评语（至少 5 字）',
            multiline: true,
            minLines: 2,
            maxLines: 4,
          ),
          AppButton(
            label: '提交补充评语',
            loading: busy,
            onTap: busy
                ? null
                : () async {
                    final error = await ref
                        .read(provider.notifier)
                        .supplement(_comment.text);
                    if (!context.mounted) return;
                    if (error == null) {
                      _comment.clear();
                      AppToast.showSuccess(context, '补充评语已提交');
                    } else {
                      AppToast.showError(context, error);
                    }
                  },
          ),
        ],
      ),
    );
  }
}
